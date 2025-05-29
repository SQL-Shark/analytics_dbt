# Detailed Setup Guide

This guide provides step-by-step instructions for setting up the Chicago Crimes Data Pipeline on different environments.

## 🖥️ System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+, macOS 10.15+, or Windows 10+ with WSL2
- **RAM**: 8GB (16GB recommended)
- **Storage**: 10GB free space
- **CPU**: 4 cores (8 cores recommended)

### Software Dependencies
- Docker 20.10+
- Docker Compose 2.0+
- Python 3.8+
- Git 2.0+

## 🐧 Ubuntu Setup (Recommended)

### Step 1: Install Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git python3 python3-pip python3-venv

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker compose version
python3 --version
git --version
```

### Step 2: Clone and Setup Project

```bash
# Clone repository
git clone https://github.com/yourusername/chicago-crimes-data-pipeline.git
cd chicago-crimes-data-pipeline

# Create environment file
cp .env.example .env

# Edit environment variables (use your preferred editor)
nano .env  # or vim .env or code .env
```

### Step 3: Configure Environment Variables

Edit `.env` file with your settings:

```bash
# Database Configuration
POSTGRES_PASSWORD=secure_password_123
POSTGRES_USER=postgres
POSTGRES_DB=analytics

# Airbyte Configuration
AIRBYTE_DB_PASSWORD=airbyte_password_123

# Optional: Custom Ports (only change if you have conflicts)
POSTGRES_PORT=5432
METABASE_PORT=3000
AIRBYTE_PORT=8000
ADMINER_PORT=8080
```

### Step 4: Start Services

```bash
# Start all services
docker compose up -d

# Check service status
docker compose ps

# View logs (optional)
docker compose logs -f

# Wait for services to be ready (usually 2-3 minutes)
# You can check individual service logs:
docker compose logs postgres
docker compose logs airbyte-server
docker compose logs metabase
```

### Step 5: Verify Installation

```bash
# Test PostgreSQL connection
docker exec -it postgres_db psql -U postgres -d analytics -c "SELECT version();"

# Check Airbyte API
curl -s http://localhost:8000/api/v1/health

# Test Metabase
curl -s http://localhost:3000/api/health
```

## 🍎 macOS Setup

### Step 1: Install Prerequisites

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install docker docker-compose python3 git

# Start Docker Desktop (download from docker.com if not installed)
open -a Docker

# Verify installations
docker --version
docker compose version
python3 --version
git --version
```

### Step 2-5: Follow Ubuntu Steps 2-5

The remaining steps are identical to Ubuntu setup.

## 🪟 Windows Setup (WSL2)

### Step 1: Enable WSL2

1. Open PowerShell as Administrator
2. Run: `wsl --install`
3. Restart computer
4. Install Ubuntu from Microsoft Store
5. Set up Ubuntu user account

### Step 2: Install Docker Desktop

1. Download Docker Desktop for Windows
2. Enable WSL2 integration
3. Restart Docker Desktop

### Step 3: Setup in WSL2 Ubuntu

Open Ubuntu terminal and follow Ubuntu setup steps.

## 🔧 Local Development Setup

For dbt development without full Docker stack:

### Step 1: Python Environment

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install Python dependencies
pip install -r requirements.txt

# Verify dbt installation
dbt --version
```

### Step 2: Start Only PostgreSQL

```bash
# Start only PostgreSQL container
docker compose up postgres -d

# Verify database is running
docker compose ps postgres
```

### Step 3: Configure dbt

```bash
# Navigate to dbt project
cd dbt_project/chicago_crimes

# Copy and edit profiles
mkdir -p ~/.dbt
cp profiles.yml ~/.dbt/profiles.yml

# Edit connection details
nano ~/.dbt/profiles.yml
```

Update the profiles.yml:

```yaml
chicago_crimes:
  outputs:
    dev:
      type: postgres
      host: localhost
      user: postgres
      password: "your_password_here"  # From .env file
      port: 5432
      dbname: analytics
      schema: staging
      threads: 4
  target: dev
```

### Step 4: Install dbt Packages

```bash
# Install dbt packages
dbt deps

# Test connection
dbt debug

# Run models
dbt run
dbt test
```

## 📊 Data Setup

### Option 1: Sample Data (Quick Start)

```bash
# Load sample data (if provided)
docker exec -i postgres_db psql -U postgres -d analytics < data/sample_chicago_crimes.sql
```

### Option 2: Full Dataset via Airbyte

1. **Access Airbyte**: http://localhost:8000
2. **Login**: admin/password (default)
3. **Create Source**:
   - Source Type: HTTP API or File (CSV)
   - URL: `https://data.cityofchicago.org/resource/crimes.csv`
   - Name: `chicago_crimes_api`

4. **Create Destination**:
   - Destination Type: PostgreSQL
   - Host: `postgres`
   - Port: `5432`
   - Database: `analytics`
   - Username: `postgres`
   - Password: `[your password from .env]`
   - Schema: `public`

