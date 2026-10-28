`ifndef FIFO_UNDERFLOW_SEQ_SV
`define FIFO_UNDERFLOW_SEQ_SV

class fifo_underflow_seq extends apb_base_seq;
    `uvm_object_utils(fifo_underflow_seq)

    function new(string name = "fifo_underflow_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;

        `uvm_info(get_type_name(), "Starting FIFO Underflow Sequence...", UVM_LOW)

        // 1. Enable FIFO
        enable_fifo();

        // 1a. Write and pop a non-zero word so FIFO memory/read registers contain non-zero stale data
        write_reg(REG_DATA, 32'hA5A5_5A5A);
        read_reg(REG_DATA, rdata, pslverr); // FIFO is now EMPTY, but internal read latch holds 0xA5A55A5A

        // 2. Verify FIFO is EMPTY
        read_reg(REG_STATUS, rdata, pslverr);

        // 3. Attempt read on EMPTY FIFO (Underflow condition, MUST return 0x0 rdata, not stale data)
        `uvm_info(get_type_name(), "Injecting underflow read attempt on EMPTY FIFO (verifying zero-data return)...", UVM_MEDIUM)
        read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_UNDERFLOW);

        // 4. Verify UNDERFLOW flag (bit 3) is asserted in STATUS
        read_reg(REG_STATUS, rdata, pslverr);

        // 5. Clear underflow sticky flag via CONTROL register (bit 3)
        `uvm_info(get_type_name(), "Clearing underflow flag...", UVM_MEDIUM)
        clear_underflow();

        // 6. Verify UNDERFLOW flag is now cleared
        read_reg(REG_STATUS, rdata, pslverr);

        // 7. Push 1 normal word and read it back to ensure functional recovery
        write_reg(REG_DATA, 32'hC001_D00D);
        read_reg(REG_DATA, rdata, pslverr);

        `uvm_info(get_type_name(), "FIFO Underflow Sequence finished.", UVM_LOW)
    endtask
endclass

`endif
