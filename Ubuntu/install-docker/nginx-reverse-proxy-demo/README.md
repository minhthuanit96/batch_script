# Node.js Server with Nginx Load Balancer

A complete Docker Compose setup demonstrating **Nginx load balancing** across 3 custom-built Node.js HTTP servers. This project shows how to build Docker images from source and configure Nginx as a load balancer with health checks and failover.

## 🏗️ Architecture

```
Client Requests (http://localhost:8080)
         ↓
    [Nginx Load Balancer] (Round-Robin)
         ↓
    ┌─────────┬─────────┬─────────┐
    ↓         ↓         ↓         ↓
[App Instance 1] [App Instance 2] [App Instance 3]
   Port 3001       Port 3002       Port 3003
```

## 📋 Components

### 1. **Node.js Application Instances** (3 containers)
- **app1**: Listening on port 3001 - "App Instance 1"
- **app2**: Listening on port 3002 - "App Instance 2"
- **app3**: Listening on port 3003 - "App Instance 3"
- **Built from**: Local Dockerfile (node:18-alpine)
- **Features**: Health checks, graceful shutdown, instance identification

### 2. **Nginx Load Balancer**
- **Image**: nginx:alpine
- **Port**: 8080 (external) → 80 (internal)
- **Algorithm**: Round-robin (default)
- **Features**: 
  - Automatic failover
  - Health checks (max_fails=3, fail_timeout=30s)
  - Keepalive connections
  - Request distribution

### 3. **Docker Network**
- **Name**: demo-network
- **Type**: Custom bridge network

## 🔧 Prerequisites

**Ubuntu 22.04 LTS** with Docker and Docker Compose installed.

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in

# Install Docker Compose
sudo apt-get install docker-compose-plugin
```

## 🚀 Quick Start

### 1. Navigate to project
```bash
cd nginx-reverse-proxy-demo
```

### 2. Make scripts executable
```bash
chmod +x deploy.sh test-loadbalancer.sh
```

### 3. Build and start all services
```bash
./deploy.sh start
```

This will:
- Build the Node.js image once
- Create 3 containers from the same image
- Start Nginx load balancer
- Configure networking and health checks

**Expected Output**:
```
✓ Services started successfully!

NAME          IMAGE                        STATUS              
demo-nginx    nginx:alpine                Up (healthy)
demo-app1     nodejs-server-demo:latest   Up (healthy)
demo-app2     nodejs-server-demo:latest   Up (healthy)
demo-app3     nodejs-server-demo:latest   Up (healthy)
```

### 4. Test load balancing
```bash
./test-loadbalancer.sh
```

Or manually:
```bash
# Make multiple requests
for i in {1..6}; do
  curl -s http://localhost:8080/api/info | grep -o '"instance":"[^"]*"'
done
```

**Expected Result** (Round-robin distribution):
```
Request 1: App Instance 1 (Port 3001)
Request 2: App Instance 2 (Port 3002)
Request 3: App Instance 3 (Port 3003)
Request 4: App Instance 1 (Port 3001)
Request 5: App Instance 2 (Port 3002)
Request 6: App Instance 3 (Port 3003)
```

## 📁 Project Structure

```
nginx-reverse-proxy-demo/
├── app/
│   ├── server.js              # Node.js HTTP server
│   ├── package.json           # Project metadata
│   ├── Dockerfile             # Build definition
│   └── .dockerignore          # Build exclusions
├── nginx/
│   └── nginx.conf             # Load balancer config
├── docker-compose.yml         # 3 app instances + nginx
├── deploy.sh                  # Deployment script
├── test-loadbalancer.sh       # Load balancing test script
└── README.md                  # This file
```

## 🔍 Load Balancing Configuration

### Nginx Upstream (nginx/nginx.conf)
```nginx
upstream backend_app {
    # Round-robin algorithm (default)
    server app1:3001 max_fails=3 fail_timeout=30s;
    server app2:3002 max_fails=3 fail_timeout=30s;
    server app3:3003 max_fails=3 fail_timeout=30s;
    
    keepalive 32;
    keepalive_requests 100;
    keepalive_timeout 60s;
}
```

### Docker Compose Services
```yaml
services:
  app1:
    environment:
      - PORT=3001
      - INSTANCE_NAME=App Instance 1
  app2:
    environment:
      - PORT=3002
      - INSTANCE_NAME=App Instance 2
  app3:
    environment:
      - PORT=3003
      - INSTANCE_NAME=App Instance 3
```

## 🌐 Service Endpoints

| Endpoint | Description |
|----------|-------------|
| `http://localhost:8080` | Main page (load balanced) |
| `http://localhost:8080/health` | Health check (via load balancer) |
| `http://localhost:8080/api/info` | JSON with instance info |
| `http://localhost:8080/nginx-health` | Nginx health |

## 🧪 Testing Scenarios

### 1. Basic Load Distribution Test
```bash
./test-loadbalancer.sh
```

