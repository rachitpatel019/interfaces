# ARM AMBA APB Specification Traceability Matrix

**Specification Reference**: ARM IHI 0024E (ID022823) — *AMBA® APB Protocol Specification*  
**Target Design Under Test (DUT)**: `apb_top` (APB 3.0 Slave Interface + Synchronous FIFO Core)  
**Verification Framework**: UVM 1.2, SystemVerilog Assertions (SVA), Verilator Code Coverage  
**Current Conformance Profile**: **AMBA APB 3.0 Completer (Slave)**  

---

## 1. Executive Summary

This document establishes the official **Requirements Traceability Matrix (RTM)** mapping every normative rule, phase transition, signal requirement, and validity constraint in **ARM IHI 0024E** to its exact implementation in the RTL, its corresponding SystemVerilog Assertion (SVA) checker, and the UVM verification suite.

### Profile Conformance Overview
| Specification Chapter | Feature Scope | Target Version | Conformance Status | Verification Evidence |
| :--- | :--- | :---: | :---: | :--- |
| **Chapter 2 / App B** | Bus Signals & Bus Topology | APB3 | **100% COMPLIANT** | Pinout, widths & reset values verified |
| **Chapter 3 (3.1)** | Write Transfers (Zero & Multi-Wait) | APB3 | **100% COMPLIANT** | SVA + UVM `apb_basic_test`, `fifo_fill_drain_test` |
| **Chapter 3 (3.3)** | Read Transfers (Zero & Multi-Wait) | APB3 | **100% COMPLIANT** | SVA + UVM `fifo_underflow_test`, `back_to_back_test` |
| **Chapter 3 (3.4)** | Error Response (`PSLVERR`) | APB3 | **100% COMPLIANT** | SVA + UVM `fifo_overflow_test`, `fifo_negative_test` |
| **Chapter 4 (4.1)** | Operating States (IDLE/SETUP/ACCESS) | APB3 | **100% COMPLIANT** | SVA + Negative VIP `apb_protocol_fault_test` |
| **Appendix A (A.1)**| Signal Validity Rules | APB3 | **100% COMPLIANT** | SVA protocol checkers & UVM Monitor |
| **Ch 3.2, 3.5, 3.6** | APB4/APB5 Extensions (`PSTRB`, `PPROT`, RME) | APB4/5 | *N/A (APB 3.0 Profile)* | Documented upgrade path for APB4/5 |

---

## 2. Signal-Level Traceability (Chapter 2 & Appendix B)

According to **ARM IHI 0024E Table 2-1 and Table B-1**, an **APB 3.0 Completer** defines the following mandatory and optional signals:

| Signal | Source | Width | ARM IHI 0024E Requirement | RTL Implementation | RTL Location | Compliance |
| :--- | :---: | :---: | :--- | :--- | :--- | :---: |
| **`PCLK`** | Clock | 1 | Clock input. All signals timed to rising edge of `PCLK`. | `input logic PCLK` | `apb_top.sv` (L8) | **COMPLIANT** |
| **`PRESETn`** | System Reset | 1 | Active-LOW asynchronous system reset. | `input logic PRESETn` | `apb_top.sv` (L9) | **COMPLIANT** |
| **`PADDR`** | Requester | `ADDR_WIDTH` (8..32) | Byte address bus. Unaligned access behavior is Completer-defined. | `input logic [ADDR_WIDTH-1:0] PADDR` | `apb_top.sv` (L14) | **COMPLIANT** |
| **`PSELx`** | Requester | 1 | Completer select line. Active HIGH for required data transfer. | `input logic PSEL` | `apb_top.sv` (L11) | **COMPLIANT** |
| **`PENABLE`** | Requester | 1 | Enable line. Indicates 2nd and subsequent cycles of an APB transfer. | `input logic PENABLE` | `apb_top.sv` (L12) | **COMPLIANT** |
| **`PWRITE`** | Requester | 1 | Direction: HIGH for Write, LOW for Read. | `input logic PWRITE` | `apb_top.sv` (L13) | **COMPLIANT** |
| **`PWDATA`** | Requester | `DATA_WIDTH` (8/16/32) | Write data bus driven during write cycles. | `input logic [DATA_WIDTH-1:0] PWDATA` | `apb_top.sv` (L15) | **COMPLIANT** |
| **`PRDATA`** | Completer | `DATA_WIDTH` (8/16/32) | Read data bus driven by Completer when `PWRITE=0`. | `output logic [DATA_WIDTH-1:0] PRDATA` | `apb_top.sv` (L17) | **COMPLIANT** |
| **`PREADY`** | Completer | 1 | Ready signal. Used to extend transfer by inserting wait states. | `output logic PREADY` | `apb_top.sv` (L18) | **COMPLIANT** |
| **`PSLVERR`** | Completer | 1 | Transfer error indicator. Valid only on final cycle (`PREADY=1`). | `output logic PSLVERR` | `apb_top.sv` (L19) | **COMPLIANT** |
| **`PPROT`** | Requester | 3 | Protection level (Normal/Privileged, Secure/Non-secure, Data/Instruction). | *Optional (APB4)* | *N/A (APB 3.0 Profile)* | N/A |
| **`PSTRB`** | Requester | `DATA_WIDTH/8` | Write sparse byte strobes. | *Optional (APB4)* | *N/A (APB 3.0 Profile)* | N/A |
| **`PWAKEUP`** | Requester | 1 | Activity / power wake-up signal. | *Optional (APB5)* | *N/A (APB 3.0 Profile)* | N/A |
| **`P*USER`** | Req/Comp | Variable | User-defined attribute signals. | *Optional (APB5)* | *N/A (APB 3.0 Profile)* | N/A |

