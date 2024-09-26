FROM alpine
RUN apk add curl nftables
COPY install.sh /install.sh
COPY scripts /scripts
RUN sh /install.sh && cp /scripts/menu.sh /etc/ShellCrash && cp /scripts/start.sh /etc/ShellCrash && \
    cp /scripts/webget.sh /etc/ShellCrash && chmod +x /etc/ShellCrash/menu.sh && \
    chmod +x /etc/ShellCrash/start.sh && chmod +x /etc/ShellCrash/webget.sh && \
    crash -l https://s1.trojanflare.one/clashx/01698000-0f5c-4e71-bbbd-a7d9f541109b && \
    crash -s start init

