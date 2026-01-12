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
  <strong>A powerful script tool for the convenient deployment and management of mihomo/sing-box kernels in Shell environments.</strong>
</p>

<p align="center">
  <a href="README_CN.md">简体中文</a> | English
</p>

---

## :rocket: Core Features

- **Multi-Kernel Support**: Easily manage and switch between **mihomo** and **sing-box** kernels directly within the Shell environment.
- **Flexible Configuration Management**: Supports online import of subscription links and configuration files to simplify the setup process.
- **Automated Tasks**: Configure scheduled tasks for automatic updates of configuration files and rules.
- **Graphical Dashboard**: Support for online installation and use of local Web Dashboards to intuitively manage built-in rules and traffic.
- **Multiple Operation Modes**: Supports switching between various traffic forwarding modes, including Router mode and Local mode.
- **One-Click Maintenance**: Built-in online update functionality to keep the script and features up to date.

## :computer: Device Support

ShellCrash is designed to be compatible with the vast majority of network devices based on the Linux kernel:

* **Router Devices**: Supports various firmwares based on OpenWrt or its derivatives.
* **Linux Servers**: Supports devices running standard Linux distributions (e.g., Debian, CentOS, Armbian, Ubuntu, etc.).
* **Third-Party Firmware**: Compatible with Padavan (Conservative Mode), Pandora, and ASUS/Merlin firmware.
* **Customized Devices**: Compatible with other specialized network devices developed using the Linux kernel.

> For additional device support, please submit an [Issue](https://github.com/juewuy/ShellCrash/issues) or provide feedback in the [Telegram Group](https://t.me/ShellClash) (please include the device model and the output of the `uname -a` command).

---

## :hammer_and_wrench: Installation Guide

> [!TIP]
> If you encounter connection failures or SSL-related issues, please try switching to an alternative installation mirror.

### Prerequisites
1. Ensure the device has **SSH** enabled and **Root privileges** obtained (Linux systems with a GUI can use the terminal directly).
2. Connect to the device using an SSH tool (such as PuTTY, JuiceSSH, or the system's built-in terminal).

### :penguin: Standard Linux Device Installation

> [!IMPORTANT]
> Please perform the installation as the root user.

> Install via wget (jsDelivr CDN source)
```sh
export url='[https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master](https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master)' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && bash /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

> Or install via curl (Author's private source)

```sh
export url='[https://gh.jwsc.eu.org/master](https://gh.jwsc.eu.org/master)' \
  && bash -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

### :satellite: Router Device Installation

**Installation via `curl`:**
> GitHub Source (Recommended for overseas environments or environments with proxy access)
```sh
export url='[https://raw.githubusercontent.com/juewuy/ShellCrash/master](https://raw.githubusercontent.com/juewuy/ShellCrash/master)' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

> Or jsDelivr CDN source

```sh
export url='[https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master](https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master)' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

> Or Author's private source
```sh
export url='[https://gh.jwsc.eu.org/master](https://gh.jwsc.eu.org/master)' \
  && sh -c "$(curl -kfsSl $url/install.sh)" \
  && . /etc/profile &> /dev/null
```

**Installation via `wget`:**
> GitHub Source (Recommended for overseas environments or environments with proxy access)
```sh
export url='[https://raw.githubusercontent.com/juewuy/ShellCrash/master](https://raw.githubusercontent.com/juewuy/ShellCrash/master)' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

> Or jsDelivr CDN source
```sh
export url='[https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master](https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master)' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

### :pager: Installation for Legacy Devices with Older `wget` Versions

> Author's private HTTP beta source
```sh
export url='[http://t.jwsc.eu.org](http://t.jwsc.eu.org)' \
  && wget -q -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```


### :cloud: Virtual Machines
- **Alpine Linux VM**: It is highly recommended to use an Alpine image for optimal compatibility.
```sh
# Install necessary dependencies
apk add --no-cache wget openrc ca-certificates tzdata nftables iproute2 dcron

# Execute installation command
export url='[https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master](https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master)' \
  && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
  && sh /tmp/install.sh \
  && . /etc/profile &> /dev/null
```

 ### :whale: Docker 

 Please visit the official Docker image:

- [ShellCrash on Docker Hub](https://hub.docker.com/r/juewuy/shellcrash)


### :package: Local Installation

If online installation is not possible, please follow the guide for local installation:

- [Local ShellCrash Installation Tutorial | Juewuy's Blog](https://juewuy.github.io/bdaz)

---

## :book: Usage Instructions

After installation, enter the following commands in the terminal to launch the management interface:

```shell
crash        # Launch the interactive script menu
crash -h     # View the list of command help
```

### Running Dependencies
| Component | Necessity | Description |
| :--- | :--- | :--- |
| curl / wget | Mandatory | Required for node saving, online installation, and update operations. |
| iptables / nftables | Critical | Without these, the script can only run in Pure Mode. |
| crontab | Low | Required for scheduled tasks; otherwise, they will not function. |
| net-tools | Very Low | Used for automatic port occupancy detection. |
| ubus / iproute-doc | Very Low | Used for automatically obtaining the local Host address. |

---

## :link: Related Links
- FAQ: [Juewuy's Blog](https://juewuy.github.io/chang-jian-wen-ti/)
- Changelog: [Release History](https://github.com/juewuy/ShellCrash/releases)
- Discussion: [Telegram Group](https://t.me/ShellClash)
