// ==============================================================================
// Negative Stimulus and Robustness Test Suite
// ==============================================================================
`ifndef FIFO_NEGATIVE_TEST_SV
`define FIFO_NEGATIVE_TEST_SV

class fifo_negative_test extends apb_base_test;
    `uvm_component_utils(fifo_negative_test)

    function new(string name = "fifo_negative_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_negative_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting FIFO Negative & Robustness Test ===", UVM_NONE)
        seq = fifo_negative_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== FIFO Negative & Robustness Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
