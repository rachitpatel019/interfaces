# ==============================================================================
# Multi-Seed Constrained-Random Regression Runner with Coverage Saturation
# Location: interfaces/APB/sim/run_multiseed_regression.ps1
# ==============================================================================

param (
    [int]$NumSeeds = 20,
    [string]$Test = "apb_random_test",
    [int]$BaseSeed = 1000,
    [switch]$KeepArtifacts = $false
)

$OriginalDir = Get-Location
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($ScriptDir) { Set-Location $ScriptDir }

$ProjDir = Split-Path -Parent $ScriptDir
$RtlDir = Join-Path $ProjDir "rtl"
$TbDir = Join-Path $ProjDir "tb"
$UVM_SRC = "C:/intelFPGA/20.1/modelsim_ase/verilog_src/uvm-1.2/src"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  MULTI-SEED CONSTRAINED-RANDOM REGRESSION RUNNER" -ForegroundColor Cyan
Write-Host "  Test Target: $Test | Total Seeds: $NumSeeds" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Ensure library is compiled
if (!(Test-Path "work")) {
    vlib work
    vmap work work
}

Write-Host "Compiling RTL and UVM Testbench..." -ForegroundColor Yellow
vlog -sv "+incdir+$UVM_SRC" "+define+UVM_NO_DPI" "+define+MODELSIM_ASE" `
    "+define+CFG_FIFO_DEPTH=16" "+define+CFG_DATA_WIDTH=32" "+define+CFG_ADDR_WIDTH=8" `
    -mfcu "$UVM_SRC/uvm_pkg.sv" `
    "$RtlDir\fifo.sv" `
    "$RtlDir\apb_pkg.sv" `
    "$RtlDir\apb_slave.sv" `
    "$RtlDir\fifo_controller.sv" `
    "$RtlDir\apb_top.sv" `
    "$TbDir\apb_if.sv" `
    "$TbDir\apb_sva.sv" `
    "$TbDir\fifo_sva.sv" `
    "+incdir+$TbDir" "+incdir+$TbDir/sequences" "+incdir+$TbDir/tests" `
    "$TbDir\apb_pkg_tb.sv" `
    "$TbDir\tb_top.sv" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation FAILED!" -ForegroundColor Red
    Set-Location $OriginalDir
    exit 1
}
Write-Host "Compilation SUCCEEDED.`n" -ForegroundColor Green

$PassedCount = 0
$FailedCount = 0
$Results = @()

for ($i = 1; $i -le $NumSeeds; $i++) {
    $seed = $BaseSeed + $i * 137
    Write-Host -NoNewline ("Running Seed [{0,2}/{1,2}]: Seed = {2,-6} ... " -f $i, $NumSeeds, $seed)

    $simOut = vsim -c tb_top "+UVM_TESTNAME=$Test" -sv_seed $seed -do "run -all; quit" 2>&1 | Out-String

    $isPass = ($simOut -match "TEST.*PASSED" -and $simOut -notmatch "UVM_ERROR\s*:\s*([1-9]\d*)" -and $simOut -notmatch "UVM_FATAL\s*:\s*([1-9]\d*)")
    
    $samples = 0
    if ($simOut -match "Total Monitored Samples\s*:\s*(\d+)") {
        $samples = [int]$matches[1]
    }
    
    $c1 = "N/A"
    if ($simOut -match "3-Way Op x State x Enable\s*:\s*(\d+)") {
        $c1 = "$($matches[1])/12"
    }

    $c4 = "N/A"
    if ($simOut -match "4-Way Op x Addr x State x PSLVERR:\s*(\d+)") {
        $c4 = "$($matches[1])/60"
    }

    if ($isPass) {
        Write-Host "[PASS] (Transfers: $samples, Op-State-En: $c1, 4-Way: $c4)" -ForegroundColor Green
        $PassedCount++
        $statusStr = "PASS"
    } else {
        Write-Host "[FAIL]" -ForegroundColor Red
        $FailedCount++
        $statusStr = "FAIL"
    }

    $Results += [PSCustomObject]@{
        Iteration = $i
        Seed      = $seed
        Status    = $statusStr
        Samples   = $samples
        OpStateEn = $c1
        FourWay   = $c4
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "           MULTI-SEED REGRESSION SUMMARY          " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Total Seeds Tested : $NumSeeds"
Write-Host "Seeds Passed       : $PassedCount" -ForegroundColor Green
Write-Host "Seeds Failed       : $FailedCount" -ForegroundColor $(if ($FailedCount -eq 0) { "Green" } else { "Red" })
$passRate = ($PassedCount * 100.0) / $NumSeeds
Write-Host ("Pass Rate          : {0:F1}%" -f $passRate) -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

if (!$KeepArtifacts -and $FailedCount -eq 0) {
    if (Test-Path "work") { Remove-Item -Recurse -Force "work" -ErrorAction SilentlyContinue }
    Remove-Item -Force transcript, *.log, *.wlf, modelsim.ini -ErrorAction SilentlyContinue
}

Set-Location $OriginalDir
if ($FailedCount -gt 0) { exit 1 } else { exit 0 }
