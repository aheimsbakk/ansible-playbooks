FROM docker.io/debian:latest
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install git sudo powerline pipenv \
    && apt-get -y autoremove
RUN useradd -m -s /bin/bash -u 1000 vscode
RUN echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode
RUN echo "if [ -f `which powerline-daemon` ]; then powerline-daemon -q; POWERLINE_BASH_CONTINUATION=1; POWERLINE_BASH_SELECT=1; . /usr/share/powerline/bindings/bash/powerline.sh; fi" >>  /home/vscode/.bashrc
RUN echo "if [ -f `which powerline-daemon` ]; then powerline-daemon -q; POWERLINE_BASH_CONTINUATION=1; POWERLINE_BASH_SELECT=1; . /usr/share/powerline/bindings/bash/powerline.sh; fi" >>  /root/.bashrc
USER vscode
ENTRYPOINT ["/bin/bash"]
