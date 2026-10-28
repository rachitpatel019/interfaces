`ifndef FIFO_OVERFLOW_TEST_SV
`define FIFO_OVERFLOW_TEST_SV

class fifo_overflow_test extends apb_base_test;
    `uvm_component_utils(fifo_overflow_test)

    function new(string name = "fifo_overflow_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_overflow_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting FIFO Overflow Test ===", UVM_NONE)
        seq = fifo_overflow_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== FIFO Overflow Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
