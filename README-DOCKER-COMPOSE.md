# 7009 Web Application – Deployment Guide
This project uses Docker Compose to build and run a two-service stack (webserver and database), with a security-hardened mode enforced via docker-compose.yml and manage-secure.sh. The hardened workflow enforces security validation, consistent builds, and controlled runtime behaviour.
Prerequisites
Docker Engine and Docker Compose must be installed and running. On Windows systems, WSL2 is recommended for compatibility with shell scripts.
Standard Docker Compose Deployment
To start the application using the baseline Compose configuration:
docker-compose up -d
The application is accessible at http://localhost.
To stop the services:
docker-compose down
A clean rebuild can be performed using:
docker-compose build --no-cache
docker-compose up -d
# View logs for all services
docker-compose logs

# Restart all services
docker-compose restart

# Clean restart (removes containers but keeps volumes)
docker-compose down && docker-compose up -d
# Complete cleanup (removes everything including data)
docker-compose down -v

Security-Hardened Deployment and manage-secure.sh
The manage-secure.sh script acts as a centralised operational wrapper for the hardened environment. It standardises how images are built, scanned, deployed, inspected, and cleaned, reducing the risk of insecure or inconsistent manual commands.

Before first use:
chmod +x manage-secure.sh

A full secure deployment and demonstration can be executed with:
./manage-secure.sh demo

Alternatively, the process can be run step by step:
./manage-secure.sh security-check
./manage-secure.sh build
./manage-secure.sh up
./manage-secure.sh status

The script also provides controlled cleanup operations (clean, clean-all) and security reporting, ensuring repeatable, auditable, and security-focused container management suitable for assessment and demonstration.
