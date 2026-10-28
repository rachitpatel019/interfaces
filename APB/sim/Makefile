# ==============================================================================
# APB FIFO UVM Verification Makefile
# Location: interfaces/APB/sim/Makefile
# Supports QuestaSim / ModelSim / VCS / Xcelium
# ==============================================================================

UVM_HOME ?= /tools/mentor/questasim/verilog_src/uvm-1.2
WORK     ?= work
TEST     ?= apb_basic_test
GUI      ?= 0

PROJ_DIR ?= ..
RTL_DIR  ?= $(PROJ_DIR)/rtl
TB_DIR   ?= $(PROJ_DIR)/tb

RTL_SRCS = \
	$(RTL_DIR)/fifo.sv \
	$(RTL_DIR)/apb_pkg.sv \
	$(RTL_DIR)/apb_slave.sv \
	$(RTL_DIR)/fifo_controller.sv \
	$(RTL_DIR)/apb_top.sv

TB_SRCS = \
	$(TB_DIR)/apb_if.sv \
	$(TB_DIR)/apb_sva.sv \
	$(TB_DIR)/fifo_sva.sv \
	$(TB_DIR)/apb_pkg_tb.sv \
	$(TB_DIR)/tb_top.sv

INCDIRS = +incdir+$(TB_DIR) +incdir+$(TB_DIR)/sequences +incdir+$(TB_DIR)/tests +incdir+$(UVM_HOME)/src

all: prep compile run

prep:
	@vlib $(WORK) 2>/dev/null || true
	@vmap $(WORK) $(WORK) 2>/dev/null || true

compile: prep
	vlog -sv -mfcu $(INCDIRS) $(UVM_HOME)/src/uvm_pkg.sv $(RTL_SRCS) $(TB_SRCS)

run:
ifeq ($(GUI), 1)
	vsim -gui $(WORK).tb_top +UVM_TESTNAME=$(TEST)
else
	vsim -c $(WORK).tb_top +UVM_TESTNAME=$(TEST) -do "run -all; quit"
endif

clean:
	rm -rf $(WORK) transcript *.log *.wlf *.vcd dump.vcd modelsim.ini obj_dir cov_annotated coverage.dat coverage.info sim_coverage

.PHONY: all prep compile run clean
