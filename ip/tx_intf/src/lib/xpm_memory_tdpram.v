module xpm_memory_tdpram # (
  parameter MEMORY_SIZE = 8*8192,
  parameter MEMORY_PRIMITIVE = "block",
  parameter CLOCKING_MODE = "common_clock",
  parameter MEMORY_INIT_FILE = "none",
  parameter MEMORY_INIT_PARAM = "",
  parameter USE_MEM_INIT = 0,
  parameter WAKEUP_TIME = "disable_sleep",
  parameter MESSAGE_CONTROL = 0,
  parameter WRITE_DATA_WIDTH_A = 64,
  parameter READ_DATA_WIDTH_A = 64,
  parameter BYTE_WRITE_WIDTH_A = 64,
  parameter ADDR_WIDTH_A = 10,
  parameter READ_RESET_VALUE_A = "0",
  parameter READ_LATENCY_A = 1,
  parameter WRITE_MODE_A = "write_first",
  parameter WRITE_DATA_WIDTH_B = 64,
  parameter READ_DATA_WIDTH_B = 64,
  parameter BYTE_WRITE_WIDTH_B = 64,
  parameter ADDR_WIDTH_B = 10,
  parameter READ_RESET_VALUE_B = "0",
  parameter READ_LATENCY_B = 1,
  parameter WRITE_MODE_B = "write_first"
)(
  input wire sleep,
  input wire clka,
  input wire rsta,
  input wire ena,
  input wire regcea,
  input wire [WRITE_DATA_WIDTH_A-1:0] wea,
  input wire [ADDR_WIDTH_A-1:0] addra,
  input wire [WRITE_DATA_WIDTH_A-1:0] dina,
  input wire injectsbiterra,
  input wire injectdbiterra,
  output wire [READ_DATA_WIDTH_A-1:0] douta,
  output wire sbiterra,
  output wire dbiterra,
  input wire clkb,
  input wire rstb,
  input wire enb,
  input wire regceb,
  input wire [WRITE_DATA_WIDTH_B-1:0] web,
  input wire [ADDR_WIDTH_B-1:0] addrb,
  input wire [WRITE_DATA_WIDTH_B-1:0] dinb,
  input wire injectsbiterrb,
  input wire injectdbiterrb,
  output wire [READ_DATA_WIDTH_B-1:0] doutb,
  output wire sbiterrb,
  output wire dbiterrb
);
  // Dummy logic
  assign douta = {READ_DATA_WIDTH_A{1'b0}};
  assign sbiterra = 1'b0;
  assign dbiterra = 1'b0;
  assign doutb = {READ_DATA_WIDTH_B{1'b0}};
  assign sbiterrb = 1'b0;
  assign dbiterrb = 1'b0;
endmodule