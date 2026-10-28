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

    // Driver Clocking Block
    clocking drv_cb @(posedge PCLK);
        default input #1step output #0;
        input  PRDATA, PREADY, PSLVERR;
        output PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA;
    endclocking

    // Monitor Clocking Block
    clocking mon_cb @(posedge PCLK);
        default input #1step;
        input  PRESETn, PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY, PSLVERR;
    endclocking
endinterface