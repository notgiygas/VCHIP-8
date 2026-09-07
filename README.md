# VCHIP-8

A CHIP-8 emulator written entirely in x86-64 assembly (NASM syntax).

## What's actually "in assembly"

Every byte of CHIP-8 emulation logic is x86-64 assembly with zero dependency on any
higher-level language. 

That logic lives in [`src/chip8_core.inc`](src/chip8_core.inc) and is identical on every platform.


<img width="800" height="457" alt="image" src="https://github.com/user-attachments/assets/209f6574-20a0-4556-b60a-fca256cb3ea4" />


## Project layout

```
VCHIP-8/
├── build.sh                 Linux build script
├── build.bat                Windows build script
├── setup_and_build.bat      Windows: downloads the whole toolchain, then builds
├── icon.ico                 App icon (Windows)
├── vchip8.rc                Windows resource script embedding icon.ico
├── roms/                    (put your CHIP-8 ROMs here lol)
└── src/
    ├── chip8_core.inc       The emulator core
    ├── debug_render.inc     Shared debug-overlay renderer
    ├── linux/main.asm       Linux front-end
    └── windows/main.asm     Windows front-end
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

> This project has been built and smoke-tested with a real toolchain
> (NASM + mingw-w64 gcc + the SDL2 MinGW dev package for Windows; NASM +
> gcc + libsdl2-dev on Linux)
> Please open an issue if something misbehaves at runtime on real Windows.

## Controls

The original COSMAC VIP CHIP-8 keypad is mapped onto the left side of a
QWERTY keyboard:

```
CHIP-8 keypad          Your keyboard
 1 2 3 C                  1 2 3 4
 4 5 6 D        <--       Q W E R
 7 8 9 E                  A S D F
 A 0 B F                  Z X C V
```

`Esc` kills the emulator.

### Windows: menu bar

The Windows build has a native Win32 menu bar attached to the window:

- **File** -- Open ROM... (native file picker), Exit
- **Options**
  - **Video** -- 1x / 2x / 3x window scale
  - **Steps/Ticks per frame** -- 6 / 12 (default) / 18 / 24 instructions
    executed per rendered (~60fps) frame, i.e. roughly 360Hz-1440Hz
  - **Quirks** -- three checkable behaviors some ROMs expect
  - **Colors** -- pick custom foreground ("pixel on") and background
    ("pixel off") colors via the native Windows color picker
  - Sound Enabled, Debug Mode -- checkable toggles
- **Help** -- Controls... (shows the keypad/keyboard mapping)

You can also just **drag and drop a `.ch8` file onto the window** to load
it

### Linux: keyboard shortcuts

| Key | Action |
|-----|--------|
| F1  | Toggle debug overlay |
| F2  | Toggle "shift uses VY" quirk |
| F3  | Toggle "BNNN uses VX" quirk |
| F4  | Toggle "FX55/FX65 increments I" quirk |
| Esc | Quit |

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

## License / credit

All credit for the creation of this emulator goes to **giygas**.
