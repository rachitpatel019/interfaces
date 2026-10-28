`ifndef FIFO_FLUSH_SEQ_SV
`define FIFO_FLUSH_SEQ_SV

class fifo_flush_seq extends apb_base_seq;
    `uvm_object_utils(fifo_flush_seq)

    function new(string name = "fifo_flush_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;
        int fill_count;

        `uvm_info(get_type_name(), "Starting FIFO Flush Sequence...", UVM_LOW)

        // 1. Enable FIFO
        enable_fifo();

        // 2. Partially fill FIFO (half capacity)
        fill_count = (FIFO_DEPTH > 2) ? (FIFO_DEPTH / 2) : 1;
        for (int i = 0; i < fill_count; i++) begin
            write_reg(REG_DATA, 32'hF000_0000 + i);
        end

        // 3. Verify count and partial status
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        // 4. Assert synchronous flush via REG_CONTROL[1]
        `uvm_info(get_type_name(), "Flushing FIFO via REG_CONTROL[1]...", UVM_MEDIUM)
        flush_fifo();

        // 5. Verify count is reset to 0 and EMPTY is asserted
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        // 6. Push a fresh item and pop it to verify normal operation after flush
        write_reg(REG_DATA, 32'hCAFE_BABE);
        read_reg(REG_DATA, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        `uvm_info(get_type_name(), "FIFO Flush Sequence finished.", UVM_LOW)
    endtask
endclass

`endif
