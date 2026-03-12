const http = require('http');
const os = require('os');

// Configuration
const PORT = process.env.PORT || 3000;
const INSTANCE_NAME = process.env.INSTANCE_NAME || 'Default Instance';
const HOST = '0.0.0.0';

// Get server information
const getServerInfo = () => {
    return {
        hostname: os.hostname(),
        platform: os.platform(),
        nodeVersion: process.version,
        uptime: process.uptime(),
        memory: {
            total: Math.round(os.totalmem() / 1024 / 1024) + ' MB',
            free: Math.round(os.freemem() / 1024 / 1024) + ' MB'
        }
    };
};

// Create HTTP server
const server = http.createServer((req, res) => {
    const serverInfo = getServerInfo();

    // Log request
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.socket.remoteAddress}`);

    // Handle different routes
    if (req.url === '/health') {
        // Health check endpoint
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'healthy', port: PORT }));
    } else if (req.url === '/api/info') {
        // API endpoint with JSON response
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            instance: INSTANCE_NAME,
            port: PORT,
            message: `Response from ${INSTANCE_NAME} on port ${PORT}`,
            serverInfo: serverInfo,
            timestamp: new Date().toISOString()
        }, null, 2));
    } else {
        // Default HTML response
        const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Node.js Server Response</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 600px;
            width: 100%;
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2em;
        }
        .port-info {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
            font-size: 1.2em;
            text-align: center;
            font-weight: bold;
        }
        .server-info {
            background: #f7f7f7;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
        .server-info h2 {
            color: #333;
            font-size: 1.2em;
            margin-bottom: 15px;
        }
        .info-item {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #ddd;
        }
        .info-item:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: 600;
            color: #555;
        }
        .value {
            color: #667eea;
            font-family: 'Courier New', monospace;
        }
        .timestamp {
            text-align: center;
            color: #999;
            font-size: 0.9em;
            margin-top: 20px;
        }
        .badge {
            display: inline-block;
            background: #4caf50;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <span class="badge">✓ Active</span>
        <h1>🚀 Node.js Server</h1>
        <p style="color: #666; margin-bottom: 20px;">Custom built Docker container</p>
        
        <div class="port-info">
            📡 ${INSTANCE_NAME} - Port ${PORT}
        </div>
        
        <div class="server-info">
            <h2>📊 Server Information</h2>
            <div class="info-item">
                <span class="label">Instance:</span>
                <span class="value">${INSTANCE_NAME}</span>
            </div>
            <div class="info-item">
                <span class="label">Port:</span>
                <span class="value">${PORT}</span>
            </div>
            <div class="info-item">
                <span class="label">Hostname:</span>
                <span class="value">${serverInfo.hostname}</span>
            </div>
            <div class="info-item">
                <span class="label">Platform:</span>
                <span class="value">${serverInfo.platform}</span>
            </div>
            <div class="info-item">
                <span class="label">Node.js Version:</span>
                <span class="value">${serverInfo.nodeVersion}</span>
            </div>
            <div class="info-item">
                <span class="label">Uptime:</span>
                <span class="value">${Math.round(serverInfo.uptime)}s</span>
            </div>
            <div class="info-item">
                <span class="label">Memory (Free/Total):</span>
                <span class="value">${serverInfo.memory.free} / ${serverInfo.memory.total}</span>
            </div>
        </div>
        
        <div class="timestamp">
            🕐 ${new Date().toISOString()}
        </div>
    </div>
</body>
</html>
        `;

        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(html);
    }
});

// Start server
server.listen(PORT, HOST, () => {
    console.log('='.repeat(50));
    console.log(`🚀 Node.js Server Started`);
    console.log('='.repeat(50));
    console.log(`📡 Listening on: http://${HOST}:${PORT}`);
    console.log(`🏠 Hostname: ${os.hostname()}`);
    console.log(`💻 Platform: ${os.platform()}`);
    console.log(`📦 Node.js: ${process.version}`);
    console.log('='.repeat(50));
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('\n📴 SIGTERM received, shutting down gracefully...');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('\n📴 SIGINT received, shutting down gracefully...');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});
