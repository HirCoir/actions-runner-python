# Multi-stage Dockerfile for GitHub Actions Self-Hosted Runner with Python
# Stage 1: Download and prepare runner
FROM ubuntu:22.04 as runner-base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_VERSION=2.328.0
ENV RUNNER_ARCH=x64

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    tar \
    sudo \
    git \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Download and extract GitHub Actions Runner
WORKDIR /home/runner
RUN curl -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    echo "01066fad3a2893e63e6ca880ae3a1fad5bf9329d60e77ee15f2b97c148c3cd4e  actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" | sha256sum -c && \
    tar xzf ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz

# Stage 2: Final image with Python and development tools
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# GitHub Actions Runner configuration environment variables
ENV GITHUB_URL=""
ENV GITHUB_TOKEN=""
ENV RUNNER_NAME=""
ENV RUNNER_LABELS=""
ENV RUNNER_GROUP=""
ENV RUNNER_WORK_DIR="_work"

# Install system dependencies including Python
RUN apt-get update && apt-get install -y \
    # Base system tools
    curl \
    wget \
    unzip \
    tar \
    sudo \
    git \
    jq \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    gnupg \
    lsb-release \
    # Python and development tools
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    # Build tools and dependencies for Python packages
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config \
    # Dependencies for numpy, pandas, matplotlib
    libopenblas-dev \
    liblapack-dev \
    gfortran \
    libfreetype6-dev \
    libpng-dev \
    libjpeg-dev \
    libffi-dev \
    libssl-dev \
    # Additional useful tools
    vim \
    nano \
    htop \
    tree \
    zip \
    unzip \
    # Node.js (often needed for GitHub Actions)
    nodejs \
    npm \
    # Docker CLI (for Docker-in-Docker scenarios)
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic link for python command
RUN ln -s /usr/bin/python3 /usr/bin/python

# Upgrade pip and install common Python packages
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install packages in stages to better handle build issues
RUN python3 -m pip install --no-cache-dir \
    # Basic packages first
    requests \
    pyyaml \
    python-dotenv \
    click

RUN python3 -m pip install --no-cache-dir \
    # Development tools
    pytest \
    black \
    flake8 \
    mypy \
    pylint

RUN python3 -m pip install --no-cache-dir \
    # Web frameworks
    flask \
    fastapi

# Install data science packages separately (they need more build dependencies)
RUN python3 -m pip install --no-cache-dir \
    numpy

RUN python3 -m pip install --no-cache-dir \
    pandas

RUN python3 -m pip install --no-cache-dir \
    matplotlib

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    usermod -aG docker runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy runner files from previous stage
COPY --from=runner-base --chown=runner:runner /home/runner /home/runner

# Switch to runner user
USER runner
WORKDIR /home/runner

# Install runner dependencies
RUN sudo ./bin/installdependencies.sh

# Create entrypoint script
RUN cat > entrypoint.sh << 'EOF'
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

# Configure runner
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

# Start runner
echo "Starting GitHub Actions Runner..."
exec ./run.sh
EOF

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Expose working directory as volume
VOLUME ["/home/runner/_work"]

# Set entrypoint
ENTRYPOINT ["./entrypoint.sh"]
