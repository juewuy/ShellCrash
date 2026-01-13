<h1 align="center">ShellCrash</h1>

<p align="center">
  <a target="_blank" href="https://github.com/MetaCubeX/mihomo/releases">
    <img src="https://img.shields.io/github/release/MetaCubeX/mihomo.svg?style=flat-square&label=Core">
  </a>
  <a target="_blank" href="https://github.com/juewuy/ShellCrash/releases">
    <img src="https://img.shields.io/github/release/juewuy/ShellCrash.svg?style=flat-square&label=ShellCrash&colorB=green">
  </a>
</p>

<p align="center">
  <strong>一款在 Shell 环境下便捷部署与管理 mihomo/sing-box 内核的脚本工具</strong>
</p>

<p align="center">
  简体中文 | <a href="README.md">English</a>
</p>

---

## :rocket: 核心特性

- **多内核支持**：在 Shell 环境下便捷管理及切换 **mihomo** 与 **sing-box** 内核。
- **灵活配置管理**：支持在线导入订阅连结及配置文件，简化配置流程。
- **自动化任务**：支持配置定时任务，实现配置文件与规则的自动定时更新。
- **图形化面板**：支持在线安装并使用本地 Web 面板（Dashboard），直观管理内置规则与流量。
- **多模式运行**：支持路由模式、本机模式等多种流量转发模式切换。
- **一键维护**：内置脚本在线更新功能，保持版本与功能的及时更迭。

## :computer: 设备支持

ShellCrash 旨在兼容绝大多数基于 Linux 内核的网络设备：

* **路由器设备**：支持各种基于 OpenWrt 或其二次开发的固件。
* **Linux 服务器**：支持运行标准 Linux 发行版（如 Debian、CentOS、Armbian、Ubuntu 等）的设备。
* **第三方固件**：兼容 Padavan（保守模式）、潘多拉固件以及华硕/梅林固件。
* **各类定制设备**：兼容其他使用 Linux 内核开发的专用网络设备。

> 更多设备支持，请提交 [Issue](https://github.com/juewuy/ShellCrash/issues) 或前往 [Telegram 群组](https://t.me/ShellClash) 反馈（请附上设备型号及 `uname -a` 命令的输出信息）。

---

## :hammer_and_wrench: 安装指南

> [!TIP]
> 若遇到连接失败或SSL相关问题，请尝试切换至其他安装镜像站。

### 前置条件
1. 确保设备已开启 **SSH** 并获得 **Root 权限**（带图形介面的 Linux 系统可直接使用终端）。
2. 使用 SSH 工具（如 Putty、JuiceSSH、或系统自带终端）连接至设备。

### :penguin: 标准 Linux 设备安装

> [!IMPORTANT]
> 请以 root 用户进行安装。

> 使用 wget 安装（jsDelivr CDN 源）
```sh
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && bash /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

> 或使用 curl 安装（作者私人源）

```sh
export url='https://gh.jwsc.eu.org/master' \
  && bash -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

### :satellite: 路由器设备安装

**使用 `curl` 安装：**
> GitHub 源（推荐海外环境或具备代理环境使用）
```sh
export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

> 或 jsDelivr CDN 源

```sh
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

> 或作者私人源
```sh
export url='https://gh.jwsc.eu.org/master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

**使用 `wget` 安装：**
> GitHub 源（推荐海外环境或具备代理环境使用）
```sh
export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

> 或 jsDelivr CDN 源
```sh
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

### :pager: 老旧设备使用低版本 `wget` 安装

> 作者私人 http 内测源
```sh
export url='http://t.jwsc.eu.org' \
  && wget -q -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```


### :cloud: 虚拟机
- **Alpine Linux 虚拟机**：强烈建议使用 Alpine 镜像以获得最佳兼容性
```sh
# 安装必要依赖
apk add --no-cache wget openrc ca-certificates tzdata nftables iproute2 dcron

# 执行安装命令
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

 ### :whale: Docker 

 请访问官方 Docker 镜像：

- [ShellCrash on Docker Hub](https://hub.docker.com/r/juewuy/shellcrash)


### :package: 本地安装

若无法进行在线安装，请参照以下指南执行本地安装：

- [本地安装ShellCrash教程 | Juewuy's Blog](https://juewuy.github.io/bdaz)

---

## :book: 使用说明

安装完成后，在终端输入以下指令即可启动管理界面：

```shell
crash        # 启动脚本交互选单
crash -h     # 查看命令帮助列表
```

### 运行依赖说明
| 依赖组件 | 必要性 | 说明 |
| :--- | :--- | :--- |
| curl / wget | 必须 | 缺少时将无法进行节点保存、在线安装及更新操作 |
| iptables / nftables | 重要 | 缺少时仅能运行于纯淨模式 |
| crontab | 较低 | 缺少时定时任务功能将失效 |
| net-tools | 极低 | 缺少时无法自动检测端口占用 |
| ubus / iproute-doc | 极低 | 缺少时无法自动获取本机 Host 地址 |

---

## :link: 相关链接
- 常见问题：[Juewuy's Blog](https://juewuy.github.io/chang-jian-wen-ti/)
- 更新日志：[Release History](https://github.com/juewuy/ShellCrash/releases)
- 交流反馈：[Telegram 讨论组](https://t.me/ShellClash)

---

## :airplane: 机场推荐

- [**Dler-墙洞**](https://dler.pro/auth/register?affid=89698)，多年稳定运行，功能齐全。
- [**大米**](https://1s.bigmeok.me/user#/register?code=2PuWY9I7)，群友力荐，流媒体解锁，月付推荐。
