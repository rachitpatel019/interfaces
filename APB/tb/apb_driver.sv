`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)

    apb_vif_t vif;

    function new(string name = "apb_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(apb_vif_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV_NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    // Run Phase
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        // Initialize
        reset_signals();

        forever begin
            // Wait for reset to be released
            if (!vif.PRESETn) begin
                `uvm_info(get_type_name(), "PRESETn active (low). Waiting for reset deassertion...", UVM_MEDIUM)
                wait(vif.PRESETn === 1'b1);
                @(vif.drv_cb);
                `uvm_info(get_type_name(), "PRESETn deasserted. Resuming driver operation.", UVM_MEDIUM)
            end

            // Get next item, drive pins, and acknowledge completion
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task reset_signals();
        vif.drv_cb.PSEL <= 1'b0;
        vif.drv_cb.PENABLE <= 1'b0;
        vif.drv_cb.PWRITE <= 1'b0;
        vif.drv_cb.PADDR <= '0;
        vif.drv_cb.PWDATA <= '0;
        vif.drv_cb.protocol_fault_active <= 1'b0;
    endtask

    // Drive a single APB read or write transfer following the APB protocol
    virtual task drive_transfer(apb_transaction tr);
        if (tr.protocol_fault != apb_transaction::FAULT_NONE) begin
            drive_protocol_fault_transfer(tr);
        end
        else begin
            drive_normal_transfer(tr);
        end
    endtask

    // Standard APB compliant transfer
    virtual task drive_normal_transfer(apb_transaction tr);
        `uvm_info(get_type_name(), $sformatf("Driving APB %s transfer: addr=0x%0h, wdata=0x%0h",
                  tr.op.name(), tr.addr, tr.wdata), UVM_HIGH)

        // SETUP Phase
        vif.drv_cb.PSEL <= 1'b1;
        vif.drv_cb.PENABLE <= 1'b0;
        vif.drv_cb.PADDR <= tr.addr;
        vif.drv_cb.PWRITE <= (tr.op == apb_transaction::APB_WRITE);

        // Drive write data only for write operations
        if (tr.op == apb_transaction::APB_WRITE) begin
            vif.drv_cb.PWDATA <= tr.wdata;
        end else begin
            vif.drv_cb.PWDATA <= '0;
        end

        @(vif.drv_cb);

        // ACCESS Phase
        vif.drv_cb.PENABLE <= 1'b1;

        // Advance to next clock edge to sample PREADY
        @(vif.drv_cb);

        // Hold inputs stable until PREADY=1
        while (!vif.drv_cb.PREADY && vif.PRESETn) begin
            @(vif.drv_cb);
        end

        // Transfer completion
        if (vif.PRESETn) begin
            if (tr.op == apb_transaction::APB_READ) begin
                tr.rdata = vif.drv_cb.PRDATA;
            end
            tr.pslverr = vif.drv_cb.PSLVERR;

            `uvm_info(get_type_name(), $sformatf("Completed APB %s transfer: addr=0x%0h, rdata=0x%0h, pslverr=%0b",
                      tr.op.name(), tr.addr, tr.rdata, tr.pslverr), UVM_HIGH)
        end
        else begin
            `uvm_warning(get_type_name(), "APB transfer aborted due to reset assertion!")
        end

        // Return to IDLE
        vif.drv_cb.PSEL    <= 1'b0;
        vif.drv_cb.PENABLE <= 1'b0;
        vif.drv_cb.PWRITE  <= 1'b0;
        vif.drv_cb.PADDR   <= '0;
        vif.drv_cb.PWDATA  <= '0;
    endtask

    // Hostile Negative VIP: Drive protocol violations directly onto the bus
    virtual task drive_protocol_fault_transfer(apb_transaction tr);
        vif.drv_cb.protocol_fault_active <= 1'b1;
        `uvm_info(get_type_name(), $sformatf("[NEGATIVE-VIP] Injecting Master Protocol Violation: %s on addr=0x%0h, wdata=0x%0h",
                  tr.protocol_fault.name(), tr.addr, tr.wdata), UVM_LOW)

        case (tr.protocol_fault)
            apb_transaction::FAULT_NO_PSEL: begin
                // VIOLATION: Assert PENABLE=1 while PSEL=0 (APB Rule: PENABLE requires PSEL)
                vif.drv_cb.PSEL    <= 1'b0;
                vif.drv_cb.PENABLE <= 1'b1;
                vif.drv_cb.PADDR   <= tr.addr;
                vif.drv_cb.PWRITE  <= (tr.op == apb_transaction::APB_WRITE);
                vif.drv_cb.PWDATA  <= tr.wdata;
                @(vif.drv_cb);
                @(vif.drv_cb);
                reset_signals();
                @(vif.drv_cb);
            end

            apb_transaction::FAULT_SKIP_SETUP: begin
                // VIOLATION: Jump straight from IDLE to ACCESS (PSEL=1, PENABLE=1 on cycle 1)
                vif.drv_cb.PSEL    <= 1'b1;
                vif.drv_cb.PENABLE <= 1'b1;
                vif.drv_cb.PADDR   <= tr.addr;
                vif.drv_cb.PWRITE  <= (tr.op == apb_transaction::APB_WRITE);
                vif.drv_cb.PWDATA  <= (tr.op == apb_transaction::APB_WRITE) ? tr.wdata : '0;
                @(vif.drv_cb);

                while (!vif.drv_cb.PREADY && vif.PRESETn) begin
                    @(vif.drv_cb);
                end

                if (tr.op == apb_transaction::APB_READ) begin
                    tr.rdata = vif.drv_cb.PRDATA;
                end
                tr.pslverr = vif.drv_cb.PSLVERR;
                reset_signals();
                @(vif.drv_cb);
            end

            apb_transaction::FAULT_WAIT_MUTATION: begin
                // VIOLATION: Mutate PADDR/PWDATA while PREADY is low during wait states
                vif.drv_cb.PSEL    <= 1'b1;
                vif.drv_cb.PENABLE <= 1'b0;
                vif.drv_cb.PADDR   <= tr.addr;
                vif.drv_cb.PWRITE  <= (tr.op == apb_transaction::APB_WRITE);
                vif.drv_cb.PWDATA  <= tr.wdata;
                @(vif.drv_cb);

                vif.drv_cb.PENABLE <= 1'b1;
                @(vif.drv_cb);

                // Mutate address and write data while PREADY is low
                while (!vif.drv_cb.PREADY && vif.PRESETn) begin
                    `uvm_info(get_type_name(), "[NEGATIVE-VIP] Mutating PADDR and PWDATA mid-transfer during low PREADY wait state!", UVM_HIGH)
                    vif.drv_cb.PADDR  <= tr.addr ^ 8'h3C;
                    vif.drv_cb.PWDATA <= ~tr.wdata;
                    @(vif.drv_cb);
                end

                if (tr.op == apb_transaction::APB_READ) begin
                    tr.rdata = vif.drv_cb.PRDATA;
                end
                tr.pslverr = vif.drv_cb.PSLVERR;
                reset_signals();
                @(vif.drv_cb);
            end

            apb_transaction::FAULT_EARLY_ABORT: begin
                // VIOLATION: Prematurely drop PSEL and PENABLE while PREADY is low
                vif.drv_cb.PSEL    <= 1'b1;
                vif.drv_cb.PENABLE <= 1'b0;
                vif.drv_cb.PADDR   <= tr.addr;
                vif.drv_cb.PWRITE  <= (tr.op == apb_transaction::APB_WRITE);
                vif.drv_cb.PWDATA  <= tr.wdata;
                @(vif.drv_cb);

                vif.drv_cb.PENABLE <= 1'b1;
                @(vif.drv_cb);

                // Abruptly drop PSEL and PENABLE without waiting for PREADY
                `uvm_info(get_type_name(), "[NEGATIVE-VIP] Abruptly dropping PSEL & PENABLE mid-transfer before PREADY asserts!", UVM_HIGH)
                reset_signals();
                @(vif.drv_cb);
                @(vif.drv_cb);
            end

            apb_transaction::FAULT_STUCK_PENABLE: begin
                // VIOLATION: Hold PENABLE=1 across back-to-back transactions without returning to SETUP/IDLE
                vif.drv_cb.PSEL    <= 1'b1;
                vif.drv_cb.PENABLE <= 1'b0;
                vif.drv_cb.PADDR   <= tr.addr;
                vif.drv_cb.PWRITE  <= (tr.op == apb_transaction::APB_WRITE);
                vif.drv_cb.PWDATA  <= tr.wdata;
                @(vif.drv_cb);

                vif.drv_cb.PENABLE <= 1'b1;
                @(vif.drv_cb);

                while (!vif.drv_cb.PREADY && vif.PRESETn) begin
                    @(vif.drv_cb);
                end

                // Rather than de-asserting PENABLE, keep it held high for 2 cycles
                `uvm_info(get_type_name(), "[NEGATIVE-VIP] Holding PENABLE=1 stuck high across transaction boundary!", UVM_HIGH)
                vif.drv_cb.PADDR  <= REG_STATUS;
                vif.drv_cb.PWRITE <= 1'b0;
                @(vif.drv_cb);
                @(vif.drv_cb);
                reset_signals();
                @(vif.drv_cb);
            end

            default: begin
                drive_normal_transfer(tr);
            end
        endcase

        vif.drv_cb.protocol_fault_active <= 1'b0;
    endtask
endclass

`endif