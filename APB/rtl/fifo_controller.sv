module fifo_controller #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
) (
    input logic PCLK,
    input logic PRESETn,

    input apb_fsm_pkg::apb_fsm_state state,

    input logic PWRITE,
    input logic [ADDR_WIDTH-1:0] PADDR,
    input logic [DATA_WIDTH-1:0] PWDATA,

    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic PREADY,
    output logic PSLVERR
);

import apb_fsm_pkg::*;

// FIFO signals
logic fifo_enable;
logic fifo_read;
logic fifo_write;
logic fifo_flush;
logic fifo_clear_overflow;
logic fifo_clear_underflow;
logic [DATA_WIDTH-1:0] fifo_read_data;
logic fifo_empty;
logic fifo_full;
logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;
logic fifo_overflow;
logic fifo_underflow;
logic fifo_read_ready; // Used to align PREADY with 1-cycle FIFO read latency
logic fifo_read_error; // Used to capture FIFO read error in cycle 1 of ACCESS
logic fifo_write_error; // Used to capture FIFO write error in cycle 1 of ACCESS

always_comb begin
    // Defaults
    fifo_read = 1'b0;
    fifo_write = 1'b0;
    fifo_flush = 1'b0;
    fifo_clear_overflow = 1'b0;
    fifo_clear_underflow = 1'b0;
    PRDATA = '0;
    PREADY = 1'b0;
    PSLVERR = 1'b0;

    if (state == ACCESS) begin
        case (PADDR)
            // Data
            'h00: begin
                if (PWRITE) begin
                    fifo_write = 1'b1 && fifo_enable;
                    PREADY = 1'b1;
                    PSLVERR = fifo_write_error;
                end
                else begin
                    fifo_read = 1'b1 && fifo_enable && !fifo_read_ready;
                    PRDATA = fifo_read_error ? 'b0 : fifo_read_data;
                    PSLVERR = fifo_read_error;
                    PREADY = fifo_read_ready;
                end
            end
            
            // Status
            'h04: begin
                if (PWRITE) begin
                    PSLVERR = 1'b1;
                end
                else begin
                    PRDATA[4:0] = {
                        fifo_enable,
                        fifo_underflow,
                        fifo_overflow,
                        fifo_full,
                        fifo_empty
                    };
                end
                PREADY = 1'b1;
            end

            // Control
            'h08: begin
                if (PWRITE) begin
                    fifo_flush = PWDATA[1];
                    fifo_clear_overflow = PWDATA[2];
                    fifo_clear_underflow = PWDATA[3];
                end
                else begin
                    PRDATA = 'b0;
                    PRDATA[0] = fifo_enable;
                end
                PREADY = 1'b1;
            end

            // Count
            'h0C: begin
                if (PWRITE) begin
                    PSLVERR = 1'b1;
                end
                else begin
                    PRDATA = {{(DATA_WIDTH-$clog2(FIFO_DEPTH+1)){1'b0}}, fifo_count};
                end
                PREADY = 1'b1;
            end

            default: begin
                PREADY = 1'b1;
                PSLVERR = 1'b1;
                PRDATA = 'b0;
            end
        endcase
    end
end

// Enable signal is persistent
always_ff @(posedge PCLK) begin
    if (!PRESETn) begin
        fifo_enable <= 1'b0;
        fifo_read_error <= 1'b0;
        fifo_write_error <= 1'b0;
        fifo_read_ready <= 1'b0;
    end
    else begin
        if (state == ACCESS && PADDR == 'h08 && PWRITE) begin
            fifo_enable <= PWDATA[0];
        end

        if (state == ACCESS && PADDR == 'h00 && !PWRITE) begin
            if (PWRITE) begin
                fifo_write_error <= (fifo_full || !fifo_enable);
            end
            else begin
                fifo_read_error <= (fifo_empty || !fifo_enable);
                fifo_read_ready <= !fifo_read_ready;
            end
        end
        else begin
            fifo_read_error <= 1'b0;
            fifo_write_error <= 1'b0;
            fifo_read_ready <= 1'b0;
        end
    end
end

fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) fifo_inst (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .enable(fifo_enable),
    .pop(fifo_read),
    .push(fifo_write),
    .flush(fifo_flush),
    .write_data(PWDATA),
    .clear_overflow(fifo_clear_overflow),
    .clear_underflow(fifo_clear_underflow),
    .read_data(fifo_read_data),
    .empty(fifo_empty),
    .full(fifo_full),
    .count(fifo_count),
    .overflow(fifo_overflow),
    .underflow(fifo_underflow)
);
    
endmodule