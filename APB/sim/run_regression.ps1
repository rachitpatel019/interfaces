# ==============================================================================
# APB-Controlled FIFO UVM Verification Environment - Regression Runner
# Location: interfaces/APB/sim/run_regression.ps1
# ==============================================================================

param (
    [string]$Test = "all",
    [int]$Depth = 16,
    [int]$DataWidth = 32,
    [int]$AddrWidth = 8,
    [switch]$Clean = $false,
    [switch]$KeepArtifacts = $false
)

$OriginalDir = Get-Location
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($ScriptDir) { Set-Location $ScriptDir }

$ProjDir = Split-Path -Parent $ScriptDir
$RtlDir = Join-Path $ProjDir "rtl"
$TbDir = Join-Path $ProjDir "tb"

$UVM_SRC = "C:/intelFPGA/20.1/modelsim_ase/verilog_src/uvm-1.2/src"

function Cleanup-Artifacts {
    Write-Host "Cleaning up simulation artifacts (work directory, transcript, logs, waveforms)..." -ForegroundColor Yellow
    if (Test-Path "work") { 
        Remove-Item -Recurse -Force "work" -ErrorAction SilentlyContinue 
    }
    $artifactFiles = Get-ChildItem -Path ".\*" -File -Include "transcript", "*.log", "*.wlf", "*.vcd", "dump.vcd", "modelsim.ini" -ErrorAction SilentlyContinue
    foreach ($file in $artifactFiles) {
        Remove-Item -Force $file.FullName -ErrorAction SilentlyContinue
    }
}

if ($Clean) {
    Cleanup-Artifacts
    Write-Host "Clean complete." -ForegroundColor Green
    Set-Location $OriginalDir
    exit 0
}

# Create / verify work library
if (!(Test-Path "work")) {
    vlib work
    vmap work work
}

Write-Host "Compiling RTL and UVM Testbench..." -ForegroundColor Cyan

vlog -sv "+incdir+$UVM_SRC" "+define+UVM_NO_DPI" "+define+MODELSIM_ASE" `
    "+define+CFG_FIFO_DEPTH=$Depth" "+define+CFG_DATA_WIDTH=$DataWidth" "+define+CFG_ADDR_WIDTH=$AddrWidth" `
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
    "$TbDir\tb_top.sv"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation FAILED!" -ForegroundColor Red
    Set-Location $OriginalDir
    exit 1
}
Write-Host "Compilation SUCCEEDED." -ForegroundColor Green

$AllTests = @(
    "apb_basic_test",
    "fifo_fill_drain_test",
    "fifo_overflow_test",
    "fifo_underflow_test",
    "fifo_flush_test",
    "back_to_back_test",
    "apb_random_test",
    "reset_during_traffic_test",
    "fifo_negative_test"
)

$TestsToRun = if ($Test -eq "all") { $AllTests } else { @($Test) }

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  RUNNING APB FIFO UVM REGRESSION SUITE" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$Passed = 0
$Failed = 0

foreach ($t in $TestsToRun) {
    Write-Host "`n>>> Running Test: $t" -ForegroundColor Yellow
    vsim -c tb_top "+UVM_TESTNAME=$t" -do "run -all; quit" | Tee-Object -Variable simOut
    
    if ($simOut -match "TEST.*PASSED" -and $simOut -notmatch "UVM_ERROR\s*:\s*([1-9]\d*)" -and $simOut -notmatch "UVM_FATAL\s*:\s*([1-9]\d*)") {
        Write-Host "  [PASS] $t" -ForegroundColor Green
        $Passed++
    } else {
        Write-Host "  [FAIL] $t" -ForegroundColor Red
        $Failed++
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "REGRESSION SUMMARY: $Passed Passed, $Failed Failed" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

if ($Failed -eq 0 -and -not $KeepArtifacts) {
    Write-Host "`nAll tests passed with zero errors! Cleaning up artifacts..." -ForegroundColor Green
    Start-Sleep -Milliseconds 200
    Cleanup-Artifacts
    Write-Host "Cleanup completed successfully." -ForegroundColor Green
} elseif ($KeepArtifacts) {
    Write-Host "`n-KeepArtifacts specified. Artifacts preserved." -ForegroundColor Yellow
} else {
    Write-Host "`n$Failed test(s) failed! Artifacts (work directory, transcript, logs) preserved for debugging." -ForegroundColor Red
}

Set-Location $OriginalDir
exit $Failed
