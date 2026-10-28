// ==============================================================================
// Reset During Active Traffic Stimulus Sequence
// ==============================================================================
`ifndef RESET_DURING_TRAFFIC_SEQ_SV
`define RESET_DURING_TRAFFIC_SEQ_SV

class reset_during_traffic_seq extends apb_base_seq;
    `uvm_object_utils(reset_during_traffic_seq)

    function new(string name = "reset_during_traffic_seq");
        super.new(name);
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;

        `uvm_info(get_type_name(), "=== Starting Reset During Traffic Sequence ===", UVM_LOW)

        // -------------------------------------------------------------
        // Phase 1: Reset while FIFO is partially occupied (8 items)
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 1: Filling 8 items before mid-occupancy reset...", UVM_MEDIUM)
        enable_fifo();
        for (int i = 0; i < 8; i++) begin
            write_reg(REG_DATA, 32'hA000_0000 + i);
        end
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        // Signal test to trigger hardware reset pulse
        `uvm_info(get_type_name(), "Phase 1: Triggering reset with 8 items stored...", UVM_MEDIUM)
        uvm_event_pool::get_global_pool().get("trigger_reset").trigger();
        uvm_event_pool::get_global_pool().get("reset_done").wait_trigger();

        // Verify post-reset clean state
        enable_fifo();
        read_reg(REG_FIFO_COUNT, rdata, pslverr);
        read_reg(REG_STATUS, rdata, pslverr);

        // Verify normal operations resume
        for (int i = 0; i < 4; i++) begin
            write_reg(REG_DATA, 32'hA111_0000 + i);
        end
        for (int i = 0; i < 4; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end

        // -------------------------------------------------------------
        // Phase 2: Reset after error states (overflow & underflow)
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 2: Inducing overflow/underflow before reset...", UVM_MEDIUM)
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            write_reg(REG_DATA, 32'hB000_0000 + i);
        end
        // Attempt overflow
        write_reg(REG_DATA, 32'hDEAD_DEAD, apb_transaction::ERR_OVERFLOW);
        read_reg(REG_STATUS, rdata, pslverr); // Verify overflow flag is high

        // Trigger hardware reset while sticky overflow is active
        `uvm_info(get_type_name(), "Phase 2: Triggering reset while overflow active...", UVM_MEDIUM)
        uvm_event_pool::get_global_pool().get("trigger_reset").trigger();
        uvm_event_pool::get_global_pool().get("reset_done").wait_trigger();

        // Verify sticky flags cleared and FIFO empty
        enable_fifo();
        read_reg(REG_STATUS, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // -------------------------------------------------------------
        // Phase 3: Consecutive rapid operations verification post-recovery
        // -------------------------------------------------------------
        `uvm_info(get_type_name(), "Phase 3: Final sanity push/pop post-reset...", UVM_MEDIUM)
        for (int i = 0; i < 6; i++) begin
            write_reg(REG_DATA, 32'hC000_0000 + i);
        end
        for (int i = 0; i < 6; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end

        read_reg(REG_STATUS, rdata, pslverr);
        `uvm_info(get_type_name(), "=== Reset During Traffic Sequence Completed Successfully ===", UVM_LOW)
    endtask
endclass

`endif
