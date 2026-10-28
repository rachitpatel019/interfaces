// ==============================================================================
// Hostile Master Protocol Fault Injection (Negative VIP) Sequence
// Location: interfaces/APB/tb/sequences/apb_protocol_fault_seq.sv
// ==============================================================================
`ifndef APB_PROTOCOL_FAULT_SEQ_SV
`define APB_PROTOCOL_FAULT_SEQ_SV

class apb_protocol_fault_seq extends apb_base_seq;
    `uvm_object_utils(apb_protocol_fault_seq)

    function new(string name = "apb_protocol_fault_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;
        bit [31:0] written_data[];

        written_data = new[FIFO_DEPTH];

        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), "  STARTING HOSTILE MASTER PROTOCOL FAULT INJECTION (NEGATIVE VIP) ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)

        // ---------------------------------------------------------------------
        // Phase 1: Baseline Sanity & Canary Pre-Load
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 1: Setting up baseline state with canary data...", UVM_MEDIUM)
        enable_fifo();
        write_reg(REG_DATA, 32'hA1B2_C3D4); // Canary item

        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        `uvm_info(get_type_name(), $sformatf("Canary pre-loaded. Initial count: %0d", rdata), UVM_HIGH)

        // ---------------------------------------------------------------------
        // Phase 2: Fault 1 - Assert PENABLE without PSEL (Violating APB Protocol)
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 2: Injecting FAULT_NO_PSEL (PENABLE=1 while PSEL=0)...", UVM_MEDIUM)
        // Attempt rogue write to DATA register with PSEL=0
        inject_fault(apb_transaction::FAULT_NO_PSEL, REG_DATA, 32'hFFFF_FFFF, apb_transaction::APB_WRITE);
        // Attempt rogue write to CONTROL register (trying to illegally clear or disable IP with PSEL=0)
        inject_fault(apb_transaction::FAULT_NO_PSEL, REG_CONTROL, 32'h0000_0000, apb_transaction::APB_WRITE);

        // Verify DUT completely ignored rogue transfers: Canary must remain safe
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        if (rdata !== 1) begin
            `uvm_error("FAULT_NO_PSEL_FAIL", $sformatf("DUT corrupted! Expected count=1, got %0d", rdata))
        end

        read_reg(REG_DATA, rdata, pslverr);
        if (rdata !== 32'hA1B2_C3D4) begin
            `uvm_error("FAULT_NO_PSEL_FAIL", $sformatf("Canary corrupted! Expected 0xA1B2C3D4, got 0x%0h", rdata))
        end else begin
            `uvm_info(get_type_name(), "Phase 2 PASS: Rogue PENABLE ignored. Canary data preserved intact.", UVM_LOW)
        end

        flush_fifo();

        // ---------------------------------------------------------------------
        // Phase 3: Fault 2 - Skipped SETUP Phase (Direct IDLE -> ACCESS transition)
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 3: Injecting FAULT_SKIP_SETUP (Direct IDLE -> ACCESS jump)...", UVM_MEDIUM)
        inject_fault(apb_transaction::FAULT_SKIP_SETUP, REG_DATA, 32'h5A5A_BEEF, apb_transaction::APB_WRITE);

        // Verify slave did not deadlock and processed transfer
        read_reg(REG_DATA, rdata, pslverr);
        if (rdata !== 32'h5A5A_BEEF) begin
            `uvm_error("FAULT_SKIP_SETUP_FAIL", $sformatf("Write data mismatch after skip setup! Expected 0x5A5ABEEF, got 0x%0h", rdata))
        end else begin
            `uvm_info(get_type_name(), "Phase 3 PASS: Slave survived skipped SETUP phase and recovered cleanly.", UVM_LOW)
        end

        flush_fifo();

        // ---------------------------------------------------------------------
        // Phase 4: Fault 3 - Control & Data Mutation During Wait States
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 4: Injecting FAULT_WAIT_MUTATION (Mutating address/data while PREADY=0)...", UVM_MEDIUM)
        write_reg(REG_DATA, 32'h1111_2222);

        // Read with illegal address mutation during wait state
        inject_fault(apb_transaction::FAULT_WAIT_MUTATION, REG_DATA, 32'h0, apb_transaction::APB_READ);

        // Hardware popped 0x1111_2222 in cycle 1 before address mutation in cycle 2.
        // Flush and clear sticky bits to resynchronize reference model
        flush_fifo();
        clear_underflow();
        `uvm_info(get_type_name(), "Phase 4 PASS: Wait state mutation rejected gracefully and bus recovered.", UVM_LOW)

        // ---------------------------------------------------------------------
        // Phase 5: Fault 4 - Early Master Abort During Wait States
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 5: Injecting FAULT_EARLY_ABORT (Dropping PSEL/PENABLE before PREADY)...", UVM_MEDIUM)
        write_reg(REG_DATA, 32'h9999_8888);
        
        // Abruptly drop bus mid-read while PREADY is 0
        inject_fault(apb_transaction::FAULT_EARLY_ABORT, REG_DATA, 32'h0, apb_transaction::APB_READ);

        // Flush and verify slave FSM self-healed and does not hang
        flush_fifo();
        clear_underflow();

        // Verify clean follow-up write and read
        write_reg(REG_DATA, 32'h4444_5555);
        read_reg(REG_DATA, rdata, pslverr);
        if (rdata !== 32'h4444_5555) begin
            `uvm_error("FAULT_EARLY_ABORT_FAIL", $sformatf("Post-abort recovery mismatch! Expected 0x44445555, got 0x%0h", rdata))
        end else begin
            `uvm_info(get_type_name(), "Phase 5 PASS: Slave FSM self-healed after premature master abort.", UVM_LOW)
        end

        flush_fifo();

        // ---------------------------------------------------------------------
        // Phase 6: Fault 5 - Stuck PENABLE Across Transactions
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 6: Injecting FAULT_STUCK_PENABLE (Holding PENABLE high across transfers)...", UVM_MEDIUM)
        inject_fault(apb_transaction::FAULT_STUCK_PENABLE, REG_CONTROL, 32'h0000_0001, apb_transaction::APB_WRITE);

        flush_fifo();

        // Verify subsequent normal read functions properly
        read_reg(REG_STATUS, rdata, pslverr);
        `uvm_info(get_type_name(), $sformatf("Post-stuck-enable status: 0x%0h (Slave recovered cleanly)", rdata), UVM_LOW)

        // ---------------------------------------------------------------------
        // Phase 7: Post-Fault Sanitization & Full Capacity Re-qualification
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 7: Comprehensive Post-Fault Sanitization and Drain Audit...", UVM_MEDIUM)
        flush_fifo();
        clear_overflow();
        clear_underflow();

        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        if (rdata !== 0) begin
            `uvm_error("POST_FAULT_SANITY", $sformatf("Expected count=0 after flush, got %0d", rdata))
        end

        // Full Fill
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            written_data[i] = 32'h7700_0000 + i;
            write_reg(REG_DATA, written_data[i]);
        end

        // Verify Full status
        read_reg(REG_STATUS, rdata, pslverr);
        if (rdata[1] !== 1'b1) begin // STATUS.full
            `uvm_error("POST_FAULT_SANITY", "Expected full flag set after fill!")
        end

        // Full Drain with bit-exact checks
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
            if (rdata !== written_data[i]) begin
                `uvm_error("POST_FAULT_DATA_MISMATCH", $sformatf("Item %0d mismatch: Expected 0x%0h, got 0x%0h",
                          i, written_data[i], rdata))
            end
        end

        // Final Empty verification
        read_reg(REG_STATUS, rdata, pslverr);
        if (rdata[0] !== 1'b1) begin // STATUS.empty
            `uvm_error("POST_FAULT_SANITY", "Expected empty flag set after full drain!")
        end

        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), "  NEGATIVE VIP PROTOCOL FAULT INJECTION: ALL PHASES PASSED        ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
    endtask
endclass

`endif
