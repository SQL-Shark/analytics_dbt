#!/bin/bash
# scripts/init-multiple-databases.sh
# Initialize multiple PostgreSQL databases for the Chicago Crimes pipeline

set -e
set -u

# Function to create database if it doesn't exist
function create_database() {
    local database=$1
    local owner=${2:-$POSTGRES_USER}
    
    echo "Creating database '$database' with owner '$owner'..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'CREATE DATABASE $database'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
        
        GRANT ALL PRIVILEGES ON DATABASE $database TO $owner;
EOSQL
    
    echo "Database '$database' created successfully."
}

# Function to create schema within a database
function create_schema() {
    local database=$1
    local schema=$2
    local owner=${3:-$POSTGRES_USER}
    
    echo "Creating schema '$schema' in database '$database'..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$database" <<-EOSQL
        CREATE SCHEMA IF NOT EXISTS $schema;
        GRANT ALL PRIVILEGES ON SCHEMA $schema TO $owner;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA $schema TO $owner;
        ALTER DEFAULT PRIVILEGES IN SCHEMA $schema GRANT ALL PRIVILEGES ON TABLES TO $owner;
EOSQL
    
    echo "Schema '$schema' created successfully in database '$database'."
}

# Main execution
echo "Starting database initialization..."

# Parse comma-separated database names from environment variable
if [ -n "${POSTGRES_MULTIPLE_DATABASES:-}" ]; then
    echo "Creating multiple databases: $POSTGRES_MULTIPLE_DATABASES"
    
    # Split by comma and create each database
    IFS=',' read -ra DATABASES <<< "$POSTGRES_MULTIPLE_DATABASES"
    for db in "${DATABASES[@]}"; do
        # Trim whitespace
        db=$(echo "$db" | xargs)
        
        # Skip if it's the main database (already exists)
        if [ "$db" != "$POSTGRES_DB" ]; then
            create_database "$db"
        fi
    done
fi

# Create schemas in the analytics database
echo "Setting up analytics database schemas..."

# Create schemas for dbt models
create_schema "analytics" "staging" "$POSTGRES_USER"
create_schema "analytics" "dw" "$POSTGRES_USER"
create_schema "analytics" "raw" "$POSTGRES_USER"

# Create schema for dbt metadata
create_schema "analytics" "dbt_meta" "$POSTGRES_USER"

# Set up the airbyte database with proper schema
if [ -n "${AIRBYTE_DB_PASSWORD:-}" ]; then
    echo "Setting up Airbyte database..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "airbyte" <<-EOSQL
        -- Create airbyte user if it doesn't exist
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'airbyte') THEN
                CREATE USER airbyte WITH PASSWORD '$AIRBYTE_DB_PASSWORD';
            END IF;
        END
        \$\$;
        
        -- Grant privileges to airbyte user
        GRANT ALL PRIVILEGES ON DATABASE airbyte TO airbyte;
        GRANT ALL PRIVILEGES ON SCHEMA public TO airbyte;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO airbyte;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO airbyte;
EOSQL
    
    echo "Airbyte database setup completed."
fi

# Create extensions in analytics database
echo "Installing PostgreSQL extensions..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "analytics" <<-EOSQL
    -- UUID extension for generating unique identifiers
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- PostGIS for geospatial data (optional, for location analysis)
    -- CREATE EXTENSION IF NOT EXISTS "postgis";
    
    -- Additional useful extensions
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
EOSQL

# Create sample views and functions for analytics
echo "Creating utility functions and views..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "analytics" <<-EOSQL
    -- Function to get table row counts
    CREATE OR REPLACE FUNCTION dbt_meta.get_table_stats()
    RETURNS TABLE(
        schema_name text,
        table_name text,
        row_count bigint,
        size_mb numeric
    ) AS \$\$
    BEGIN
        RETURN QUERY
        SELECT 
            schemaname::text,
            tablename::text,
            n_tup_ins - n_tup_del as row_count,
            round((pg_total_relation_size(schemaname||'.'||tablename))::numeric / 1024 / 1024, 2) as size_mb
        FROM pg_stat_user_tables
        WHERE schemaname IN ('staging', 'dw', 'raw')
        ORDER BY size_mb DESC;
    END;
    \$\$ LANGUAGE plpgsql;

    -- View for monitoring dbt model freshness
    CREATE OR REPLACE VIEW dbt_meta.model_freshness AS
    SELECT 
        schemaname as schema_name,
        tablename as table_name,
        n_tup_ins as total_inserts,
        n_tup_upd as total_updates,
        n_tup_del as total_deletes,
        last_autovacuum,
        last_autoanalyze
    FROM pg_stat_user_tables
    WHERE schemaname IN ('staging', 'dw');

    -- Grant permissions on utility objects
    GRANT EXECUTE ON FUNCTION dbt_meta.get_table_stats() TO $POSTGRES_USER;
    GRANT SELECT ON dbt_meta.model_freshness TO $POSTGRES_USER;
EOSQL

echo "Database initialization completed successfully!"

# Display summary
echo ""
echo "=== Database Setup Summary ==="
echo "✅ Main database: $POSTGRES_DB"
echo "✅ Additional databases: ${POSTGRES_MULTIPLE_DATABASES:-none}"
echo "✅ Analytics schemas: staging, dw, raw, dbt_meta"
echo "✅ Extensions: uuid-ossp, pg_stat_statements, pg_trgm"
echo "✅ Utility functions and views created"
echo ""
echo "You can now connect to the databases using:"
echo "  Analytics: psql -h localhost -U $POSTGRES_USER -d analytics"
echo "  Airbyte:   psql -h localhost -U airbyte -d airbyte"
echo "  Metabase:  psql -h localhost -U $POSTGRES_USER -d metabase"
echo ""
echo "=== Next Steps ==="
echo "1. Start Airbyte and configure data sources"
echo "2. Run dbt models: cd dbt_project/chicago_crimes && dbt run"
echo "3. Set up Metabase dashboards"
echo "4. Explore the data using Adminer at http://localhost:8080"
echo ""