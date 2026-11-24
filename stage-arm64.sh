#!/bin/bash
# Stage installer/bin and installer/icons for the Windows on ARM installer.
# Run from the MSYS2 CLANGARM64 shell, in the repo root, after building
# winq-emu-qemu (build-arm64.sh) and winq-emu-virglrenderer for CLANGARM64:
#
#   QEMU_BUILD=../winq-emu-qemu/build-arm64 VIRGL_PREFIX=/clangarm64 ./stage-arm64.sh
#   cd installer && makensis -DARM64 installer.nsi
#
# The launcher (installer/WINQ-EMU.exe) is built separately, see README.
set -euo pipefail

if [[ "${MSYSTEM:-}" != CLANGARM64 ]]; then
    echo "Run this from the MSYS2 CLANGARM64 shell." >&2
    exit 1
fi

QEMU_BUILD=${QEMU_BUILD:-../winq-emu-qemu/build-arm64}
VIRGL_PREFIX=${VIRGL_PREFIX:-/clangarm64}
SHARE=/clangarm64/share/qemu
BIN=installer/bin

for f in "$QEMU_BUILD/qemu-system-aarch64.exe" "$QEMU_BUILD/qemu-system-aarch64w.exe" \
         "$QEMU_BUILD/qemu-img.exe" "$VIRGL_PREFIX/bin/libvirglrenderer-1.dll" \
         "$SHARE/edk2-aarch64-code.fd"; do
    [[ -f "$f" ]] || { echo "Missing: $f" >&2; exit 1; }
done

mkdir -p "$BIN/share/keymaps" "$BIN/share/firmware" installer/icons
cp "$QEMU_BUILD"/qemu-system-aarch64.exe "$QEMU_BUILD"/qemu-system-aarch64w.exe \
   "$QEMU_BUILD"/qemu-img.exe "$BIN/"
cp "$VIRGL_PREFIX/bin/libvirglrenderer-1.dll" "$BIN/"

# Firmware and option ROMs. The edk2 images in the QEMU build tree are
# compressed, so take the ready-to-use ones from the MSYS2 qemu data dir
# (pacman -S mingw-w64-clang-aarch64-qemu-common).
cp "$SHARE"/edk2-aarch64-code.fd "$SHARE"/edk2-arm-vars.fd "$SHARE"/*.rom "$BIN/share/"
cp "$SHARE"/firmware/*aarch64*.json "$BIN/share/firmware/" 2>/dev/null || true
cp -r "$SHARE"/keymaps/* "$BIN/share/keymaps/"

cp launcher/winq-emu.ico installer/icons/

# DLL dependencies (from /clangarm64/bin), including the runtime-loaded
# ones ldd can't see.
./gather-dlls.sh

echo "Staged $(du -sh "$BIN" | cut -f1) in $BIN"
