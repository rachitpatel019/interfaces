`timescale 1ns / 1ps

interface apb_if #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
)(
    input logic PCLK
);
    // APB Slave Signals
    logic PRESETn;
    logic PSEL;
    logic PENABLE;
    logic PWRITE;
    logic [ADDR_WIDTH-1:0] PADDR;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic PREADY;
    logic PSLVERR;

    // Negative VIP / Hostile Protocol Fault Injection Indicator
    logic protocol_fault_active;

    // Driver Clocking Block
    clocking drv_cb @(posedge PCLK);
        default input #1step output #0;
        input  PRDATA, PREADY, PSLVERR;
        output PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, protocol_fault_active;
    endclocking

    // Monitor Clocking Block
    clocking mon_cb @(posedge PCLK);
        default input #1step;
        input  PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY, PSLVERR, protocol_fault_active;
    endclocking
endinterface