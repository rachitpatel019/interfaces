`ifndef APB_WRITE_SEQ_SV
`define APB_WRITE_SEQ_SV

class apb_write_seq extends apb_base_seq;
    `uvm_object_utils(apb_write_seq)

    rand bit [ADDR_WIDTH-1:0] write_addr;
    rand bit [DATA_WIDTH-1:0] write_data;
    rand apb_transaction::apb_error_type_e err_type;

    constraint c_default_addr {
        soft write_addr inside {REG_DATA, REG_CONTROL};
        soft err_type == apb_transaction::NO_ERR;
    }

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    virtual task body();
        write_reg(write_addr, write_data, err_type);
    endtask
endclass

`endif
