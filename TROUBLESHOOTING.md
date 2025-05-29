# Troubleshooting Guide

This guide covers common issues you might encounter when setting up and running the Chicago Crimes Data Pipeline.

## 🚨 Quick Diagnostics

### Health Check Script
Run this command to check the status of all services:

```bash
# Check all container status
docker compose ps

# Check service health
docker compose exec postgres pg_isready -U postgres
curl -s http://localhost:8000/api/v1/health  # Airbyte
curl -s http://localhost:3000/api/health     # Metabase
```

### Log Inspection
```bash
# View logs for specific services
docker compose logs postgres
docker compose logs airbyte-server
docker compose logs metabase

# Follow logs in real-time
docker compose logs -f airbyte-server

# View logs with timestamps
docker compose logs -t postgres
```

## 🐳 Docker Issues

### Issue: Permission Denied
```
Error: Got permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Alternative: Fix socket permissions
sudo chmod 666 /var/run/docker.sock
```

### Issue: Port Already in Use
```
Error: Port 5432 is already allocated
```

**Solution:**
```bash
# Find what's using the port
sudo netstat -tulpn | grep :5432
sudo lsof -i :5432

# Kill the process or change port in .env file
POSTGRES_PORT=5433
```

### Issue: Out of Memory
```
Error: Container killed due to memory pressure
```

**Solution:**
```bash
# Check Docker memory usage
docker stats

# Increase Docker memory allocation:
# Docker Desktop: Settings → Resources → Memory → 8GB+

# On Linux: Check available memory
free -h

# Stop unnecessary containers
docker compose down
docker system prune -f
```

### Issue: Container Won't Start
```
Error: Container exited with code 1
```

**Solution:**
```bash
# Check specific container logs
docker compose logs [service_name]

# Remove and recreate containers
docker compose down
docker compose up --force-recreate

# Clean up and restart
docker system prune -f
docker compose up -d
```

## 🗄️ PostgreSQL Issues

### Issue: Connection Refused
```
Error: Connection to localhost:5432 refused
```

**Solutions:**
```bash
# 1. Check if PostgreSQL container is running
docker compose ps postgres

# 2. Check PostgreSQL logs
docker compose logs postgres

# 3. Test connection from host
psql -h localhost -U postgres -d analytics

# 4. Test connection from inside container
docker exec -it postgres_db psql -U postgres -d analytics

# 5. Check if port is bound correctly
docker port postgres_db 5432
```

### Issue: Authentication Failed
```
Error: password authentication failed for user "postgres"
```

**Solutions:**
```bash
# 1. Check .env file has correct password
cat .env | grep POSTGRES_PASSWORD

# 2. Recreate container with new password
docker compose down
docker volume rm chicago-crimes-data-pipeline_postgres_data
docker compose up -d

# 3. Reset PostgreSQL password
docker exec -it postgres_db psql -U postgres -c "ALTER USER postgres PASSWORD 'newpassword';"
```

### Issue: Database Does Not Exist
```
Error: database "analytics" does not exist
```

**Solutions:**
```bash
# 1. Check if init script ran successfully
docker compose logs postgres | grep "database system is ready"

# 2. Manually create database
docker exec -it postgres_db createdb -U postgres analytics

# 3. Check database list
docker exec -it postgres_db psql -U postgres -l
```

### Issue: Permission Denied on Schema
```
Error: permission denied for schema public
```

**Solutions:**
```bash
# Grant proper permissions
docker exec -it postgres_db psql -U postgres -d analytics -c "
GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO postgres;
"
```

## 🔄 Airbyte Issues

### Issue: Airbyte UI Not Loading
```
Error: This site can't be reached (localhost:8000)
```

**Solutions:**
```bash
# 1. Check Airbyte containers
docker compose ps | grep airbyte

# 2. Check Airbyte server logs
docker compose logs airbyte-server

# 3. Restart Airbyte services
docker compose restart airbyte-server airbyte-worker airbyte-webapp

# 4. Check port binding
docker port airbyte_webapp 80
```

### Issue: Can't Connect to PostgreSQL from Airbyte
```
Error: Connection test failed
```

**Solutions:**
```bash
# 1. Use correct host name in Airbyte connection:
# ❌ Wrong: localhost, 127.0.0.1
# ✅ Correct: postgres (Docker service name)

# 2. Test connection from Airbyte container
docker exec -it airbyte_server ping postgres
docker exec -it airbyte_server telnet postgres 5432

# 3. Check if containers are on same network
docker network inspect chicago-crimes-network
```

### Issue: Airbyte Sync Fails
```
Error: Sync failed with error code 1
```

