
#!/bin/bash

# deploy.sh - Main deployment script for CRUD application

set -e

DEPLOY_ALL=${1:-false}
SERVICES=${2:-""}
APP_DIR="/opt/crud-app"

echo "=== CRUD Application Deployment ==="
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

# Function to wait for service
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1

    echo "Waiting for $service..."

    while [ "$attempt" -le "$max_attempts" ]; do

        if docker compose ps --status running --services | grep -Fxq "$service"; then
            echo "✓ $service is running"
            return 0
        fi

        echo "Attempt $attempt/$max_attempts: $service is not running"

        sleep 10
        attempt=$((attempt + 1))
    done

    echo "ERROR: $service failed to start within timeout"
    return 1
}

# Function to deploy all services
deploy_all_services() {

    echo "Deploying all services..."

    # Build and start all services
    # Existing database volumes will be preserved
    docker compose up -d --build

    # Wait for services
    wait_for_service "db"
    wait_for_service "redis"
    wait_for_service "backend"
    wait_for_service "frontend"

    echo "✓ All services deployed"
}

# Function to deploy specific services
deploy_specific_services() {

    local services=($1)

    echo "Deploying specific services: ${services[*]}"

    for service in "${services[@]}"; do

        if [ -z "$service" ]; then
            continue
        fi

        echo "Deploying service: $service"

        # Handle backend dependencies
        if [ "$service" = "backend" ]; then

            echo "Starting database and redis..."

            docker compose up -d db redis

            wait_for_service "db"
            wait_for_service "redis"
        fi

        # Pull latest image if available
        docker compose pull "$service" 2>/dev/null || \
            echo "No pre-built image for $service. Building locally..."

        # Build and restart selected service
        docker compose up -d --build --no-deps "$service"

        # Wait for service
        wait_for_service "$service"

        echo "✓ Service $service deployed"

    done
}

# Execute deployment
if [ "$DEPLOY_ALL" = "true" ]; then

    deploy_all_services

elif [ -n "$SERVICES" ]; then

    deploy_specific_services "$SERVICES"

else

    echo "No services to deploy"
fi

# Show final deployment status
echo ""
echo "=== Deployment Finished ==="
echo ""
echo "Running services:"

docker compose ps

echo ""
echo "Deployment script completed successfully!"

