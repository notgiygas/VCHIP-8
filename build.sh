#!/usr/bin/env bash
# ============================================================================
#  VCHIP-8 build script (Linux)
#
#  Prerequisites:
#    sudo apt install nasm gcc libsdl2-dev      (Debian/Ubuntu)
#    sudo dnf install nasm gcc SDL2-devel       (Fedora)
#    sudo pacman -S nasm gcc sdl2               (Arch)
# ============================================================================
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/src"
OUT="$ROOT/build"

mkdir -p "$OUT"

echo "[VCHIP-8] Assembling src/linux/main.asm ..."
nasm -f elf64 -I"$SRC/" -o "$OUT/main.o" "$SRC/linux/main.asm"

echo "[VCHIP-8] Linking ..."
# -no-pie: the CHIP-8 core addresses its state with absolute
# register+displacement addressing (e.g. [chip8_mem + rax]), which requires
# a non-position-independent executable.
gcc -no-pie -o "$OUT/vchip8" "$OUT/main.o" -lSDL2

echo "[VCHIP-8] Build complete: $OUT/vchip8"
echo "Run with:  $OUT/vchip8 <path-to-rom>"
echo "Enjoy!"
