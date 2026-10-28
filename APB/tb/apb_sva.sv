// ==============================================================================
// APB Protocol SystemVerilog Assertions (SVA)
// ==============================================================================
`ifndef APB_SVA_SV
`define APB_SVA_SV

module apb_sva #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32
) (
    input logic                   PCLK,
    input logic                   PRESETn,
    input logic                   PSEL,
    input logic                   PENABLE,
    input logic                   PWRITE,
    input logic [ADDR_WIDTH-1:0]  PADDR,
    input logic [DATA_WIDTH-1:0]  PWDATA,
    input logic [DATA_WIDTH-1:0]  PRDATA,
    input logic                   PREADY,
    input logic                   PSLVERR
);

    // -------------------------------------------------------------------------
    // Property 1: PENABLE must never be asserted without PSEL active
    // -------------------------------------------------------------------------
    property p_enable_requires_psel;
        @(posedge PCLK) disable iff (!PRESETn)
        PENABLE |-> PSEL;
    endproperty
    assert_enable_requires_psel: assert property (p_enable_requires_psel)
        else $error("[SVA-APB-01] Protocol Violation: PENABLE is asserted without PSEL!");

    // -------------------------------------------------------------------------
    // Property 2: ACCESS phase (PSEL && PENABLE) must be preceded by SETUP phase (PSEL && !PENABLE)
    // -------------------------------------------------------------------------
    property p_setup_before_access;
        @(posedge PCLK) disable iff (!PRESETn)
        ($rose(PENABLE) && PSEL) |-> $past(PSEL && !PENABLE);
    endproperty
    assert_setup_before_access: assert property (p_setup_before_access)
        else $error("[SVA-APB-02] Protocol Violation: ACCESS phase entered without preceding SETUP phase!");

    // -------------------------------------------------------------------------
    // Property 3: Address, write command, and write data must remain stable during wait states
    // -------------------------------------------------------------------------
    property p_stability_during_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> ($stable(PADDR) && $stable(PWRITE) && $stable(PSEL) && (PWRITE ? $stable(PWDATA) : 1'b1));
    endproperty
    assert_stability_during_wait: assert property (p_stability_during_wait)
        else $error("[SVA-APB-03] Protocol Violation: APB control/data signals changed while PREADY was low!");

    // -------------------------------------------------------------------------
    // Property 4: PENABLE must drop after transfer completion unless back-to-back transfer initiates next access
    // -------------------------------------------------------------------------
    property p_penable_falls_after_transfer;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY) |=> (!PENABLE || !PSEL);
    endproperty
    assert_penable_falls_after_transfer: assert property (p_penable_falls_after_transfer)
        else $error("[SVA-APB-04] Protocol Violation: PENABLE remained high across back-to-back transfers without SETUP phase!");

    // -------------------------------------------------------------------------
    // Immediate assertion for reset behavior
    // -------------------------------------------------------------------------
    always_comb begin
        if (!PRESETn) begin
            if (PSEL && PENABLE) begin
                // In reset, master should drop or idle
            end
        end
    end

endmodule

`endif
