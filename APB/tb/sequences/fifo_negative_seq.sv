// ==============================================================================
// Negative Stimulus and Error Boundary Attack Sequence
// ==============================================================================
`ifndef FIFO_NEGATIVE_SEQ_SV
`define FIFO_NEGATIVE_SEQ_SV

class fifo_negative_seq extends apb_base_seq;
    `uvm_object_utils(fifo_negative_seq)

    function new(string name = "fifo_negative_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;
        bit [31:0] written_data[];

        written_data = new[FIFO_DEPTH];

        `uvm_info(get_type_name(), "=== Starting Negative and Corner Attack Sequence ===", UVM_LOW)

        // -------------------------------------------------------------
        // Attack 1: Unmapped Address Reads & Writes
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Attack 1: Accessing unmapped addresses [0x20, 0x40, 0xFC]...", UVM_MEDIUM)
        write_reg(8'h20, 32'hDEAD_1111, apb_transaction::ERR_INV_ADDR);
        read_reg(8'h20, rdata, pslverr, apb_transaction::ERR_INV_ADDR);

        write_reg(8'h40, 32'hDEAD_2222, apb_transaction::ERR_INV_ADDR);
        read_reg(8'h40, rdata, pslverr, apb_transaction::ERR_INV_ADDR);

        write_reg(8'hFC, 32'hDEAD_3333, apb_transaction::ERR_INV_ADDR);
        read_reg(8'hFC, rdata, pslverr, apb_transaction::ERR_INV_ADDR);

        // Unaligned address attacks (exercising PADDR[0] and PADDR[1])
        write_reg(8'h01, 32'h1111_1111, apb_transaction::ERR_INV_ADDR);
        write_reg(8'h02, 32'h2222_2222, apb_transaction::ERR_INV_ADDR);
        write_reg(8'h03, 32'h3333_3333, apb_transaction::ERR_INV_ADDR);
        read_reg(8'h0F, rdata, pslverr, apb_transaction::ERR_INV_ADDR);

        // -------------------------------------------------------------
        // Attack 2: Write to Read-Only Registers (STATUS and FIFO_COUNT)
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Attack 2: Attempting writes to read-only registers...", UVM_MEDIUM)
        write_reg(REG_STATUS, 32'hFFFF_FFFF, apb_transaction::ERR_RO_WRITE);
        write_reg(REG_FIFO_COUNT, 32'h1234_5678, apb_transaction::ERR_RO_WRITE);

        // Verify registers remained uncorrupted
        read_reg(REG_STATUS, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // -------------------------------------------------------------
        // Attack 3: Operations While Peripheral is Disabled
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Attack 3: Operations on disabled FIFO...", UVM_MEDIUM)
        disable_fifo(); // REG_CONTROL = 0
        read_reg(REG_STATUS, rdata, pslverr); // Verify enable == 0

        write_reg(REG_DATA, 32'hBADC_0DE0, apb_transaction::ERR_DISABLED);
        read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_DISABLED);

        // Verify count remains 0
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // -------------------------------------------------------------
        // Attack 4: Multi-Burst Overflow Saturation (10 writes to full FIFO)
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Attack 4: Sustained overflow attack (10 writes to FULL FIFO)...", UVM_MEDIUM)
        enable_fifo();
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            written_data[i] = 32'hD000_0000 + i;
            write_reg(REG_DATA, written_data[i]);
        end

        // 10 consecutive overflow attempts
        for (int i = 0; i < 10; i++) begin
            write_reg(REG_DATA, 32'hDEAD_0000 + i, apb_transaction::ERR_OVERFLOW);
        end

        // Verify overflow flag is sticky
        read_reg(REG_STATUS, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr); // Must still be exactly 16

        // Clear overflow flag
        clear_overflow();
        read_reg(REG_STATUS, rdata, pslverr); // Must be cleared

        // Verify all 16 items pop intact in perfect FIFO order
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end
        read_reg(REG_STATUS, rdata, pslverr); // Must be empty

        // -------------------------------------------------------------
        // Attack 5: Multi-Burst Underflow Saturation (5 reads from empty FIFO)
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Attack 5: Sustained underflow attack (5 reads from EMPTY FIFO)...", UVM_MEDIUM)
        for (int i = 0; i < 5; i++) begin
            read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_UNDERFLOW);
        end

        // Verify underflow flag is sticky
        read_reg(REG_STATUS, rdata, pslverr);
        clear_underflow();
        read_reg(REG_STATUS, rdata, pslverr);

        // -------------------------------------------------------------
        // Attack 6: Sanity Post-Attack Data Verification
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Attack 6: Post-attack sanity push/pop...", UVM_MEDIUM)
        write_reg(REG_DATA, 32'h55AA_55AA);
        read_reg(REG_DATA, rdata, pslverr);

        `uvm_info(get_type_name(), "=== Negative Attack Sequence Completed Successfully ===", UVM_LOW)
    endtask
endclass

`endif
