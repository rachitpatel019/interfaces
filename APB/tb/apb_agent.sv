`ifndef APB_AGENT_SV
`define APB_AGENT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_vif_t vif;

    apb_sequencer sqr;
    apb_driver drv;
    apb_monitor mon;

    // Broadcast observed transactions to Scoreboard and Coverage
    uvm_analysis_port #(apb_transaction) ap;

    function new(string name = "apb_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase: instantiate monitor unconditionally, driver & sequencer if ACTIVE
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ap = new("ap", this);

        // Retrieve virtual interface from config db if available, and forward down to child components
        if (uvm_config_db#(apb_vif_t)::get(this, "", "vif", vif)) begin
            uvm_config_db#(apb_vif_t)::set(this, "*", "vif", vif);
        end

        mon = apb_monitor::type_id::create("mon", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv = apb_driver::type_id::create("drv", this);
            sqr = apb_sequencer::type_id::create("sqr", this);
        end
    endfunction

    // Connect Phase: wire TLM ports between internal subcomponents and external interfaces
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        mon.ap.connect(this.ap);

        // In ACTIVE mode, connect driver's sequence item pull port to sequencer's export
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass

`endif