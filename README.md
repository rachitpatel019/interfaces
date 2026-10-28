# APB-Controlled Synchronous FIFO IP Core

[![Verification Status](https://img.shields.io/badge/Verification-100%25%20Passed-brightgreen.svg)]()
[![Protocol](https://img.shields.io/badge/Protocol-AMBA%20APB%203.0-blue.svg)]()
[![Framework](https://img.shields.io/badge/Framework-UVM%201.2-purple.svg)]()
[![Code Coverage](https://img.shields.io/badge/Code%20Coverage-100%25-brightgreen.svg)]()
[![Functional Coverage](https://img.shields.io/badge/Functional%20Coverage-100%25-brightgreen.svg)]()
[![Mutation Score](https://img.shields.io/badge/Mutation%20Score-100%25%20(14%2F14)-brightgreen.svg)]()

A high-reliability, parameterized **AMBA APB 3.0 Completer (Slave) Interface** integrated with a **Synchronous First-In-First-Out (FIFO) buffer**. Fully verified and qualified for drop-in SoC interconnect and RISC-V memory subsystem integration.

---

## Architecture Overview

The core decouples APB 3.0 bus protocol timing from internal memory operations, providing automatic wait-state management (PREADY), sticky error reporting (PSLVERR), and complete memory isolation during illegal bus transfers.

### Module Breakdown
* [
tl/apb_top.sv](rtl/apb_top.sv): Top-level wrapper integrating bus decode, controller, and circular storage.
* [
tl/apb_slave.sv](rtl/apb_slave.sv): APB 3.0 protocol FSM (IDLE -> SETUP -> ACCESS).
* [
tl/fifo_controller.sv](rtl/fifo_controller.sv): Register address decoding, sticky error latching, wait-state generation, and bus fault isolation.
* [
tl/fifo.sv](rtl/fifo.sv): Parameterized circular memory buffer with pointer logic, watermark tracking, and boundary flags.
* [
tl/apb_pkg.sv](rtl/apb_pkg.sv): Protocol type definitions, register address constants, and error codes.

---

## Key Features

* **AMBA APB 3.0 Completer Compliance**: Full conformance with ARM IHI 0024E, supporting zero-wait writes and single wait-state synchronous reads.
* **Autonomous Error Handling**: Non-blocking PSLVERR generation on overflow, underflow, unmapped addresses, byte mis-alignment, and disabled access.
* **Hardware Memory Isolation**: Under illegal operations (overflow write or underflow read), the circular buffer remains untouched and PRDATA returns zeroed data, preventing stale bus leaks.
* **Dynamic Soft Flush**: Single-cycle pointer and count reset via control register without requiring a system hardware reset.
* **Sticky Error Status**: Self-contained sticky overflow and underflow flags that persist until explicitly cleared via software.
* **Parameterized Scalability**: Configurable DATA_WIDTH (8, 16, 32), ADDR_WIDTH, and FIFO_DEPTH (supports power-of-two, non-power-of-two, odd, and prime depths).

---

## Register Memory Map

All register addresses are strictly 32-bit word-aligned (PADDR[1:0] == 2'b00):

| Address Offset | Register Name | Access | Width | Reset Value | Description |
| :---: | :---: | :---: | :---: | :---: | :--- |
| 0x00 | REG_DATA | R/W | DATA_WIDTH | 0x00000000 | **Write**: Push word into FIFO.<br/>**Read**: Pop word from FIFO. |
| 0x04 | REG_STATUS | RO | 5 bits | 0x00000001 | [0]: Empty (1 at reset)<br/>[1]: Full<br/>[2]: Sticky Overflow<br/>[3]: Sticky Underflow<br/>[4]: FIFO Enable Status |
| 0x08 | REG_FIFO_COUNT| RO | [(DEPTH+1)-1:0] | 0x0 | Current valid word occupancy count ( \le \text{count} \le \text{DEPTH}$). |
| 0x0C | REG_CONTROL | R/W | 4 bits | 0x00000001 | [0]: FIFO Enable (1 = enabled)<br/>[1]: Soft Flush (resets pointers & count)<br/>[2]: Clear Sticky Overflow Flag<br/>[3]: Clear Sticky Underflow Flag |

---


## Verification & Qualification Summary

The core has passed complete verification sign-off across all standard ASIC quality metrics:

| Qualification Metric | Result | Target | Status |
| :--- | :---: | :---: | :---: |
| **UVM Regression Tests** | **11 / 11** | 100% Pass | **PASSED** |
| **Multi-Seed Regression** | **20 / 20 Seeds (7,760 trans)** | 100% Pass | **PASSED** |
| **Functional Coverage** | **100.00%** | 100% Reachable | **PASSED** |
| **Multidimensional Cross-Coverage** | **100.00%** | 100% Valid Bins | **PASSED** |
| **SystemVerilog Assertions (SVA)** | **11 / 11 (0 Failures)** | 0 Violations | **PASSED** |
| **Verilator Structural Line Coverage** | **17 / 17 (100.0%)** | 100% | **PASSED** |
| **Verilator Branch Coverage** | **302 / 302 (100.0%)** | 100% | **PASSED** |
| **Verilator Toggle Coverage** | **306 / 306 (100.0%)** | 100% | **PASSED** |
| **Mutation Testing (Fault Injections)** | **14 / 14 Killed (100.0%)** | 100% | **PASSED** |
| **Hostile Bus Fuzzing** | **171 Trans / 0 Mismatches** | 0 Faults | **PASSED** |
| **Negative VIP Protocol Violations** | **5 Faults / 0 Deadlocks** | Clean Recovery | **PASSED** |
| **Architectural Parameter Sweeps** | **10 / 10 Configs Passed** | 100% | **PASSED** |

> Detailed empirical reports and compliance mappings can be found in:
> * [**Verification Sign-Off Report**](docs/VERIFICATION_REPORT.md)
> * [**ARM Specification Traceability Matrix**](docs/ARM_SPEC_TRACEABILITY_MATRIX.md)

---

## Getting Started: Running Simulations

All automation scripts are located in sim/ and support PowerShell (Windows/WSL) as well as GNU Make.

### Prerequisites
* **UVM Simulators**: Siemens QuestaSim / ModelSim ASE (2020.1+)
* **Code Coverage**: Verilator (5.032+)
* **Scripting**: PowerShell 5.1+ or 7+ / Bash

### 1. Run Core UVM Regression
Executes all 11 directed, random, hostile stress, and negative VIP testcases:
`powershell
cd sim
powershell -File .\run_regression.ps1
`
To run an individual test:
`powershell
powershell -File .\run_regression.ps1 -Test apb_hostile_stress_test
`

### 2. Run Multi-Seed Constrained-Random Regression
Executes 20 pseudo-random seeds across 7,700+ transactions:
`powershell
powershell -File .\run_multiseed_regression.ps1 -NumSeeds 20
`

### 3. Run Structural Code Coverage (Verilator)
Compiles RTL via Verilator with line, branch, and toggle coverage enabled:
`powershell
powershell -File .\run_verilator_coverage.ps1
`

### 4. Run Fault Injection & Mutation Testing
Injects 14 architectural defects into RTL and validates that the verification suite detects and kills all mutants:
`powershell
powershell -File .\run_mutation_tests.ps1
`

### 5. Run Parameter Sweeps
Validates odd depths, prime depths, and varied bus widths across 10 configurations:
`powershell
powershell -File .\run_parameter_sweep.ps1 -Mode quick
`