### 2. Manual Request Testing
```bash
# Single request
curl http://localhost:8080/api/info | jq

# Multiple requests
for i in {1..9}; do
  curl -s http://localhost:8080/api/info | jq -r '.instance'
done
```

### 3. Failover Testing
```bash
# Stop one instance
docker stop demo-app1

# Test load balancing (should only use app2 and app3)
./test-loadbalancer.sh

# Restart the instance
docker start demo-app1

# Verify all 3 instances are used again
./test-loadbalancer.sh
```

### 4. Monitor Logs
```bash
# All services
./deploy.sh logs

# Specific instance
./deploy.sh logs app1
./deploy.sh logs app2
./deploy.sh logs nginx
```

### 5. Check Health Status
```bash
# All containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Detailed health
docker inspect demo-app1 | jq '.[0].State.Health'
```

## 📊 Load Balancing Algorithms

### Current: Round-Robin (Default)
Distributes requests evenly across all servers in sequence.

**Good for**: Equal capacity servers, stateless applications

### Alternative Algorithms

Edit `nginx/nginx.conf` upstream block:

#### Least Connections
```nginx
upstream backend_app {
    least_conn;
    server app1:3001;
    server app2:3002;
    server app3:3003;
}
```
Routes to server with fewest active connections.

#### IP Hash (Session Persistence)
```nginx
upstream backend_app {
    ip_hash;
    server app1:3001;
    server app2:3002;
    server app3:3003;
}
```
Same client IP always goes to same server.

#### Random
```nginx
upstream backend_app {
    random;
    server app1:3001;
    server app2:3002;
    server app3:3003;
}
```
Randomly selects a server.

## 🛠️ Customization

### Add More Instances

1. Edit `docker-compose.yml`:
```yaml
  app4:
    build:
      context: ./app
      dockerfile: Dockerfile
    image: nodejs-server-demo:latest
    container_name: demo-app4
    environment:
      - PORT=3004
      - INSTANCE_NAME=App Instance 4
    # ... rest of config
```

2. Edit `nginx/nginx.conf`:
```nginx
upstream backend_app {
    server app1:3001;
    server app2:3002;
    server app3:3003;
    server app4:3004;  # Add new instance
}
```

3. Restart:
```bash
./deploy.sh restart
```

### Configure Weights
```nginx
upstream backend_app {
    server app1:3001 weight=3;  # Gets 3x more requests
    server app2:3002 weight=1;
    server app3:3003 weight=1;
}
```

### Mark Server as Backup
```nginx
upstream backend_app {
    server app1:3001;
    server app2:3002;
    server app3:3003 backup;  # Only used if others fail
}
```

## 📖 Deployment Commands

```bash
./deploy.sh start         # Start all services
./deploy.sh stop          # Stop all services
./deploy.sh restart       # Rebuild and restart
./deploy.sh logs          # View all logs
./deploy.sh logs app1     # View specific instance
./deploy.sh status        # Check service status
./deploy.sh test          # Test connection
./deploy.sh clean         # Remove everything
./test-loadbalancer.sh    # Test load balancing
```

## 🐛 Troubleshooting

### All Requests Go to Same Instance
- Check nginx config has correct upstream servers
- Verify round-robin (no ip_hash directive)
- Clear browser cache or use curl

### Instance Not Receiving Requests
```bash
# Check health
docker ps

# Check logs
docker logs demo-app1

# Verify nginx can reach it
docker exec demo-nginx wget -qO- http://app1:3001/health
```

### Rebuild After Configuration Changes
```bash
# Reload nginx only (config changes)
docker exec demo-nginx nginx -s reload

# Full restart (code changes)
./deploy.sh restart
```

## 🎯 What This Demonstrates

### Load Balancing Concepts
- ✅ **Distribution algorithms** (round-robin, least_conn, ip_hash)
- ✅ **Health checks** and automatic failover
- ✅ **Horizontal scaling** with multiple instances
- ✅ **Session persistence** options
- ✅ **Weighted load balancing**

### Docker Skills
- ✅ **Multiple containers** from same image
- ✅ **Environment variables** for configuration
- ✅ **Service dependencies** and orchestration
- ✅ **Health monitoring**

### Production Practices
- ✅ **High availability** through redundancy
- ✅ **Zero-downtime** deployments (rolling updates)
- ✅ **Fault tolerance** with automatic failover
- ✅ **Performance** with keepalive connections

## 📝 Load Balancing Benefits

1. **High Availability**: If one instance fails, others continue serving
2. **Scalability**: Easy to add more instances
3. **Performance**: Distribute load across multiple servers
4. **Maintenance**: Update instances without downtime

## 🎓 Next Steps

- Implement sticky sessions for stateful apps
- Add monitoring with Prometheus
- Set up SSL/TLS termination at load balancer
- Configure rate limiting
- Add caching layer with Redis
- Implement circuit breakers
- Deploy to production with container orchestration (Kubernetes)

## 📝 License

Free to use for learning and development.
