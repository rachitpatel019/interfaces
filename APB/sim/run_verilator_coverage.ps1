# ==============================================================================
# Verilator Code Coverage Pipeline (Single Unified Script)
# Location: interfaces/APB/sim/run_verilator_coverage.ps1
# Combines WSL build, simulation execution, coverage extraction,
# and Python metrics analysis in a single standalone file.
# ==============================================================================

param (
    [switch]$Clean = $false,
    [switch]$KeepArtifacts = $false
)

$OriginalDir = Get-Location
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($ScriptDir) { Set-Location $ScriptDir }

# Convert Windows path to WSL path
$WslDir = (wsl wslpath -a -u ($ScriptDir -replace '\\', '/')).Trim()

function Cleanup-Artifacts {
    Write-Host "Cleaning Verilator coverage artifacts..." -ForegroundColor Yellow
    wsl bash -c "cd '$WslDir' && rm -rf obj_dir cov_annotated coverage.dat coverage.info sim_coverage transcript *.log"
    Write-Host "Clean complete." -ForegroundColor Green
}

if ($Clean) {
    Cleanup-Artifacts
    Set-Location $OriginalDir
    exit 0
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  RUNNING UNIFIED VERILATOR COVERAGE PIPELINE     " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$bashScriptTemplate = @'
set -e
TARGET_DIR="__TARGET_DIR__"
cd "$TARGET_DIR"

echo ">> [1/4] Compiling RTL with Verilator Coverage..."
verilator verilator.vlt --coverage -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
    --cc ../rtl/fifo.sv ../rtl/apb_pkg.sv ../rtl/apb_slave.sv ../rtl/fifo_controller.sv ../rtl/apb_top.sv \
    --top-module apb_top \
    --exe ../tb/tb_verilator.cpp \
    -o sim_coverage

echo ">> [2/4] Building C++ Simulation Binary..."
make -C obj_dir -f Vapb_top.mk -j$(nproc 2>/dev/null || echo 2)

echo ">> [3/4] Running Simulation to Collect Coverage..."
./obj_dir/sim_coverage

echo ">> [4/4] Generating Coverage Data & Annotations..."
verilator_coverage --annotate-all --annotate cov_annotated coverage.dat
verilator_coverage --write-info coverage.info coverage.dat

# Embedded Python Coverage Parser & Formatter
python3 - << 'PY_EOF'
import sys
import os
from collections import defaultdict

target_files = ["apb_slave.sv", "apb_top.sv", "fifo_controller.sv", "fifo.sv"]
line_total, line_hit = defaultdict(int), defaultdict(int)
toggle_total, toggle_hit = defaultdict(int), defaultdict(int)
branch_total, branch_hit = defaultdict(int), defaultdict(int)

# 1. Parse coverage.dat for Line and Toggle coverage
if os.path.exists("coverage.dat"):
    with open("coverage.dat", "rb") as f:
        for raw_line in f:
            if not raw_line.startswith(b"C '"):
                continue
            line = raw_line.decode('utf-8', errors='ignore')
            last_quote = line.rfind("'")
            if last_quote == -1:
                continue
            count_str = line[last_quote+1:].strip()
            if not count_str.isdigit():
                continue
            count = int(count_str)
            meta = line[3:last_quote]
            fields = {}
            for item in meta.split('\x01'):
                if '\x02' in item:
                    k, v = item.split('\x02', 1)
                    fields[k] = v
            fname, page = fields.get('f'), fields.get('page')
            if not fname or not page:
                continue
            base = os.path.basename(fname)
            if base not in target_files:
                continue
            if "v_line" in page:
                line_total[base] += 1
                if count > 0:
                    line_hit[base] += 1
            elif "v_toggle" in page:
                toggle_total[base] += 1
                if count > 0:
                    toggle_hit[base] += 1

# 2. Parse coverage.info for Branch coverage
if os.path.exists("coverage.info"):
    current_base = None
    with open("coverage.info", "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                current_base = os.path.basename(line[3:])
            elif line.startswith("BRDA:") and current_base in target_files:
                parts = line[5:].split(",")
                if len(parts) >= 4:
                    taken = parts[3]
                    branch_total[current_base] += 1
                    if taken != "-" and int(taken) > 0:
                        branch_hit[current_base] += 1

print("\n" + "=" * 89)
print("                      VERILATOR CODE COVERAGE METRICS REPORT                            ")
print("=" * 89)
print(f"{'Source File':<25} | {'Line Coverage':<18} | {'Branch Coverage':<18} | {'Toggle Coverage':<18}")
print("-" * 89)

tot_lh, tot_lt = 0, 0
tot_bh, tot_bt = 0, 0
tot_th, tot_tt = 0, 0

for f in target_files:
    lh, lt = line_hit[f], line_total[f]
    bh, bt = branch_hit[f], branch_total[f]
    th, tt = toggle_hit[f], toggle_total[f]
    
    lp = (lh / lt * 100) if lt > 0 else 100.0
    bp = (bh / bt * 100) if bt > 0 else 100.0
    tp = (th / tt * 100) if tt > 0 else 100.0
    
    tot_lh += lh; tot_lt += lt
    tot_bh += bh; tot_bt += bt
    tot_th += th; tot_tt += tt
    
    print(f"{f:<25} | {f'{lh}/{lt} ({lp:5.1f}%)':<18} | {f'{bh}/{bt} ({bp:5.1f}%)':<18} | {f'{th}/{tt} ({tp:5.1f}%)':<18}")

print("-" * 89)
tot_lp = (tot_lh / tot_lt * 100) if tot_lt > 0 else 100.0
tot_bp = (tot_bh / tot_bt * 100) if tot_bt > 0 else 100.0
tot_tp = (tot_th / tot_tt * 100) if tot_tt > 0 else 100.0

print(f"{'TOTAL (RTL Module)':<25} | {f'{tot_lh}/{tot_lt} ({tot_lp:5.1f}%)':<18} | {f'{tot_bh}/{tot_bt} ({tot_bp:5.1f}%)':<18} | {f'{tot_th}/{tot_tt} ({tot_tp:5.1f}%)':<18}")
print("=" * 89 + "\n")
PY_EOF
'@

$tempScript = Join-Path $ScriptDir ".cov_runner.sh"
$scriptContent = $bashScriptTemplate.Replace("__TARGET_DIR__", $WslDir).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($tempScript, $scriptContent, [System.Text.UTF8Encoding]::new($false))

try {
    wsl bash ./.cov_runner.sh
} finally {
    Remove-Item -Force $tempScript -ErrorAction SilentlyContinue
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Coverage run failed!" -ForegroundColor Red
    Set-Location $OriginalDir
    exit 1
}

# Clean intermediate build objects (obj_dir, binary) unless -KeepArtifacts specified
if (-not $KeepArtifacts) {
    Write-Host "Cleaning intermediate compilation artifacts (obj_dir, sim_coverage)..." -ForegroundColor Gray
    wsl bash -c "cd '$WslDir' && rm -rf obj_dir sim_coverage"
}

Write-Host "Coverage pipeline completed successfully. Annotated reports available in cov_annotated/" -ForegroundColor Green
Set-Location $OriginalDir
