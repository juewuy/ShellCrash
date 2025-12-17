############################
# Stage 1: builder
############################
FROM alpine:latest AS builder

ARG TARGETPLATFORM
ARG TZ=Asia/Shanghai
ARG S6_OVERLAY_V=v3.2.1.0

RUN apk add --no-cache \
    curl \
    ca-certificates \
    tar \
	gzip \
	xz \
    tzdata \
    dcron

# 时区
RUN ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

WORKDIR /build

#安装脚本相关文件
COPY ShellCrash.tar.gz /tmp/ShellCrash.tar.gz
RUN set -eux; \
    mkdir -p /tmp/SC_tmp; \
    tar -zxf /tmp/ShellCrash.tar.gz -C /tmp/SC_tmp; \
    /bin/sh /tmp/SC_tmp/init.sh
	
#获取内核及s6文件
RUN set -eux; \
	case "$TARGETPLATFORM" in \
      linux/amd64)  K=amd64 S=x86_64;; \
      linux/arm64)  K=arm64 S=aarch64;; \
      linux/arm/v7) K=armv7 S=arm;; \
      linux/386)    K=386 S=i486;; \
      *) echo "unsupported $TARGETPLATFORM" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/juewuy/ShellCrash/raw/update/bin/meta/clash-linux-${K}.tar.gz" -o /tmp/CrashCore.tar.gz; \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_V}/s6-overlay-${S}.tar.xz" -o /tmp/s6_arch.tar.xz; \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_V}/s6-overlay-noarch.tar.xz" -o /tmp/s6_noarch.tar.xz && ls -l /tmp

#安装面板文件
RUN set -eux; \
    mkdir -p /etc/ShellCrash/ruleset /etc/ShellCrash/ui; \
    curl -fsSL "https://github.com/juewuy/ShellCrash/raw/update/bin/geodata/mrs.tar.gz" | tar -zxf - -C /etc/ShellCrash/ruleset; \
    curl -fsSL "https://github.com/juewuy/ShellCrash/raw/update/bin/dashboard/zashboard.tar.gz" | tar -zxf - -C /etc/ShellCrash/ui
	  
############################
# Stage 2: runtime
############################
FROM alpine:latest

ARG TZ=Asia/Shanghai

LABEL org.opencontainers.image.source="https://github.com/juewuy/ShellCrash"
#安装依赖
RUN apk add --no-cache \
	tini \
	openrc \
    wget \
    ca-certificates \
    tzdata \
    nftables \
    iproute2 \
    dcron
#清理openrc
RUN apk del openrc && rm -rf /etc/runlevels/* /run/openrc

RUN ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

#复制文件
COPY --from=builder /etc/ShellCrash /etc/ShellCrash
COPY --from=builder /tmp/CrashCore.tar.gz /etc/ShellCrash/CrashCore.tar.gz
COPY --from=builder /etc/profile /etc/profile
COPY --from=builder /usr/bin/crash /usr/bin/crash

#安装s6
COPY --from=builder /tmp/s6_arch.tar.xz /tmp/s6_arch.tar.xz
COPY --from=builder /tmp/s6_noarch.tar.xz /tmp/s6_noarch.tar.xz
RUN tar -xJf /tmp/s6_noarch.tar.xz -C / && rm -rf /tmp/s6_noarch.tar.xz
RUN tar -xJf /tmp/s6_arch.tar.xz -C / && rm -rf /tmp/s6_arch.tar.xz
COPY docker/s6-rc.d /etc/s6-overlay/s6-rc.d
ENV S6_CMD_WAIT_FOR_SERVICES=1

ENTRYPOINT ["/init"]

