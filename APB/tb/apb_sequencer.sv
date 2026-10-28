`ifndef APB_SEQUENCER_SV
`define APB_SEQUENCER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class apb_sequencer extends uvm_sequencer #(apb_transaction);
    `uvm_component_utils(apb_sequencer)

    function new(string name = "apb_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
endclass

`endif