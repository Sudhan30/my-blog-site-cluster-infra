# Use specific nginx:alpine version to avoid tag resolution pulls
FROM nginx:1.25-alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Copy static files
COPY public/ /usr/share/nginx/html/

# Create health check endpoint (combine with static files copy to reduce layers)
RUN echo '<!DOCTYPE html><html><body><h1>Health Check</h1><p>Blog is healthy</p></body></html>' > /usr/share/nginx/html/health.html

# Expose port
EXPOSE 80

# Health check (use wget instead of curl to avoid additional package installs)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
