#!/bin/bash

##############################################################################
# Load Balancing Test Script
# Tests Nginx load balancing across 3 Node.js instances
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Nginx Load Balancing Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test function
test_load_balancing() {
    echo -e "${YELLOW}Making 10 requests to see load distribution...${NC}"
    echo ""
    
    for i in {1..10}; do
        response=$(curl -s http://localhost:8080/api/info)
        instance=$(echo "$response" | grep -o '"instance":"[^"]*"' | cut -d'"' -f4)
        port=$(echo "$response" | grep -o '"port":[0-9]*' | grep -o '[0-9]*')
        
        echo -e "${GREEN}Request $i:${NC} $instance (Port $port)"
        sleep 0.5
    done
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Load balancing test complete!${NC}"
    echo ""
    echo -e "${YELLOW}Expected behavior:${NC}"
    echo "- Requests should be distributed across all 3 instances"
    echo "- Round-robin: Instance 1 → Instance 2 → Instance 3 → repeat"
    echo ""
}

# Check if services are running
echo -e "${YELLOW}Checking if services are running...${NC}"
if ! curl -s http://localhost:8080/nginx-health > /dev/null; then
    echo -e "${RED}Error: Services are not running!${NC}"
    echo "Please start the services first: ./deploy.sh start"
    exit 1
fi

echo -e "${GREEN}✓ Services are running${NC}"
echo ""

# Run test
test_load_balancing

# Show current status
echo -e "${YELLOW}Current container status:${NC}"
docker ps --filter "name=demo-app" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Additional Commands:${NC}"
echo ""
echo "Test specific instance:"
echo "  curl http://localhost:8080/api/info | jq"
echo ""
echo "Monitor logs:"
echo "  ./deploy.sh logs app1"
echo "  ./deploy.sh logs app2"
echo "  ./deploy.sh logs app3"
echo ""
echo "Test failover (stop one instance):"
echo "  docker stop demo-app1"
echo "  ./test-loadbalancer.sh"
echo "  docker start demo-app1"
echo ""
