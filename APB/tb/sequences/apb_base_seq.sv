`ifndef APB_BASE_SEQ_SV
`define APB_BASE_SEQ_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_base_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_base_seq)

    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction

    // Helper task to perform a single APB write
    virtual task write_reg(
        input bit [ADDR_WIDTH-1:0]               addr,
        input bit [DATA_WIDTH-1:0]               data,
        input apb_transaction::apb_error_type_e  err_type = apb_transaction::NO_ERR
    );
        apb_transaction tr;
        tr = apb_transaction::type_id::create("tr");
        start_item(tr);
`ifndef MODELSIM_ASE
        if (!tr.randomize() with {
            op         == apb_transaction::APB_WRITE;
            addr       == local::addr;
            wdata      == local::data;
            error_type == local::err_type;
        }) begin
            `uvm_fatal("RND_FAIL", "Randomization failed in write_reg!")
        end
`else
        tr.op         = apb_transaction::APB_WRITE;
        tr.addr       = addr;
        tr.wdata      = data;
        tr.error_type = err_type;
`endif
        finish_item(tr);
    endtask

    // Helper task to perform a single APB read
    virtual task read_reg(
        input  bit [ADDR_WIDTH-1:0]              addr,
        output bit [DATA_WIDTH-1:0]              data,
        output bit                               pslverr,
        input  apb_transaction::apb_error_type_e err_type = apb_transaction::NO_ERR
    );
        apb_transaction tr;
        tr = apb_transaction::type_id::create("tr");
        start_item(tr);
`ifndef MODELSIM_ASE
        if (!tr.randomize() with {
            op         == apb_transaction::APB_READ;
            addr       == local::addr;
            error_type == local::err_type;
        }) begin
            `uvm_fatal("RND_FAIL", "Randomization failed in read_reg!")
        end
`else
        tr.op         = apb_transaction::APB_READ;
        tr.addr       = addr;
        tr.error_type = err_type;
`endif
        finish_item(tr);
        data    = tr.rdata;
        pslverr = tr.pslverr;
    endtask

    // Helper task to enable the FIFO peripheral (REG_CONTROL[0] = 1)
    virtual task enable_fifo();
        write_reg(REG_CONTROL, 32'h0000_0001);
    endtask

    // Helper task to disable the FIFO peripheral (REG_CONTROL[0] = 0)
    virtual task disable_fifo();
        write_reg(REG_CONTROL, 32'h0000_0000);
    endtask

    // Helper task to flush the FIFO (REG_CONTROL[1] = 1, keeping enable active)
    virtual task flush_fifo();
        write_reg(REG_CONTROL, 32'h0000_0003);
    endtask

    // Helper task to clear overflow sticky flag
    virtual task clear_overflow();
        write_reg(REG_CONTROL, 32'h0000_0005);
    endtask

    // Helper task to clear underflow sticky flag
    virtual task clear_underflow();
        write_reg(REG_CONTROL, 32'h0000_0009);
    endtask

endclass

`endif