**Solutions:**
```bash
# 1. Check worker logs
docker compose logs airbyte-worker

# 2. Check source data accessibility
curl -I "https://data.cityofchicago.org/resource/crimes.csv"

# 3. Verify destination permissions
docker exec -it postgres_db psql -U postgres -d analytics -c "SELECT 1;"

# 4. Reset connection
# In Airbyte UI: Connections → [Your Connection] → Settings → Reset Data
```

### Issue: Airbyte Database Migration Fails
```
Error: Database migration failed
```

**Solutions:**
```bash
# 1. Check Airbyte database
docker compose logs airbyte-db

# 2. Reset Airbyte database
docker compose down
docker volume rm chicago-crimes-data-pipeline_airbyte_db_data
docker compose up -d

# 3. Check Airbyte DB connection
docker exec -it airbyte_db psql -U airbyte -d airbyte -c "SELECT version();"
```

## 📊 dbt Issues

### Issue: dbt Command Not Found
```
Error: dbt: command not found
```

**Solutions:**
```bash
# 1. Activate virtual environment
source .venv/bin/activate

# 2. Install dbt
pip install dbt-postgres

# 3. Check dbt installation
dbt --version

# 4. Add to PATH (if needed)
export PATH=$PATH:~/.local/bin
```

### Issue: dbt Connection Failed
```
Error: Database Error - could not connect to server
```

**Solutions:**
```bash
# 1. Test dbt connection
dbt debug

# 2. Check profiles.yml location
ls -la ~/.dbt/profiles.yml

# 3. Verify profiles.yml content
cat ~/.dbt/profiles.yml

# 4. Test PostgreSQL connection manually
psql -h localhost -U postgres -d analytics
```

### Issue: dbt Models Fail to Run
```
Error: Compilation Error in model 'dim_crime_type'
```

**Solutions:**
```bash
# 1. Check for syntax errors
dbt compile

# 2. Run with debug output
dbt run --debug

# 3. Check source data exists
dbt source freshness

# 4. Verify source configuration
dbt run-operation list_sources
```

### Issue: dbt Tests Fail
```
Error: FAIL 1184 unique_fact_crime_incidents_incident_key
```

**Solutions:**
```bash
# 1. Investigate specific test failure
dbt test --select fact_crime_incidents

# 2. Check for data quality issues
dbt run-operation debug_test --args '{"test_name": "unique_fact_crime_incidents_incident_key"}'

# 3. Examine failing records
# In PostgreSQL, run the compiled test query to see duplicates

# 4. Fix upstream data quality issues
dbt run --models staging
dbt test --models staging
```

### Issue: dbt Packages Won't Install
```
Error: Could not find a version that satisfies the requirement
```

**Solutions:**
```bash
# 1. Check packages.yml syntax
cat packages.yml

# 2. Update dbt packages
dbt deps --upgrade

# 3. Clear package cache
rm -rf dbt_packages/
dbt deps

# 4. Check internet connectivity
curl -I https://hub.getdbt.com/
```

## 📈 Metabase Issues

### Issue: Metabase Won't Start
```
Error: Metabase initialization failed
```

**Solutions:**
```bash
# 1. Check Metabase logs
docker compose logs metabase

# 2. Check memory allocation
docker stats metabase

# 3. Increase memory limit in docker-compose.yml
metabase:
  deploy:
    resources:
      limits:
        memory: 2G

# 4. Reset Metabase data
docker compose down
docker volume rm chicago-crimes-data-pipeline_metabase_data
docker compose up -d
```

### Issue: Can't Connect Metabase to PostgreSQL
```
Error: Database connection failed
```

**Solutions:**
```bash
# 1. Use correct connection details in Metabase:
# Host: postgres (not localhost)
# Port: 5432
# Database: analytics
# Username: postgres

# 2. Test connection from Metabase container
docker exec -it metabase ping postgres

# 3. Check PostgreSQL accepts connections
docker exec -it postgres_db psql -U postgres -d analytics -c "SELECT 1;"
```

### Issue: Metabase Setup Wizard Fails
```
Error: Internal server error during setup
```

**Solutions:**
```bash
# 1. Clear browser cache and cookies

# 2. Try incognito/private browsing mode

# 3. Check Metabase logs for specific errors
docker compose logs metabase | grep ERROR

# 4. Reset Metabase completely
docker compose down
docker volume rm chicago-crimes-data-pipeline_metabase_data
docker compose up -d metabase
```

## 🌐 Network Issues

### Issue: Services Can't Communicate
```
Error: Name resolution failed
```

**Solutions:**
```bash
# 1. Check Docker network
docker network ls
docker network inspect chicago-crimes-network

# 2. Verify all containers are on same network
docker inspect postgres_db | grep NetworkMode
docker inspect airbyte_server | grep NetworkMode

# 3. Test connectivity between containers
docker exec -it airbyte_server ping postgres
docker exec -it metabase ping postgres
```

### Issue: DNS Resolution Fails
```
Error: could not translate host name "postgres" to address
```

