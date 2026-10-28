// ==============================================================================
// Hostile & Illegal Protocol Stress Test
// Location: interfaces/APB/tb/tests/apb_hostile_stress_test.sv
// ==============================================================================
`ifndef APB_HOSTILE_STRESS_TEST_SV
`define APB_HOSTILE_STRESS_TEST_SV

class apb_hostile_stress_test extends apb_base_test;
    `uvm_component_utils(apb_hostile_stress_test)

    function new(string name = "apb_hostile_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_hostile_stress_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting APB Hostile & Illegal Protocol Stress Test ===", UVM_NONE)
        seq = apb_hostile_stress_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== APB Hostile & Illegal Protocol Stress Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
