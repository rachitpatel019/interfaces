`ifndef FIFO_RANDOM_SEQ_SV
`define FIFO_RANDOM_SEQ_SV

class fifo_random_seq extends apb_base_seq;
    `uvm_object_utils(fifo_random_seq)

`ifndef MODELSIM_ASE
    rand int unsigned num_random_trans;

    constraint c_num_trans {
        soft num_random_trans inside {[200:400]};
    }
`else
    int unsigned num_random_trans = 300;
`endif

    function new(string name = "fifo_random_seq");
        super.new(name);
        num_random_trans = 300;
    endfunction

    virtual task body();
        bit [31:0] rdata;
        bit pslverr;
        bit [31:0] pat_data;

        `uvm_info(get_type_name(), $sformatf("Starting Comprehensive Random & Coverage Sequence (%0d random trans)...", num_random_trans), UVM_LOW)

        // -------------------------------------------------------------
        // Phase 1: Data Patterns Coverage (Walking 1s/0s, 0s, 1s, AA, 55)
        // -------------------------------------------------------------
        enable_fifo();

        // 1a. Specific patterns
        write_reg(REG_DATA, 32'h0000_0000);
        write_reg(REG_DATA, 32'hFFFF_FFFF);
        write_reg(REG_DATA, 32'hAAAA_AAAA);
        write_reg(REG_DATA, 32'h5555_5555);

        // 1b. Walking 1s
        for (int b = 0; b < 4; b++) begin
            write_reg(REG_DATA, (32'h1 << (b * 8)));
        end

        // 1c. Walking 0s
        for (int b = 0; b < 4; b++) begin
            write_reg(REG_DATA, ~(32'h1 << (b * 8)));
        end

        // Pop all back to cover read data patterns as well
        for (int i = 0; i < 12; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end

        // -------------------------------------------------------------
        // Phase 2: Directed Occupancy Transitions and Boundaries
        // -------------------------------------------------------------
        // Empty to 1 (fill_0_to_1)
        write_reg(REG_DATA, 32'h1001);
        // Fill up to 14
        for (int i = 1; i < 14; i++) begin
            write_reg(REG_DATA, 32'h2000 + i);
        end
        read_reg(REG_FIFO_COUNT, rdata, pslverr); // Read count at 14

        // 14 -> 15 (fill_14_to_15)
        write_reg(REG_DATA, 32'h3015);
        read_reg(REG_FIFO_COUNT, rdata, pslverr); // Read count at 15

        // 15 -> 16 (fill_15_to_16)
        write_reg(REG_DATA, 32'h3016);
        read_reg(REG_FIFO_COUNT, rdata, pslverr); // Read count at 16 (full)
        read_reg(REG_STATUS, rdata, pslverr);     // Read status (full=1)

        // Hold full (16 -> 16) by attempting write while full
        write_reg(REG_DATA, 32'hEEEE, apb_transaction::ERR_OVERFLOW);
        read_reg(REG_STATUS, rdata, pslverr); // Observe overflow

        // Clear overflow
        clear_overflow();
        read_reg(REG_STATUS, rdata, pslverr);

        // 16 -> 15 (drain_16_to_15)
        read_reg(REG_DATA, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // 15 -> 14 (drain_15_to_14)
        read_reg(REG_DATA, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // Drain down to 1
        for (int i = 0; i < 13; i++) begin
            read_reg(REG_DATA, rdata, pslverr);
        end
        read_reg(REG_FIFO_COUNT, rdata, pslverr); // Count = 1

        // 1 -> 0 (drain_1_to_0)
        read_reg(REG_DATA, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr); // Count = 0
        read_reg(REG_STATUS, rdata, pslverr);     // Empty = 1

        // Hold empty (0 -> 0) by attempting read while empty
        read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_UNDERFLOW);
        read_reg(REG_STATUS, rdata, pslverr); // Observe underflow

        // Clear underflow
        clear_underflow();
        read_reg(REG_STATUS, rdata, pslverr);

        // -------------------------------------------------------------
        // Phase 3: Error Classification & Control/Status Bitfields
        // -------------------------------------------------------------
        // Unmapped address access
        write_reg(8'h20, 32'hBADC_0DE0, apb_transaction::ERR_INV_ADDR);
        read_reg(8'h24, rdata, pslverr, apb_transaction::ERR_INV_ADDR);

        // Read-only register write errors
        write_reg(REG_STATUS, 32'hFFFF_FFFF, apb_transaction::ERR_RO_WRITE);
        write_reg(REG_FIFO_COUNT, 32'h0000_0005, apb_transaction::ERR_RO_WRITE);

        // Disable FIFO and attempt write/read
        disable_fifo();
        read_reg(REG_STATUS, rdata, pslverr); // Verify enable=0
        write_reg(REG_DATA, 32'h1234, apb_transaction::ERR_DISABLED);
        read_reg(REG_DATA, rdata, pslverr, apb_transaction::ERR_DISABLED);

        // Re-enable and flush test
        enable_fifo();
        write_reg(REG_DATA, 32'h5678);
        write_reg(REG_DATA, 32'h9ABC);
        flush_fifo();
        read_reg(REG_STATUS, rdata, pslverr);
        read_reg(REG_FIFO_COUNT, rdata, pslverr);

        // -------------------------------------------------------------
        // Phase 4: Constrained Random Stimulus Loop
        // -------------------------------------------------------------
        for (int i = 0; i < num_random_trans; i++) begin
            apb_transaction tr;
            tr = apb_transaction::type_id::create($sformatf("rand_tr_%0d", i));
            start_item(tr);

`ifndef MODELSIM_ASE
            if (!tr.randomize() with {
                // Bias address selection
                addr dist {
                    REG_DATA       := 70,
                    REG_STATUS     := 12,
                    REG_FIFO_COUNT := 12,
                    REG_CONTROL    := 4,
                    8'h18          := 2
                };
                // Softly allow default legal error types unless unmapped or RO write
                if (!(addr inside {REG_DATA, REG_STATUS, REG_CONTROL, REG_FIFO_COUNT})) {
                    error_type == apb_transaction::ERR_INV_ADDR;
                } else if ((addr inside {REG_STATUS, REG_FIFO_COUNT}) && (op == apb_transaction::APB_WRITE)) {
                    error_type == apb_transaction::ERR_RO_WRITE;
                } else {
                    error_type == apb_transaction::NO_ERR;
                }
            }) begin
                `uvm_fatal("RND_FAIL", "Randomization failed in random stimulus loop!")
            end
`else
            begin
                int pick = $urandom_range(0, 99);
                if (pick < 70) tr.addr = REG_DATA;
                else if (pick < 82) tr.addr = REG_STATUS;
                else if (pick < 94) tr.addr = REG_FIFO_COUNT;
                else if (pick < 98) tr.addr = REG_CONTROL;
                else tr.addr = 8'h18;

                tr.op = ($urandom_range(0, 1) == 1) ? apb_transaction::APB_WRITE : apb_transaction::APB_READ;
                tr.wdata = $urandom();

                if (!(tr.addr inside {REG_DATA, REG_STATUS, REG_CONTROL, REG_FIFO_COUNT})) begin
                    tr.error_type = apb_transaction::ERR_INV_ADDR;
                end else if ((tr.addr inside {REG_STATUS, REG_FIFO_COUNT}) && (tr.op == apb_transaction::APB_WRITE)) begin
                    tr.error_type = apb_transaction::ERR_RO_WRITE;
                end else begin
                    tr.error_type = apb_transaction::NO_ERR;
                end
            end
`endif

            finish_item(tr);
        end

        `uvm_info(get_type_name(), "Random & Coverage Sequence completed successfully.", UVM_LOW)
    endtask
endclass

`endif
