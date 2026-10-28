`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    apb_vif_t vif;

    // Broadcast observed transactions to Scoreboard and Coverage
    uvm_analysis_port #(apb_transaction) ap;

    // Track verified hostile protocol violations
    int protocol_faults_observed;

    function new(string name = "apb_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);

        if (!uvm_config_db#(apb_vif_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON_NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    // Run Phase
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever begin
            // Wait for reset to be released
            if (!vif.PRESETn) begin
                `uvm_info(get_type_name(), "PRESETn active (low). Waiting for reset deassertion...", UVM_MEDIUM)
                wait(vif.PRESETn === 1'b1);
                @(vif.mon_cb);
                `uvm_info(get_type_name(), "PRESETn deasserted. Resuming monitor operation.", UVM_MEDIUM)
            end

            collect_transfer();
        end
    endtask

    // Collect and reconstruct a single completed APB transfer
    virtual task collect_transfer();
        apb_transaction tr;

        @(vif.mon_cb);

        // Abort sampling if reset was asserted during this cycle
        if (!vif.mon_cb.PRESETn) begin
            return;
        end

        // Protocol check: PENABLE must not be asserted without PSEL active
        if (vif.mon_cb.PENABLE === 1'b1 && vif.mon_cb.PSEL === 1'b0) begin
            if (vif.mon_cb.protocol_fault_active) begin
                protocol_faults_observed++;
                `uvm_info("MON_PROTO_FAULT_CAUGHT", "[NEGATIVE-VIP] Monitor verified intentional master protocol fault: PENABLE high with PSEL deasserted", UVM_MEDIUM)
            end else begin
                `uvm_error("MON_PROTO_ERR", "Protocol violation: PENABLE is asserted while PSEL is deasserted!")
            end
        end

        // An APB transfer completes when PSEL, PENABLE, and PREADY are all asserted high
        if (vif.mon_cb.PSEL === 1'b1 && vif.mon_cb.PENABLE === 1'b1 && vif.mon_cb.PREADY === 1'b1) begin
            tr = apb_transaction::type_id::create("tr");

            tr.op = (vif.mon_cb.PWRITE === 1'b1) ? apb_transaction::APB_WRITE : apb_transaction::APB_READ;
            tr.addr = vif.mon_cb.PADDR;
            tr.pslverr = vif.mon_cb.PSLVERR;

            if (tr.op == apb_transaction::APB_WRITE) begin
                tr.wdata = vif.mon_cb.PWDATA;
                tr.rdata = '0;
            end
            else begin
                tr.wdata = '0;
                tr.rdata = vif.mon_cb.PRDATA;
            end

            // Classify stateless error types if PSLVERR was asserted
            if (!tr.pslverr) begin
                tr.error_type = apb_transaction::NO_ERR;
            end
            else begin
                if (!(tr.addr inside {REG_DATA, REG_STATUS, REG_CONTROL, REG_FIFO_COUNT})) begin
                    tr.error_type = apb_transaction::ERR_INV_ADDR;
                end
                else if ((tr.addr inside {REG_STATUS, REG_FIFO_COUNT}) && (tr.op == apb_transaction::APB_WRITE)) begin
                    tr.error_type = apb_transaction::ERR_RO_WRITE;
                end
            end

            `uvm_info(get_type_name(), $sformatf("Monitored APB %s transfer: addr=0x%0h, wdata=0x%0h, rdata=0x%0h, pslverr=%0b",
                      tr.op.name(), tr.addr, tr.wdata, tr.rdata, tr.pslverr), UVM_HIGH)

            // Publish observed transaction to analysis port
            ap.write(tr);
        end
    endtask
endclass

`endif