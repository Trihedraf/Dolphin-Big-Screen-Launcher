
# Dolphin Big Screen Launcher (DBSL)

A cross-platform, controller or keyboard launcher for [Dolphin Emulator](https://dolphin-emu.org/) games. It reads your existing Dolphin game library, downloads cover art from GameTDB, and launches games in Dolphin's batch mode.

![Screenshot of Dolphin Big Screen Launcher](resources/screenshots/screenshot1.webp?raw=true)

## Features

- Coverflow view with smooth 3D animation and platform tabs (GameCube, Wii, etc.).
- Automatic cover art download from GameTDB.
- Use game titles from Dolphin's `wiitdb` database, falling back to the filename when unavailable.
- Wallpaper background support.

## Supported Game Formats

CISO, ISO, GCM, RVZ, TGC, WIA and WBFS reads the title id from inside the file.  
DOL, ELF, GCZ and WAD use their file name as the title.

## Controls

| Action | Controller | Keyboard |
| --- | --- | --- |
| Browse games | D-pad left/right / left stick | Arrow left/right / A/D |
| Switch system tab | L1 / R1 | Q / E |
| Launch game | A or Start | Enter / Space |
| Exit | Select / Back | Escape |
| Toggle fullscreen | — | F |

## Configuration

The config file `dbsl.json` is located next to the executable. The options that can be set are the following:

- `dolphin_executable`: Path to your Dolphin executable. Single backslashes are auto-escaped.
- `dolphin_user_dir`: Optional override for Dolphin's user directory. Leave blank to auto-detect.
- `fullscreen`: Start the launcher in borderless fullscreen.
- `wallpaper`: Optional image path. Scaled to cover the screen while maintaining aspect ratio.

### Command-Line Arguments

All arguments override `dbsl.json` values:

| Flag | Description |
| --- | --- |
| `-d <path>` | Override Dolphin executable path |
| `-u <path>` | Override Dolphin user directory |
| `-v` | Print diagnostic info (paths, gamepad, game count) |
| `-w <path>` | Override wallpaper image |

By default, only errors are printed.

```bash
./dbsl -d /usr/bin/dolphin-emu -u ~/emu/Dolphin/User -w bg.jpg -v
```

## Building

### Prerequisites

- [Odin](https://odin-lang.org/) (dev-2026-07a or compatible)
- C compiler/linker:
  - Linux: clang
  - Windows: MSVC
  - macOS: Xcode Command Line Tools
- Dependencies:
  - Linux: libx11-dev libcurl4-openssl-dev

### Linux and MacOS

```bash
./scripts/build.sh
```

The script automatically downloads Odin if it is not present.

### Windows

```powershell
.\scripts\build.ps1
```

The script automatically downloads Odin and raylib if they are not present.

## Packaging

Packages are output into the `dist` directory.

### Linux and MacOS

```bash
./scripts/package.sh
```

### Windows

```powershell
.\scripts\package.ps1
```
