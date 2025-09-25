# Use specific node:18-alpine version to avoid tag resolution pulls
FROM node:18.19-alpine

# Set working directory
WORKDIR /app

# Create non-root user first (for better layer caching)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy package files
COPY package*.json ./

# Install dependencies (as root, then change ownership)
RUN npm install --omit=dev --frozen-lockfile && \
    npm cache clean --force

# Copy application code
COPY . .

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Start the application
CMD ["npm", "start"]