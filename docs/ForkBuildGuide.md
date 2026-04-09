# Fork Build Guide

This document describes how to clone and build the SDK from the `MatouSakura` fork chain on Windows.

## What Is Already Wired

The `.gitmodules` files in this fork have already been changed to point at the following fork chain:

- `MatouSakura/RTXNTC`
- `MatouSakura/Donut`
- `MatouSakura/NVRHI`
- `MatouSakura/RTXNTC-Library`
- `MatouSakura/RTXTF-Library`
- `MatouSakura/RTXTS-TTM`
- `MatouSakura/RTXMU`
- `MatouSakura/Vulkan-Headers`
- `MatouSakura/DirectX-Headers`
- `MatouSakura/ShaderMake`
- `MatouSakura/imgui`
- `MatouSakura/stb`
- `MatouSakura/glfw`
- `MatouSakura/cgltf`
- `MatouSakura/libdeflate`
- `MatouSakura/implot`
- `MatouSakura/lodepng`

Because of that, users do not need to manually relink submodules after cloning this fork.

## Prerequisites

Install the following tools first:

- Visual Studio 2022 with C++ build tools
- CMake
- CUDA Toolkit 12.9
- Git

For local shader compiler binaries, prepare these tools manually:

- DXC `dxc_2025_05_24`
- Slang `2025.19.1`

Example local paths used in this guide:

```text
D:\Tools\DXC\dxc_2025_05_24\bin\x64\dxc.exe
D:\Tools\Slang\slang-2025.19.1-windows-x86_64\bin\slangc.exe
```

After installing CUDA, confirm that `nvcc` is available:

```powershell
where.exe nvcc
```

## Clone With Recursive Submodules

Use `--recursive` the first time:

```powershell
git clone --recursive https://github.com/MatouSakura/RTXNTC.git
cd RTXNTC
```

If the repository was cloned without `--recursive`, run:

```powershell
git submodule sync --recursive
git submodule update --init --recursive
```

To verify that everything is checked out:

```powershell
git submodule status --recursive
```

All lines should start with a space. A leading `-` means not initialized.

## Configure With CMake

The following command was verified on this fork:

```powershell
cmake -S . -B build_check -G "Visual Studio 17 2022" -A x64 `
  -DDONUT_WITH_DLSS=OFF `
  -DSHADERMAKE_FIND_DXC=OFF `
  -DSHADERMAKE_DXC_PATH="D:\Tools\DXC\dxc_2025_05_24\bin\x64\dxc.exe" `
  -DSHADERMAKE_FIND_SLANG=OFF `
  -DSHADERMAKE_SLANG_PATH="D:\Tools\Slang\slang-2025.19.1-windows-x86_64\bin\slangc.exe"
```

Notes:

- `DONUT_WITH_DLSS=OFF` avoids an extra Git fetch for DLSS during configuration.
- If CUDA is installed but not found automatically, add:

```powershell
-DCUDAToolkit_ROOT="C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"
```

## Build

Build from PowerShell:

```powershell
cmake --build build_check --config Release --parallel
```

## Run

The generated executables are placed in:

```text
bin\windows-x64
```

Typical launch commands:

```powershell
cd bin\windows-x64
.\ntc-explorer.exe
.\ntc-renderer.exe
.\ntc-cli.exe --help
```

`ntc-renderer.exe` can run without arguments and load the bundled `FlightHelmet` sample.

If DX12 cooperative vector features cause runtime trouble, try:

```powershell
.\ntc-renderer.exe --no-coopVec
```

Or force Vulkan:

```powershell
.\ntc-renderer.exe --vk
```

## Recovery Commands

If submodules ever drift after switching branches or pulling:

```powershell
git submodule sync --recursive
git submodule update --init --recursive
```

If a specific submodule still looks empty, check its state:

```powershell
git submodule status --recursive
```

Then re-run the update command above.

## Current Verified Result

This fork was verified to:

- clone with recursive submodules from the `MatouSakura` fork chain
- pass `cmake` configure on Windows
- build successfully into `bin\windows-x64`
- launch `ntc-renderer.exe`