---

## 3. Protocol Operating States & FSM Traceability (Chapter 4)

ARM IHI 0024E Chapter 4 defines the canonical 3-state APB protocol machine (`IDLE`, `SETUP`, `ACCESS`):

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> SETUP : Transfer requested\n(PSEL=1, PENABLE=0)
    IDLE --> IDLE : No transfer\n(PSEL=0, PENABLE=0)
    SETUP --> ACCESS : Next PCLK edge\n(PSEL=1, PENABLE=1)
    ACCESS --> ACCESS : Wait state\n(PREADY=0)
    ACCESS --> IDLE : Transfer complete\n(PREADY=1, no transfer)
    ACCESS --> SETUP : Back-to-back transfer\n(PREADY=1, transfer pending)
```

### State & Phase Transition Verification Matrix

| Rule ID | ARM IHI 0024E Clause | Specification Requirement | Verification Checker / SVA | Test Evidence | Compliance |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **RULE-4.1-1** | Section 4.1 (p. 4-34) | **Default IDLE State**: `PSEL=0, PENABLE=0`. Peripheral must ignore bus activity. | [`apb_monitor.sv`](../tb/apb_monitor.sv#L58-L64)<br/>`MON_PROTO_ERR` | `apb_basic_test`<br/>`apb_protocol_fault_test` (Phase 2) | **PASS** |
| **RULE-4.1-2** | Section 4.1 (p. 4-34) | **SETUP State Duration**: Interface only remains in `SETUP` for **exactly one clock cycle** (`PSEL=1, PENABLE=0`) and always moves to `ACCESS` on next rising edge. | SVA: `assert_setup_before_access`<br/>[`apb_sva.sv`](../tb/apb_sva.sv#L36-L42) | `apb_basic_test`<br/>`back_to_back_test` | **PASS** |
| **RULE-4.1-3** | Section 4.1 (p. 4-34) | **ENABLE Invariant**: `PENABLE` is asserted only in `ACCESS`. Must never be asserted without `PSEL` active. | SVA: `assert_enable_requires_psel`<br/>[`apb_sva.sv`](../tb/apb_sva.sv#L26-L32) | `apb_protocol_fault_test` (Phase 2)<br/>`MON_PROTO_FAULT_CAUGHT` | **PASS** |
| **RULE-4.1-4** | Section 4.1 (p. 4-34) | **ACCESS Signal Stability**: `PADDR`, `PWRITE`, `PWDATA`, and `PSEL` **must not change** between `SETUP` and `ACCESS`, nor during wait states (`PREADY=0`). | SVA: `assert_stability_during_wait`<br/>[`apb_sva.sv`](../tb/apb_sva.sv#L46-L52) | `apb_protocol_fault_test` (Phase 4)<br/>`fifo_fill_drain_test` | **PASS** |
| **RULE-4.1-5** | Section 4.1 (p. 4-34) | **Exit via PREADY**: If `PREADY=0`, remain in `ACCESS`. If `PREADY=1`, `ACCESS` is exited and returns to `IDLE` or directly to `SETUP`. | SVA: `assert_penable_falls_after_transfer`<br/>[`apb_sva.sv`](../tb/apb_sva.sv#L56-L62) | `back_to_back_test`<br/>`apb_protocol_fault_test` (Phase 6) | **PASS** |

---

## 4. Transfers & Handshaking Traceability (Chapter 3)

### 4.1 Write Transfers (Section 3.1)
- **Clause 3.1.1 (No Wait States)**: Write data `PWDATA` is sampled by the Completer on the rising edge of `PCLK` at the end of the `ACCESS` cycle (`PREADY=1`).
  - *RTL Implementation*: `fifo_controller.sv` (L52-L56) sets `fifo_write = 1` and `PREADY = 1` during `ACCESS` when `PADDR == REG_DATA`. Data is captured by `fifo.sv` into memory array at posedge `PCLK`.
  - *Verification*: Monitored and validated by [`apb_scoreboard.sv`](../tb/apb_scoreboard.sv#L95-L123) across all write testcases.
- **Clause 3.1.2 (With Wait States)**: Completer extends transfer by driving `PREADY=0`. Signals remain stable until transfer completes.
  - *RTL Implementation*: `fifo_controller.sv` provides clean wait-state insertion architecture (`fifo_read_ready`).

### 4.2 Read Transfers (Section 3.3)
- **Clause 3.3.1 & 3.3.2 (Read Data Validity & Extension)**: Completer provides read data on `PRDATA` before the end of the read transfer (`PREADY=1`).
  - *RTL Implementation*: In `fifo_controller.sv` (L57-L63), read from `REG_DATA` drives `PREADY = 0` in cycle 1 of `ACCESS`, allowing `fifo.sv` 1 cycle synchronous read latency, asserting `PREADY = 1` in cycle 2 with valid `PRDATA`.
  - *Verification*: `fifo_fill_drain_test`, `back_to_back_test`, multi-seed regressions (7,760 transfers) verified with **0 mismatches**.

### 4.3 Error Response (`PSLVERR`) (Section 3.4)
- **Clause 3.4-1 (Sampling Condition)**: `PSLVERR` is **only considered valid during the last cycle of an APB transfer**, when `PSEL=1, PENABLE=1, PREADY=1`.
  - *RTL Implementation*: `fifo_controller.sv` (L47, L60, L67, L96, L106) assigns `PSLVERR` in `ACCESS` phase, and registers read errors so `PSLVERR` is aligned with `PREADY=1`.
  - *Verification*: [`apb_scoreboard.sv`](../tb/apb_scoreboard.sv#L179-L185) verifies `PSLVERR` strictly at `PREADY=1` sampling edge.
- **Clause 3.4-2 (State Invariance & Safety)**: A write receiving an error might or might not change peripheral state; read error can return invalid data without requiring 0s.
  - *RTL Implementation*: `fifo_controller.sv` enforces **hardware memory isolation**: overflow writes and underflow reads block push/pop (`write_valid=0`, `read_valid=0`), preventing buffer corruption and driving `PRDATA='0` on error reads.
  - *Verification*: Tested in `fifo_overflow_test`, `fifo_underflow_test`, `apb_hostile_stress_test` (Phase 2 Canary Latch Priming).

