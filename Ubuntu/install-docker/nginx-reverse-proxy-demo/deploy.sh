#!/bin/bash

##############################################################################
# Nginx Reverse Proxy Deployment Script
# Target Environment: Ubuntu 22.04 LTS
# Description: Manages Docker Compose stack for Nginx reverse proxy demo
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Project name
PROJECT_NAME="nginx-reverse-proxy-demo"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_requirements() {
    print_header "Checking Requirements"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        echo "Please install Docker: https://docs.docker.com/engine/install/ubuntu/"
        exit 1
    fi
    print_success "Docker is installed ($(docker --version))"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed!"
        echo "Please install Docker Compose"
        exit 1
    fi
    
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        print_success "Docker Compose is installed ($(docker compose version))"
    else
        COMPOSE_CMD="docker-compose"
        print_success "Docker Compose is installed ($(docker-compose --version))"
    fi
    
    # Check if user can run Docker without sudo
    if ! docker ps &> /dev/null; then
        print_error "Cannot run Docker commands. You may need to:"
        echo "  1. Add your user to the docker group: sudo usermod -aG docker \$USER"
        echo "  2. Log out and log back in"
        echo "  3. Or run this script with sudo"
        exit 1
    fi
    print_success "Docker permissions OK"
    
    echo ""
}

start_services() {
    print_header "Starting Services"
    
    check_requirements
    
    print_info "Building and starting containers..."
    $COMPOSE_CMD up -d --build
    
    echo ""
    print_success "Services started successfully!"
    echo ""
    
    # Wait a moment for services to initialize
    sleep 3
    
    show_status
    
    echo ""
    print_info "Access the application at: ${GREEN}http://localhost:8080${NC}"
    echo ""
}

stop_services() {
    print_header "Stopping Services"
    
    print_info "Stopping containers..."
    $COMPOSE_CMD down
    
    echo ""
    print_success "Services stopped successfully!"
}

restart_services() {
    print_header "Restarting Services"
    
    stop_services
    echo ""
    start_services
}

show_logs() {
    print_header "Service Logs"
    
    if [ -z "$1" ]; then
        print_info "Showing logs for all services (Ctrl+C to exit)..."
        $COMPOSE_CMD logs -f --tail=100
    else
        print_info "Showing logs for service: $1 (Ctrl+C to exit)..."
        $COMPOSE_CMD logs -f --tail=100 "$1"
    fi
}

show_status() {
    print_header "Service Status"
    
    $COMPOSE_CMD ps
    
    echo ""
    print_info "Network Information:"
    docker network inspect demo-network --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{println}}{{end}}' 2>/dev/null || echo "Network not created yet"
}

clean_all() {
    print_header "Cleaning Up"
    
    read -p "$(echo -e ${YELLOW}This will remove all containers, volumes, and networks. Continue? [y/N]: ${NC})" -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing containers, networks, and volumes..."
        $COMPOSE_CMD down -v --remove-orphans
        
        print_success "Cleanup complete!"
    else
        print_info "Cleanup cancelled"
    fi
}

test_connection() {
    print_header "Testing Connection"
    
    print_info "Testing Nginx reverse proxy..."
    
    if command -v curl &> /dev/null; then
        echo ""
        curl -s http://localhost:8080 | head -20
        echo ""
        print_success "Connection test complete!"
    else
        print_error "curl is not installed. Install it with: sudo apt-get install curl"
        exit 1
    fi
}

show_help() {
    cat << EOF
${BLUE}Nginx Reverse Proxy Deployment Script${NC}

Usage: $0 [COMMAND]

Commands:
    start       Start all services
    stop        Stop all services
    restart     Restart all services
    status      Show service status
    logs        Show logs for all services (add service name for specific service)
    test        Test the connection to the application
    clean       Remove all containers, networks, and volumes
    help        Show this help message

Examples:
    $0 start              # Start the stack
    $0 logs               # Follow all logs
    $0 logs nginx         # Follow nginx logs only
    $0 test               # Test the connection
    $0 clean              # Clean up everything

EOF
}

##############################################################################
# Main Script Logic
##############################################################################

case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs "$2"
        ;;
    status)
        show_status
        ;;
    test)
        test_connection
        ;;
    clean)
        clean_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Invalid command: ${1:-<none>}"
        echo ""
        show_help
        exit 1
        ;;
esac

exit 0
