# ShellCrash (Official Docker Image)

**ShellCrash 官方 Docker 镜像**，用于在容器环境中运行 ShellCrash，支持 **HTTP / SOCKS 代理** 与 **旁路由透明代理** 两种部署模式。

该镜像由 **ShellCrash 官方维护**，基于原项目脚本构建，并通过 Docker 多架构机制发布。

------

## Quick Start（最小化运行）

仅启用 HTTP(S) / SOCKS5 代理功能，适用于基础代理需求，Mix代理端口：7890，面板管理端口：9999。

```shell
docker run -d \
  --name shellcrash \
  -p 7890:7890 \
  -p 9999:9999 \
  juewuy/shellcrash:latest
```

------

## Container Management（容器管理）

首次部署完成后，请务必使用以下命令进入容器完成设置（导入配置文件，允许开机启动，及启动内核服务），之后也可用此命令进入容器sh环境进行管理：

```shell
docker exec -it shellcrash sh -l
```

------

## Advanced Usage（旁路由 / 透明代理）

适用于旁路由、软路由或需要透明代理的部署场景，需提前创建macvlan，这里不推荐使用容器的host模式。

### 1. 创建 macvlan 网络

此处请根据实际网络环境调整参数，如之前已创建可忽略。

```shell
docker network create \
  --driver macvlan \
  --subnet 192.168.31.0/24 \
  --gateway 192.168.31.1 \
  -o parent=eth0 \
  macvlan_lan
```

### 2. 启动容器（旁路由模式）

```shell
docker run -d \
  --name shellcrash \
  --network macvlan_lan \
  --ip 192.168.31.222 \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --cap-add SYS_ADMIN \
  --device /dev/net/tun:/dev/net/tun \
  --restart unless-stopped \
  juewuy/shellcrash:latest
```

### 3. 配置需要路由的设备

将需要路由的设备IPV4网关与DNS均指向启动容器时指定的IP地址如：192.168.31.222

注意，旁路由模式必须禁用子设备的IPV6地址，或主路由的IPV6功能，否则流量可能会经由IPV6直连而不会进入旁路由转发

------

## Persistent Configuration（持久化配置,可选）

推荐使用 volume 挂载以持久化 ShellCrash 配置。

### 1. 创建宿主机目录

```shell
mkdir -p /root/ShellCrash
```

### 2. 启用持久化

将命令粘贴到你的实际容器启动命令中间，例如：

```shell
docker run -d \
  ………………
  -v /root/ShellCrash:/etc/ShellCrash \
  ………………
```

------



------

## Compose Deployment（Compose部署）

### 1. 创建宿主机目录并进入目录

```shell
mkdir -p /root/ShellCrash
cd /root/ShellCrash
```

### 2. 下载Compose模版

```shell
curl -sSL https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@dev/docker/compose.yml -O
```

### 3. 根据本地环境修改Compose模版

```shell
vi compose.yml #或者使用其他文本编辑器
```

### 4. 运行服务

```shell
docker compose up -d
```

------

### Notes

- 旁路由模式需要宿主机支持 `TUN`
- macvlan 网络下宿主机默认无法直接访问容器 IP
- 透明代理场景可能需要额外的网络规划
