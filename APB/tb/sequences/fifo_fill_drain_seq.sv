`ifndef FIFO_FILL_DRAIN_SEQ_SV
`define FIFO_FILL_DRAIN_SEQ_SV

class fifo_fill_drain_seq extends apb_base_seq;
    `uvm_object_utils(fifo_fill_drain_seq)

    int depth = FIFO_DEPTH;

    function new(string name = "fifo_fill_drain_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;
        bit [31:0] written_data[];

        written_data = new[depth];

        `uvm_info(get_type_name(), $sformatf("Starting Fill & Drain Sequence for depth=%0d", depth), UVM_LOW)

        // 1. Ensure FIFO is enabled and empty
        enable_fifo();
        read_reg(REG_STATUS, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // 2. Fill FIFO to capacity
        for (int i = 0; i < depth; i++) begin
            written_data[i] = 32'h1000_0000 + i;
            write_reg(REG_DATA, written_data[i]);
        end

        // 3. Verify FULL status and count
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        // 4. Drain FIFO completely
        for (int i = 0; i < depth; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end

        // 5. Verify EMPTY status and count == 0
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        `uvm_info(get_type_name(), "Fill & Drain Sequence completed successfully.", UVM_LOW)
    endtask
endclass

`endif
