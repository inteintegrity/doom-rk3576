#!/usr/bin/env bash
# Prepare the locally verified DOOM AppImage for ARM64 Armbian Bookworm.
# Run as your regular user on the RK3576, after completing the FlipCTL project.
(
  set -eu
  test "$(dpkg --print-architecture)" = arm64
  . /etc/os-release
  test "$VERSION_CODENAME" = bookworm

  repo="$HOME/flipper-test/flipctl-slint"
  test -x "$repo/target/appimage/tools/appimagetool-aarch64"
  test -x "$repo/target/appimage/tools/runtime-aarch64"
  test -f /usr/share/glvnd/egl_vendor.d/50_mesa.json
  mkdir -p "$repo/target/appimage"
  work="$(mktemp -d "$repo/target/appimage/doom-bookworm-XXXXXXXX")"

  curl -fL --retry 3 --connect-timeout 20 --max-time 300 \
    -o "$work/doom-upstream.AppImage" \
    https://github.com/flipperdevices/flipctl-apps/releases/download/apps/doom-aarch64.fap.AppImage
  printf '%s  %s\n' \
    17ba41e2552ee65c20b914dd01945da7c05899fafe121fc5572dd1e013e085af \
    "$work/doom-upstream.AppImage" | sha256sum -c -
  chmod +x "$work/doom-upstream.AppImage"
  mkdir "$work/original"
  (cd "$work/original" && "$work/doom-upstream.AppImage" --appimage-extract > /dev/null)

  appdir="$work/Doom.AppDir"
  original="$work/original/squashfs-root"
  mkdir -p "$appdir/runtime" "$work/debs"
  for name in AppRun app.toml doom.desktop doom.png palette.wad NOTICE.md; do
    cp -p "$original/$name" "$appdir/$name"
  done

  (
    cd "$work/debs"
    apt-get download dsda-doom=0.25.6+dfsg-1 \
      libdumb1 libglu1-mesa libportmidi0 libsdl2-image-2.0-0 \
      libopusfile0 libsdl2-mixer-2.0-0 libegl1
  )
  for deb in "$work"/debs/*.deb; do
    dpkg-deb -x "$deb" "$appdir/runtime"
  done
  mkdir -p "$appdir/runtime/usr/share/games/doom"
  cp -p "$original/runtime/usr/share/games/doom/freedoom1.wad" \
    "$appdir/runtime/usr/share/games/doom/freedoom1.wad"

  DOOM_APPDIR="$appdir" python3 - <<'PY'
import os
from pathlib import Path

appdir = Path(os.environ["DOOM_APPDIR"])
launcher = appdir / "AppRun"
text = launcher.read_text()
assert text.count("-aspect 16:9") == 1
text = text.replace("-aspect 16:9", "-aspect 16x9")
marker = "# Where the engine looks for its own resource wad"
assert text.count(marker) == 1
settings = """export SDL_RENDER_DRIVER=software
export SDL_VIDEO_EGL_DRIVER="$RUNTIME/usr/lib/aarch64-linux-gnu/libEGL.so.1"
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export LIBGL_ALWAYS_SOFTWARE=1
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR/pulse" ]; then
    PULSE_RUNTIME_PATH=$(readlink -f "$XDG_RUNTIME_DIR/pulse")
    export PULSE_RUNTIME_PATH
    export PULSE_SERVER="${PULSE_SERVER:-unix:$PULSE_RUNTIME_PATH/native}"
fi
"""
launcher.write_text(text.replace(marker, settings + marker))
launcher.chmod(0o755)
PY

  if ! LD_LIBRARY_PATH="$appdir/runtime/usr/lib/aarch64-linux-gnu" \
    ldd "$appdir/runtime/usr/games/dsda-doom" > "$work/ldd.txt" 2>&1; then
    cat "$work/ldd.txt"
    exit 1
  fi
  cat "$work/ldd.txt"
  if grep -q 'not found' "$work/ldd.txt"; then
    exit 1
  fi

  output="$work/doom-bookworm-aarch64.fap.AppImage"
  SOURCE_DATE_EPOCH="$(git -C "$repo" log -1 --format=%ct)" ARCH=aarch64 \
    "$repo/target/appimage/tools/appimagetool-aarch64" --appimage-extract-and-run \
    -n --comp zstd \
    --mksquashfs-opt -Xcompression-level --mksquashfs-opt 19 \
    --runtime-file "$repo/target/appimage/tools/runtime-aarch64" \
    "$appdir" "$output"
  sha256sum "$output"

  mkdir -p "$HOME/Apps/Games" "$HOME/.local/share/flipctl-app-backups"
  installed="$HOME/Apps/Games/doom-aarch64.fap.AppImage"
  if [ -f "$installed" ]; then
    backup="$(mktemp -d "$HOME/.local/share/flipctl-app-backups/doom-XXXXXXXX")"
    cp -p "$installed" "$backup/"
  fi
  install -m 755 "$output" "$HOME/Apps/Games/.doom-installing"
  mv -- "$HOME/Apps/Games/.doom-installing" "$installed"
  printf 'Installed: %s\n' "$installed"
)
