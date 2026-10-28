# ==============================================================================
# Scaled Mutation Testing / Automated Fault Qualification Runner
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
    Get-ChildItem -Path $RtlDir -Filter "*.bak" | ForEach-Object {
        $orig = $_.FullName.Substring(0, $_.FullName.Length - 4)
        Copy-Item -Path $_.FullName -Destination $orig -Force
        Remove-Item -Force $_.FullName -ErrorAction SilentlyContinue
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
        "$TbDir\tb_top.sv" *>$null

    if ($LASTEXITCODE -ne 0) {
        return @{ Result = "KILLED"; Log = "Compile syntax/type check caught mutant" }
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

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   STARTING SCALED MUTATION TESTING (FAULT QUALIFICATION SUITE)  " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$Mutants = @(
    @{
        ID = "MUT-01";
        Name = "Off-by-one FULL flag assertion (asserts at DEPTH-1)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "full  <= (count + 1'b1 == FIFO_DEPTH);";
        Replacement = "full  <= (count + 1'b1 == FIFO_DEPTH - 1);";
        Test = "fifo_fill_drain_test";
        Mech = "Detected early full flag"
    },
    @{
        ID = "MUT-02";
        Name = "Dropped PSLVERR on Write Overflow/Disabled";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "PSLVERR = (!fifo_enable || fifo_full);";
        Replacement = "PSLVERR = 1'b0;";
        Test = "fifo_overflow_test";
        Mech = "Detected missing PSLVERR"
    },
    @{
        ID = "MUT-03";
        Name = "Incomplete Flush (read_pointer not cleared)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "if (!PRESETn || flush) begin`r`n        read_pointer <= 'b0;";
        Replacement = "if (!PRESETn || flush) begin`r`n        // read_pointer <= 'b0;";
        Test = "fifo_flush_test";
        Mech = "Detected stale data post-flush"
    },
    @{
        ID = "MUT-04";
        Name = "Read pointer premature wrap boundary (wraps at DEPTH-2)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "if (read_pointer >= FIFO_DEPTH - 1) begin";
        Replacement = "if (read_pointer >= FIFO_DEPTH - 2) begin";
        Test = "fifo_fill_drain_test";
        Mech = "Detected data mismatch on drain"
    },
    @{
        ID = "MUT-05";
        Name = "Inverted empty flag assertion on reset (starts 0)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "empty <= 1'b1;";
        Replacement = "empty <= 1'b0;";
        Test = "apb_basic_test";
        Mech = "Detected empty status mismatch"
    },
    @{
        ID = "MUT-06";
        Name = "Write pointer premature wrap boundary (wraps at DEPTH-2)";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "if (write_pointer >= FIFO_DEPTH - 1) begin";
        Replacement = "if (write_pointer >= FIFO_DEPTH - 2) begin";
        Test = "fifo_fill_drain_test";
        Mech = "Detected overwritten buffer item"
    },
    @{
        ID = "MUT-07";
        Name = "Count decrement suppressed on pop operation";
        File = (Join-Path $RtlDir "fifo.sv");
        Target = "count <= count - 1'b1;";
        Replacement = "count <= count;";
        Test = "fifo_fill_drain_test";
        Mech = "Detected count mismatch on pop"
    },
    @{
        ID = "MUT-08";
        Name = "Suppress PSLVERR on Read Underflow";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "fifo_read_error <= (fifo_empty || !fifo_enable);";
        Replacement = "fifo_read_error <= 1'b0;";
        Test = "fifo_underflow_test";
        Mech = "Detected missing underflow PSLVERR"
    },
    @{
        ID = "MUT-09";
        Name = "Suppress PSLVERR on Unmapped Address Decode";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "default: begin`r`n                PREADY = 1'b1;`r`n                PSLVERR = 1'b1;";
        Replacement = "default: begin`r`n                PREADY = 1'b1;`r`n                PSLVERR = 1'b0;";
        Test = "apb_hostile_stress_test";
        Mech = "Caught by hostile address fuzzer"
    },
    @{
        ID = "MUT-10";
        Name = "Suppress Sticky Overflow Flag Clear Action";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "fifo_clear_overflow = PWDATA[2];";
        Replacement = "fifo_clear_overflow = 1'b0;";
        Test = "apb_hostile_stress_test";
        Mech = "Detected non-clearing sticky overflow"
    },
    @{
        ID = "MUT-11";
        Name = "Suppress Sticky Underflow Flag Clear Action";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "fifo_clear_underflow = PWDATA[3];";
        Replacement = "fifo_clear_underflow = 1'b0;";
        Test = "apb_hostile_stress_test";
        Mech = "Detected non-clearing sticky underflow"
    },
    @{
        ID = "MUT-12";
        Name = "Skip APB SETUP phase (illegal jump to ACCESS)";
        File = (Join-Path $RtlDir "apb_slave.sv");
        Target = "else if (!PENABLE) begin`r`n        state = SETUP;`r`n    end";
        Replacement = "else if (!PENABLE) begin`r`n        state = ACCESS;`r`n    end";
        Test = "apb_basic_test";
        Mech = "Caught by SVA / Scoreboard"
    },
    @{
        ID = "MUT-13";
        Name = "Leak stale data on Read Underflow/Disabled error";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "PRDATA = fifo_read_error ? 'b0 : fifo_read_data;";
        Replacement = "PRDATA = fifo_read_data;";
        Test = "apb_hostile_stress_test";
        Mech = "Caught data leakage on disabled read"
    },
    @{
        ID = "MUT-14";
        Name = "Address aliasing: unmap REG_FIFO_COUNT";
        File = (Join-Path $RtlDir "fifo_controller.sv");
        Target = "REG_FIFO_COUNT: begin";
        Replacement = "8'h77: begin";
        Test = "apb_basic_test";
        Mech = "Detected unexpected PSLVERR on count read"
    }
)

$KilledCount = 0
$SurvivedCount = 0
$ScriptErrors = 0

foreach ($m in $Mutants) {
    Write-Host "`n>>> Applying $($m.ID): $($m.Name)" -ForegroundColor Yellow
    
    $rawContent = [System.IO.File]::ReadAllText($m.File)
    # Check with normalized CRLF
    $targetNorm = $m.Target.Replace("`r`n", "`n")
    $contentNorm = $rawContent.Replace("`r`n", "`n")

    if (-not $contentNorm.Contains($targetNorm)) {
        Write-Host "  [-] ERROR: Target string not found in $($m.File)!" -ForegroundColor Red
        $ScriptErrors++
        continue
    }

    $backupPath = "$($m.File).bak"
    Copy-Item $m.File $backupPath -Force

    try {
        $replacementNorm = $m.Replacement.Replace("`r`n", "`n")
        $mutatedNorm = $contentNorm.Replace($targetNorm, $replacementNorm)
        [System.IO.File]::WriteAllText($m.File, $mutatedNorm.Replace("`n", "`r`n"))

        Write-Host "  Executing test $($m.Test) against mutant..." -ForegroundColor Gray
        $res = Compile-And-Run -TestName $m.Test

        if ($res.Result -eq "KILLED") {
            Write-Host "  [+] MUTANT KILLED! ($($res.Log) - $($m.Mech))" -ForegroundColor Green
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
    "$TbDir\tb_top.sv" *>$null

$cleanSuccess = ($LASTEXITCODE -eq 0)

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "MUTATION SCORE: $KilledCount / $($Mutants.Count) Killed ($([math]::Round($KilledCount / $Mutants.Count * 100))%)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

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
if ($SurvivedCount -gt 0 -or $ScriptErrors -gt 0) { exit 1 } else { exit 0 }
