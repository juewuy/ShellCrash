FROM alpine
RUN apk add curl nftables
COPY install.sh /install.sh
RUN sh /install.sh -d /app && crash -l https://s1.trojanflare.one/clashx/01698000-0f5c-4e71-bbbd-a7d9f541109b && \
    crash -s start init