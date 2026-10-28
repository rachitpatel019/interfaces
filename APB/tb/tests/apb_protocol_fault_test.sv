// ==============================================================================
// Hostile Master Protocol Fault Injection (Negative VIP) Test
// Location: interfaces/APB/tb/tests/apb_protocol_fault_test.sv
// ==============================================================================
`ifndef APB_PROTOCOL_FAULT_TEST_SV
`define APB_PROTOCOL_FAULT_TEST_SV

class apb_protocol_fault_test extends apb_base_test;
    `uvm_component_utils(apb_protocol_fault_test)

    function new(string name = "apb_protocol_fault_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_protocol_fault_seq seq;
        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting APB Hostile Master Protocol Fault Injection Test ===", UVM_NONE)
        seq = apb_protocol_fault_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
        `uvm_info(get_type_name(), "=== APB Hostile Master Protocol Fault Injection Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
