module apb_slave #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
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

// APB state decoding
apb_fsm_state apb_current_state;

always_comb begin
    if (!PRESETn || !PSEL) begin
        apb_current_state = IDLE;
    end
    else if (!PENABLE) begin
        apb_current_state = SETUP;
    end
    else begin
        apb_current_state = ACCESS;
    end
end

// Controller for the FIFO interface
fifo_controller #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) fr (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .state(apb_current_state),
    .PWRITE(PWRITE),
    .PADDR(PADDR),
    .PWDATA(PWDATA),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR)
);

endmodule