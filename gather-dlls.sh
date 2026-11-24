#!/bin/bash
# Walks ldd graph for the qemu binaries + virglrenderer, copies every DLL
# found under the MSYS2 environment's bin dir into installer/bin/.
#
# Run from the MSYS2 shell matching the target:
#   UCRT64     -> x86_64 build (qemu-system-x86_64)
#   CLANGARM64 -> Windows on ARM build (qemu-system-aarch64)
set -euo pipefail

case "${MSYSTEM:-UCRT64}" in
    CLANGARM64) PREFIX=/clangarm64; QEMU_SYS=qemu-system-aarch64 ;;
    *)          PREFIX=/ucrt64;     QEMU_SYS=qemu-system-x86_64 ;;
esac
ENV_BIN=$PREFIX/bin
ENV_BIN_WIN=/c/msys64$PREFIX/bin
INSTALLER_BIN=installer/bin

declare -A SEEN

copy_dll() {
    local path="$1"
    local fname
    fname="$(basename "$path")"
    if [[ ! -f "$INSTALLER_BIN/$fname" ]]; then
        cp "$path" "$INSTALLER_BIN/"
        echo "  + $fname"
    fi
}

walk() {
    local target="$1"
    if [[ -n "${SEEN[$target]:-}" ]]; then
        return
    fi
    SEEN[$target]=1

    # ldd will list both system DLLs (KERNEL32.dll, etc.) and MSYS2 ones.
    # We only copy MSYS2 ones; system DLLs ship with Windows.
    # ldd actually loads the image, so guard against it hanging.
    while read -r line; do
        # Format: "name => path (offset)"
        local path
        path=$(echo "$line" | sed -E 's/.* => ([^ ]+) .*/\1/')
        if [[ "$path" == "$ENV_BIN"/* ]] || [[ "$path" == "$ENV_BIN_WIN"/* ]]; then
            copy_dll "$path"
            walk "$path"
        fi
    done < <(/c/msys64/usr/bin/bash.exe -lc "timeout 20 ldd '$target' 2>/dev/null" || true)
}

echo "Walking dependencies ($MSYSTEM)..."
for bin in "$INSTALLER_BIN/$QEMU_SYS.exe" "$INSTALLER_BIN"/qemu-img.exe "$INSTALLER_BIN"/libvirglrenderer-1.dll; do
    [[ -f "$bin" ]] || continue
    echo "  [$bin]"
    walk "$bin"
done

# DLLs loaded at runtime with LoadLibrary, which ldd can't see:
#   SDL3.dll                - MSYS2's SDL2 is sdl2-compat, which loads SDL3
#   libEGL.dll/libGLESv2.dll - ANGLE, loaded by libepoxy for EGL
echo "Runtime-loaded DLLs..."
for dll in SDL3.dll libEGL.dll libGLESv2.dll; do
    if [[ -f "$ENV_BIN/$dll" ]]; then
        copy_dll "$ENV_BIN/$dll"
        walk "$ENV_BIN/$dll"
    fi
done

echo "Done. Total DLLs in installer/bin/:"
ls -1 "$INSTALLER_BIN"/*.dll | wc -l
