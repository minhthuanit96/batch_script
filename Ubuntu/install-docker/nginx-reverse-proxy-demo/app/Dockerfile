# Use official Node.js LTS (Long Term Support) image as base
FROM node:18-alpine

# Set metadata
LABEL maintainer="your-email@example.com"
LABEL description="Custom Node.js HTTP server for reverse proxy demo"
LABEL version="1.0.0"

# Create app directory
WORKDIR /usr/src/app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy package files
COPY package*.json ./

# Install dependencies (if any in the future)
# For now, we're using only Node.js built-in modules, so this is optional
RUN npm install --omit=dev 2>/dev/null || true

# Copy application source code
COPY server.js ./

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /usr/src/app

# Switch to non-root user
USER nodejs

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Start the application
CMD ["node", "server.js"]
