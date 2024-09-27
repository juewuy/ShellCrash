FROM alpine
RUN apk add curl nftables
COPY install.sh /install.sh
COPY scripts /scripts
RUN sh /install.sh -d /app && cp /scripts/menu.sh /app && cp /scripts/start.sh /app && \
    cp /scripts/webget.sh /app && chmod +x /app/menu.sh && \
    chmod +x /app/start.sh && chmod +x /app/webget.sh && \
    crash -l https://s1.trojanflare.one/clashx/01698000-0f5c-4e71-bbbd-a7d9f541109b && \
    crash -s start init

