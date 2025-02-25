module xpm_cdc_array_single (
  input wire src_clk,
  input wire [WIDTH-1:0] src_in,
  input wire dest_clk,
  output wire [WIDTH-1:0] dest_out
);
  parameter DEST_SYNC_FF = 4;  // integer; range: 2-10
  parameter INIT_SYNC_FF = 0;  // integer; 0=disable simulation init values, 1=enable simulation init values
  parameter SIM_ASSERT_CHK = 0; // integer; 0=disable simulation messages, 1=enable simulation messages
  parameter SRC_INPUT_REG = 1;  // integer; 0=do not register input, 1=register input
  parameter WIDTH = 1;          // integer; range: 1-1024

  // Dummy logic for the module
  reg [WIDTH-1:0] sync_ff [0:DEST_SYNC_FF-1];

  always @(posedge src_clk) begin
    if (SRC_INPUT_REG) begin
      sync_ff[0] <= src_in;
    end
  end

  integer i;
  always @(posedge dest_clk) begin
    for (i = 1; i < DEST_SYNC_FF; i = i + 1) begin
      sync_ff[i] <= sync_ff[i-1];
    end
  end

  assign dest_out = sync_ff[DEST_SYNC_FF-1];

endmodule