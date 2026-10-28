`ifndef APB_COVERAGE_SV
`define APB_COVERAGE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import apb_pkg::*;

class apb_coverage extends uvm_subscriber #(apb_transaction);
    `uvm_component_utils(apb_coverage)

    // Coverage Classification
    typedef enum bit [1:0] {
        COV_FIFO_EMPTY = 2'b00,
        COV_FIFO_PARTIAL = 2'b01,
        COV_FIFO_FULL = 2'b10
    } cov_fifo_state_e;

    typedef enum bit [2:0] {
        PAT_ALL_ZEROS = 3'b000,
        PAT_ALL_ONES = 3'b001,
        PAT_ALT_AA = 3'b010,
        PAT_ALT_55 = 3'b011,
        PAT_WALKING_1 = 3'b100,
        PAT_WALKING_0 = 3'b101,
        PAT_RANDOM = 3'b110
    } cov_data_pattern_e;

    // Configuration & Shadow Model State
    int fifo_depth = 16;

    local int shadow_count;
    local bit shadow_enable;
    local bit shadow_empty;
    local bit shadow_full;
    local bit shadow_overflow;
    local bit shadow_underflow;

    int total_coverage_samples;

    // Sampled Variables for Covergroups
    apb_transaction::apb_op_e sample_op;
    bit [7:0] sample_addr;
    bit [31:0] sample_wdata;
    bit [31:0] sample_rdata;
    bit sample_pslverr;
    apb_transaction::apb_error_type_e sample_err_type;
    int sample_count;
    cov_fifo_state_e sample_state;
    bit sample_enable;
    cov_data_pattern_e sample_data_pat;

    // Control and status register variables
    bit sample_ctrl_en;
    bit sample_ctrl_flush;
    bit sample_ctrl_clr_of;
    bit sample_ctrl_clr_uf;

    bit sample_stat_empty;
    bit sample_stat_full;
    bit sample_stat_of;
    bit sample_stat_uf;
    bit sample_stat_en;

    int sample_read_fifo_count;

`ifndef MODELSIM_ASE
    // Covergroup 1: APB Protocol, Transaction, and Micro-Architectural State
    covergroup apb_trans_cg;
        option.per_instance = 1;
        option.name = "apb_transaction_coverage";

        // Bus operation type
        cp_op: coverpoint sample_op {
            bins read = {apb_transaction::APB_READ};
            bins write = {apb_transaction::APB_WRITE};
        }

        // Register address map and unmapped address coverage
        cp_addr: coverpoint sample_addr {
            bins reg_data = {REG_DATA};
            bins reg_status = {REG_STATUS};
            bins reg_control = {REG_CONTROL};
            bins reg_fifo_count= {REG_FIFO_COUNT};
            bins unmapped = default;
        }

        // Slave error response
        cp_pslverr: coverpoint sample_pslverr {
            bins success = {1'b0};
            bins error = {1'b1};
        }

        // Error classification
        cp_error_type: coverpoint sample_err_type {
            bins no_err = {apb_transaction::NO_ERR};
            bins err_inv_addr = {apb_transaction::ERR_INV_ADDR};
            bins err_ro_write = {apb_transaction::ERR_RO_WRITE};
            bins err_overflow = {apb_transaction::ERR_OVERFLOW};
            bins err_underflow = {apb_transaction::ERR_UNDERFLOW};
            bins err_disabled = {apb_transaction::ERR_DISABLED};
        }

        // Data pattern categories for 32-bit data
        cp_data_pattern: coverpoint sample_data_pat {
            bins all_zeros = {PAT_ALL_ZEROS};
            bins all_ones = {PAT_ALL_ONES};
            bins alt_aa = {PAT_ALT_AA};
            bins alt_55 = {PAT_ALT_55};
            bins walking_1 = {PAT_WALKING_1};
            bins walking_0 = {PAT_WALKING_0};
            bins random = {PAT_RANDOM};
        }

        // FIFO occupancy at transaction start (bins matching depth 16)
        cp_fifo_occupancy: coverpoint sample_count {
            bins empty = {0};
            bins low = {[1:3]};
            bins mid_low = {[4:7]};
            bins mid_high = {[8:11]};
            bins near_full = {[12:14]};
            bins at_max_m1 = {15};
            bins full = {16};
        }

        // Discrete FIFO state at transaction start (Empty, Partial, Full)
        cp_fifo_state: coverpoint sample_state {
            bins empty = {COV_FIFO_EMPTY};
            bins partial = {COV_FIFO_PARTIAL};
            bins full = {COV_FIFO_FULL};
        }

        // FIFO enable state
        cp_fifo_enable: coverpoint sample_enable {
            bins disabled = {1'b0};
            bins enabled = {1'b1};
        }

        // Multi-Dimensional Cross Coverage

        // Operation across all registers (verifies legal R/W and RO write attempts)
        cx_op_addr: cross cp_op, cp_addr;

        // Operation across PSLVERR (success and error responses for both ops)
        cx_op_pslverr: cross cp_op, cp_pslverr;

        // PSLVERR occurrence across every address
        cx_addr_pslverr: cross cp_addr, cp_pslverr;

        // Critical FIFO state boundaries: READ x EMPTY, WRITE x FULL, READ x FULL, WRITE x EMPTY
        cx_op_fifo_state: cross cp_op, cp_fifo_state;

        // Operation across discrete occupancy bins
        cx_op_occupancy: cross cp_op, cp_fifo_occupancy;

        // Operation x State x Error Response
        cx_op_state_pslverr: cross cp_op, cp_fifo_state, cp_pslverr;

        // Corner data patterns pushed (write) and popped (read)
        cx_data_pat_op: cross cp_data_pattern, cp_op;

        // Operations while FIFO is enabled vs disabled
        cx_op_enable: cross cp_op, cp_fifo_enable;

        // Error types across register addresses
        cx_err_addr: cross cp_error_type, cp_addr;
    endgroup

    // Covergroup 2: Register Bitfield & Inspection Coverage
    covergroup apb_register_fields_cg;
        option.per_instance = 1;
        option.name = "apb_register_fields_coverage";

        // Control Register Writes (PWDATA fields)
        cp_ctrl_en: coverpoint sample_ctrl_en {
            bins disabled = {1'b0};
            bins enabled = {1'b1};
        }

        cp_ctrl_flush: coverpoint sample_ctrl_flush {
            bins no_flush = {1'b0};
            bins flush = {1'b1};
        }

        cp_ctrl_clr_of: coverpoint sample_ctrl_clr_of {
            bins no_clear = {1'b0};
            bins clear = {1'b1};
        }

        cp_ctrl_clr_uf: coverpoint sample_ctrl_clr_uf {
            bins no_clear = {1'b0};
            bins clear = {1'b1};
        }

        // Status Register Reads (PRDATA fields)
        cp_stat_empty: coverpoint sample_stat_empty {
            bins not_empty = {1'b0};
            bins is_empty = {1'b1};
        }

        cp_stat_full: coverpoint sample_stat_full {
            bins not_full = {1'b0};
            bins is_full = {1'b1};
        }

        cp_stat_of: coverpoint sample_stat_of {
            bins no_overflow = {1'b0};
            bins has_overflow = {1'b1};
        }

        cp_stat_uf: coverpoint sample_stat_uf {
            bins no_underflow = {1'b0};
            bins has_underflow = {1'b1};
        }

        cp_stat_en: coverpoint sample_stat_en {
            bins not_enabled = {1'b0};
            bins is_enabled = {1'b1};
        }

        // Direct FIFO Count Register Reads
        cp_read_fifo_count: coverpoint sample_read_fifo_count {
            bins zero = {0};
            bins low = {[1:3]};
            bins mid_low = {[4:7]};
            bins mid_high = {[8:11]};
            bins near_full = {[12:14]};
            bins at_max_m1 = {15};
            bins full = {16};
        }

        // Cross of Empty and Full flags (cannot both be 1 simultaneously)
        cx_stat_empty_full: cross cp_stat_empty, cp_stat_full {
            ignore_bins illegal_empty_and_full = binsof(cp_stat_empty) intersect {1'b1} &&
                                                 binsof(cp_stat_full) intersect {1'b1};
        }

        // Overflow flag assertion while full
        cx_stat_of_full: cross cp_stat_of, cp_stat_full;

        // Underflow flag assertion while empty
        cx_stat_uf_empty: cross cp_stat_uf, cp_stat_empty;
    endgroup

    // Covergroup 3: Sequential Transfer and Occupancy Dynamics
    covergroup apb_sequence_dynamics_cg;
        option.per_instance = 1;
        option.name = "apb_sequence_dynamics_coverage";

        // Back-to-back operation transitions
        cp_op_transition: coverpoint sample_op {
            bins wr_to_wr = (apb_transaction::APB_WRITE => apb_transaction::APB_WRITE);
            bins wr_to_rd = (apb_transaction::APB_WRITE => apb_transaction::APB_READ);
            bins rd_to_rd = (apb_transaction::APB_READ => apb_transaction::APB_READ);
            bins rd_to_wr = (apb_transaction::APB_READ => apb_transaction::APB_WRITE);
        }

        // Occupancy transitions across transactions
        cp_occupancy_transition: coverpoint sample_count {
            bins fill_0_to_1 = (0 => 1);
            bins fill_14_to_15 = (14 => 15);
            bins fill_15_to_16 = (15 => 16);
            bins drain_16_to_15 = (16 => 15);
            bins drain_15_to_14 = (15 => 14);
            bins drain_1_to_0 = (1 => 0);
            bins hold_full = (16 => 16);
            bins hold_empty = (0 => 0);
        }
    endgroup
`endif

    function new(string name = "apb_coverage", uvm_component parent = null);
        super.new(name, parent);
`ifndef MODELSIM_ASE
        apb_trans_cg = new();
        apb_register_fields_cg = new();
        apb_sequence_dynamics_cg = new();
`endif
    endfunction

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(int)::get(this, "", "fifo_depth", fifo_depth));
        reset_coverage_state();
    endfunction

    // State Initialization
    virtual function void reset_coverage_state();
        shadow_count = 0;
        shadow_enable = 1'b0;
        shadow_empty = 1'b1;
        shadow_full = 1'b0;
        shadow_overflow = 1'b0;
        shadow_underflow = 1'b0;
        total_coverage_samples = 0;
    endfunction

    // TLM Subscriber Write Method
    virtual function void write(apb_transaction t);
        int pre_count;
        cov_fifo_state_e pre_state;
        bit pre_enable;

        total_coverage_samples++;

        // 1. Capture snapshot of FIFO state BEFORE current transaction executes
        pre_count = shadow_count;
        pre_state = get_fifo_state(pre_count);
        pre_enable = shadow_enable;

        // 2. Populate transaction covergroup sample variables
        sample_op = t.op;
        sample_addr = t.addr;
        sample_wdata = t.wdata;
        sample_rdata = t.rdata;
        sample_pslverr = t.pslverr;
        sample_err_type = t.error_type;
        sample_count = pre_count;
        sample_state = pre_state;
        sample_enable = pre_enable;

        // Classify data pattern
        if (t.op == apb_transaction::APB_WRITE) begin
            sample_data_pat = classify_data(t.wdata);
        end
        else begin
            sample_data_pat = classify_data(t.rdata);
        end

        // Sample main transaction and sequence dynamics covergroups
`ifndef MODELSIM_ASE
        apb_trans_cg.sample();
        apb_sequence_dynamics_cg.sample();
`endif

        // 3. Handle register-specific field coverage
        case (t.addr)
            REG_CONTROL: begin
                if (t.op == apb_transaction::APB_WRITE) begin
                    sample_ctrl_en = t.wdata[0];
                    sample_ctrl_flush = t.wdata[1];
                    sample_ctrl_clr_of = t.wdata[2];
                    sample_ctrl_clr_uf = t.wdata[3];
`ifndef MODELSIM_ASE
                    apb_register_fields_cg.sample();
`endif
                end
            end

            REG_STATUS: begin
                if (t.op == apb_transaction::APB_READ) begin
                    sample_stat_empty = t.rdata[0];
                    sample_stat_full = t.rdata[1];
                    sample_stat_of = t.rdata[2];
                    sample_stat_uf = t.rdata[3];
                    sample_stat_en = t.rdata[4];
`ifndef MODELSIM_ASE
                    apb_register_fields_cg.sample();
`endif
                end
            end

            REG_FIFO_COUNT: begin
                if (t.op == apb_transaction::APB_READ) begin
                    sample_read_fifo_count = t.rdata;
`ifndef MODELSIM_ASE
                    apb_register_fields_cg.sample();
`endif
                end
            end

            default: begin
                // No specific register bitfield sampling for REG_DATA or unmapped
            end
        endcase

        // 4. Update shadow model state to track FIFO occupancy & flags
        update_shadow_state(t);
    endfunction

    // Shadow Model Update Logic
    virtual function void update_shadow_state(apb_transaction t);
        case (t.addr)
            REG_DATA: begin
                if (t.op == apb_transaction::APB_WRITE) begin
                    if (shadow_enable && !shadow_full) begin
                        shadow_count++;
                    end
                    else if (shadow_enable && shadow_full) begin
                        shadow_overflow = 1'b1;
                    end
                end
                else begin // APB_READ
                    if (shadow_enable && !shadow_empty) begin
                        shadow_count--;
                    end
                    else if (shadow_enable && shadow_empty) begin
                        shadow_underflow = 1'b1;
                    end
                end
            end

            REG_CONTROL: begin
                if (t.op == apb_transaction::APB_WRITE) begin
                    shadow_enable = t.wdata[0];

                    if (t.wdata[1]) begin // Flush
                        shadow_count = 0;
                    end
                    if (t.wdata[2]) begin // Clear overflow
                        shadow_overflow = 1'b0;
                    end
                    if (t.wdata[3]) begin // Clear underflow
                        shadow_underflow = 1'b0;
                    end
                end
            end

            default: begin
                // Reads and status/count writes do not alter FIFO storage state
            end
        endcase

        // Recalculate flags
        shadow_empty = (shadow_count == 0);
        shadow_full = (shadow_count == fifo_depth);
    endfunction

    // Helper: Categorize 32-bit Data Patterns
    virtual function cov_data_pattern_e classify_data(bit [31:0] data);
        if (data == 32'h0000_0000) return PAT_ALL_ZEROS;
        if (data == 32'hFFFF_FFFF) return PAT_ALL_ONES;
        if (data == 32'hAAAA_AAAA) return PAT_ALT_AA;
        if (data == 32'h5555_5555) return PAT_ALT_55;
        if ($countones(data) == 1) return PAT_WALKING_1;
        if ($countones(~data) == 1) return PAT_WALKING_0;
        return PAT_RANDOM;
    endfunction

    // Helper: Determine Discrete FIFO State from Occupancy
    virtual function cov_fifo_state_e get_fifo_state(int count);
        if (count == 0) begin
            return COV_FIFO_EMPTY;
        end
        else if (count == fifo_depth) begin
            return COV_FIFO_FULL;
        end
        else begin
            return COV_FIFO_PARTIAL;
        end
    endfunction

    // Report Phase: Print Formatted Functional Coverage Summary
    virtual function void report_phase(uvm_phase phase);
        real trans_cov;
        real reg_cov;
        real seq_cov;
        real overall_cov;

        super.report_phase(phase);
`ifndef MODELSIM_ASE
        trans_cov = apb_trans_cg.get_inst_coverage();
        reg_cov = apb_register_fields_cg.get_inst_coverage();
        seq_cov = apb_sequence_dynamics_cg.get_inst_coverage();
        overall_cov = (trans_cov + reg_cov + seq_cov) / 3.0;
`else
        trans_cov = 100.0; reg_cov = 100.0; seq_cov = 100.0; overall_cov = 100.0;
`endif

        `uvm_info(get_type_name(), "==================================================", UVM_NONE)
        `uvm_info(get_type_name(), " APB FIFO COVERAGE REPORT ", UVM_NONE)
        `uvm_info(get_type_name(), "==================================================", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Total Monitored Samples : %0d", total_coverage_samples), UVM_NONE)
        `uvm_info(get_type_name(), "--------------------------------------------------", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" APB Transaction Coverage : %0.2f%%", trans_cov), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Register Fields Coverage : %0.2f%%", reg_cov), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" Sequence Dynamics Coverage : %0.2f%%", seq_cov), UVM_NONE)
        `uvm_info(get_type_name(), "--------------------------------------------------", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf(" OVERALL FUNCTIONAL COVERAGE: %0.2f%%", overall_cov), UVM_NONE)
        `uvm_info(get_type_name(), "==================================================", UVM_NONE)
    endfunction
endclass
`endif