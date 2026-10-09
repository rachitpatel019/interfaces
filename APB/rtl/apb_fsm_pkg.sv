package apb_fsm_pkg;

typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ACCESS
} apb_fsm_state;

endpackage