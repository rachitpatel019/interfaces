// ==============================================================================
// FIFO Micro-Architectural SystemVerilog Assertions (SVA)
// ==============================================================================
`ifndef FIFO_SVA_SV
`define FIFO_SVA_SV

module fifo_sva #(
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
) (
    input logic                             PCLK,
    input logic                             PRESETn,
    input logic                             enable,
    input logic                             pop,
    input logic                             push,
    input logic                             flush,
    input logic                             empty,
    input logic                             full,
    input logic [$clog2(FIFO_DEPTH+1)-1:0]  count,
    input logic                             overflow,
    input logic                             underflow,
    input logic                             write_valid,
    input logic                             read_valid,
    input logic [(FIFO_DEPTH > 1 ? $clog2(FIFO_DEPTH) : 1)-1:0] read_pointer,
    input logic [(FIFO_DEPTH > 1 ? $clog2(FIFO_DEPTH) : 1)-1:0] write_pointer
);

    // -------------------------------------------------------------------------
    // Invariant 1: Count must never exceed FIFO capacity
    // -------------------------------------------------------------------------
    property p_count_within_bounds;
        @(posedge PCLK) disable iff (!PRESETn)
        count <= FIFO_DEPTH;
    endproperty
    assert_count_within_bounds: assert property (p_count_within_bounds)
        else $error("[SVA-FIFO-01] Count exceeds FIFO capacity! count=%0d, depth=%0d", count, FIFO_DEPTH);

    // -------------------------------------------------------------------------
    // Invariant 2: Empty flag must strictly reflect count == 0
    // -------------------------------------------------------------------------
    property p_empty_matches_count;
        @(posedge PCLK) disable iff (!PRESETn)
        empty == (count == 0);
    endproperty
    assert_empty_matches_count: assert property (p_empty_matches_count)
        else $error("[SVA-FIFO-02] Inconsistent EMPTY flag! empty=%0b, count=%0d", empty, count);

    // -------------------------------------------------------------------------
    // Invariant 3: Full flag must strictly reflect count == FIFO_DEPTH
    // -------------------------------------------------------------------------
    property p_full_matches_count;
        @(posedge PCLK) disable iff (!PRESETn)
        full == (count == FIFO_DEPTH);
    endproperty
    assert_full_matches_count: assert property (p_full_matches_count)
        else $error("[SVA-FIFO-03] Inconsistent FULL flag! full=%0b, count=%0d", full, count);

    // -------------------------------------------------------------------------
    // Invariant 4: No valid read permitted when empty
    // -------------------------------------------------------------------------
    property p_no_read_when_empty;
        @(posedge PCLK) disable iff (!PRESETn)
        empty |-> !read_valid;
    endproperty
    assert_no_read_when_empty: assert property (p_no_read_when_empty)
        else $error("[SVA-FIFO-04] Protocol Violation: read_valid asserted while FIFO is empty!");

    // -------------------------------------------------------------------------
    // Invariant 5: No valid write permitted when full (unless simultaneous pop)
    // -------------------------------------------------------------------------
    property p_no_write_when_full;
        @(posedge PCLK) disable iff (!PRESETn)
        (full && !pop) |-> !write_valid;
    endproperty
    assert_no_write_when_full: assert property (p_no_write_when_full)
        else $error("[SVA-FIFO-05] Protocol Violation: write_valid asserted while FIFO is full without simultaneous pop!");

    // -------------------------------------------------------------------------
    // Property 6: Flush operation resets occupancy to 0 on defined next cycle
    // -------------------------------------------------------------------------
    property p_flush_clears_fifo;
        @(posedge PCLK) disable iff (!PRESETn)
        (enable && flush) |=> (count == 0 && empty == 1'b1 && full == 1'b0);
    endproperty
    assert_flush_clears_fifo: assert property (p_flush_clears_fifo)
        else $error("[SVA-FIFO-06] Functional Error: FIFO not empty on cycle following flush!");

    // -------------------------------------------------------------------------
    // Invariant 7: Pointers must remain within valid array bounds
    // -------------------------------------------------------------------------
    property p_pointers_within_bounds;
        @(posedge PCLK) disable iff (!PRESETn)
        (read_pointer < FIFO_DEPTH) && (write_pointer < FIFO_DEPTH);
    endproperty
    assert_pointers_within_bounds: assert property (p_pointers_within_bounds)
        else $error("[SVA-FIFO-07] Pointer out of bounds! rd_ptr=%0d, wr_ptr=%0d, depth=%0d",
                    read_pointer, write_pointer, FIFO_DEPTH);

endmodule

`endif
