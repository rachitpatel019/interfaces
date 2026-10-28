`ifndef FIFO_FILL_DRAIN_TEST_SV
`define FIFO_FILL_DRAIN_TEST_SV

class fifo_fill_drain_test extends apb_base_test;
    `uvm_component_utils(fifo_fill_drain_test)

    function new(string name = "fifo_fill_drain_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_fill_drain_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting FIFO Fill & Drain Test ===", UVM_NONE)
        seq = fifo_fill_drain_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== FIFO Fill & Drain Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
