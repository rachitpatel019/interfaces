import apb_pkg::*;

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)

    function new(string name = "apb_transaction");
        super.new(name);
    endfunction
    
    typedef enum bit {
        APB_READ = 1'b0,
        APB_WRITE = 1'b1
    } apb_op_e;

    // Error classification
    typedef enum bit [2:0] {
        // Stateless
        NO_ERR = 3'b000,
        ERR_INV_ADDR = 3'b001,
        ERR_RO_WRITE = 3'b010,

        // Stateful
        ERR_OVERFLOW = 3'b011,
        ERR_UNDERFLOW = 3'b100,
        ERR_DISABLED = 3'b101
    } apb_error_type_e;

`ifndef MODELSIM_ASE
    rand apb_error_type_e error_type;
    rand apb_op_e op;
    rand bit [ADDR_WIDTH-1:0] addr;
    rand bit [DATA_WIDTH-1:0] wdata;
`else
    apb_error_type_e error_type;
    apb_op_e op;
    bit [ADDR_WIDTH-1:0] addr;
    bit [DATA_WIDTH-1:0] wdata;
`endif

    // Response
    bit [DATA_WIDTH-1:0] rdata;
    bit pslverr;

`ifndef MODELSIM_ASE
    // Default to legal operations
    constraint c_error_default {
        soft error_type == NO_ERR;
    }

    // 4-byte (word) aligned address
    constraint c_addr_aligned {
        addr[1:0] == 2'b00;
    }

    // Address assignment based on error scenario
    constraint c_addr_policy {
        if (error_type == ERR_INV_ADDR) {
            !(addr inside {REG_DATA, REG_STATUS, REG_CONTROL, REG_FIFO_COUNT});
        }
        else if (error_type inside {ERR_OVERFLOW, ERR_UNDERFLOW, ERR_DISABLED}) {
            addr == REG_DATA;
        }
        else {
            addr inside {REG_DATA, REG_STATUS, REG_CONTROL, REG_FIFO_COUNT};
        }
    }

    // Operation assignment based on error scenario
    constraint c_op_policy {
        if (error_type == ERR_RO_WRITE) {
            addr inside {REG_STATUS, REG_FIFO_COUNT};
            op == APB_WRITE;
        } else if (error_type == ERR_OVERFLOW) {
            op == APB_WRITE;
        } else if (error_type == ERR_UNDERFLOW) {
            op == APB_READ;
        } else {
            (addr inside {REG_STATUS, REG_FIFO_COUNT}) -> (op == APB_READ);
        }
    }

    // Zero-out unused upper bits when writing control register
    constraint c_ctrl_wdata {
        soft (addr == REG_CONTROL && op == APB_WRITE) -> (wdata[31:4] == '0);
    }
`endif

    // Helper function for scoreboard checking
    function bit expect_pslverr();
        return (error_type != NO_ERR);
    endfunction
endclass