5. **Create Connection**:
   - Source: chicago_crimes_api
   - Destination: PostgreSQL
   - Sync Mode: Full Refresh
   - Schedule: Manual (for testing)

6. **Run Sync**:
   - Click "Sync Now"
   - Monitor progress in Airbyte UI
   - Data will be loaded into `public.raw_chicago_crimes`

### Option 3: Manual Data Load

```bash
# Download Chicago crimes data
wget -O data/chicago_crimes.csv "https://data.cityofchicago.org/resource/crimes.csv?$limit=100000"

# Load into PostgreSQL
docker exec -i postgres_db psql -U postgres -d analytics -c "
CREATE TABLE IF NOT EXISTS public.raw_chicago_crimes (
    -- Define your schema here based on CSV structure
);

COPY public.raw_chicago_crimes 
FROM '/tmp/chicago_crimes.csv' 
DELIMITER ',' CSV HEADER;
"
```

## 🧪 Testing Your Setup

### 1. Verify All Services

```bash
# Check all containers are running
docker compose ps

# Expected output:
# postgres_db      running   0.0.0.0:5432->5432/tcp
# airbyte_server   running   
# airbyte_worker   running
# airbyte_webapp   running   0.0.0.0:8000->80/tcp
# metabase         running   0.0.0.0:3000->3000/tcp
# adminer          running   0.0.0.0:8080->8080/tcp
```

### 2. Test Database Connection

```bash
# Test from command line
docker exec -it postgres_db psql -U postgres -d analytics

# Inside PostgreSQL:
\l                    # List databases
\c analytics          # Connect to analytics
\dt public.*          # List tables in public schema
SELECT COUNT(*) FROM public.raw_chicago_crimes;  # Count records
\q                    # Quit
```

### 3. Test dbt Models

```bash
cd dbt_project/chicago_crimes

# Test connection
dbt debug

# Run staging models
dbt run --models staging

# Run all models
dbt run

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve  # Access at http://localhost:8080
```

### 4. Test Web Interfaces

Visit these URLs in your browser:

- **Airbyte**: http://localhost:8000 (admin/password)
- **Metabase**: http://localhost:3000 (complete setup wizard)
- **Adminer**: http://localhost:8080 (PostgreSQL/postgres/localhost/analytics)
- **dbt docs**: http://localhost:8080 (after running `dbt docs serve`)

## 🚨 Troubleshooting

### Port Conflicts

```bash
# Check what's using your ports
sudo netstat -tulpn | grep :5432
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8000

# Kill processes if needed
sudo kill -9 <PID>

# Or change ports in docker-compose.yml
```

### Permission Issues

```bash
# Fix Docker permissions
sudo chmod 666 /var/run/docker.sock

# Fix file permissions
sudo chown -R $USER:$USER ./
chmod -R 755 ./
```

### Memory Issues

```bash
# Check Docker memory usage
docker stats

# Increase Docker memory (Docker Desktop):
# Settings → Resources → Memory → Increase to 8GB+

# On Linux, check available memory:
free -h
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
docker compose logs postgres

# Test connection from host
psql -h localhost -U postgres -d analytics

# Test connection from container
docker exec -it postgres_db psql -U postgres -d analytics
```

### Airbyte Issues

```bash
# Check Airbyte logs
docker compose logs airbyte-server
docker compose logs airbyte-worker

# Restart Airbyte services
docker compose restart airbyte-server airbyte-worker airbyte-webapp

# Reset Airbyte (if needed)
docker compose down
docker volume rm chicago-crimes-data-pipeline_airbyte_data
docker compose up -d
```

### dbt Issues

```bash
# Check dbt debug output
dbt debug

# Common fixes:
# 1. Check profiles.yml location
ls -la ~/.dbt/

# 2. Verify dbt project structure
dbt list

# 3. Check for compilation errors
dbt compile

# 4. Run with debug output
dbt run --debug
```

## 🔄 Updating the Project

```bash
# Pull latest changes
git pull origin main

# Update Docker images
docker compose pull

# Restart services with new images
docker compose down
docker compose up -d

# Update dbt packages
cd dbt_project/chicago_crimes
dbt deps --upgrade

# Re-run models if needed
dbt run
```

## 📚 Next Steps

After successful setup:

1. **Explore the data** using Adminer or psql
2. **Run dbt models** to build the star schema
3. **Create Metabase dashboards** for visualization
4. **Read the blog series** for detailed explanations
5. **Customize the models** for your use case

## 🆘 Getting Help

If you encounter issues:

1. **Check this troubleshooting guide** first
2. **Search existing issues** on GitHub
3. **Create a new issue** with:
   - Your OS and version
   - Error messages
   - Steps to reproduce
   - Logs from `docker compose logs [service]`

---

**Happy analyzing! 📊**