# Multi-stage Dockerfile for GitHub Actions Self-Hosted Runner with Python
# Stage 1: Download and prepare runner
FROM --platform=$TARGETPLATFORM ubuntu:22.04 AS runner-base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_VERSION=2.327.1

# Use build arguments for platform detection
ARG TARGETPLATFORM
ARG BUILDPLATFORM

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

# Download and extract GitHub Actions Runner based on target platform
WORKDIR /home/runner
RUN echo "Target platform: $TARGETPLATFORM" && \
    case ${TARGETPLATFORM} in \
        linux/amd64) \
            RUNNER_ARCH=x64 && \
            RUNNER_CHECKSUM=01066fad3a2893e63e6ca880ae3a1fad5bf9329d60e77ee15f2b97c148c3cd4e \
            ;; \
        linux/arm64) \
            RUNNER_ARCH=arm64 && \
            RUNNER_CHECKSUM=b801b9809c4d9301932bccadf57ca13533073b2aa9fa9b8e625a8db905b5d8eb \
            ;; \
        linux/arm/v7) \
            RUNNER_ARCH=arm && \
            RUNNER_CHECKSUM=530bb83124f38edc9b410fbcc0a8b0baeaa336a14e3707acc8ca308fe0cb7540 \
            ;; \
        *) \
            echo "Unsupported platform: ${TARGETPLATFORM}" && \
            exit 1 \
            ;; \
    esac && \
    echo "Downloading runner for architecture: ${RUNNER_ARCH}" && \
    curl -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz -L \
        https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    echo "${RUNNER_CHECKSUM}  actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" | sha256sum -c && \
    tar xzf ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz

# Stage 2: Final image with Python and development tools
FROM --platform=$TARGETPLATFORM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# GitHub Actions Runner configuration environment variables
ENV GITHUB_URL=""
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

# Install GitHub CLI - Alternative method for better ARM64 compatibility
RUN apt-get update && apt-get install -y wget gpg \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor > /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update --allow-insecure-repositories \
    && apt-get install -y --allow-unauthenticated gh \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic link for python command
RUN ln -s /usr/bin/python3 /usr/bin/python

# Upgrade pip only - packages will be installed in workflows as needed
RUN python3 -m pip install --upgrade pip setuptools wheel

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

# Copy and setup entrypoint script
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

# Expose working directory as volume
#VOLUME ["/home/runner/_work"]

# Set entrypoint
ENTRYPOINT ["./entrypoint.sh"]