**Solutions:**
```bash
# 1. Restart Docker daemon
sudo systemctl restart docker

# 2. Recreate network
docker compose down
docker network rm chicago-crimes-network
docker compose up -d

# 3. Use IP addresses instead of service names
# Find container IP:
docker inspect postgres_db | grep IPAddress
```

## 💾 Data Issues

### Issue: No Data in Raw Tables
```
Error: Table 'raw_chicago_crimes' is empty
```

**Solutions:**
```bash
# 1. Check Airbyte sync status
# Go to Airbyte UI → Connections → View sync history

# 2. Verify source data availability
curl -I "https://data.cityofchicago.org/resource/crimes.csv"

# 3. Check for data in PostgreSQL
docker exec -it postgres_db psql -U postgres -d analytics -c "SELECT COUNT(*) FROM public.raw_chicago_crimes;"

# 4. Manual data load (if needed)
wget -O /tmp/crimes.csv "https://data.cityofchicago.org/resource/crimes.csv?$limit=1000"
# Then load via Adminer or psql
```

### Issue: dbt Models Return No Data
```
Warning: Model 'dim_crime_type' returned 0 rows
```

**Solutions:**
```bash
# 1. Check source data
dbt run-operation list_sources

# 2. Verify source table has data
dbt run-operation run_query --args '{"sql": "SELECT COUNT(*) FROM {{ source(\"raw\", \"raw_chicago_crimes\") }}"}'

# 3. Check staging model first
dbt run --models staging.stg_chicago_crimes
dbt run-operation run_query --args '{"sql": "SELECT COUNT(*) FROM {{ ref(\"stg_chicago_crimes\") }}"}'

# 4. Debug specific model
dbt run --models dim_crime_type --debug
```

## 🔧 Performance Issues

### Issue: Slow Query Performance
```
Warning: Model took 10+ minutes to run
```

**Solutions:**
```bash
# 1. Add indexes to frequently queried columns
# In PostgreSQL:
CREATE INDEX idx_crimes_date ON raw_chicago_crimes(date);
CREATE INDEX idx_crimes_type ON raw_chicago_crimes(primary_type);
CREATE INDEX idx_crimes_location ON raw_chicago_crimes(beat, district);

# 2. Optimize dbt model materialization
# Change from view to table for better performance
{{ config(materialized='table') }}

# 3. Use incremental models for large datasets
{{ config(
    materialized='incremental',
    unique_key='crime_id'
) }}

# 4. Increase dbt threads in profiles.yml
threads: 8  # Adjust based on CPU cores

# 5. Monitor query execution
dbt run --debug | grep "TIMER"
```

### Issue: High Memory Usage
```
Error: Out of memory during dbt run
```

**Solutions:**
```bash
# 1. Reduce dbt threads
threads: 2  # In profiles.yml

# 2. Process models in smaller batches
dbt run --models staging
dbt run --models marts.dimensions
dbt run --models marts.facts

# 3. Use incremental processing
# Break large transformations into smaller steps

# 4. Increase Docker memory allocation
# Docker Desktop: Settings → Advanced → Memory: 8GB+
```

### Issue: Docker Containers Consuming Too Much Disk
```
Warning: Low disk space
```

**Solutions:**
```bash
# 1. Clean up Docker resources
docker system prune -f
docker volume prune -f
docker image prune -f

# 2. Check disk usage
df -h
docker system df

# 3. Remove unused volumes
docker volume ls
docker volume rm <unused_volume_name>

# 4. Optimize PostgreSQL
docker exec -it postgres_db psql -U postgres -d analytics -c "VACUUM FULL;"
```

## 📱 Platform-Specific Issues

### Ubuntu/Linux Issues

**Issue: Docker service not starting**
```bash
# Check Docker service status
sudo systemctl status docker

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Check for permission issues
ls -la /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock
```

**Issue: Python version conflicts**
```bash
# Install specific Python version
sudo apt update
sudo apt install python3.9 python3.9-venv python3.9-pip

# Create virtual environment with specific version
python3.9 -m venv .venv
source .venv/bin/activate
```

### macOS Issues

**Issue: Docker Desktop not starting**
```bash
# Reset Docker Desktop
# Go to Docker Desktop → Troubleshoot → Reset to factory defaults

# Check for resource limits
# Docker Desktop → Preferences → Resources → Advanced
# Increase Memory to 8GB+, CPU to 4+ cores

# Clear Docker cache
docker system prune -a -f
```

**Issue: Port binding issues on macOS**
```bash
# Check what's using ports
sudo lsof -i :5432
sudo lsof -i :3000

# Kill processes if needed
sudo kill -9 <PID>

# Use different ports in .env file
POSTGRES_PORT=5433
METABASE_PORT=3001
```

### Windows (WSL2) Issues

