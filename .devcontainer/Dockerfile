FROM alpine:latest

ARG USERNAME=vscode

# Install packages using apk
RUN apk update && apk add --no-cache \
    bash \
    zola \
    just \
    npm \
    git \
    openssh-client \
    sudo \
    shadow \
    && rm -rf /var/cache/apk/*

# Create user and configure sudo
RUN adduser -D -s /bin/bash -G wheel -u 1000 ${USERNAME} \
    && echo "%wheel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN mkdir -p /home/${USERNAME}/.npm-global \
    && npm config set prefix /home/${USERNAME}/.npm-global
ENV PATH="$PATH:/home/${USERNAME}/.npm-global/bin"

RUN npm install -g wrangler
