import apb_pkg::*;

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)

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

    // Hostile Protocol Fault Injection Classification
    typedef enum bit [2:0] {
        FAULT_NONE          = 3'b000,
        FAULT_NO_PSEL       = 3'b001, // PENABLE asserted without PSEL active
        FAULT_SKIP_SETUP    = 3'b010, // ACCESS asserted directly from IDLE without SETUP phase
        FAULT_WAIT_MUTATION = 3'b011, // Mutate PADDR/PWDATA during wait state (PREADY=0)
        FAULT_EARLY_ABORT   = 3'b100, // Prematurely drop PSEL/PENABLE before PREADY=1
        FAULT_STUCK_PENABLE = 3'b101  // Hold PENABLE=1 across transactions without SETUP phase
    } apb_protocol_fault_e;

`ifndef MODELSIM_ASE
    rand apb_error_type_e error_type;
    rand apb_protocol_fault_e protocol_fault;
    rand apb_op_e op;
    bit [ADDR_WIDTH-1:0] addr;
    rand bit [DATA_WIDTH-1:0] wdata;
`else
    apb_error_type_e error_type;
    apb_protocol_fault_e protocol_fault;
    apb_op_e op;
    bit [ADDR_WIDTH-1:0] addr;
    bit [DATA_WIDTH-1:0] wdata;
`endif

    // Response
    bit [DATA_WIDTH-1:0] rdata;
    bit pslverr;

    function new(string name = "apb_transaction");
        super.new(name);
        protocol_fault = FAULT_NONE;
    endfunction

`ifndef MODELSIM_ASE
    // Default to legal operations
    constraint c_error_default {
        soft error_type == NO_ERR;
        soft protocol_fault == FAULT_NONE;
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

    virtual function void do_copy(uvm_object rhs);
        apb_transaction rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("DO_COPY", "Type mismatch in apb_transaction::do_copy")
        end
        super.do_copy(rhs);
        this.error_type     = rhs_.error_type;
        this.protocol_fault = rhs_.protocol_fault;
        this.op             = rhs_.op;
        this.addr           = rhs_.addr;
        this.wdata          = rhs_.wdata;
        this.rdata          = rhs_.rdata;
        this.pslverr        = rhs_.pslverr;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_transaction rhs_;
        if (!$cast(rhs_, rhs)) return 1'b0;
        return (super.do_compare(rhs, comparer) &&
                (this.error_type     == rhs_.error_type) &&
                (this.protocol_fault == rhs_.protocol_fault) &&
                (this.op             == rhs_.op) &&
                (this.addr           == rhs_.addr) &&
                (this.wdata          == rhs_.wdata) &&
                (this.rdata          == rhs_.rdata) &&
                (this.pslverr        == rhs_.pslverr));
    endfunction

    virtual function string convert2string();
        return $sformatf("op=%s addr=0x%0h wdata=0x%0h rdata=0x%0h pslverr=%0b err_type=%s protocol_fault=%s",
                         op.name(), addr, wdata, rdata, pslverr, error_type.name(), protocol_fault.name());
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_string("transaction_summary", convert2string());
    endfunction
endclass
