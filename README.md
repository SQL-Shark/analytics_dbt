Chicago Crimes Data Pipeline
Show Image
Show Image
Show Image
Show Image
A modern, production-ready data pipeline for analyzing Chicago crime data using open-source tools. This project demonstrates best practices in analytics engineering, from raw data ingestion to interactive dashboards.
🎯 Project Overview
This project transforms raw Chicago crime data into a clean, analytics-ready star schema using modern data engineering practices. It showcases:

Data Ingestion: Automated data loading with Airbyte
Data Transformation: dbt models implementing dimensional modeling
Data Quality: Comprehensive testing and validation
Data Visualization: Interactive dashboards with Metabase
Infrastructure: Containerized deployment with Docker Compose

Architecture
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐
│   Raw Data  │───▶│   Airbyte    │───▶│ PostgreSQL  │───▶│  Metabase   │
│ CSV-ADLSGen2│    │ (Ingestion)  │    │Data Warehouse│   │ (Dashboards)│
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │     dbt     │
                                       │(Transform)  │
                                       └─────────────┘
📊 Data Model
The project implements a star schema optimized for crime analytics:
Dimensions:

dim_date - Complete date dimension with business attributes
dim_crime_type - Crime classifications and severity levels
dim_location - Geographic hierarchy with coordinates
dim_case - Case-level attributes and outcomes

Facts:

fact_crime_incidents - Grain: One row per crime incident

🚀 Quick Start
Prerequisites

Docker & Docker Compose (recommended)
Python 3.8+ with pip
Git
8GB+ RAM for all services

Option 1: Docker Compose (Recommended)

Clone the repository
bashgit clone https://github.com/yourusername/chicago-crimes-data-pipeline.git
cd chicago-crimes-data-pipeline

Configure environment
bashcp .env.example .env
# Edit .env with your passwords and settings

Start all services
bashdocker compose up -d

Wait for services to be ready (2-3 minutes)
bash# Check service status
docker compose ps

# View logs if needed
docker compose logs -f

Access the applications

Airbyte: http://localhost:8000 (admin/password)
Metabase: http://localhost:3000
PostgreSQL: localhost:5432 (analytics database)
Adminer: http://localhost:8080 (database management)



Option 2: Local Development Setup

Set up Python environment
bashpython3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

Start PostgreSQL (via Docker)
bashdocker compose up postgres -d

Configure dbt
bashcd dbt_project/chicago_crimes
cp profiles.yml ~/.dbt/profiles.yml
# Edit connection details in profiles.yml

Install dbt packages
bashdbt deps

Run dbt models
bashdbt run
dbt test


📁 Project Structure
chicago-crimes-data-pipeline/
├── 📄 README.md                    # This file
├── 🐳 docker-compose.yml           # Multi-service orchestration
├── 🔧 .env.example                 # Environment variables template
├── 📋 requirements.txt             # Python dependencies
├── 📊 dbt_project/
│   └── chicago_crimes/
│       ├── 📄 dbt_project.yml      # dbt project configuration
│       ├── 🔗 profiles.yml         # Database connection
│       ├── 📦 packages.yml         # dbt dependencies
│       └── 📁 models/
│           ├── 📄 src_raw.yml      # Source definitions
│           ├── 🧹 staging/         # Data cleaning layer
│           │   ├── stg_chicago_crimes.sql
│           │   └── schema.yml
│           └── 🏪 marts/           # Business logic layer
│               ├── schema.yml
│               ├── dimensions/     # Star schema dimensions
│               └── facts/         # Star schema facts
├── 📁 docs/                       # Documentation
├── 📁 scripts/                    # Utility scripts
└── 📁 data/                       # Sample data files


🔧 Configuration
Environment Variables
Copy .env.example to .env and configure:
bash# Database Configuration
POSTGRES_PASSWORD=your_secure_password
POSTGRES_USER=postgres
POSTGRES_DB=analytics

# Airbyte Configuration  
AIRBYTE_DB_PASSWORD=airbyte_password

# Optional: Service Ports (if you need to change defaults)
POSTGRES_PORT=5432
METABASE_PORT=3000
AIRBYTE_PORT=8000
ADMINER_PORT=8080
dbt Configuration
The dbt profile is configured in dbt_project/chicago_crimes/profiles.yml:
yamlchicago_crimes:
  outputs:
    dev:
      type: postgres
      host: localhost
      user: postgres
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      port: 5432
      dbname: analytics
      schema: staging
      threads: 4
  target: dev
📈 Usage Guide
1. Data Ingestion with Airbyte

