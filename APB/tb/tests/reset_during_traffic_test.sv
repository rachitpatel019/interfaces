// ==============================================================================
// Reset During Active Traffic Test Suite
// ==============================================================================
`ifndef RESET_DURING_TRAFFIC_TEST_SV
`define RESET_DURING_TRAFFIC_TEST_SV

class reset_during_traffic_test extends apb_base_test;
    `uvm_component_utils(reset_during_traffic_test)

    function new(string name = "reset_during_traffic_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        reset_during_traffic_seq seq;
        uvm_event ev_trigger, ev_done;

        super.run_phase(phase);
        phase.raise_objection(this);

        ev_trigger = uvm_event_pool::get_global_pool().get("trigger_reset");
        ev_done    = uvm_event_pool::get_global_pool().get("reset_done");

        // Background reset handler thread
        fork
            forever begin
                ev_trigger.wait_trigger();
                `uvm_info(get_type_name(), ">>> Asserting asynchronous/synchronous PRESETn low...", UVM_MEDIUM)
                vif.PRESETn = 1'b0;
                repeat (3) @(vif.drv_cb);
                vif.PRESETn = 1'b1;
                repeat (2) @(vif.drv_cb);
                `uvm_info(get_type_name(), ">>> PRESETn restored high. Re-synchronizing reference model...", UVM_MEDIUM)
                env.sb.reset_reference_model();
                env.cov.reset_coverage_state();
                ev_done.trigger();
            end
        join_none

        `uvm_info(get_type_name(), "=== Starting Reset During Traffic Test ===", UVM_NONE)
        seq = reset_during_traffic_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== Reset During Traffic Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
