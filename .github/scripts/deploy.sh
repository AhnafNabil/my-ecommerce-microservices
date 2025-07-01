#!/bin/bash

# deploy.sh - Main deployment script with environment variable injection

set -e

DEPLOY_ALL=${1:-false}
SERVICES=${2:-""}
APP_DIR="/opt/ecommerce-app"

echo "=== E-commerce Microservices Deployment ==="
echo "Deploy All: $DEPLOY_ALL"
echo "Services: $SERVICES"
echo "Working Directory: $APP_DIR"
echo ""

# Change to application directory
cd "$APP_DIR"

# Pull latest code
echo "Pulling latest code..."
git fetch origin
git reset --hard origin/main
echo "✓ Code updated"

# Create/Update environment files with secrets
create_env_files() {
    echo "Setting up environment variables..."
    
    # Update notification service .env file
    if [ -f "notification-service/.env" ]; then
        # Backup original
        cp notification-service/.env notification-service/.env.backup
        
        # Update SMTP credentials if provided
        if [ -n "$SMTP_USER" ]; then
            sed -i "s/^SMTP_USER=.*/SMTP_USER=${SMTP_USER}/" notification-service/.env
        fi
        if [ -n "$SMTP_PASSWORD" ]; then
            sed -i "s/^SMTP_PASSWORD=.*/SMTP_PASSWORD=${SMTP_PASSWORD}/" notification-service/.env
        fi
        
        echo "✓ Updated notification service environment variables"
    else
        echo "⚠️ Warning: notification-service/.env not found"
    fi
}

# Function to deploy all services
deploy_all_services() {
    echo "Deploying all services..."
    
    create_env_files
    
    echo "Stopping all services..."
    docker-compose down
    
    echo "Pulling latest images..."
    docker-compose pull 2>/dev/null || echo "Building images locally..."
    
    echo "Building and starting all services..."
    docker-compose up -d --build
    
    echo "✓ All services deployed"
}

# Function to deploy specific services
deploy_specific_services() {
    local services=($1)
    
    echo "Deploying specific services: ${services[*]}"
    
    # Update env files if notification-service is being deployed
    for service in "${services[@]}"; do
        if [ "$service" = "notification-service" ]; then
            create_env_files
            break
        fi
    done
    
    for service in "${services[@]}"; do
        if [ -z "$service" ]; then
            continue
        fi
        
        echo "Deploying service: $service"
        
        # Pull latest image for the service
        docker-compose pull "$service" 2>/dev/null || echo "No pre-built image for $service, will build locally"
        
        # Build and restart the service
        docker-compose up -d --build --no-deps "$service"
        
        echo "✓ Service $service deployed"
        
        # Wait a moment for service to start
        sleep 5
    done
}

# Execute deployment
if [ "$DEPLOY_ALL" = "true" ]; then
    deploy_all_services
else
    if [ -n "$SERVICES" ]; then
        deploy_specific_services "$SERVICES"
    else
        echo "No services to deploy"
    fi
fi

echo ""
echo "=== Deployment completed successfully ==="

# Show running services
echo ""
echo "Running services:"
docker-compose ps