# VCHIP-8

A CHIP-8 emulator written entirely in x86-64 assembly (NASM syntax).

## What's actually "in assembly"

Every byte of CHIP-8 emulation logic is hand-written x86-64 assembly with zero dependency on any
higher-level language.

That logic lives in [`src/chip8_core.inc`](src/chip8_core.inc)
and is identical on every platform.

The two platform front-ends (`src/linux/main.asm` and `src/windows/main.asm`)
are also 100% assembly.

**SDL2** (for the window, renderer,
keyboard events and audio) and the **C runtime** (`fopen`/`fread`/`fclose` to
load the ROM file, and program entry/exit)

No C or any other language was used to
implement any part of the emulation itself.

## Project layout

```
VCHIP-8/
├── build.sh                 Linux build script
├── build.bat                Windows build script
├── setup_and_build.bat      Windows: downloads the whole toolchain, then builds
├── icon.ico                 App icon (Windows)
├── vchip8.rc                Windows resource script embedding icon.ico
├── roms/                    (put your CHIP-8 ROMs here)
└── src/
    ├── chip8_core.inc       The emulator's core (CPU/memory/display/timers/quirks)
    ├── debug_render.inc     Shared debug-overlay renderer (bitmap font + HUD)
    ├── linux/main.asm       Linux front-end (SDL2, System V x86-64 ABI)
    └── windows/main.asm     Windows front-end (SDL2 + native menu, Win64 ABI)
```

## Building

### Linux

```
sudo apt install nasm gcc libsdl2-dev   # Debian/Ubuntu
./build.sh
./build/vchip8 roms/pong.ch8
```

### Windows

**Easiest option:** just run `setup_and_build.bat`. It downloads NASM, a
standalone gcc (w64devkit), and the SDL2 MinGW dev package into a local
`tools\` folder next to the project (nothing installed system-wide, your
PATH is untouched outside the script), builds the emulator, and copies
`SDL2.dll` next to the exe automatically. Re-running it is safe -- it skips
anything already downloaded. Requires only that you have internet access
and PowerShell (built into Windows).

```
setup_and_build.bat
build\vchip8.exe roms\ibm_logo.ch8
```

**Manual option**, if you'd rather install things yourself or already have
a toolchain:

1. Install [NASM](https://www.nasm.us/) and a [MinGW-w64](https://www.mingw-w64.org/) `gcc`, and put both on `PATH`.
2. Download the SDL2 **MinGW development package** from the
   [SDL releases page](https://github.com/libsdl-org/SDL/releases)
   (`SDL2-devel-x.xx.x-mingw.zip`), extract it, and set `SDL2_PATH` at the
   top of `build.bat` to the `x86_64-w64-mingw32` folder inside it.
3. Run `build.bat`.
4. Copy `SDL2.dll` (from the SDL2 package's `bin` folder) next to
   `build\vchip8.exe`.
5. `build\vchip8.exe roms\pong.ch8`

## Controls

The original COSMAC VIP CHIP-8 keypad is mapped onto the left side of a
QWERTY keyboard:

```
CHIP-8 keypad          Your keyboard
 1 2 3 C                 1 2 3 4
 4 5 6 D        <--       Q W E R
 7 8 9 E                  A S D F
 A 0 B F                  Z X C V
```

`Esc` quits.

### Windows: menu bar

The Windows build has a native Win32 menu bar attached to the window:

- **File** -- Open ROM... (native file picker), Exit
- **Options**
  - **Video** -- 1x / 2x / 3x window scale
  - **Steps/Ticks per frame** -- 6 / 12 (default) / 18 / 24 instructions
    executed per rendered (~60fps) frame, i.e. roughly 360Hz-1440Hz
  - **Quirks** -- three checkable behaviors some ROMs expect (see below)
  - Sound Enabled, Debug Mode -- checkable toggles
- **Help** -- About VCHIP8...

### Linux: keyboard shortcuts

| Key | Action |
|-----|--------|
| F1  | Toggle debug overlay |
| F2  | Toggle "shift uses VY" quirk |
| F3  | Toggle "BNNN uses VX" quirk |
| F4  | Toggle "FX55/FX65 increments I" quirk |
| Esc | Quit |

Video scale, steps/ticks, sound toggle, and the Open ROM dialog are
Windows-only for now (loading a different ROM on Linux means relaunching
with a new command-line argument).

## Debug mode

Toggling Debug Mode (Windows: Options menu; Linux: F1) overlays live CPU
state on top of the display in red text: `PC`, `I`, the delay/sound timers,
the last fetched opcode, all 16 `V` registers, and the call stack. The
overlay text is rendered from a small 5x7 bitmap font drawn with the same
rectangle-fill primitive used for the CHIP-8 display itself -- no font
library involved.

## Quirks

CHIP-8 has a handful of behaviors that differ between the original COSMAC
VIP interpreter and later "modern" interpreters (SUPER-CHIP, CHIP-48, and
most contemporary implementations). VCHIP-8 defaults to the modern
behavior, matching most ROMs written today, with three toggles to switch
individual instructions back to the classic behavior if a specific ROM
needs it:

- **8XY6/8XYE shift**: default shifts `VX` in place; toggled, shifts `VY`
  into `VX` first (the original COSMAC VIP behavior).
- **BNNN jump**: default jumps to `NNN + V0`; toggled, jumps to
  `NNN + VX` (the "BXNN"/SUPER-CHIP behavior), where `X` is the address's
  top nibble.
- **FX55/FX65 store/load**: default leaves `I` unchanged; toggled, `I` is
  left incremented by `X + 1` afterward (the original COSMAC VIP behavior).

## Implementation notes

* **CPU speed:** see Steps/Ticks above; default is 12 instructions per
  frame at ~60fps (~720Hz effective).
* **Display:** each CHIP-8 pixel is drawn as an NxN block (N = 5/10/15px
  for 1x/2x/3x). `DXYN` sprites **clip** at the screen edges rather than
  wrapping, and `00E0` clears the whole framebuffer.
* **Audio:** a simple 440Hz square wave is queued to SDL2's audio device
  for as long as the sound timer is non-zero and sound isn't muted.
* **RNG:** a 32-bit xorshift PRNG seeded from `rdtsc`, used by `CXNN`.
* **Icon:** the Windows build embeds `icon.ico` (generated from the
  provided logo) via a compiled `.rc` resource, linked in by `build.bat`.
