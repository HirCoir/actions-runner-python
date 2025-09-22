#!/bin/bash
set -e

# Check required environment variables
if [ -z "$GITHUB_URL" ]; then
    echo "Error: GITHUB_URL environment variable is required"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

# Set default runner name if not provided
if [ -z "$RUNNER_NAME" ]; then
    RUNNER_NAME=$(hostname)
fi

# Set restart delay (default 10 seconds)
RESTART_DELAY=${RESTART_DELAY:-10}

# Function to configure runner
configure_runner() {
    echo "Removing any existing runner registration..."
    ./config.sh remove --token "$GITHUB_TOKEN" || true
    
    echo "Configuring GitHub Actions Runner..."
    ./config.sh \
        --url "$GITHUB_URL" \
        --token "$GITHUB_TOKEN" \
        --name "$RUNNER_NAME" \
        --work "$RUNNER_WORK_DIR" \
        --labels "$RUNNER_LABELS" \
        --runnergroup "$RUNNER_GROUP" \
        --unattended \
        --replace
}

# Function to start runner with restart logic
start_runner() {
    local attempt=1
    
    while true; do
        echo "Starting GitHub Actions Runner (attempt #$attempt)..."
        
        # Configure runner before each start
        configure_runner
        
        # Start the runner
        ./run.sh
        
        local exit_code=$?
        echo "Runner exited with code: $exit_code"
        
        # If exit code is 0 or 2 (graceful shutdown), don't restart
        if [ $exit_code -eq 0 ] || [ $exit_code -eq 2 ]; then
            echo "Runner shutdown gracefully. Exiting..."
            break
        fi
        
        echo "Runner crashed or exited unexpectedly. Restarting in $RESTART_DELAY seconds..."
        sleep $RESTART_DELAY
        
        attempt=$((attempt + 1))
    done
}

# Handle signals for graceful shutdown
cleanup() {
    echo "Received shutdown signal. Cleaning up..."
    ./config.sh remove --token "$GITHUB_TOKEN" || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start the runner with restart logic
start_runner