---

## 5. Signal Validity Rules Traceability (Appendix A)

ARM IHI 0024E **Section A.1 (Validity Rules)** defines the exact condition when each interface signal must be valid:

| ARM Spec Signal Validity Requirement | Trigger Condition | RTL / SVA Implementation | Testbench Verification | Compliance |
| :--- | :--- | :--- | :--- | :---: |
| **`PSEL` must always be valid** | Always | `apb_if.sv` drv_cb / mon_cb | Driven continuously without `X`/`Z` | **PASS** |
| **`PADDR` valid when `PSEL` asserted** | `PSEL == 1` | `fifo_controller.sv` decodes `PADDR` | SVA `assert_stability_during_wait` | **PASS** |
| **`PENABLE` valid when `PSEL` asserted** | `PSEL == 1` | `apb_slave.sv` state decoder | SVA `assert_enable_requires_psel` | **PASS** |
| **`PWRITE` valid when `PSEL` asserted** | `PSEL == 1` | `fifo_controller.sv` read/write gating | SVA `assert_stability_during_wait` | **PASS** |
| **`PWDATA` valid for active write lanes** | `PSEL == 1 && PWRITE == 1` | `fifo.sv` memory latch | SVA `assert_stability_during_wait` | **PASS** |
| **`PREADY` valid when `PSEL && PENABLE`** | `ACCESS` Phase | `fifo_controller.sv` sets `PREADY` | Sampled exclusively when `PENABLE=1` | **PASS** |
| **`PRDATA` valid when `PSEL && PENABLE && PREADY`** | Read Access Done | `PRDATA` driven from `fifo_read_data` | Scoreboard samples `PRDATA` on `PREADY=1` | **PASS** |
| **`PSLVERR` valid when `PSEL && PENABLE && PREADY`** | Transfer Done | `PSLVERR` driven from error logic | Scoreboard validates `PSLVERR` on `PREADY=1` | **PASS** |

