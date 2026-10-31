#!/bin/bash

# 7009 Docker Compose Security Management Script


SID="16498040"
COMPOSE_FILE="docker-compose.hardened.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Security checks function
security_check() {
    echo -e "${BLUE}Running security pre-flight checks...${NC}"
    
    # Check if secrets exist
    if [[ ! -f "secrets/db_root_password.txt" ]] || [[ ! -f "secrets/db_user_password.txt" ]]; then
        echo -e "${RED}ERROR: Secret files missing in ./secrets/ directory${NC}"
        return 1
    fi
    
    # Check secret permissions
    chmod 600 secrets/*.txt
    
    # Check directory permissions
    chmod 700 secrets/
    chmod 755 data/ logs/
    chmod 755 logs/mysql logs/nginx
    
    # Ensure required directories exist
    mkdir -p logs/mysql logs/nginx
    chmod 755 logs/mysql logs/nginx
    
    # Verify Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Docker daemon is not running${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Security checks passed${NC}"
    return 0
}

# Vulnerability scan function
vulnerability_scan() {
    echo -e "${BLUE}Running vulnerability scan with Trivy...${NC}"
    
    if ! command -v trivy &> /dev/null; then
        echo -e "${YELLOW}Trivy not installed. Installing via Homebrew...${NC}"
        brew install trivy
    fi
    
    # Scan database image
    echo "Scanning database image..."
    trivy image --severity HIGH,CRITICAL "${SID}/7009_dbserver_secure_i" || true
    
    # Scan web server image
    echo "Scanning web server image..."
    trivy image --severity HIGH,CRITICAL "${SID}/7009_webserver_secure_i" || true
    
    # Scan configuration files
    echo "Scanning configuration files..."
    trivy config . || true
}

case "$1" in
    "security-check")
        security_check
        ;;
    "build")
        if security_check; then
            echo -e "${BLUE}Building secure containers...${NC}"
            docker-compose -f $COMPOSE_FILE build
            echo -e "${GREEN}Build completed successfully${NC}"
        else
            echo -e "${RED}Security checks failed. Aborting build.${NC}"
            exit 1
        fi
        ;;
    "scan")
        vulnerability_scan
        ;;
    "up")
        if security_check; then
            echo -e "${BLUE}Starting secure services...${NC}"
            docker-compose -f $COMPOSE_FILE up -d
            echo -e "${GREEN}Services started successfully${NC}"
            echo -e "${BLUE}Database will be ready shortly with automatic SQL import${NC}"
            echo -e "${BLUE}Web application will be available at http://localhost/${NC}"
            echo -e "${YELLOW}Run './manage-secure.sh status' to check service health${NC}"
        else
            echo -e "${RED}Security checks failed. Aborting startup.${NC}"
            exit 1
        fi
        ;;
    "down")
        echo -e "${BLUE}Stopping secure containers...${NC}"
        docker-compose -f $COMPOSE_FILE down
        echo -e "${GREEN}Services stopped successfully${NC}"
        ;;
    "clean")
        echo -e "${YELLOW}Stopping containers and cleaning up (keeping volumes)...${NC}"
        docker-compose -f $COMPOSE_FILE down
        ;;
    "clean-all")
        echo -e "${RED}WARNING: This will remove all data including database content!${NC}"
        read -p "Are you sure? (yes/no): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            docker-compose -f $COMPOSE_FILE down -v
            docker system prune -f
            echo -e "${GREEN}Complete cleanup finished${NC}"
        else
            echo -e "${YELLOW}Cleanup cancelled${NC}"
        fi
        ;;
    "logs")
        echo -e "${BLUE}Showing logs for all secure services...${NC}"
        docker-compose -f $COMPOSE_FILE logs -f
        ;;
    "status")
        echo -e "${BLUE}Checking status of all secure services...${NC}"
        docker-compose -f $COMPOSE_FILE ps
        echo ""
        echo -e "${BLUE}Health check status:${NC}"
        docker-compose -f $COMPOSE_FILE exec db mysqladmin ping -h localhost --silent && echo -e "${GREEN}Database: Healthy${NC}" || echo -e "${RED}Database: Unhealthy${NC}"
        curl -f http://localhost/health 2>/dev/null && echo -e "${GREEN}Web Server: Healthy${NC}" || echo -e "${RED}Web Server: Unhealthy${NC}"
        ;;
    "security-report")
        echo -e "${BLUE}Generating security report...${NC}"
        echo "=== Container Security Status ==="
        docker-compose -f $COMPOSE_FILE ps
        echo ""
        echo "=== Non-root user verification ==="
        docker-compose -f $COMPOSE_FILE exec web whoami 2>/dev/null || echo "Web container not running"
        docker-compose -f $COMPOSE_FILE exec db whoami 2>/dev/null || echo "DB container not running"
        echo ""
        echo "=== Resource usage ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
        ;;
    "demo")
        echo -e "${BLUE}Running security demonstration...${NC}"
        
        # Build and start
        ./manage-secure.sh build
        ./manage-secure.sh up
        
        # Wait for services
        sleep 30
        
        # Show security features
        echo -e "\n${GREEN}=== Security Demo Results ===${NC}"
        echo "1. Non-root user verification:"
        docker-compose -f $COMPOSE_FILE exec web whoami
        
        echo "2. Resource limits active:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        
        echo "3. Application accessibility:"
        curl -s http://localhost/ | head -10
        
        echo -e "\n${GREEN}Demo completed successfully!${NC}"
        ;;
    *)
        echo -e "${BLUE}Security-Hardened Docker Management${NC}"
        echo ""
        echo "Usage: $0 {security-check|build|scan|up|down|clean|clean-all|logs|status|security-report|demo}"
        echo ""
        echo -e "${GREEN}Security Commands:${NC}"
        echo "  security-check - Run security pre-flight checks"
        echo "  build         - Build containers with security validation"
        echo "  scan          - Run vulnerability scans with Trivy"
        echo "  up            - Start services with security checks"
        echo "  security-report - Generate security status report"
        echo "  demo          - Run complete security demonstration"
        echo ""
        echo -e "${GREEN}Standard Commands:${NC}"
        echo "  down          - Stop and remove containers"
        echo "  clean         - Same as 'down' (for compatibility)"
        echo "  clean-all     - Remove everything including volumes"
        echo "  logs          - Show logs from all services"
        echo "  status        - Show service status and health"
        echo ""
        echo -e "${YELLOW}Security Features Enabled:${NC}"
        echo "  ✓ Non-root user execution"
        echo "  ✓ Read-only root filesystems"
        echo "  ✓ Resource limits (CPU/Memory)"
        echo "  ✓ Security capabilities dropped"
        echo "  ✓ AppArmor security profiles"
        echo "  ✓ Docker secrets for passwords"
        echo "  ✓ Health monitoring"
        echo "  ✓ Vulnerability scanning integration"
        echo ""
        echo -e "${BLUE}Quick start:${NC}"
        echo "  1. Update SID in docker-compose.hardened.yml"
        echo "  2. Run: ./manage-secure.sh security-check"
        echo "  3. Run: ./manage-secure.sh build"
        echo "  4. Run: ./manage-secure.sh up"
        echo "  5. Visit: http://localhost/"
        exit 1
esac
