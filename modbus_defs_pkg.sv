package modbus_defs_pkg;

    localparam logic [7:0] FC_READ_HOLDING = 8'h03;
    localparam logic [7:0] FC_WRITE_SINGLE = 8'h06;

    localparam int unsigned MODBUS_MAX_READ_REGISTERS = 125;

    typedef enum logic [2:0] {
        STATUS_OK            = 3'd0,
        STATUS_EXCEPTION     = 3'd1,
        STATUS_CRC_ERROR     = 3'd2,
        STATUS_TIMEOUT       = 3'd3,
        STATUS_INVALID       = 3'd4,
        STATUS_OVERFLOW      = 3'd5,
        STATUS_UNSUPPORTED   = 3'd6,
        STATUS_INVALID_PARAM = 3'd7
    } modbus_status_t;

endpackage
