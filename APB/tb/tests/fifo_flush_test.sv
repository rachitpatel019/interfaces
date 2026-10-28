`ifndef FIFO_FLUSH_TEST_SV
`define FIFO_FLUSH_TEST_SV

class fifo_flush_test extends apb_base_test;
    `uvm_component_utils(fifo_flush_test)

    function new(string name = "fifo_flush_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_flush_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting FIFO Flush Test ===", UVM_NONE)
        seq = fifo_flush_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== FIFO Flush Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
