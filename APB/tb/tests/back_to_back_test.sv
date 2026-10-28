`ifndef BACK_TO_BACK_TEST_SV
`define BACK_TO_BACK_TEST_SV

class back_to_back_test extends apb_base_test;
    `uvm_component_utils(back_to_back_test)

    function new(string name = "back_to_back_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_back_to_back_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting Back-to-Back Test ===", UVM_NONE)
        seq = fifo_back_to_back_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== Back-to-Back Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
