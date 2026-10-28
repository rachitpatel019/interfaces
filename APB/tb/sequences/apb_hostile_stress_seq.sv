// ==============================================================================
// Hostile & Illegal Protocol Stress Sequence
// Location: interfaces/APB/tb/sequences/apb_hostile_stress_seq.sv
// ==============================================================================
`ifndef APB_HOSTILE_STRESS_SEQ_SV
`define APB_HOSTILE_STRESS_SEQ_SV

class apb_hostile_stress_seq extends apb_base_seq;
    `uvm_object_utils(apb_hostile_stress_seq)

    function new(string name = "apb_hostile_stress_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;
        bit [31:0] written_data[];
        bit [7:0] fuzzed_addresses[];

        written_data = new[FIFO_DEPTH];
        fuzzed_addresses = '{
            8'h01, 8'h02, 8'h03, 8'h05, 8'h06, 8'h07, 8'h09, 8'h0A, 8'h0E, 8'h0F,
            8'h10, 8'h14, 8'h18, 8'h1C, 8'h20, 8'h30, 8'h44, 8'h80, 8'hA0, 8'hFC
        };

        `uvm_info(get_type_name(), "==================================================", UVM_LOW)
        `uvm_info(get_type_name(), " STARTING HOSTILE & ILLEGAL PROTOCOL STRESS TEST ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================", UVM_LOW)

        // ---------------------------------------------------------------------
        // Phase 1: Hostile Address Fuzzing (20 Unmapped & Unaligned Addresses)
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 1: Fuzzing unmapped and byte-unaligned address space...", UVM_MEDIUM)
        enable_fifo();

        foreach (fuzzed_addresses[i]) begin
            bit [7:0] addr = fuzzed_addresses[i];
            // Adversarial Write to invalid address
            write_reg(addr, 32'hDEAD_0000 | addr, apb_transaction::ERR_INV_ADDR);
            // Adversarial Read from invalid address
            read_reg(addr, rdata, pslverr, apb_transaction::ERR_INV_ADDR);
        end

        // Verify FIFO remains pristine and empty
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        // ---------------------------------------------------------------------
        // Phase 2: Hostile Peripheral Disable & Memory Isolation Attack
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 2: Priming read latch, disabling IP, and verifying zero-leakage...", UVM_MEDIUM)
        
        // Prime internal read latch with non-zero canary pattern
        write_reg(REG_DATA, 32'hCAFE_BABE);
        read_reg(REG_DATA, rdata, pslverr); // Read latch in fifo.sv now retains 0xCAFEBABE

        for (int i = 0; i < FIFO_DEPTH / 2; i++) begin
            written_data[i] = 32'hCAFE_0000 + i;
            write_reg(REG_DATA, written_data[i]);
        end

        // Disable IP
        disable_fifo();

        // Hostile write attempts to disabled FIFO
        for (int i = 0; i < 6; i++) begin
            write_reg(REG_DATA, 32'hBAD0_0000 + i, apb_transaction::ERR_DISABLED);
        end

        // Hostile read attempts from disabled FIFO
        for (int i = 0; i < 6; i++) begin
            read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_DISABLED);
        end

        // Hostile writes to read-only registers while disabled
        write_reg(REG_STATUS, 32'hFFFF_FFFF, apb_transaction::ERR_RO_WRITE);
        write_reg(REG_FIFO_COUNT, 32'h1234_5678, apb_transaction::ERR_RO_WRITE);

        // Re-enable IP and verify data integrity of previously stored items
        enable_fifo();
        for (int i = 0; i < FIFO_DEPTH / 2; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end
        read_reg(REG_STATUS, rdata, pslverr); // Must be empty

        // ---------------------------------------------------------------------
        // Phase 3: Simultaneous Error Flag Clear and Flush Race
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 3: Triggering simultaneous flag clears and dynamic soft flush...", UVM_MEDIUM)
        
        // Induce Underflow
        read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_UNDERFLOW);
        read_reg(REG_STATUS, rdata, pslverr); // Verify underflow asserted

        // Fill to capacity and induce Overflow
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            write_reg(REG_DATA, 32'hF1F0_0000 + i);
        end
        write_reg(REG_DATA, 32'hDEAD_0F10, apb_transaction::ERR_OVERFLOW);
        read_reg(REG_STATUS, rdata, pslverr); // Both underflow and overflow flags set!

        // Issue simultaneous flush + clear_overflow + clear_underflow (CONTROL = 4'b1111)
        write_reg(REG_CONTROL, 32'h0000_000F); // en=1, flush=1, clr_of=1, clr_uf=1

        // Verify status: must be empty=1, full=0, of=0, uf=0, count=0
        read_reg(REG_STATUS, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // ---------------------------------------------------------------------
        // Phase 4: Extreme Back-to-Back Saturation Hammering
        // ---------------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 4: Multi-burst sustained saturation attacks...", UVM_MEDIUM)
        
        // Fill completely
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            written_data[i] = 32'hBEEF_0000 + i;
            write_reg(REG_DATA, written_data[i]);
        end

        // Hammer 15 consecutive overflow writes
        for (int i = 0; i < 15; i++) begin
            write_reg(REG_DATA, 32'hDEAD_1000 + i, apb_transaction::ERR_OVERFLOW);
        end

        // Drain 1 item
        read_reg(REG_DATA, rdata, pslverr);

        // Immediately push 1 item to re-saturate
        write_reg(REG_DATA, 32'hBEEF_FFFF);

        // Hammer another 5 overflow writes
        for (int i = 0; i < 5; i++) begin
            write_reg(REG_DATA, 32'hDEAD_2000 + i, apb_transaction::ERR_OVERFLOW);
        end

        // Drain entire FIFO to 0
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end

        // Hammer 15 consecutive underflow reads
        for (int i = 0; i < 15; i++) begin
            read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_UNDERFLOW);
        end

        // Clean up flags
        clear_overflow();
        clear_underflow();
        read_reg(REG_STATUS, rdata, pslverr);

        `uvm_info(get_type_name(), "==================================================", UVM_LOW)
        `uvm_info(get_type_name(), " HOSTILE & ILLEGAL PROTOCOL STRESS TEST PASSED    ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================", UVM_LOW)
    endtask
endclass

`endif
