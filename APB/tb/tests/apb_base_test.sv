`ifndef APB_BASE_TEST_SV
`define APB_BASE_TEST_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    apb_env env;
    apb_vif_t vif;

    function new(string name = "apb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Retrieve virtual interface from config db
        if (!uvm_config_db#(apb_vif_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", {"Virtual interface vif must be set for: ", get_full_name()})
        end

        // Pass interface and default parameters to env
        uvm_config_db#(apb_vif_t)::set(this, "env*", "vif", vif);
        uvm_config_db#(int)::set(this, "env*", "fifo_depth", FIFO_DEPTH);

        // Instantiate test environment
        env = apb_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        // Print topology
        uvm_top.print_topology();
        // Set simulation timeout
        uvm_top.set_timeout(1000ms, 0);
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info(get_type_name(), "Starting base test run phase...", UVM_MEDIUM)
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        super.report_phase(phase);
        svr = uvm_report_server::get_server();

        `uvm_info(get_type_name(), "--------------------------------------------------", UVM_NONE)
        if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0) begin
            `uvm_info(get_type_name(), $sformatf(" *** TEST %s PASSED ***", get_type_name()), UVM_NONE)
        end
        else begin
            `uvm_error(get_type_name(), $sformatf(" *** TEST %s FAILED (%0d errors) ***",
                       get_type_name(), svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR)))
        end
        `uvm_info(get_type_name(), "--------------------------------------------------", UVM_NONE)
    endfunction

endclass

`endif
