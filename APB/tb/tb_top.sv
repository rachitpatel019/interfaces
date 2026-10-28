`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg_tb::*;

module tb_top;
    import uvm_pkg::*;
    import apb_pkg_tb::*;
    import apb_pkg::*;

    `ifndef CFG_ADDR_WIDTH
        `define CFG_ADDR_WIDTH 8
    `endif
    `ifndef CFG_DATA_WIDTH
        `define CFG_DATA_WIDTH 32
    `endif
    `ifndef CFG_FIFO_DEPTH
        `define CFG_FIFO_DEPTH 16
    `endif

    localparam int ADDR_WIDTH = `CFG_ADDR_WIDTH;
    localparam int DATA_WIDTH = `CFG_DATA_WIDTH;
    localparam int FIFO_DEPTH = `CFG_FIFO_DEPTH;

    // Clock Generation (100 MHz, 10ns period)
    bit PCLK;
    always #5 PCLK = ~PCLK;

    // Interface Instantiation
    apb_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) apb_bus (
        .PCLK(PCLK)
    );

    // DUT Instantiation
    apb_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .PCLK(apb_bus.PCLK),
        .PRESETn(apb_bus.PRESETn),
        .PSEL(apb_bus.PSEL),
        .PENABLE(apb_bus.PENABLE),
        .PWRITE(apb_bus.PWRITE),
        .PADDR(apb_bus.PADDR),
        .PWDATA(apb_bus.PWDATA),
        .PRDATA(apb_bus.PRDATA),
        .PREADY(apb_bus.PREADY),
        .PSLVERR(apb_bus.PSLVERR)
    );

    // APB Protocol SVA Assertion Checker
    apb_sva #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_apb_sva (
        .PCLK(apb_bus.PCLK),
        .PRESETn(apb_bus.PRESETn),
        .PSEL(apb_bus.PSEL),
        .PENABLE(apb_bus.PENABLE),
        .PWRITE(apb_bus.PWRITE),
        .PADDR(apb_bus.PADDR),
        .PWDATA(apb_bus.PWDATA),
        .PRDATA(apb_bus.PRDATA),
        .PREADY(apb_bus.PREADY),
        .PSLVERR(apb_bus.PSLVERR)
    );

    // FIFO Micro-Architectural SVA Assertion Checker
    fifo_sva #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo_sva (
        .PCLK(dut.u_fifo_controller.fifo_inst.PCLK),
        .PRESETn(dut.u_fifo_controller.fifo_inst.PRESETn),
        .enable(dut.u_fifo_controller.fifo_inst.enable),
        .pop(dut.u_fifo_controller.fifo_inst.pop),
        .push(dut.u_fifo_controller.fifo_inst.push),
        .flush(dut.u_fifo_controller.fifo_inst.flush),
        .empty(dut.u_fifo_controller.fifo_inst.empty),
        .full(dut.u_fifo_controller.fifo_inst.full),
        .count(dut.u_fifo_controller.fifo_inst.count),
        .overflow(dut.u_fifo_controller.fifo_inst.overflow),
        .underflow(dut.u_fifo_controller.fifo_inst.underflow),
        .write_valid(dut.u_fifo_controller.fifo_inst.write_valid),
        .read_valid(dut.u_fifo_controller.fifo_inst.read_valid),
        .read_pointer(dut.u_fifo_controller.fifo_inst.read_pointer),
        .write_pointer(dut.u_fifo_controller.fifo_inst.write_pointer)
    );

    // Initial Reset Generation
    initial begin
        apb_bus.PRESETn = 1'b0;
        repeat (3) @(posedge PCLK);
        apb_bus.PRESETn = 1'b1;
    end

    // UVM Configuration & Test Execution Control
    initial begin
        // Register virtual interface in config_db for driver, monitor, and env
        uvm_config_db#(apb_vif_t)::set(null, "*", "vif", apb_bus);

        // Pass default FIFO depth to scoreboard and coverage collectors
        uvm_config_db#(int)::set(null, "*", "fifo_depth", FIFO_DEPTH);

        // Waveform dumping for debug (enabled with +define+DUMP_WAVES or simulator argument)
        `ifdef DUMP_WAVES
            $dumpfile("dump.vcd");
            $dumpvars(0, tb_top);
        `endif

        // Start UVM simulation phases (+UVM_TESTNAME=<test_name>)
        run_test();
    end
endmodule