# Node.js HTTP Server

A simple, production-ready HTTP server built with pure Node.js (no external dependencies).

## Features

- ✅ Pure Node.js - no npm packages required
- ✅ Styled HTML response with server information
- ✅ Multiple endpoints (HTML, JSON, health check)
- ✅ Request logging with timestamps
- ✅ Graceful shutdown handling
- ✅ Environment variable configuration
- ✅ Docker-ready with health checks

## Running Locally (without Docker)

### Prerequisites
- Node.js 18+ installed

### Start Server
```bash
# Default port 3000
node server.js

# Custom port
PORT=4000 node server.js
```

### Access
- Main page: http://localhost:3000
- Health check: http://localhost:3000/health
- Server info API: http://localhost:3000/api/info

## Running with Docker

### Build Image
```bash
docker build -t nodejs-server-demo .
```

### Run Container
```bash
docker run -d \
  --name my-node-server \
  -p 3000:3000 \
  -e PORT=3000 \
  nodejs-server-demo
```

### Check Health
```bash
docker ps
docker logs my-node-server
curl http://localhost:3000/health
```

## Endpoints

| Endpoint | Method | Response Type | Description |
|----------|--------|---------------|-------------|
| `/` | GET | HTML | Styled page with server info |
| `/health` | GET | JSON | Health check status |
| `/api/info` | GET | JSON | Detailed server information |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server listening port |
| `NODE_ENV` | - | Node environment (development/production) |

## Server Information Displayed

- Hostname (container ID in Docker)
- Platform (linux, darwin, win32)
- Node.js version
- Process uptime
- Memory usage (free/total)
- Current timestamp

## Development

### Watch Mode (Node 18+)
```bash
npm run dev
# or
node --watch server.js
```

### Modify Response
Edit the `html` variable in `server.js` to customize the response.

## Production Deployment

The server includes:
- Graceful shutdown on SIGTERM/SIGINT
- Request logging
- Health check endpoint
- Non-root user execution (in Docker)

## License

MIT