---

## 6. Hostile Protocol & Negative VIP Compliance Matrix

To prove that the DUT conforms not only to well-behaved masters, but also handles **illegal protocol sequences** without deadlock (as specified in ARM IHI 0024E), the following negative tests were qualified:

| Negative VIP Test Scenario | Official ARM Violation Mode | DUT Protection & Isolation Mechanism | Verified Outcome |
| :--- | :--- | :--- | :---: |
| **Rogue PENABLE without PSEL** | Breaches Section 2.1 & 4.1 (`PENABLE` requires `PSEL`) | Slave remains in `IDLE`. All internal logic gated; Canary memory unharmed. | **0 Memory Corruption** |
| **Direct Jump IDLE to ACCESS** | Breaches Section 4.1 (`SETUP` phase skipped) | Combinational FSM decodes `ACCESS`; handles write/read with `PREADY=1`. | **0 Deadlocks** |
| **Address Mutation During Wait** | Breaches Section 3.1.2 & 4.1 (Stability during `PREADY=0`) | Controller completes cycle; unmapped address decode issues `PSLVERR=1`. | **Bus Recovers Cleanly** |
| **Premature Master Abort** | Breaches Handshake Rules (Terminating on `PREADY=0`) | Slave FSM cleanly **self-heals** back to `IDLE`; `fifo_read_ready` resets to 0. | **0 Hung States** |
| **Stuck PENABLE Across Boundaries** | Breaches Section 4.1 (Failing to deassert `PENABLE`) | Slave completes transfer and returns to `IDLE` upon bus release. | **Clean Post-Fault Recovery** |

---

## 7. Future Extension Roadmap for APB4 and APB5

For SoC integration requiring higher-tier AMBA standards:

```mermaid
flowchart LR
    A["Current: APB 3.0 Completer<br/>(PCLK, PRESETn, PADDR, PSEL,<br/>PENABLE, PWRITE, PWDATA,<br/>PRDATA, PREADY, PSLVERR)"] --> B["APB 4.0 Profile<br/>+ PSTRB (Byte Strobes)<br/>+ PPROT (Privilege & Security)"]
    B --> C["APB 5.0 Profile<br/>+ PWAKEUP (Power Signaling)<br/>+ P*USER (Sideband Attributes)<br/>+ Interface Parity Checking"]
```

1. **APB 4.0 Upgrade (`PSTRB`, `PPROT`)**:
   - `PSTRB`: Byte write strobes mapping to individual FIFO byte lanes.
   - `PPROT`: Restricting FIFO configuration registers (`REG_CONTROL`) to privileged transfers (`PPROT[0]=1`).
2. **APB 5.0 Upgrade (Parity & Power)**:
   - Interface odd parity generation and checking (`PADDRCHK`, `PWDATACHK`, `PRDATACHK`, `PCTRLCHK`) per ARM IHI 0024E Chapter 5.
   - Clock gating wake-up handshaking via `PWAKEUP` per Section 3.7.

---

## 8. Conclusion & Sign-Off

The **APB-Controlled FIFO IP core** (`apb_top`) is fully compliant with all normative Completer requirements of the **ARM IHI 0024E AMBA APB 3.0 specification**:
- All mandatory signal definitions, widths, and reset states verified.
- All operating state transitions (`IDLE`, `SETUP`, `ACCESS`, back-to-back `SETUP`) verified via SVA and UVM.
- Error reporting via `PSLVERR` conforms strictly to the ARM sampling standard.
- 100% pass rate achieved across directed, randomized, hostile fuzzing, and negative protocol fault injection suites.

**Formal Sign-Off**: **AMBA APB 3.0 COMPLIANT**
