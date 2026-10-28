# ==============================================================================
# Mutation Testing / Bug Injection Verification Experiment
# Location: interfaces/APB/sim/run_mutation_tests.ps1
# ==============================================================================

param (
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
    # Restore any leftover backup file
    $fifoBackup = Join-Path $RtlDir "fifo.sv.bak"
    $fifoFile = Join-Path $RtlDir "fifo.sv"
    if (Test-Path $fifoBackup) {
        Copy-Item -Path $fifoBackup -Destination $fifoFile -Force
        Remove-Item -Force $fifoBackup -ErrorAction SilentlyContinue
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

function Compile-And-Run([string]$TestName) {
    vlog -sv "+incdir+$UVM_SRC" "+define+UVM_NO_DPI" "+define+MODELSIM_ASE" -mfcu "$UVM_SRC/uvm_pkg.sv" `
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
        "$TbDir\tb_top.sv" *>$null

    if ($LASTEXITCODE -ne 0) {
        return @{ Result = "COMPILE_FAIL"; Log = "Compilation error" }
    }

    $out = vsim -c tb_top "+UVM_TESTNAME=$TestName" -do "run -all; quit" 2>&1
    $outStr = $out -join "`n"

    if ($outStr -match "UVM_ERROR\s*:\s*([1-9]\d*)" -or $outStr -match "SCOREBOARD FAILED" -or $outStr -match "UVM_FATAL\s*:\s*([1-9]\d*)") {
        return @{ Result = "KILLED"; Log = "Caught by Scoreboard/Checkers" }
    } elseif ($outStr -match "TEST.*PASSED") {
        return @{ Result = "SURVIVED"; Log = "Test unexpectedly passed!" }
    } else {
        return @{ Result = "KILLED"; Log = "Simulation failed/aborted" }
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   STARTING MUTATION TESTING VERIFICATION EXPERIMENT" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$Mutants = @(
    @{
        ID = "MUT-01";
        Name = "Off-by-one FULL flag assertion (asserts at DEPTH-1)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "full  <= (count + 1'b1 == FIFO_DEPTH);";
        Replacement = "full  <= (count + 1'b1 == FIFO_DEPTH - 1);";
        Test = "fifo_fill_drain_test"
    },
    @{
        ID = "MUT-02";
        Name = "Dropped PSLVERR on Write Overflow/Disabled";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "PSLVERR = (!fifo_enable || fifo_full);";
        Replacement = "PSLVERR = 1'b0;";
        Test = "fifo_overflow_test"
    },
    @{
        ID = "MUT-03";
        Name = "Incomplete Flush (read_pointer not cleared)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "read_pointer <= 'b0;";
        Replacement = "// read_pointer <= 'b0;";
        Test = "fifo_flush_test"
    },
    @{
        ID = "MUT-04";
        Name = "Read pointer premature wrap boundary (wraps at DEPTH-2)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "if (read_pointer >= FIFO_DEPTH - 1) begin";
        Replacement = "if (read_pointer >= FIFO_DEPTH - 2) begin";
        Test = "fifo_fill_drain_test"
    }
)

$KilledCount = 0
$SurvivedCount = 0
$ScriptErrors = 0

foreach ($m in $Mutants) {
    Write-Host "`n>>> Applying $($m.ID): $($m.Name)" -ForegroundColor Yellow
    
    $content = Get-Content $m.File -Raw
    if (-not $content.Contains($m.Target)) {
        Write-Host "  [-] ERROR: Target string not found in $($m.File)!" -ForegroundColor Red
        $ScriptErrors++
        continue
    }

    $backupPath = "$($m.File).bak"
    Copy-Item $m.File $backupPath -Force

    try {
        $mutatedContent = $content.Replace($m.Target, $m.Replacement)
        Set-Content -Path $m.File -Value $mutatedContent -NoNewline

        Write-Host "  Executing test $($m.Test) against mutant..." -ForegroundColor Gray
        $res = Compile-And-Run -TestName $m.Test

        if ($res.Result -eq "KILLED") {
            Write-Host "  [+] MUTANT KILLED! ($($res.Log))" -ForegroundColor Green
            $KilledCount++
        } elseif ($res.Result -eq "SURVIVED") {
            Write-Host "  [-] MUTANT SURVIVED! Test passed despite introduced defect." -ForegroundColor Red
            $SurvivedCount++
        } else {
            Write-Host "  [?] Compile/Sim failed ($($res.Log))" -ForegroundColor Magenta
            $KilledCount++
        }
    }
    finally {
        Copy-Item $backupPath $m.File -Force
        Remove-Item $backupPath -Force
    }
}

# Recompile clean RTL so the simulation library remains in golden working state
vlog -sv "+incdir+$UVM_SRC" "+define+UVM_NO_DPI" "+define+MODELSIM_ASE" -mfcu "$UVM_SRC/uvm_pkg.sv" `
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
    "$TbDir\tb_top.sv" *>$null

$cleanSuccess = ($LASTEXITCODE -eq 0)

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "MUTATION SCORE: $KilledCount / $($Mutants.Count) Killed ($([math]::Round($KilledCount / $Mutants.Count * 100))%)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

if ($cleanSuccess -and ($ScriptErrors -eq 0) -and -not $KeepArtifacts) {
    Write-Host "`nMutation run completed with no execution errors! Cleaning up artifacts..." -ForegroundColor Green
    Start-Sleep -Milliseconds 200
    Cleanup-Artifacts
    Write-Host "Cleanup completed successfully." -ForegroundColor Green
} elseif ($KeepArtifacts) {
    Write-Host "`n-KeepArtifacts specified. Artifacts preserved." -ForegroundColor Yellow
} else {
    Write-Host "`nErrors occurred during mutation test execution! Artifacts preserved for debugging." -ForegroundColor Red
}

Set-Location $OriginalDir
