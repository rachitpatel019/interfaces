`ifndef FIFO_OVERFLOW_SEQ_SV
`define FIFO_OVERFLOW_SEQ_SV

class fifo_overflow_seq extends apb_base_seq;
    `uvm_object_utils(fifo_overflow_seq)

    int depth = FIFO_DEPTH;

    function new(string name = "fifo_overflow_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;

        `uvm_info(get_type_name(), "Starting FIFO Overflow Sequence...", UVM_LOW)

        // 1. Enable FIFO
        enable_fifo();

        // 2. Fill FIFO to capacity
        for (int i = 0; i < depth; i++) begin
            write_reg(REG_DATA, 32'hB000_0000 + i);
        end

        // 3. Verify FULL status
        read_reg(REG_STATUS, rdata, pslverr);

        // 4. Attempt write to FULL FIFO (Overflow condition, expects PSLVERR)
        `uvm_info(get_type_name(), "Injecting overflow write attempt to FULL FIFO...", UVM_MEDIUM)
        write_reg(REG_DATA, 32'hDEAD_DEAD, apb_transaction::ERR_OVERFLOW);

        // 5. Read STATUS to verify OVERFLOW bit (bit 2) is asserted
        read_reg(REG_STATUS, rdata, pslverr);

        // 6. Clear overflow sticky flag via CONTROL register (bit 2)
        `uvm_info(get_type_name(), "Clearing overflow flag...", UVM_MEDIUM)
        clear_overflow();

        // 7. Verify OVERFLOW bit is now cleared
        read_reg(REG_STATUS, rdata, pslverr);

        // 8. Drain FIFO to verify data integrity
        for (int i = 0; i < depth; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end

        // 9. Verify EMPTY status
        read_reg(REG_STATUS, rdata, pslverr);

        `uvm_info(get_type_name(), "FIFO Overflow Sequence finished.", UVM_LOW)
    endtask
endclass

`endif
