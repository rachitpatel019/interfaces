`ifndef APB_ENV_SV
`define APB_ENV_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    // Component Handles
    apb_agent agent;
    apb_scoreboard sb;
    apb_coverage cov;

    // Configuration Knobs & Interface
    apb_vif_t vif;
    int fifo_depth = 16;
    bit has_scoreboard = 1'b1;
    bit has_coverage = 1'b1;

    // Constructor
    function new(string name = "apb_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve configuration overrides from test level if present
        void'(uvm_config_db#(int)::get(this, "", "fifo_depth", fifo_depth));
        void'(uvm_config_db#(bit)::get(this, "", "has_scoreboard", has_scoreboard));
        void'(uvm_config_db#(bit)::get(this, "", "has_coverage", has_coverage));

        // Retrieve and propagate virtual interface handle down to agent hierarchy
        if (uvm_config_db#(apb_vif_t)::get(this, "", "vif", vif)) begin
            uvm_config_db#(apb_vif_t)::set(this, "agent*", "vif", vif);
        end

        // Instantiate APB Master Agent
        agent = apb_agent::type_id::create("agent", this);

        // Conditionally configure and instantiate Scoreboard
        if (has_scoreboard) begin
            uvm_config_db#(int)::set(this, "sb", "fifo_depth", fifo_depth);
            sb = apb_scoreboard::type_id::create("sb", this);
        end

        // Conditionally configure and instantiate Functional Coverage Subscriber
        if (has_coverage) begin
            uvm_config_db#(int)::set(this, "cov", "fifo_depth", fifo_depth);
            cov = apb_coverage::type_id::create("cov", this);
        end

        `uvm_info(get_type_name(), $sformatf("Build phase complete [fifo_depth=%0d, has_sb=%0b, has_cov=%0b]",
                  fifo_depth, has_scoreboard, has_coverage), UVM_HIGH)
    endfunction

    // Connect Phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Route monitored APB transactions to Scoreboard
        if (has_scoreboard) begin
            agent.ap.connect(sb.item_collected_export);
            `uvm_info(get_type_name(), "Connected agent.ap -> sb.item_collected_export", UVM_HIGH)
        end

        // Route monitored APB transactions to Functional Coverage Subscriber
        if (has_coverage) begin
            agent.ap.connect(cov.analysis_export);
            `uvm_info(get_type_name(), "Connected agent.ap -> cov.analysis_export", UVM_HIGH)
        end
    endfunction

    // End of Elaboration Phase
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info(get_type_name(), "APB FIFO verification environment elaboration finalized.", UVM_MEDIUM)
    endfunction
endclass
`endif