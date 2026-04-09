[CmdletBinding()]
param(
    [string]$BuildDir = "build_check",
    [string]$Generator = "Visual Studio 17 2022",
    [string]$Platform = "x64",
    [string]$Config = "Release",
    [switch]$Build,
    [switch]$EnableDlss,
    [string]$CudaToolkitRoot,
    [string]$DxcPath,
    [string]$SlangPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-ExistingFile {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    $resolved = Resolve-Path -Path $PathValue -ErrorAction SilentlyContinue
    if ($resolved) {
        return $resolved.Path
    }

    return $null
}

function Resolve-ToolFromCommand {
    param([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

function Resolve-CudaToolkitRoot {
    param([string]$RequestedRoot)

    $candidate = Resolve-ExistingFile $RequestedRoot
    if ($candidate) {
        return $candidate
    }

    if ($env:CUDA_PATH -and (Test-Path $env:CUDA_PATH)) {
        return (Resolve-Path $env:CUDA_PATH).Path
    }

    $nvccPath = Resolve-ToolFromCommand "nvcc"
    if ($nvccPath) {
        return (Split-Path -Parent (Split-Path -Parent $nvccPath))
    }

    return $null
}

function Add-CMakeCacheArgument {
    param(
        [System.Collections.Generic.List[string]]$Arguments,
        [string]$Name,
        [string]$Value
    )

    $Arguments.Add("-D${Name}=$Value")
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $repoRoot

try {
    $null = Get-Command git -ErrorAction Stop
    $null = Get-Command cmake -ErrorAction Stop

    Write-Host "==> Syncing submodules"
    & git submodule sync --recursive
    & git submodule update --init --recursive

    $cudaRoot = Resolve-CudaToolkitRoot $CudaToolkitRoot
    if (-not $cudaRoot) {
        throw "CUDA Toolkit was not found. Install CUDA 12.9 or pass -CudaToolkitRoot."
    }

    $resolvedDxcPath = Resolve-ExistingFile $DxcPath
    if (-not $resolvedDxcPath -and $env:SHADERMAKE_DXC_PATH) {
        $resolvedDxcPath = Resolve-ExistingFile $env:SHADERMAKE_DXC_PATH
    }
    if (-not $resolvedDxcPath -and $env:VULKAN_SDK) {
        $resolvedDxcPath = Resolve-ExistingFile (Join-Path $env:VULKAN_SDK "Bin\dxc.exe")
    }
    if (-not $resolvedDxcPath) {
        $resolvedDxcPath = Resolve-ToolFromCommand "dxc"
    }

    $resolvedSlangPath = Resolve-ExistingFile $SlangPath
    if (-not $resolvedSlangPath -and $env:SHADERMAKE_SLANG_PATH) {
        $resolvedSlangPath = Resolve-ExistingFile $env:SHADERMAKE_SLANG_PATH
    }
    if (-not $resolvedSlangPath) {
        $resolvedSlangPath = Resolve-ToolFromCommand "slangc"
    }

    $cmakeArgs = [System.Collections.Generic.List[string]]::new()
    foreach ($argument in @("-S", ".", "-B", $BuildDir, "-G", $Generator, "-A", $Platform)) {
        $cmakeArgs.Add($argument)
    }
    Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "CUDAToolkit_ROOT" -Value $cudaRoot

    if ($EnableDlss) {
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "DONUT_WITH_DLSS" -Value "ON"
    } else {
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "DONUT_WITH_DLSS" -Value "OFF"
    }

    if ($resolvedDxcPath) {
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "SHADERMAKE_FIND_DXC" -Value "OFF"
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "SHADERMAKE_DXC_PATH" -Value $resolvedDxcPath
    } else {
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "SHADERMAKE_FIND_DXC" -Value "ON"
    }

    if ($resolvedSlangPath) {
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "SHADERMAKE_FIND_SLANG" -Value "OFF"
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "SHADERMAKE_SLANG_PATH" -Value $resolvedSlangPath
    } else {
        Add-CMakeCacheArgument -Arguments $cmakeArgs -Name "SHADERMAKE_FIND_SLANG" -Value "ON"
    }

    Write-Host "==> Configuring with CMake"
    & cmake @cmakeArgs

    if ($Build) {
        Write-Host "==> Building $Config"
        & cmake --build $BuildDir --config $Config --parallel
    }

    Write-Host ""
    Write-Host "Setup completed."
    Write-Host "Build directory: $BuildDir"
    Write-Host "Binaries: bin\windows-x64"
}
finally {
    Pop-Location
}
