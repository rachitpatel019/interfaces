module apb_top #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
) (
    input logic PCLK,
    input logic PRESETn,

    input logic PSEL,
    input logic PENABLE,

    input logic PWRITE,
    input logic [ADDR_WIDTH-1:0] PADDR,
    input logic [DATA_WIDTH-1:0] PWDATA,

    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic PREADY,
    output logic PSLVERR
);

import apb_fsm_pkg::*;

localparam int FIFO_DEPTH = 16;

// Decoded APB state connecting apb_slave and fifo_controller
apb_fsm_state state;

// APB Protocol / FSM State Decoder
apb_slave u_apb_slave (
    .PCLK (PCLK),
    .PRESETn (PRESETn),
    .PSEL (PSEL),
    .PENABLE (PENABLE),
    .state (state)
);

// FIFO Register Controller
fifo_controller #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .FIFO_DEPTH (FIFO_DEPTH)
) u_fifo_controller (
    .PCLK (PCLK),
    .PRESETn (PRESETn),
    .state (state),
    .PWRITE (PWRITE),
    .PADDR (PADDR),
    .PWDATA (PWDATA),
    .PRDATA (PRDATA),
    .PREADY (PREADY),
    .PSLVERR (PSLVERR)
);

endmodule