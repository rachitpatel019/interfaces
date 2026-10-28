`ifndef APB_BASIC_TEST_SV
`define APB_BASIC_TEST_SV

class apb_basic_test extends apb_base_test;
    `uvm_component_utils(apb_basic_test)

    function new(string name = "apb_basic_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_base_seq seq;
        bit [31:0] rdata;
        bit pslverr;

        super.run_phase(phase);
        phase.raise_objection(this);

        `uvm_info(get_type_name(), "=== Starting APB Basic Smoke Test ===", UVM_NONE)

        seq = apb_base_seq::type_id::create("seq");
        seq.start(env.agent.sqr);

        // 1. Enable FIFO
        `uvm_info(get_type_name(), "Step 1: Enabling FIFO...", UVM_MEDIUM)
        seq.enable_fifo();

        // 2. Read initial STATUS (should be EMPTY)
        `uvm_info(get_type_name(), "Step 2: Checking initial STATUS...", UVM_MEDIUM)
        seq.read_reg(REG_STATUS, rdata, pslverr);

        // 3. Write 1 data word
        `uvm_info(get_type_name(), "Step 3: Writing 1 word to DATA register...", UVM_MEDIUM)
        seq.write_reg(REG_DATA, 32'hA5A5_5A5A);

        // 4. Read FIFO count (should be 1)
        `uvm_info(get_type_name(), "Step 4: Checking FIFO count...", UVM_MEDIUM)
        seq.read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // 5. Read back data word
        `uvm_info(get_type_name(), "Step 5: Reading back data word from DATA register...", UVM_MEDIUM)
        seq.read_reg(REG_DATA, rdata, pslverr);

        // 6. Check final STATUS (should be EMPTY)
        `uvm_info(get_type_name(), "Step 6: Checking final STATUS...", UVM_MEDIUM)
        seq.read_reg(REG_STATUS, rdata, pslverr);

        `uvm_info(get_type_name(), "=== APB Basic Smoke Test Complete ===", UVM_NONE)

        phase.drop_objection(this);
    endtask
endclass

`endif
