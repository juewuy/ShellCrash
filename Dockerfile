FROM alpine
RUN apk add curl nftables
RUN sh <(curl -kfsSl https://raw.githubusercontent.com/jimorsm/ShellCrash/master/install.sh) -d /app && \
   crash -l https://your-subscription-address 
CMD [ "/app/start.sh","start" ]
