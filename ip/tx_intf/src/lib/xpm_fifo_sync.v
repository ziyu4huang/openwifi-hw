
`timescale 1ns / 1ps

// Dummy xpm_fifo_sync module for compatibility

module xpm_fifo_sync #(
  parameter DOUT_RESET_VALUE = "0",     // String
  parameter ECC_MODE = "no_ecc",        // String
  parameter FIFO_MEMORY_TYPE = "auto",  // String
  parameter FIFO_READ_LATENCY = 0,      // DECIMAL
  parameter FIFO_WRITE_DEPTH = 64,      // DECIMAL
  parameter FULL_RESET_VALUE = 0,       // DECIMAL
  parameter PROG_EMPTY_THRESH = 10,     // DECIMAL
  parameter PROG_FULL_THRESH = 10,      // DECIMAL
  parameter RD_DATA_COUNT_WIDTH = 7,    // DECIMAL
  parameter READ_DATA_WIDTH = 32,       // DECIMAL
  parameter READ_MODE = "fwft",         // String
  parameter USE_ADV_FEATURES = "0404",  // String
  parameter WAKEUP_TIME = 0,            // DECIMAL
  parameter WRITE_DATA_WIDTH = 32,      // DECIMAL
  parameter WR_DATA_COUNT_WIDTH = 7     // DECIMAL
) (
  output almost_empty,
  output almost_full,
  output data_valid,
  output dbiterr,
  output [READ_DATA_WIDTH-1:0] dout,
  output empty,
  output full,
  output overflow,
  output prog_empty,
  output prog_full,
  output [RD_DATA_COUNT_WIDTH-1:0] rd_data_count,
  output rd_rst_busy,
  output sbiterr,
  output underflow,
  output wr_ack,
  output [WR_DATA_COUNT_WIDTH-1:0] wr_data_count,
  output wr_rst_busy,
  input [WRITE_DATA_WIDTH-1:0] din,
  input injectdbiterr,
  input injectsbiterr,
  input rd_en,
  input rst,
  input sleep,
  input wr_clk,
  input wr_en
);

  // Internal signals (dummy logic)
  assign almost_empty = 0;
  assign almost_full = 0;
  assign data_valid = 0;
  assign dbiterr = 0;
  assign dout = {READ_DATA_WIDTH{1'b0}};
  assign empty = 0;
  assign full = 0;
  assign overflow = 0;
  assign prog_empty = 0;
  assign prog_full = 0;
  assign rd_data_count = {RD_DATA_COUNT_WIDTH{1'b0}};
  assign rd_rst_busy = 0;
  assign sbiterr = 0;
  assign underflow = 0;
  assign wr_ack = 0;
  assign wr_data_count = {WR_DATA_COUNT_WIDTH{1'b0}};
  assign wr_rst_busy = 0;

endmodule
