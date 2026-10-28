`ifndef APB_PKG_TB_SV
`define APB_PKG_TB_SV

package apb_pkg_tb;

    // Standard UVM macros and package imports
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // Import DUT / RTL Definitions (register address enum, FSM states)
    import apb_pkg::*;

    // Default Testbench Architectural Parameters (overridable via compiler +define+)
    `ifndef CFG_ADDR_WIDTH
        `define CFG_ADDR_WIDTH 8
    `endif
    `ifndef CFG_DATA_WIDTH
        `define CFG_DATA_WIDTH 32
    `endif
    `ifndef CFG_FIFO_DEPTH
        `define CFG_FIFO_DEPTH 16
    `endif

    parameter int ADDR_WIDTH = `CFG_ADDR_WIDTH;
    parameter int DATA_WIDTH = `CFG_DATA_WIDTH;
    parameter int FIFO_DEPTH = `CFG_FIFO_DEPTH;

    // Parameterized virtual interface typedef
    typedef virtual apb_if #(ADDR_WIDTH, DATA_WIDTH) apb_vif_t;

    // Component and Object Includes (in strict compilation dependency order)
    `include "apb_transaction.sv"
    `include "apb_sequencer.sv"
    `include "apb_driver.sv"
    `include "apb_monitor.sv"
    `include "apb_agent.sv"
    `include "apb_scoreboard.sv"
    `include "apb_coverage.sv"
    `include "apb_env.sv"

    // Stimulus Sequences
    `include "sequences/apb_base_seq.sv"
    `include "sequences/apb_write_seq.sv"
    `include "sequences/apb_read_seq.sv"
    `include "sequences/fifo_fill_drain_seq.sv"
    `include "sequences/fifo_overflow_seq.sv"
    `include "sequences/fifo_underflow_seq.sv"
    `include "sequences/fifo_flush_seq.sv"
    `include "sequences/fifo_back_to_back_seq.sv"
    `include "sequences/fifo_random_seq.sv"
    `include "sequences/reset_during_traffic_seq.sv"
    `include "sequences/fifo_negative_seq.sv"
    `include "sequences/apb_hostile_stress_seq.sv"
    `include "sequences/apb_protocol_fault_seq.sv"

    // Test Suites
    `include "tests/apb_base_test.sv"
    `include "tests/apb_basic_test.sv"
    `include "tests/fifo_fill_drain_test.sv"
    `include "tests/fifo_overflow_test.sv"
    `include "tests/fifo_underflow_test.sv"
    `include "tests/fifo_flush_test.sv"
    `include "tests/back_to_back_test.sv"
    `include "tests/apb_random_test.sv"
    `include "tests/reset_during_traffic_test.sv"
    `include "tests/fifo_negative_test.sv"
    `include "tests/apb_hostile_stress_test.sv"
    `include "tests/apb_protocol_fault_test.sv"

endpackage : apb_pkg_tb

`endif
