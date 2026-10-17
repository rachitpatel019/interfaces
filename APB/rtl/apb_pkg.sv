package apb_pkg;
    // APB FSM States
    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } apb_fsm_state_e;

    // Register Address Map
    typedef enum logic [3:0] {
        REG_DATA = 'h0,
        REG_STATUS = 'h4,
        REG_CONTROL = 'h8,
        REG_FIFO_COUNT = 'hC
    } apb_reg_addr_e;

endpackage