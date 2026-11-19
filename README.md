# DOOM on reComputer RK3576 with FlipCTL

This script prepares an ARM64 AppImage for the verified Armbian Bookworm / glibc 2.36 setup. It uses the upstream dsda-doom/Freedoom app data, Bookworm-compatible engine packages and an application-specific Mesa software-rendering configuration.

## Requirements

- ARM64 Armbian based on Debian Bookworm.
- FlipCTL with working Hello World and Wayland hosting in `~/flipper-test/flipctl-slint`.
- The checked AppImage tools in `target/appimage/tools/` from the prerequisite FlipCTL project.
- System-compatible SDL2/Mesa multimedia libraries, including `/usr/share/glvnd/egl_vendor.d/50_mesa.json`.
- Access to GitHub releases and Debian Bookworm package repositories.
- Close a running Doom app before replacing its package.

## Run on the board

```bash
bash prepare-doom-rk3576-bookworm.sh
```

Run as your regular Linux user. Do not use sudo for this script. It downloads Debian packages and extracts them into the application's private runtime; it does not install system packages, replace system graphics drivers or upgrade glibc.

The installed app is `~/Apps/Games/doom-aarch64.fap.AppImage`. Any previous app is backed up under `~/.local/share/flipctl-app-backups/`. Keep the existing FlipCTL and PC SSH tunnel running, then open Games -> Doom in FlipCTL.

## 中文说明

此脚本面向已实测的 ARM64 Armbian Bookworm / glibc 2.36 环境。请先完成 FlipCTL 前置项目，确认 Hello World 可以运行，且 AppImage 打包工具和 SDL2/Mesa 运行库已准备好。

在开发板上，以普通用户执行 `bash prepare-doom-rk3576-bookworm.sh`，不要加 sudo。替换应用包前先关闭 Doom。

脚本会校验官方原包，保留 Freedoom 游戏数据，并使用 Bookworm 引擎、应用专用 EGL 加载器与 Mesa 软件渲染重新打包。旧包备份到 `~/.local/share/flipctl-app-backups/`。此包仍依赖板上已有的兼容多媒体运行库，并非适用于任意 Linux 发行版的通用镜像。

## Verification scope

The compatibility approach was verified on RK3576: the game scene, movement, firing and game-menu input worked. The extracted script passed Bash and embedded Python syntax checks. The complete downloaded script has not yet been rerun from a clean system; it retains the documented prerequisites.

Upstream app: https://github.com/flipperdevices/flipctl-apps/releases/tag/apps
Bookworm engine: https://packages.debian.org/bookworm/dsda-doom
