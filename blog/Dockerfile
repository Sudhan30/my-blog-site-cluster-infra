FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Copy static files (if you have any)
COPY public/ /usr/share/nginx/html/ 2>/dev/null || true

# Create health check endpoint
RUN echo '<!DOCTYPE html><html><body><h1>Health Check</h1><p>Blog is healthy</p></body></html>' > /usr/share/nginx/html/health.html

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
