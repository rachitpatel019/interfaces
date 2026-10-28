`ifndef APB_RANDOM_TEST_SV
`define APB_RANDOM_TEST_SV

class apb_random_test extends apb_base_test;
    `uvm_component_utils(apb_random_test)

    function new(string name = "apb_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fifo_random_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting APB Random & Coverage Closure Test ===", UVM_NONE)
        seq = fifo_random_seq::type_id::create("seq");
`ifndef MODELSIM_ASE
        if (!seq.randomize() with {
            num_random_trans inside {[250:350]};
        }) begin
            `uvm_fatal("RND_FAIL", "Failed to randomize seq trans count")
        end
`else
        seq.num_random_trans = 300;
`endif
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== APB Random & Coverage Closure Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