Access Airbyte UI: http://localhost:8000
Create a Source:

Choose "File (CSV)" or "HTTP API"
Configure Chicago crimes data URL


Create a Destination:

Choose "PostgreSQL"
Host: postgres (container name)
Database: analytics
Schema: public


Create and Run Connection

2. Data Transformation with dbt
bash# Navigate to dbt project
cd dbt_project/chicago_crimes

# Install dependencies
dbt deps

# Run staging models
dbt run --models staging

# Run dimension models
dbt run --models marts.dimensions

# Run fact models  
dbt run --models marts.facts

# Run all models
dbt run

# Test data quality
dbt test

# Generate documentation
dbt docs generate
dbt docs serve  # Access at http://localhost:8080
3. Data Visualization with Metabase

Access Metabase: http://localhost:3000
Complete setup wizard
Connect to PostgreSQL:

Host: postgres
Port: 5432
Database: analytics
Username: postgres
Password: Your password


Create dashboards using the star schema tables

4. Database Management

Adminer: http://localhost:8080

System: PostgreSQL
Server: postgres
Username: postgres
Database: analytics


DBeaver (if installed locally):

Host: localhost
Port: 5432
Database: analytics



🧪 Testing
The project includes comprehensive data quality tests:
bash# Run all tests
dbt test

# Run tests for specific model
dbt test --models dim_crime_type

# Run specific test types
dbt test --select test_type:unique
dbt test --select test_type:not_null
dbt test --select test_type:relationships
Test Coverage

✅ Primary Key Integrity: All dimension and fact tables
✅ Referential Integrity: Foreign key relationships
✅ Data Quality: Null checks and accepted values
✅ Business Rules: Domain-specific validations

📊 Star Schema Details
Fact Table: fact_crime_incidents

Grain: One row per crime incident
Measures: incident_count, arrest_count, domestic_violence_count
Dimensions: date, crime_type, location, case

Dimension Tables
TableKeyDescriptionRecordsdim_datedate_keyComplete date dimension (2001-2030)~11Kdim_crime_typecrime_type_keyCrime classifications with business categories~300dim_locationlocation_keyGeographic hierarchy with coordinates~76Kdim_casecase_keyCase attributes and outcomes~95K
🔍 Troubleshooting
Common Issues
1. Airbyte can't connect to PostgreSQL
bash# Check if containers are on same network
docker network ls
docker network inspect chicago-crimes-data-pipeline_default

# Restart Airbyte services
docker compose restart airbyte-server airbyte-worker
2. dbt connection fails
bash# Test connection
dbt debug

# Check profiles.yml location and content
cat ~/.dbt/profiles.yml

# Verify PostgreSQL is accessible
psql -h localhost -U postgres -d analytics
3. Services won't start
bash# Check port conflicts
sudo netstat -tulpn | grep :5432

# View container logs
docker compose logs postgres
docker compose logs airbyte-server

# Clean restart
docker compose down
docker compose up -d
4. dbt models fail
bash# Check for missing dependencies
dbt deps

# Run with debug output
dbt run --debug

# Check source data
dbt source freshness
Performance Optimization

Increase Docker memory to 8GB+ for optimal performance
Use SSD storage for Docker volumes
Adjust dbt threads in profiles.yml based on your CPU cores

🤝 Contributing

Fork the repository
Create a feature branch (git checkout -b feature/amazing-feature)
Commit your changes (git commit -m 'Add amazing feature')
Push to the branch (git push origin feature/amazing-feature)
Open a Pull Request

Development Guidelines

Follow dbt naming conventions (stg_, dim_, fact_)
Add tests for all new models
Update documentation for schema changes
Test locally before submitting PR

📚 Learning Resources
Blog Series
This project is documented in a comprehensive blog series:

Part 1: Environment Setup - Building a Modern Data Stack on Ubuntu
Part 2: dbt Modeling Journey - From Raw Data to Production Star Schema
Part 3: Dashboard Creation - Building Interactive Crime Analytics

Key Concepts Demonstrated

Analytics Engineering with dbt
Dimensional Modeling (star schema)
Data Quality Testing and validation
Container Orchestration with Docker Compose
Modern Data Stack architecture
CI/CD for data pipelines

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
🙏 Acknowledgments

City of Chicago for providing open crime data
dbt Labs for the excellent transformation framework
Airbyte for simplifying data ingestion
Metabase for powerful open-source BI
Open-source community for all the amazing tools


⭐ Star this repository if you found it helpful!
📧 Questions? Open an issue or reach out via [your-contact-method]
🔗 Connect: LinkedIn | sqlshark.net 