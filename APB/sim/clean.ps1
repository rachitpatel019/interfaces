# ==============================================================================
# Simulation Environment Cleanup Script
# Location: interfaces/APB/sim/clean.ps1
# Cleans all ModelSim, Verilator, and temporary simulation artifacts
# ==============================================================================

param (
    [switch]$VerilatorOnly = $false,
    [switch]$ModelSimOnly = $false
)

$OriginalDir = Get-Location
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($ScriptDir) { Set-Location $ScriptDir }

$ProjDir = Split-Path -Parent $ScriptDir
$RtlDir = Join-Path $ProjDir "rtl"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "       CLEANING SIMULATION ENVIRONMENT" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Clean ModelSim artifacts
if (-not $VerilatorOnly) {
    Write-Host "Cleaning ModelSim artifacts..." -ForegroundColor Yellow
    if (Test-Path "work") { 
        Remove-Item -Recurse -Force "work" -ErrorAction SilentlyContinue 
    }
    $msArtifacts = Get-ChildItem -Path ".\*" -File -Include "transcript", "*.log", "*.wlf", "*.vcd", "dump.vcd", "modelsim.ini" -ErrorAction SilentlyContinue
    foreach ($f in $msArtifacts) {
        Remove-Item -Force $f.FullName -ErrorAction SilentlyContinue
    }
    # Restore any accidental backup files in RTL
    $fifoBackup = Join-Path $RtlDir "fifo.sv.bak"
    $fifoFile = Join-Path $RtlDir "fifo.sv"
    if (Test-Path $fifoBackup) {
        Copy-Item -Path $fifoBackup -Destination $fifoFile -Force
        Remove-Item -Force $fifoBackup -ErrorAction SilentlyContinue
    }
}

# Clean Verilator artifacts
if (-not $ModelSimOnly) {
    Write-Host "Cleaning Verilator coverage artifacts..." -ForegroundColor Yellow
    if (Test-Path "obj_dir") { 
        Remove-Item -Recurse -Force "obj_dir" -ErrorAction SilentlyContinue 
    }
    if (Test-Path "cov_annotated") { 
        Remove-Item -Recurse -Force "cov_annotated" -ErrorAction SilentlyContinue 
    }
    $verArtifacts = Get-ChildItem -Path ".\*" -File -Include "coverage.dat", "coverage.info", "sim_coverage", "sim_coverage.exe" -ErrorAction SilentlyContinue
    foreach ($f in $verArtifacts) {
        Remove-Item -Force $f.FullName -ErrorAction SilentlyContinue
    }
}

Write-Host "Clean complete! Workspace is clean." -ForegroundColor Green
Set-Location $OriginalDir
