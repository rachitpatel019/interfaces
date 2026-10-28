`ifndef FIFO_BACK_TO_BACK_SEQ_SV
`define FIFO_BACK_TO_BACK_SEQ_SV

class fifo_back_to_back_seq extends apb_base_seq;
    `uvm_object_utils(fifo_back_to_back_seq)

    function new(string name = "fifo_back_to_back_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;

        `uvm_info(get_type_name(), "Starting FIFO Back-to-Back Sequence...", UVM_LOW)

        // 1. Enable FIFO
        enable_fifo();

        // 2. Burst of writes: WR -> WR transition
        for (int i = 0; i < 4; i++) begin
            write_reg(REG_DATA, 32'h1111_0000 + i);
        end

        // 3. WR -> RD transition followed by RD -> RD transition
        read_reg(REG_DATA, rdata, pslverr);
        read_reg(REG_DATA, rdata, pslverr);

        // 4. RD -> WR transition followed by WR -> WR
        write_reg(REG_DATA, 32'h2222_0001);
        write_reg(REG_DATA, 32'h2222_0002);

        // 5. Interleaved WR and RD pattern
        for (int i = 0; i < 6; i++) begin
            write_reg(REG_DATA, 32'h3333_0000 + i);
            read_reg(REG_DATA, rdata, pslverr);
        end

        // 6. Drain remaining items
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        for (int i = 0; i < rdata; i++) begin
            bit [31:0] pop_val;
            read_reg(REG_DATA, pop_val, pslverr);
        end

        `uvm_info(get_type_name(), "FIFO Back-to-Back Sequence finished.", UVM_LOW)
    endtask
endclass

`endif
