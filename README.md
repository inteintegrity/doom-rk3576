# DOOM on reComputer RK3576 with FlipCTL

Set up FlipCTL and a Bookworm-compatible DOOM application from one script, then play from a PC browser over an SSH tunnel. The application uses dsda-doom and Freedoom data; commercial DOOM WAD files are not required.

## Requirements

- ARM64 Armbian based on Debian Bookworm (the verified board uses glibc 2.36).
- A regular Linux user with sudo access.
- A PC with SSH and a web browser.
- Network access to GitHub, Rust downloads/crates and Debian package repositories. Configure the board-side HTTP/HTTPS proxy if your network needs one; a PC proxy is not automatically inherited by an SSH session.

FlipCTL and Hello World do not need to be installed beforehand.

## 1. Prepare the software on the board

```bash
sudo apt update && sudo apt install -y curl ca-certificates &&
curl -fL --retry 3 --connect-timeout 20 --max-time 120 -o setup-doom-rk3576.sh \
  https://github.com/inteintegrity/doom-rk3576/releases/download/v0.2.0/setup-doom-rk3576.sh &&
printf '%s  %s\n' \
  c961924e97284eb04d480d036a6f70ca44ab38276634bea35edb97f87b13f3db \
  setup-doom-rk3576.sh | sha256sum -c - &&
bash setup-doom-rk3576.sh
```

Run as your normal user, not root. Enter your sudo password when asked. Wait for `Ready.`; the first native compilation can take time.

The script installs build/runtime packages, prepares a recent Rust toolchain when needed, builds FlipCTL revision `8aeb387dc4d13fcef9056267b2a3dd7409099834`, verifies AppImage tools and runs the fixed v0.2.0 DOOM compatibility installer. It does not run Flipper One deployment scripts or start/stop an existing FlipCTL service. An existing source checkout at another revision is left untouched and causes setup to stop.

## 2. Connect

On the board, if FlipCTL is not already listening on port 8899:

```bash
cd ~/flipper-test/flipctl-slint
WLR_RENDERER=pixman ./target/release/flipctl --headless \
  --remote 127.0.0.1:8899 --assets "$PWD/crates/flipper-ui/assets/remote"
```

In a separate PC terminal (replace `<BOARD_IP>` and adjust the username):

```bash
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 127.0.0.1:8899:127.0.0.1:8899 seeed@<BOARD_IP>
```

Keep both terminals open. Reuse an existing working tunnel. Open http://127.0.0.1:8899 in the PC browser.

## 3. Play

Enable **Show controls**, open **Menu -> Apps -> Games -> Doom**, and press **Enter**. Arrow keys move/turn, Z fires, X changes weapon, V interacts, B shows the map, A opens/closes the game menu and Enter confirms menu choices. The original remote panel is 256x144 pixels.

Before rerunning setup, close Doom through the app switcher: Tab, select Doom, then Z (Kill). Esc/Backspace alone backgrounds the application.

## Files and backups

- `setup-doom-rk3576.sh`: complete software preparation.
- `prepare-doom-rk3576-bookworm.sh`: compatibility-only installer; the original release remains available as v0.1.0 for existing setups.
- `SHA256SUMS`: checksums of both shell scripts.
- Installed app: `~/Apps/Games/doom-aarch64.fap.AppImage`.
- Previous Doom packages: `~/.local/share/flipctl-app-backups/`.

## 中文说明

无需预先安装 FlipCTL 或 Hello World。组合脚本面向 ARM64 Armbian Bookworm，以普通用户执行，按提示输入 sudo 密码。脚本会准备依赖和 Rust、编译固定版本的 FlipCTL、校验打包工具，再安装兼容 Bookworm 的 DOOM。等待 `Ready.` 后启动 FlipCTL，在电脑上建立 SSH 隧道并打开浏览器即可操作。

重新安装前，请用 Tab 打开应用切换器，选择 Doom 后按 Z（Kill）关闭。Esc/Backspace 只会让应用进入后台。旧应用包会备份在 `~/.local/share/flipctl-app-backups/`。

## Verification

On 2026-11-19, the public v0.2.0 download and SHA256 check, dependency setup, Rust check, FlipCTL build, AppImage tool checks and DOOM installation completed with exit code 0 on the RK3576 Armbian Bookworm / glibc 2.36 board. Downloads used the user's existing proxy through temporary SSH forwarding.

The newly built FlipCTL launched the installed game. Movement, firing, the game menu and closing through Tab -> Doom -> Z (Kill) were verified. The board's glibc remained 2.36 and its default EGL link remained the Mali library.

The existing Rust toolchain and source checkout were reused. Installing Rust and cloning the source on a newly flashed system were not separately tested. The setup script includes those branches so no previous FlipCTL project is required.

## Upstream

- FlipCTL: https://github.com/flipperdevices/flipctl-slint/tree/8aeb387dc4d13fcef9056267b2a3dd7409099834
- Application: https://github.com/flipperdevices/flipctl-apps/releases/tag/apps
- Bookworm engine: https://packages.debian.org/bookworm/dsda-doom
