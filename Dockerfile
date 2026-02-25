FROM node:22-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    procps \
    sudo \
    fzf \
    zsh \
    wget \
    ca-certificates \
    gnupg2 \
    jq \
    unzip \
    ripgrep \
    fd-find \
    less \
    gh \
    curl \
    python3 \
    build-essential \
    openssh-client \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up non-root user and directories
ARG USERNAME=node
RUN mkdir -p /usr/local/share/npm-global /workspace /home/node/.claude /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME:$USERNAME /usr/local/share/npm-global /workspace /home/node/.claude /commandhistory

# Install delta
RUN ARCH=$(dpkg --print-architecture) \
    && wget -q "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" \
    && dpkg -i "git-delta_0.18.2_${ARCH}.deb" \
    && rm "git-delta_0.18.2_${ARCH}.deb"

USER $USERNAME
WORKDIR /workspace

# Environment setup
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/bin/zsh
ENV HISTFILE=/commandhistory/.bash_history
ENV PROMPT_COMMAND='history -a'

# Install zsh configuration and claude-code
ARG CLAUDE_VERSION=latest
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)" -- \
    -t robbyrussell \
    -p git \
    -p fzf \
    -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
    -a "source /usr/share/doc/fzf/examples/completion.zsh" \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -x \
    && npm install -g @anthropic-ai/claude-code${CLAUDE_VERSION:+@$CLAUDE_VERSION}

VOLUME /commandhistory
