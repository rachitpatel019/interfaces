module apb_slave (
    input  logic                     PCLK,
    input  logic                     PRESETn,

    input  logic                     PSEL,
    input  logic                     PENABLE,

    output apb_fsm_pkg::apb_fsm_state state
);

import apb_fsm_pkg::*;

// APB state decoding
always_comb begin
    if (!PRESETn || !PSEL) begin
        state = IDLE;
    end
    else if (!PENABLE) begin
        state = SETUP;
    end
    else begin
        state = ACCESS;
    end
end

endmodule