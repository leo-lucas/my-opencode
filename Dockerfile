FROM ubuntu:26.04

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    make \
    build-essential \
    gcc \
    g++ \
    python3 \
    python3-pip \
    pipx \
    vim \
    nano \
    jq \
    sudo \
    unzip \
    wget \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=22
ENV PATH="/root/.nvm/versions/node/v22.23.1/bin:/root/.local/bin:/root/.cargo/bin:$PATH"

RUN [ -s "$NVM_DIR/nvm.sh" ] && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    npm install -g opencode-ai@latest

RUN git clone https://github.com/leo-lucas/my-term.git /tmp/my-term && \
    chmod +x /tmp/my-term/install.sh /tmp/my-term/install-nvim.sh /tmp/my-term/install-opencode.sh /tmp/my-term/scripts/*.sh && \
    CI=true /tmp/my-term/scripts/setup-zsh.sh && \
    CI=true /tmp/my-term/scripts/setup-oh-my-zsh.sh && \
    CI=true /tmp/my-term/scripts/setup-zshrc.sh && \
    CI=true /tmp/my-term/scripts/setup-spaceship.sh && \
    CI=true /tmp/my-term/install-nvim.sh

RUN echo '# Load nvm\nexport NVM_DIR="$NVM_DIR"\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\nexport PATH="/root/.local/bin:$PATH"' >> ~/.bashrc

ENV OPENCODE_DIR=/opencode
ENV WORKSPACE_DIR=/workspace

RUN mkdir -p ${OPENCODE_DIR} ${WORKSPACE_DIR}

WORKDIR ${WORKSPACE_DIR}

ENV OPENCODE_CONFIG_DIR=${OPENCODE_DIR}/.opencode

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["tui"]
