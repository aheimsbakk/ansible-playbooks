FROM docker.io/debian:bookworm

# Author of this container
LABEL org.opencontainers.image.authors="arnulf.heimsbakk@gmail.com"

# Install software
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install git sudo powerline pipenv locales procps nano \
    && apt-get -y autoremove

# Add vscode user with bash as default shell
RUN useradd -m -s /bin/bash -u 1000 vscode

# Allow vscode to be sudo in devcontainer without password
RUN echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode

# Set powerline for vscode and root user
RUN echo "if [ -f `which powerline-daemon` ]; then powerline-daemon -q; POWERLINE_BASH_CONTINUATION=1; POWERLINE_BASH_SELECT=1; . /usr/share/powerline/bindings/bash/powerline.sh; fi" >>  /home/vscode/.bashrc
RUN echo "if [ -f `which powerline-daemon` ]; then powerline-daemon -q; POWERLINE_BASH_CONTINUATION=1; POWERLINE_BASH_SELECT=1; . /usr/share/powerline/bindings/bash/powerline.sh; fi" >>  /root/.bashrc

# Enter vscode user
USER vscode

# Use bash as entrypoint
ENTRYPOINT ["/bin/bash"]
