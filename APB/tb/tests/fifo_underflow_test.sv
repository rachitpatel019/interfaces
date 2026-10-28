`ifndef FIFO_UNDERFLOW_TEST_SV
`define FIFO_UNDERFLOW_TEST_SV

class fifo_underflow_test extends apb_base_test;
    `uvm_component_utils(fifo_underflow_test)

    function new(string name = "fifo_underflow_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_underflow_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting FIFO Underflow Test ===", UVM_NONE)
        seq = fifo_underflow_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== FIFO Underflow Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
