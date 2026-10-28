`ifndef APB_READ_SEQ_SV
`define APB_READ_SEQ_SV

class apb_read_seq extends apb_base_seq;
    `uvm_object_utils(apb_read_seq)

    rand bit [ADDR_WIDTH-1:0] read_addr;
    bit [DATA_WIDTH-1:0] read_data;
    bit pslverr;
    rand apb_transaction::apb_error_type_e err_type;

    constraint c_default_read_addr {
        soft read_addr inside {REG_DATA, REG_STATUS, REG_CONTROL, REG_FIFO_COUNT};
        soft err_type == apb_transaction::NO_ERR;
    }

    function new(string name = "apb_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        read_reg(read_addr, read_data, pslverr, err_type);
    endtask
endclass

`endif
