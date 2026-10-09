# VCHIP-8

A CHIP-8 emulator written in x86-64 assembly (NASM). The CPU core, timers, input
handling and debug overlay are all assembly; the only external dependency is SDL2
(plus the Win32 API for the menu bar on Windows).

The interpreter itself is in `src/chip8_core.inc` and is shared by both the Windows and
Linux front-ends.

## Layout

```
VCHIP-8/
├── build.sh               Linux build
├── build.bat              Windows build
├── setup_and_build.bat    Windows: fetches the toolchain, then builds
├── icon.ico, vchip8.rc    Windows icon and resource script
├── roms/                  Put your .ch8 files here
└── src/
    ├── chip8_core.inc     Interpreter core
    ├── debug_render.inc   Debug overlay renderer
    ├── linux/main.asm     Linux front-end
    └── windows/main.asm   Windows front-end
```

## Building

### Linux

```
sudo apt install nasm gcc libsdl2-dev
./build.sh
./build/vchip8 roms/pong.ch8
```

### Windows

The easy way is `setup_and_build.bat`. It downloads NASM, w64devkit (gcc) and the SDL2
MinGW package into a local `tools\` folder, builds the emulator and copies `SDL2.dll`
next to the exe. Nothing is installed system-wide and your `PATH` isn't touched. It
needs internet access and PowerShell, and is safe to re-run.

```
setup_and_build.bat
build\vchip8.exe roms\ibm_logo.ch8
```

To use your own toolchain instead:

1. Install [NASM](https://www.nasm.us/) and [MinGW-w64](https://www.mingw-w64.org/) and
   put both on `PATH`.
2. Download `SDL2-devel-x.xx.x-mingw.zip` from the
   [SDL releases](https://github.com/libsdl-org/SDL/releases) and extract it.
3. Set `SDL2_PATH` at the top of `build.bat` to the `x86_64-w64-mingw32` folder inside it.
4. Run `build.bat`, then copy `SDL2.dll` from the package's `bin` folder next to
   `build\vchip8.exe`.

If something misbehaves on Windows, please open an issue.

## Controls

The CHIP-8 keypad maps to the left side of a QWERTY keyboard:

```
CHIP-8        Keyboard
1 2 3 C       1 2 3 4
4 5 6 D       Q W E R
7 8 9 E       A S D F
A 0 B F       Z X C V
```

`Esc` quits.

### Windows

The window has a menu bar:

- **File**: Open ROM (file picker), Exit
- **Options**
  - **Video**: 1x, 2x or 3x window scale
  - **Steps/Ticks per frame**: 6, 12 (default), 18 or 24 instructions per frame, which
    works out to roughly 360 to 1440 instructions per second at 60 fps
  - **Quirks**: the three toggles described below
  - **Colors**: pick the foreground and background colors
  - **Sound Enabled**, **Debug Mode**
- **Help**: shows the key mapping

You can also drag a `.ch8` file onto the window to load it.

### Linux

| Key | Action                             |
| --- | ---------------------------------- |
| F1  | Toggle debug overlay               |
| F2  | Toggle shift-uses-VY quirk         |
| F3  | Toggle BNNN-uses-VX quirk          |
| F4  | Toggle FX55/FX65-increments-I quirk |
| Esc | Quit                               |

## Quirks

The original COSMAC VIP interpreter and later ones (CHIP-48, SUPER-CHIP) disagree on a
few instructions. VCHIP-8 defaults to the modern behavior and lets you switch each one
back to the original:

| Instruction  | Default (modern)            | Toggled (COSMAC VIP)                    |
| ------------ | --------------------------- | --------------------------------------- |
| `8XY6/8XYE`  | Shift VX in place           | Copy VY into VX, then shift             |
| `BNNN`       | Jump to NNN + V0            | Jump to NNN + VX (X = top nibble of NNN) |
| `FX55/FX65`  | I is left unchanged         | I ends up incremented by X + 1          |

## Notes

- **Speed:** 12 instructions per frame at about 60 fps (roughly 720 Hz) by default.
- **Display:** each CHIP-8 pixel is drawn as a 5, 10 or 15 pixel square at 1x, 2x or 3x
  scale. `DXYN` clips at the screen edges instead of wrapping (the starting position
  does wrap), and `00E0` clears the whole framebuffer.
- **Sound:** a 440 Hz square wave plays through SDL2 while the sound timer is non-zero
  and sound is enabled.
- **Random numbers:** `CXNN` uses a 32-bit xorshift generator seeded from `rdtsc`.

## License

Apache-2.0. Created by giygas.
