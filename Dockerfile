FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# UID/GID do usuário do host — default 1000 (usuário Linux padrão).
# Sobrescreva se seu usuário host tiver outro UID: docker build --build-arg USER_UID=$(id -u)
ARG USER_UID=1000
ARG USER_GID=1000

# ── Base tools ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    curl wget git git-lfs ca-certificates \
    make build-essential gcc g++ cmake pkg-config \
    python3 python3-pip python3-venv pipx \
    zsh tmux vim nano jq sudo unzip zip \
    xdg-utils htop tree \
    libssl-dev libffi-dev \
    openssh-client fonts-powerline \
    eza bat fd-find ripgrep fzf zoxide git-delta lazygit starship neovim \
    && rm -rf /var/lib/apt/lists/*

# fd-find instala como fdfind — criar alias fd
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd
# bat instala como batcat no Ubuntu — criar alias bat
RUN ln -sf /usr/bin/batcat /usr/local/bin/bat

# ── User ─────────────────────────────────────────────────────────────
# Remove o usuário ubuntu default da imagem para liberar o UID 1000
RUN userdel -r ubuntu 2>/dev/null || true

RUN groupadd -g ${USER_GID} dev && \
    useradd -m -s /bin/zsh -u ${USER_UID} -g dev dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev
WORKDIR /workspace

# ── Oh My Zsh ────────────────────────────────────────────────────────
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" '' --unattended

# ── nvm + Node ───────────────────────────────────────────────────────
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
ENV NVM_DIR=/home/dev/.nvm
ENV NODE_VERSION=22
ENV PATH="/home/dev/.local/bin:$PATH"

RUN [ -s "$NVM_DIR/nvm.sh" ] && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    echo "export PATH=\"\$(nvm which \$NODE_VERSION | xargs dirname):\$PATH\"" >> /home/dev/.zshrc

# ── pnpm, yarn ───────────────────────────────────────────────────────
RUN bash -lc '. "$NVM_DIR/nvm.sh" && nvm use $NODE_VERSION && npm install -g pnpm yarn'

# ── Bun ──────────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash

# ── uv + yq (pipx) ───────────────────────────────────────────────────
# Instala em /opt/pipx (fora de ~/.local/share que é montado do host)
RUN sudo mkdir -p /opt/pipx && sudo chown dev:dev /opt/pipx
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/opt/pipx/bin
ENV PATH="/opt/pipx/bin:/home/dev/.local/bin:$PATH"
RUN pipx install uv
RUN pipx install yq

# ── GitHub CLI ───────────────────────────────────────────────────────
RUN sudo install -d -m 0755 /usr/share/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    sudo apt-get update && sudo apt-get install -y gh

# ── Docker CLI ───────────────────────────────────────────────────────
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    sudo apt-get update && sudo apt-get install -y docker-ce-cli docker-compose-plugin

# ── Kubernetes ───────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && sudo install -m 755 /tmp/kubectl /usr/local/bin/kubectl \
    && rm /tmp/kubectl

RUN curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod +x /tmp/get_helm.sh \
    && /tmp/get_helm.sh \
    && rm /tmp/get_helm.sh

# ── OpenCode ─────────────────────────────────────────────────────────
RUN bash -lc '. "$NVM_DIR/nvm.sh" && nvm use $NODE_VERSION && npm install -g opencode-ai@latest'

# ── Symlinks globais ────────────────────────────────────────────────
# Expor binários do nvm/node/bun para todo shell (sem depender de nvm no PATH)
RUN bash -lc '. "$NVM_DIR/nvm.sh" && nvm use $NODE_VERSION >/dev/null && \
    NODE_BIN="$(dirname "$(nvm which $NODE_VERSION)")" && \
    for bin in node npm npx corepack yarn pnpm opencode; do \
        sudo ln -sf "$NODE_BIN/$bin" /usr/local/bin/$bin; \
    done && \
    sudo ln -sf /home/dev/.bun/bin/bun /usr/local/bin/bun && \
    sudo ln -sf /home/dev/.bun/bin/bunx /usr/local/bin/bunx'

# ── Workspace directories ────────────────────────────────────────────
RUN sudo mkdir -p /workspace/projects /workspace/company /workspace/personal /workspace/playground /workspace/tmp \
    && sudo chown dev:dev /workspace

# ── Bootstrap & startup scripts ──────────────────────────────────────
COPY --chown=dev:dev bootstrap/ /home/dev/bootstrap/
COPY --chown=dev:dev startup.d/ /home/dev/startup.d/
COPY --chown=dev:dev scripts/ /home/dev/scripts/
COPY --chown=dev:dev tools/ /home/dev/tools/
COPY --chown=dev:dev entrypoint.sh /usr/local/bin/entrypoint.sh

RUN sudo chmod +x /usr/local/bin/entrypoint.sh \
    /home/dev/bootstrap/*.sh \
    /home/dev/startup.d/*.sh \
    /home/dev/scripts/*.sh \
    /home/dev/tools/*.sh

# ── Zsh config ───────────────────────────────────────────────────────
RUN cat >> /home/dev/.zshrc << 'ZSHRC'

# PATH adicional (pipx, uv)
export PATH="$HOME/.local/bin:$PATH"

# Starship prompt
eval "$(starship init zsh)"

# NVM
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# zoxide
eval "$(zoxide init zsh)"

# fzf
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# Aliases
alias ls='eza'
alias ll='eza -la'
alias la='eza -la'
alias grep='rg'
alias find='fd'
alias cat='bat'
alias g='lazygit'
alias dk='docker'
alias dka='docker compose'
ZSHRC

# ── Default config dirs ──────────────────────────────────────────────
RUN mkdir -p /home/dev/.config/opencode /home/dev/.config/nvim

USER dev
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
