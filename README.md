<h1 align="center">
  <br>ShellCrash<br>
</h1>


<p align="center">
	<a target="_blank" href="https://github.com/MetaCubeX/mihomo/releases">
    <img src="https://img.shields.io/github/release/MetaCubeX/mihomo.svg?style=flat-square&label=Core">
  </a>
  <a target="_blank" href="https://github.com/juewuy/ShellCrash/releases">
    <img src="https://img.shields.io/github/release/juewuy/ShellCrash.svg?style=flat-square&label=ShellCrash&colorB=green">
  </a>
</p>

[中文](README_CN.md) | English

---

## Overview

ShellCrash is a lightweight Shell-based management script that enables convenient use of the **Mihomo / Sing-box** core across a wide range of Linux-based systems.

Key features include:

- Run and manage Mihomo / Sing-box directly from a Shell environment
- Fully Shell-based management with minimal dependencies
- Import subscription links and configuration URLs online
- Schedule automated tasks, including periodic configuration updates
- Install and manage built-in rules via a local web control panel
- Switch seamlessly between multiple operating modes (e.g. router mode, local mode)
- Support in-place online updates

## Supported Platforms

ShellCrash is designed to work across a broad range of Linux-based devices, including:

- Routers based on **OpenWrt** or OpenWrt-derived custom firmware
- Standard Linux distributions such as **Debian**, **CentOS**, **Armbian**, and similar
- **Padavan** firmware (conservative mode), **Pandora** firmware, and **ASUS / Merlin** firmware
- Other embedded or customised systems built on the Linux kernel

> If your device is not listed above, please open an issue or provide feedback in the Telegram group. When reporting, include the device model and the output of `uname -a`.

## Frequently Asked Questions

- [ShellCrash FAQ | Juewuy's Blog](https://juewuy.github.io/chang-jian-wen-ti/)

## Getting Started

### Prerequisites

- SSH access must be enabled on the target device
- Root privileges are required (Linux systems with a desktop environment may use the built-in terminal)

Use an SSH client such as **PuTTY**, **JuiceSSH**, or the system terminal to connect to your router or Linux host.

### Installation

Follow the instructions below according to your device type. Execute the commands in an SSH session and follow the on-screen prompts to complete installation.

> **Note**  
> If you encounter connection failures or SSL-related errors, try switching to a different installation mirror.

#### Standard Linux Distributions

```sh
sudo -i  # Switch to root user (enter password if prompted)
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && bash /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

Alternative mirror:

```sh
sudo -i
export url='https://gh.jwsc.eu.org/master' \
  && bash -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

#### Router Devices (curl)

```sh
# GitHub source (may require a proxy)
export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

Alternative mirrors:

```sh
# jsDelivr CDN
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

```sh
# Author's private mirror
export url='https://gh.jwsc.eu.org/master' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

#### Router Devices (wget)

```sh
# GitHub source (may require a proxy)
export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

Alternative mirror:

```sh
# jsDelivr CDN
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

#### Legacy Devices (older wget versions)

```sh
# HTTP mirror for legacy environments
export url='http://t.jwsc.eu.org' \
  && wget -q -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

#### Virtual Machines

For virtual machine deployments, using an **Alpine Linux** image is strongly recommended.

```sh
# Install required dependencies
apk add --no-cache wget openrc ca-certificates tzdata nftables iproute2 dcron

# Run the installer
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

#### Docker

An official Docker image is available:

- [ShellCrash on Docker Hub](https://hub.docker.com/r/juewuy/shellcrash)

### Local Installation

If online installation is not possible, please refer to the following guide for offline or local installation:

- [Local ShellCrash Installation Guide | Juewuy's Blog](https://juewuy.github.io/bdaz)

## Usage

After installation, the management script can be accessed using the following commands:

```sh
crash        # Enter interactive mode
crash -h     # Display help information
```

## Runtime Dependencies

Most systems already include the majority of the following dependencies. Missing low-priority components can usually be ignored if functionality is unaffected.

| Dependency | Priority | Notes |
|---|---|---|
| curl / wget | Required | Needed for installation, updates, and node persistence |
| iptables / nftables | Important | Without these, only clean mode is available |
| crontab | Low | Required for scheduled tasks |
| net-tools | Very low | Used for detecting port usage |
| ubus / iproute-doc | Very low | Used to obtain the local host address |

## Changelog

- [Release History](https://github.com/juewuy/ShellCrash/releases)

## Community

- [Telegram Discussion Group](https://t.me/ShellClash)

