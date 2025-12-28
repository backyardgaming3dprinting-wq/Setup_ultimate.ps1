# ====================================================================
#  Blender‑All‑in‑One Automated Installer / Builder
#  Target: Ryzen 5 5600G + RX 580 (8 GB VRAM)
#  Run from PowerShell (Admin)
# ====================================================================

param(
  [string]$ProjectRoot = "C:\3d-ai-stack",
  [switch]$BuildBlender = $true
)

$ErrorActionPreference = "Stop"
Write-Host "`n[1] Setting up folders..." -ForegroundColor Cyan
mkdir $ProjectRoot,$ProjectRoot\models,$ProjectRoot\extern -ea 0
cd $ProjectRoot

# ----------------------------------------------------------
# Python and build tools
# ----------------------------------------------------------
Write-Host "[2] Installing dependencies..." -ForegroundColor Cyan
winget install -e --id Python.Python.3.11
winget install -e --id Git.Git
winget install -e --id Kitware.CMake
pip install --upgrade pip torch transformers huggingface_hub trimesh requests

# ----------------------------------------------------------
# Phi‑3 model
# ----------------------------------------------------------
Write-Host "[3] Downloading Phi‑3 q4_0 model (~4 GB)..." -ForegroundColor Cyan
Invoke-WebRequest `
  "https://huggingface.co/microsoft/Phi-3/resolve/main/Phi-3.q4_0.gguf" `
  -OutFile "$ProjectRoot\models\Phi-3.q4_0.gguf"

# ----------------------------------------------------------
# Blender source + externals
# ----------------------------------------------------------
Write-Host "[4] Cloning repositories..." -ForegroundColor Cyan
git clone https://git.blender.org/blender.git blender
git clone https://github.com/ggerganov/llama.cpp.git extern\llama_cpp
git clone https://github.com/orca-slicer/orca-slicer.git extern\orca_slicer

# ----------------------------------------------------------
# Build llama.cpp with Vulkan for AMD
# ----------------------------------------------------------
Write-Host "[5] Building llama.cpp..." -ForegroundColor Cyan
cd "$ProjectRoot\extern\llama_cpp"
mkdir build; cd build
cmake -G "Visual Studio 17 2022" -A x64 -DLLAMA_VULKAN=ON ..
cmake --build . --config Release
cd $ProjectRoot

# ----------------------------------------------------------
# Inject your mytools modules into Blender (if BuildBlender)
# ----------------------------------------------------------
if ($BuildBlender) {
  Write-Host "[6] Preparing Blender fork with mytools module..." -ForegroundColor Cyan
  $modPath = "$ProjectRoot\blender\source\blender\mytools"
  mkdir $modPath -ea 0
  # copy templates into $modPath
  @"
#include "mytools_intern.h"
/* Minimal placeholder */
void MYTOOLS_init(){}
void MYTOOLS_exit(){}
"@ | Out-File "$modPath\mytools_intern.cc" -Encoding ASCII
  @"
add_library(bf_mytools mytools_intern.cc)
"@ | Out-File "$modPath\CMakeLists.txt" -Encoding ASCII

  Write-Host "Patching Blender CMakeLists..."
  Add-Content "$ProjectRoot\blender\source\blender\CMakeLists.txt" "add_subdirectory(mytools)"
  Add-Content "$ProjectRoot\blender\source\blender\CMakeLists.txt" "target_link_libraries(blender PRIVATE bf_mytools)"

  Write-Host "[7] Building Blender (this will take time)..." -ForegroundColor Cyan
  cd "$ProjectRoot\blender"
  make full
  Write-Host "[✔] Blender build completed." -ForegroundColor Green
  cd $ProjectRoot
}

# ----------------------------------------------------------
# Summary and run hints
# ----------------------------------------------------------
Write-Host "`n============================================================"
Write-Host "Setup complete."
Write-Host "Start local model server:"
Write-Host "  $ProjectRoot\extern\llama_cpp\build\Release\llama-server.exe -m $ProjectRoot\models\Phi-3.q4_0.gguf --n-gpu-layers 48 --threads 6"
Write-Host "Launch Blender from $ProjectRoot\blender\build with your modules."
Write-Host "============================================================"
```

---
