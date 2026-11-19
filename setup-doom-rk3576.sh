#!/usr/bin/env bash
# Prepare FlipCTL and DOOM on ARM64 Armbian Bookworm.
set -Eeuo pipefail
trap 'printf "Setup failed at line %s. Resolve the error above before retrying.\n" "$LINENO" >&2' ERR

if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Run as a regular user on ARM64 Armbian Bookworm:' \
    '  bash setup-doom-rk3576.sh' \
    'Installs dependencies with sudo, prepares Rust if needed, builds pinned FlipCTL,' \
    'checks AppImage tools, and installs a Bookworm-compatible Doom AppImage.' \
    'Does not start or stop an existing FlipCTL service.'
  exit 0
fi
[[ $# == 0 ]] || { printf 'Unknown argument. Use --help.\n' >&2; exit 2; }
[[ $EUID -ne 0 ]] || { printf 'Run as your normal Linux user, not root.\n' >&2; exit 1; }
[[ $(dpkg --print-architecture) == arm64 ]] || { printf 'ARM64 is required.\n' >&2; exit 1; }
. /etc/os-release
[[ ${VERSION_CODENAME:-} == bookworm ]] || { printf 'Debian/Armbian Bookworm is required.\n' >&2; exit 1; }
if command -v pgrep >/dev/null && pgrep -u "$(id -u)" -x dsda-doom >/dev/null; then
  printf 'Close Doom first: Tab, select Doom, then Z (Kill).\n' >&2
  exit 1
fi

repo="$HOME/flipper-test/flipctl-slint"
revision=8aeb387dc4d13fcef9056267b2a3dd7409099834
if [[ -e $repo ]]; then
  [[ $(git -C "$repo" rev-parse HEAD) == "$revision" ]] || {
    printf 'Existing %s is not at the tested revision %s. No checkout/reset was performed.\n' "$repo" "$revision" >&2
    exit 1
  }
fi

printf '\n[1/5] Installing build and runtime dependencies\n'
sudo apt-get update
sudo apt-get install -y --no-install-recommends --no-upgrade \
  git curl ca-certificates file build-essential pkg-config \
  sway fuse3 desktop-file-utils python3 binutils procps \
  dsda-doom libegl-mesa0

printf '\n[2/5] Preparing Rust\n'
[[ ! -f $HOME/.cargo/env ]] || . "$HOME/.cargo/env"
rust_ok=false
if command -v rustc >/dev/null && command -v cargo >/dev/null; then
  rust_version=$(rustc --version | awk '{print $2}')
  [[ $(printf '%s\n' 1.92.0 "$rust_version" | sort -V | head -n 1) != 1.92.0 ]] || rust_ok=true
fi
if [[ $rust_ok != true ]]; then
  rust_installer=$(mktemp)
  curl --proto '=https' --tlsv1.2 -fLsS --retry 3 --connect-timeout 20 --max-time 900 \
    https://sh.rustup.rs -o "$rust_installer"
  sh "$rust_installer" -y --profile minimal --default-toolchain stable
  rm -f -- "$rust_installer"
  . "$HOME/.cargo/env"
fi
rustc --version
cargo --version

printf '\n[3/5] Building the pinned FlipCTL source\n'
if [[ ! -e $repo ]]; then
  mkdir -p "$HOME/flipper-test"
  git clone --branch dev https://github.com/flipperdevices/flipctl-slint.git "$repo"
  git -C "$repo" checkout --detach "$revision"
fi
git -C "$repo" submodule update --init --recursive
(
  cd "$repo"
  CARGO_TARGET_DIR="$repo/target" CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-4}" \
    CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 \
    cargo build --locked --release -p flipctl --features device,slint,remote,wayland
)

printf '\n[4/5] Preparing verified AppImage tools\n'
(
  cd "$repo"
  mkdir -p target/appimage/tools
  while read -r name url checksum; do
    case "$name" in
      appimagetool-aarch64|runtime-aarch64)
        tool="target/appimage/tools/$name"
        if [[ ! -f $tool ]] || ! printf '%s  %s\n' "$checksum" "$tool" | sha256sum -c --status; then
          curl -fL --retry 3 --connect-timeout 20 --max-time 900 -o "$tool.part" "$url"
          printf '%s  %s\n' "$checksum" "$tool.part" | sha256sum -c -
          mv -- "$tool.part" "$tool"
        fi
        printf '%s  %s\n' "$checksum" "$tool" | sha256sum -c -
        chmod +x "$tool"
        ;;
    esac
  done < tools/appimage/tools.lock
  test -x target/appimage/tools/appimagetool-aarch64
  test -x target/appimage/tools/runtime-aarch64
)

printf '\n[5/5] Installing the verified DOOM compatibility package\n'
installer="$repo/target/appimage/prepare-doom-rk3576-bookworm-v0.2.0.sh"
curl -fL --retry 3 --connect-timeout 20 --max-time 120 \
  -o "$installer" \
  https://github.com/inteintegrity/doom-rk3576/releases/download/v0.2.0/prepare-doom-rk3576-bookworm.sh
printf '%s  %s\n' \
  6e0dbf168ff47f2a0bf890b14cf933f3bf4ebb2a9173ba4aa8618dfebe9b0c43 \
  "$installer" | sha256sum -c -
bash "$installer"
printf '\nReady. Start FlipCTL with:\n'
printf '  cd %q\n' "$repo"
printf '  WLR_RENDERER=pixman ./target/release/flipctl --headless --remote 127.0.0.1:8899 --assets "$PWD/crates/flipper-ui/assets/remote"\n'
