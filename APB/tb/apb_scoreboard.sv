`ifndef APB_SCOREBOARD_SV
`define APB_SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    // TLM Analysis export to receive monitored transactions from apb_agent/apb_monitor
    uvm_analysis_imp #(apb_transaction, apb_scoreboard) item_collected_export;

    // Architectural Shadow Reference Model
    int fifo_depth = apb_pkg_tb::FIFO_DEPTH;
    parameter int DATA_WIDTH = apb_pkg_tb::DATA_WIDTH;

    local bit [DATA_WIDTH-1:0] shadow_fifo[$];
    local bit shadow_enable;
    local bit shadow_empty;
    local bit shadow_full;
    local bit shadow_overflow;
    local bit shadow_underflow;
    local int shadow_count;

    // Verification statistics & counters
    int total_trans;
    int write_trans;
    int read_trans;
    int data_matches;
    int data_mismatches;
    int status_matches;
    int status_mismatches;
    int count_matches;
    int count_mismatches;
    int ctrl_matches;
    int ctrl_mismatches;
    int pslverr_matches;
    int pslverr_mismatches;

    function new(string name = "apb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_collected_export = new("item_collected_export", this);

        // Allow testbench configuration of FIFO depth
        void'(uvm_config_db#(int)::get(this, "", "fifo_depth", fifo_depth));

        reset_reference_model();
    endfunction

    virtual function void reset_reference_model();
        shadow_fifo.delete();
        shadow_enable = 1'b0;
        shadow_empty = 1'b1;
        shadow_full = 1'b0;
        shadow_overflow = 1'b0;
        shadow_underflow = 1'b0;
        shadow_count = 0;

        total_trans = 0;
        write_trans = 0;
        read_trans = 0;
        data_matches = 0;
        data_mismatches = 0;
        status_matches = 0;
        status_mismatches = 0;
        count_matches = 0;
        count_mismatches = 0;
        ctrl_matches = 0;
        ctrl_mismatches = 0;
        pslverr_matches = 0;
        pslverr_mismatches = 0;
    endfunction

    // Called whenever monitor broadcasts a completed transfer
    virtual function void write(apb_transaction tr);
        total_trans++;

        if (tr.op == apb_transaction::APB_WRITE) begin
            write_trans++;
            process_write(tr);
        end
        else begin
            read_trans++;
            process_read(tr);
        end
    endfunction

    // Process and verify APB Write transfers
    virtual function void process_write(apb_transaction tr);
        bit expected_pslverr;

        case (tr.addr)
            // Check for errors: push while disabled or full
            REG_DATA: begin
                expected_pslverr = (!shadow_enable || shadow_full);
                check_pslverr(tr, expected_pslverr, "WRITE to REG_DATA");

                if (shadow_enable) begin
                    if (!shadow_full) begin
                        shadow_fifo.push_back(tr.wdata);
                        shadow_count++;
                        shadow_empty = (shadow_count == 0);
                        shadow_full  = (shadow_count == fifo_depth);
                        `uvm_info(get_type_name(), $sformatf("Pushed 0x%08h to shadow FIFO. Count=%0d, Full=%0b, Empty=%0b",
                                  tr.wdata, shadow_count, shadow_full, shadow_empty), UVM_HIGH)
                    end
                    else begin
                        shadow_overflow = 1'b1;
                        `uvm_info(get_type_name(), "Write attempted while FIFO is full. Shadow overflow flag set.", UVM_HIGH)
                    end
                end
                else begin
                    `uvm_info(get_type_name(), "Write attempted while FIFO is disabled. Dropped and error expected.", UVM_HIGH)
                end
            end

            // Check for errors: write to read-only register
            REG_STATUS: begin
                expected_pslverr = 1'b1;
                check_pslverr(tr, expected_pslverr, "WRITE to Read-Only REG_STATUS");
            end

            // No errors
            REG_CONTROL: begin
                expected_pslverr = 1'b0;
                check_pslverr(tr, expected_pslverr, "WRITE to REG_CONTROL");

                // Bit 0: FIFO Enable
                shadow_enable = tr.wdata[0];

                // Bit 1: Flush FIFO
                if (tr.wdata[1]) begin
                    shadow_fifo.delete();
                    shadow_count = 0;
                    shadow_empty = 1'b1;
                    shadow_full = 1'b0;
                    `uvm_info(get_type_name(), "Shadow FIFO flushed via REG_CONTROL[1]", UVM_HIGH)
                end

                // Bit 2: Clear Overflow sticky flag
                if (tr.wdata[2]) begin
                    shadow_overflow = 1'b0;
                    `uvm_info(get_type_name(), "Shadow overflow cleared via REG_CONTROL[2]", UVM_HIGH)
                end

                // Bit 3: Clear Underflow sticky flag
                if (tr.wdata[3]) begin
                    shadow_underflow = 1'b0;
                    `uvm_info(get_type_name(), "Shadow underflow cleared via REG_CONTROL[3]", UVM_HIGH)
                end
            end

            // Check for errors: write to read-only register
            REG_FIFO_COUNT: begin
                expected_pslverr = 1'b1;
                check_pslverr(tr, expected_pslverr, "WRITE to Read-Only REG_FIFO_COUNT");
            end
            // Check for errors: address not in register map
            default: begin
                expected_pslverr = 1'b1;
                check_pslverr(tr, expected_pslverr, $sformatf("WRITE to Unmapped Address 0x%0h", tr.addr));
            end
        endcase
    endfunction

    // Process and verify APB Read transfers
    virtual function void process_read(apb_transaction tr);
        bit expected_pslverr;

        case (tr.addr)
            // Check for errors: pop while disabled or empty, read data mismatch
            REG_DATA: begin
                expected_pslverr = (!shadow_enable || shadow_empty);
                check_pslverr(tr, expected_pslverr, "READ from REG_DATA");

                if (shadow_enable && !shadow_empty) begin
                    bit [DATA_WIDTH-1:0] expected_data;
                    expected_data = shadow_fifo.pop_front();
                    shadow_count--;
                    shadow_empty = (shadow_count == 0);
                    shadow_full = (shadow_count == fifo_depth);

                    if (tr.rdata === expected_data) begin
                        data_matches++;
                        `uvm_info(get_type_name(), $sformatf("DATA MATCH: Popped 0x%08h from REG_DATA. Remaining Count=%0d",
                                  tr.rdata, shadow_count), UVM_HIGH)
                    end
                    else begin
                        data_mismatches++;
                        `uvm_error("SB_DATA_MISMATCH", $sformatf("REG_DATA Read Mismatch: Expected=0x%08h, Monitored=0x%08h",
                                   expected_data, tr.rdata))
                    end
                end
                else if (shadow_enable && shadow_empty) begin
                    shadow_underflow = 1'b1;
                    if (tr.rdata !== '0) begin
                        data_mismatches++;
                        `uvm_error("SB_EMPTY_RDATA_ERR", $sformatf("Underflow Read: Expected PRDATA=0x0, Monitored=0x%08h", tr.rdata))
                    end
                end
                else begin
                    if (tr.rdata !== '0) begin
                        data_mismatches++;
                        `uvm_error("SB_DIS_RDATA_ERR", $sformatf("Disabled Read: Expected PRDATA=0x0, Monitored=0x%08h", tr.rdata))
                    end
                end
            end

            // Check for errors: read data mismatch
            REG_STATUS: begin
                bit [4:0] expected_status;
                expected_pslverr = 1'b0;
                check_pslverr(tr, expected_pslverr, "READ from REG_STATUS");

                expected_status = {
                    shadow_enable,
                    shadow_underflow,
                    shadow_overflow,
                    shadow_full,
                    shadow_empty
                };

                if (tr.rdata[4:0] === expected_status && tr.rdata[DATA_WIDTH-1:5] === '0) begin
                    status_matches++;
                    `uvm_info(get_type_name(), $sformatf("STATUS MATCH: 0x%02h (en=%0b, uf=%0b, of=%0b, full=%0b, empty=%0b)",
                              tr.rdata[4:0], shadow_enable, shadow_underflow, shadow_overflow, shadow_full, shadow_empty), UVM_HIGH)
                end
                else begin
                    status_mismatches++;
                    `uvm_error("SB_STATUS_MISMATCH", $sformatf("REG_STATUS Mismatch: Expected=0x%02h (bits [4:0]={en=%0b, uf=%0b, of=%0b, full=%0b, empty=%0b}), Monitored=0x%08h",
                               expected_status, shadow_enable, shadow_underflow, shadow_overflow, shadow_full, shadow_empty, tr.rdata))
                end
            end

            // Check for errors: read data mismatch
            REG_CONTROL: begin
                expected_pslverr = 1'b0;
                check_pslverr(tr, expected_pslverr, "READ from REG_CONTROL");

                if (tr.rdata[0] === shadow_enable && tr.rdata[DATA_WIDTH-1:1] === '0) begin
                    ctrl_matches++;
                    `uvm_info(get_type_name(), $sformatf("CONTROL MATCH: Enable=%0b", shadow_enable), UVM_HIGH)
                end
                else begin
                    ctrl_mismatches++;
                    `uvm_error("SB_CTRL_MISMATCH", $sformatf("REG_CONTROL Read Mismatch: Expected=0x%08h, Monitored=0x%08h",
                               {{(DATA_WIDTH-1){1'b0}}, shadow_enable}, tr.rdata))
                end
            end

            // Check for errors: read data mismatch
            REG_FIFO_COUNT: begin
                expected_pslverr = 1'b0;
                check_pslverr(tr, expected_pslverr, "READ from REG_FIFO_COUNT");

                if (tr.rdata === shadow_count) begin
                    count_matches++;
                    `uvm_info(get_type_name(), $sformatf("COUNT MATCH: Expected=%0d, Monitored=%0d", shadow_count, tr.rdata), UVM_HIGH)
                end
                else begin
                    count_mismatches++;
                    `uvm_error("SB_COUNT_MISMATCH", $sformatf("REG_FIFO_COUNT Mismatch: Expected=%0d, Monitored=%0d",
                               shadow_count, tr.rdata))
                end
            end
            
            // Check for errors: address not in register map
            default: begin
                expected_pslverr = 1'b1;
                check_pslverr(tr, expected_pslverr, $sformatf("READ from Unmapped Address 0x%0h", tr.addr));
                if (tr.rdata !== '0) begin
                    `uvm_error("SB_INV_ADDR_RDATA", $sformatf("Unmapped read returned non-zero PRDATA=0x%08h", tr.rdata))
                end
            end
        endcase
    endfunction

    // Check monitored PSLVERR against predicted expectation
    virtual function void check_pslverr(apb_transaction tr, bit expected_pslverr, string desc);
        if (tr.pslverr === expected_pslverr) begin
            pslverr_matches++;
            `uvm_info(get_type_name(), $sformatf("PSLVERR MATCH on %s: pslverr=%0b (as expected)", desc, tr.pslverr), UVM_HIGH)
        end
        else begin
            pslverr_mismatches++;
            `uvm_error("SB_PSLVERR_MISMATCH", $sformatf("PSLVERR Mismatch on %s: Expected=%0b, Monitored=%0b (Addr=0x%0h, Op=%s)",
                       desc, expected_pslverr, tr.pslverr, tr.addr, tr.op.name()))
        end
    endfunction

    // Check phase: verify reference model has no unconsumed residue if applicable
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (shadow_fifo.size() > 0) begin
            `uvm_warning("SB_RESIDUAL_DATA", $sformatf("Simulation ended with %0d unread item(s) remaining in shadow FIFO!", shadow_fifo.size()))
        end
    endfunction

    // Report phase: display formatted summary table of scoreboard results
    virtual function void report_phase(uvm_phase phase);
        int total_errors;
        super.report_phase(phase);

        total_errors = data_mismatches + status_mismatches + count_mismatches + ctrl_mismatches + pslverr_mismatches;

        `uvm_info(get_type_name(), "==================================================", UVM_NONE)
        `uvm_info(get_type_name(), "             APB FIFO SCOREBOARD REPORT            ", UVM_NONE)
        `uvm_info(get_type_name(), "==================================================", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Total Transfers Observed  : %0d", total_trans), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("   - Write Transfers       : %0d", write_trans), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("   - Read Transfers        : %0d", read_trans), UVM_NONE)
        `uvm_info(get_type_name(), "--------------------------------------------------", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Data Matches / Mismatches  : %0d / %0d", data_matches, data_mismatches), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Status Matches / Mismatches: %0d / %0d", status_matches, status_mismatches), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Count Matches / Mismatches : %0d / %0d", count_matches, count_mismatches), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Ctrl Matches / Mismatches  : %0d / %0d", ctrl_matches, ctrl_mismatches), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" PSLVERR Matches / Mismatches: %0d / %0d", pslverr_matches, pslverr_mismatches), UVM_NONE)
        `uvm_info(get_type_name(), "--------------------------------------------------", UVM_NONE)
        if (total_errors == 0) begin
            `uvm_info(get_type_name(), " [TEST STATUS] SCOREBOARD PASSED (0 MISMATCHES)   ", UVM_NONE)
        end
        else begin
            `uvm_error(get_type_name(), $sformatf(" [TEST STATUS] SCOREBOARD FAILED (%0d MISMATCHES) ", total_errors))
        end
        `uvm_info(get_type_name(), "==================================================", UVM_NONE)
    endfunction
endclass

`endif