**Issue: WSL2 integration not working**
```bash
# Enable WSL2 integration in Docker Desktop
# Settings → Resources → WSL Integration → Enable integration

# Restart WSL2
wsl --shutdown
wsl

# Check WSL2 version
wsl -l -v
```

**Issue: File permission issues in WSL2**
```bash
# Fix file permissions
sudo chown -R $USER:$USER ./
chmod -R 755 ./

# Mount with proper permissions
# In /etc/wsl.conf:
[automount]
options = "metadata,umask=0022,fmask=0011"
```

## 🔍 Debugging Techniques

### Enable Debug Logging

```bash
# dbt debug logging
dbt run --debug --log-level debug

# Docker Compose debug
docker compose --log-level DEBUG up

# PostgreSQL query logging
# Add to docker-compose.yml:
postgres:
  command: >
    postgres
    -c log_statement=all
    -c log_destination=stderr
    -c logging_collector=on
```

### Database Query Analysis

```sql
-- Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname IN ('staging', 'dw', 'public')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### Network Debugging

```bash
# Test network connectivity between containers
docker exec -it airbyte_server ping postgres
docker exec -it metabase telnet postgres 5432

# Check DNS resolution
docker exec -it airbyte_server nslookup postgres

# Inspect network configuration
docker network inspect chicago-crimes-network

# Check port mappings
docker port postgres_db
docker port metabase
```

## 🚑 Emergency Recovery

### Complete System Reset

```bash
# WARNING: This will delete all data!

# 1. Stop all services
docker compose down

# 2. Remove all volumes (DATA LOSS!)
docker volume prune -f

# 3. Remove all containers and networks
docker system prune -f

# 4. Start fresh
docker compose up -d

# 5. Wait for initialization
sleep 60

# 6. Verify services
docker compose ps
```

### Backup and Restore

```bash
# Backup PostgreSQL data
docker exec postgres_db pg_dump -U postgres analytics > backup_analytics.sql

# Backup Docker volumes
docker run --rm -v chicago-crimes-data-pipeline_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz /data

# Restore PostgreSQL data
cat backup_analytics.sql | docker exec -i postgres_db psql -U postgres analytics

# Restore Docker volumes
docker run --rm -v chicago-crimes-data-pipeline_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_backup.tar.gz -C /
```

### Data Recovery from Failed dbt Run

```bash
# 1. Check which models failed
dbt run --fail-fast

# 2. Drop problematic tables if needed
docker exec -it postgres_db psql -U postgres -d analytics -c "DROP TABLE IF EXISTS dw.problematic_table CASCADE;"

# 3. Run models one by one
dbt run --models staging.stg_chicago_crimes
dbt run --models marts.dimensions.dim_date
# ... continue with each model

# 4. Run tests to verify
dbt test --models staging
dbt test --models marts
```

## 📞 Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide** thoroughly
2. **Search existing GitHub issues** in the repository
3. **Collect relevant information**:
   - Your operating system and version
   - Docker and Docker Compose versions
   - Complete error messages
   - Service logs: `docker compose logs [service]`
   - Output of `docker compose ps`

### Creating a Good Issue Report

Include this information when reporting issues:

```bash
# System information
uname -a
docker --version
docker compose version

# Service status
docker compose ps

# Error logs
docker compose logs postgres
docker compose logs airbyte-server
docker compose logs metabase

# Network information
docker network ls
docker network inspect chicago-crimes-network

# Volume information
docker volume ls
df -h
```

### Community Resources

- **GitHub Issues**: Report bugs and request features
- **dbt Community**: [community.getdbt.com](https://community.getdbt.com/)
- **Airbyte Community**: [airbyte.io/community](https://airbyte.io/community)
- **Stack Overflow**: Use tags: `dbt`, `airbyte`, `metabase`, `postgresql`

## 📚 Additional Resources

### Documentation Links

- [dbt Documentation](https://docs.getdbt.com/)
- [Airbyte Documentation](https://docs.airbyte.com/)
- [Metabase Documentation](https://www.metabase.com/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Documentation](https://docs.docker.com/)

### Monitoring and Maintenance

```bash
# Daily health check script
#!/bin/bash
echo "=== Daily Health Check ==="
echo "Container Status:"
docker compose ps

echo "Disk Usage:"
df -h | grep -E "(Size|/dev/)"

echo "Memory Usage:"
free -h

echo "Database Connections:"
docker exec postgres_db psql -U postgres -d analytics -c "SELECT count(*) FROM pg_stat_activity;"

echo "Last Airbyte Sync:"
# Check Airbyte API for last sync status

echo "dbt Test Results:"
cd dbt_project/chicago_crimes && dbt test --quiet
```

Remember: Most issues can be resolved by carefully reading error messages and checking service logs. Don't hesitate to restart services or recreate containers when in doubt!

---

**Need more help?** Open an issue on GitHub with detailed information about your problem. 🆘