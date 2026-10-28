module fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
) (
    input logic PCLK,
    input logic PRESETn,
    input logic enable,
    
    input logic pop,
    input logic push,
    input logic flush,
    input logic [DATA_WIDTH-1:0] write_data,

    input logic clear_overflow,
    input logic clear_underflow,

    output logic [DATA_WIDTH-1:0] read_data,

    output logic empty,
    output logic full,
    output logic [$clog2(FIFO_DEPTH+1)-1:0] count, // +1 becase the fifo can hold values 0-N, total N+1 values

    output logic overflow,
    output logic underflow
);

// pointer width handling (edge case of FIFO_DEPTH == 1)
localparam int PTR_WIDTH = (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1'b1;

// memory and pointers
logic [DATA_WIDTH-1:0] memory [0:FIFO_DEPTH-1];
logic [PTR_WIDTH-1:0] read_pointer;
logic [PTR_WIDTH-1:0] write_pointer;

logic write_valid;
logic read_valid;

// A write is valid if not full, or if full and an element is being popped simultaneously
assign write_valid = push && (!full || (pop && !empty));
// A read is valid if not empty
assign read_valid  = pop && !empty;

// read and write logic
always_ff @(posedge PCLK) begin
    // clear signals executed first so that new overflow/underflow signals take priority
    if (clear_overflow) begin
        overflow <= 1'b0;
    end
    if (clear_underflow) begin
        underflow <= 1'b0;
    end

    if (!PRESETn || flush) begin
        read_pointer <= 'b0;
        write_pointer <= 'b0;
        count <= 'b0;
        empty <= 1'b1;
        full <= 1'b0;
        read_data <= '0;

        if (!PRESETn) begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end
    end
    else if (enable) begin
        // Overflow flag: push attempted but FIFO cannot accept write
        if (push && !write_valid) begin
            overflow <= 1'b1;
        end

        // Underflow flag: pop attempted on empty FIFO
        if (pop && !read_valid) begin
            underflow <= 1'b1;
        end

        // Read pointer update and synchronous read
        if (read_valid) begin
            read_data <= memory[read_pointer];
            if (read_pointer >= FIFO_DEPTH - 1) begin
                read_pointer <= 'b0;
            end
            else begin
                read_pointer <= read_pointer + 1'b1;
            end
        end
        else if (pop) begin
            read_data <= '0;
        end

        // Write pointer and memory update
        if (write_valid) begin
            memory[write_pointer] <= write_data;

            if (write_pointer >= FIFO_DEPTH - 1) begin
                write_pointer <= 'b0;
            end
            else begin
                write_pointer <= write_pointer + 1'b1;
            end
        end

        // Count, empty, and full tracking
        case ({write_valid, read_valid})
            // Push only
            2'b10: begin
                count <= count + 1'b1;
                empty <= 1'b0;
                full  <= (count + 1'b1 == FIFO_DEPTH);
            end

            // Pop only
            2'b01: begin
                count <= count - 1'b1;
                empty <= (count == 1'b1);
                full  <= 1'b0;
            end
            
            // Simultaneous push and pop
            2'b11: begin
                count <= count;
            end

            // Neither
            default: begin
                count <= count;
            end
        endcase
    end
end

endmodule