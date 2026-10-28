# ==============================================================================
# APB-Controlled FIFO UVM Verification - Parameter Sweep Runner
# Location: interfaces/APB/sim/run_parameter_sweep.ps1
# Sweeps FIFO_DEPTH, DATA_WIDTH, and ADDR_WIDTH across diverse configurations
# ==============================================================================

param (
    [string]$Mode = "quick", # "quick" (key boundary tests) or "full" (all 9 regression tests)
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

# Parameter Configuration Matrix
$SweepConfigs = @(
    @{ Name = "CFG-01"; Depth = 16; DataWidth = 32; AddrWidth = 8;  Desc = "Default Baseline (Power-of-Two)" },
    @{ Name = "CFG-02"; Depth = 2;  DataWidth = 32; AddrWidth = 8;  Desc = "Minimum Power-of-Two Depth" },
    @{ Name = "CFG-03"; Depth = 3;  DataWidth = 32; AddrWidth = 8;  Desc = "Small Odd Non-Power-of-Two" },
    @{ Name = "CFG-04"; Depth = 7;  DataWidth = 32; AddrWidth = 8;  Desc = "Prime Non-Power-of-Two Depth" },
    @{ Name = "CFG-05"; Depth = 10; DataWidth = 32; AddrWidth = 8;  Desc = "Even Non-Power-of-Two Depth" },
    @{ Name = "CFG-06"; Depth = 15; DataWidth = 32; AddrWidth = 8;  Desc = "Boundary Off-by-One Depth (15)" },
    @{ Name = "CFG-07"; Depth = 32; DataWidth = 32; AddrWidth = 8;  Desc = "Large Depth (32 words)" },
    @{ Name = "CFG-08"; Depth = 8;  DataWidth = 16; AddrWidth = 8;  Desc = "16-bit Halfword Data Bus" },
    @{ Name = "CFG-09"; Depth = 8;  DataWidth = 32; AddrWidth = 12; Desc = "12-bit Extended Address Space" },
    @{ Name = "CFG-10"; Depth = 16; DataWidth = 32; AddrWidth = 16; Desc = "16-bit Large Address Space" }
)

$TestsToRun = if ($Mode -eq "quick") {
    @("fifo_fill_drain_test", "fifo_overflow_test", "fifo_flush_test", "fifo_negative_test")
} else {
    @(
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
}

Write-Host "=========================================================================================" -ForegroundColor Cyan
Write-Host "             STARTING APB FIFO ARCHITECTURAL PARAMETER SWEEP REGRESSION                 " -ForegroundColor Cyan
Write-Host "=========================================================================================" -ForegroundColor Cyan
Write-Host "Mode: $Mode ($($TestsToRun.Count) tests per configuration | $($SweepConfigs.Count) configurations)" -ForegroundColor Yellow

$Results = @()
$TotalPassedConfigs = 0
$TotalFailedConfigs = 0

foreach ($cfg in $SweepConfigs) {
    Write-Host "`n-----------------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ">> Testing $($cfg.Name): DEPTH=$($cfg.Depth), DATA=$($cfg.DataWidth), ADDR=$($cfg.AddrWidth) - $($cfg.Desc)" -ForegroundColor Yellow
    Write-Host "-----------------------------------------------------------------------------------------" -ForegroundColor Cyan

    # Ensure clean work library
    if (!(Test-Path "work")) {
        vlib work *>$null
        vmap work work *>$null
    }

    # Compile with configuration macros
    $vlogOut = vlog -sv "+incdir+$UVM_SRC" "+define+UVM_NO_DPI" "+define+MODELSIM_ASE" `
        "+define+CFG_FIFO_DEPTH=$($cfg.Depth)" `
        "+define+CFG_DATA_WIDTH=$($cfg.DataWidth)" `
        "+define+CFG_ADDR_WIDTH=$($cfg.AddrWidth)" `
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
        "$TbDir\tb_top.sv" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [-] Compilation Failed for $($cfg.Name)!" -ForegroundColor Red
        $TotalFailedConfigs++
        $Results += [PSCustomObject]@{
            Config      = $cfg.Name
            Depth       = $cfg.Depth
            DataWidth   = $cfg.DataWidth
            AddrWidth   = $cfg.AddrWidth
            TestsPassed = 0
            TestsFailed = $TestsToRun.Count
            Status      = "COMPILE_FAIL"
        }
        continue
    }

    $cfgPassed = 0
    $cfgFailed = 0

    foreach ($t in $TestsToRun) {
        $simOut = vsim -c tb_top "+UVM_TESTNAME=$t" -do "run -all; quit" 2>&1
        $outStr = $simOut -join "`n"

        if ($outStr -match "TEST.*PASSED" -and $outStr -notmatch "UVM_ERROR\s*:\s*([1-9]\d*)" -and $outStr -notmatch "UVM_FATAL\s*:\s*([1-9]\d*)") {
            Write-Host "   [PASS] $t" -ForegroundColor Green
            $cfgPassed++
        } else {
            Write-Host "   [FAIL] $t" -ForegroundColor Red
            $cfgFailed++
        }
    }

    $status = if ($cfgFailed -eq 0) { "PASS" } else { "FAIL" }
    if ($status -eq "PASS") { $TotalPassedConfigs++ } else { $TotalFailedConfigs++ }

    $Results += [PSCustomObject]@{
        Config      = $cfg.Name
        Depth       = $cfg.Depth
        DataWidth   = $cfg.DataWidth
        AddrWidth   = $cfg.AddrWidth
        TestsPassed = $cfgPassed
        TestsFailed = $cfgFailed
        Status      = $status
    }
}

Write-Host "`n=========================================================================================" -ForegroundColor Cyan
Write-Host "                           PARAMETER SWEEP RESULTS SUMMARY                               " -ForegroundColor Cyan
Write-Host "=========================================================================================" -ForegroundColor Cyan
Write-Host ("{0,-8} | {1,-6} | {2,-6} | {3,-6} | {4,-12} | {5,-12} | {6,-8}" -f "Config", "Depth", "Data", "Addr", "Passed", "Failed", "Status")
Write-Host "-----------------------------------------------------------------------------------------"

foreach ($r in $Results) {
    $color = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host ("{0,-8} | {1,-6} | {2,-6} | {3,-6} | {4,-12} | {5,-12} | {6,-8}" -f $r.Config, $r.Depth, $r.DataWidth, $r.AddrWidth, $r.TestsPassed, $r.TestsFailed, $r.Status) -ForegroundColor $color
}

Write-Host "=========================================================================================" -ForegroundColor Cyan
Write-Host "OVERALL SWEEP: $TotalPassedConfigs / $($SweepConfigs.Count) Configurations Passed ($TotalFailedConfigs Failed)" -ForegroundColor Cyan
Write-Host "=========================================================================================" -ForegroundColor Cyan

if ($TotalFailedConfigs -eq 0 -and -not $KeepArtifacts) {
    Write-Host "`nAll configurations passed without errors! Cleaning up artifacts..." -ForegroundColor Green
    Start-Sleep -Milliseconds 200
    Cleanup-Artifacts
    Write-Host "Cleanup completed successfully." -ForegroundColor Green
} elseif ($KeepArtifacts) {
    Write-Host "`n-KeepArtifacts specified. Artifacts preserved." -ForegroundColor Yellow
} else {
    Write-Host "`nFailures detected during parameter sweep. Simulation work directory and logs preserved for debugging." -ForegroundColor Red
}

Set-Location $OriginalDir
exit $TotalFailedConfigs
