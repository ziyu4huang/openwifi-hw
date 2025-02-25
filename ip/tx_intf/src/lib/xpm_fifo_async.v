`timescale 1 ns / 1 ps

module xpm_fifo_async #(
    parameter integer CDC_SYNC_STAGES = 2,
    parameter string DOUT_RESET_VALUE = "0",
    parameter string ECC_MODE = "no_ecc",
    parameter string FIFO_MEMORY_TYPE = "auto",
    parameter integer FIFO_READ_LATENCY = 1,
    parameter integer FIFO_WRITE_DEPTH = 16,
    parameter integer FULL_RESET_VALUE = 0,
    parameter integer PROG_EMPTY_THRESH = 10,
    parameter integer PROG_FULL_THRESH = 10,
    parameter integer RD_DATA_COUNT_WIDTH = 5,
    parameter integer READ_DATA_WIDTH = 8,  // Adjust as needed
    parameter string READ_MODE = "std",
    parameter integer RELATED_CLOCKS = 0,
    parameter string USE_ADV_FEATURES = "0000",
    parameter integer WAKEUP_TIME = 0,
    parameter integer WRITE_DATA_WIDTH = 8,  // Adjust as needed
    parameter integer WR_DATA_COUNT_WIDTH = 5
)(
    output wire almost_empty,
    output wire almost_full,
    output wire data_valid,
    output wire dbiterr,
    output wire [READ_DATA_WIDTH-1:0] dout,
    output wire empty,
    output wire full,
    output wire overflow,
    output wire prog_empty,
    output wire prog_full,
    output wire [RD_DATA_COUNT_WIDTH-1:0] rd_data_count,
    output wire rd_rst_busy,
    output wire sbiterr,
    output wire underflow,
    output wire wr_ack,
    output wire [WR_DATA_COUNT_WIDTH-1:0] wr_data_count,
    output wire wr_rst_busy,
    input wire [WRITE_DATA_WIDTH-1:0] din,
    input wire injectdbiterr,
    input wire injectsbiterr,
    input wire rd_clk,
    input wire rd_en,
    input wire rst,
    input wire sleep,
    input wire wr_clk,
    input wire wr_en
);

    // Dummy assignments for output signals
    assign almost_empty = 0;
    assign almost_full = 0;
    assign data_valid = 0;
    assign dbiterr = 0;
    assign dout = 0;
    assign empty = 0;
    assign full = 0;
    assign overflow = 0;
    assign prog_empty = 0;
    assign prog_full = 0;
    assign rd_data_count = 0;
    assign rd_rst_busy = 0;
    assign sbiterr = 0;
    assign underflow = 0;
    assign wr_ack = 0;
    assign wr_data_count = 0;
    assign wr_rst_busy = 0;

endmodule