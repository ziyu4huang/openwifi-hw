/*
 * HT short_preamble_rom - TODO
 *
 * Michael Tetemke Mehari michael.mehari@ugent.be
 * Xianjun Jiao xianjun.jiao@imec.be putaoshu@msn.com
 */
`include "openofdm_tx_pre_def.v"

module ht_stf_rom
(
  input      [3:0]  addr,
  output reg [31:0] dout  
);

  always @ *
    case (addr)
	/*michael code*/
            //   0:   dout = 32'h02D402D4;
            //   1:   dout = 32'hF7DB0025;
            //   2:   dout = 32'hFF2CFB2C;
            //   3:   dout = 32'h08C7FF39;
            //   4:   dout = 32'h05A80000;
            //   5:   dout = 32'h08C7FF39;
            //   6:   dout = 32'hFF2CFB2C;
            //   7:   dout = 32'hF7DB0025;
            //   8:   dout = 32'h02D402D4;
            //   9:   dout = 32'h0025F7DB;
            //  10:   dout = 32'hFB2CFF2C;
            //  11:   dout = 32'hFF3908C7;
            //  12:   dout = 32'h000005A8;
            //  13:   dout = 32'hFF3908C7;
            //  14:   dout = 32'hFB2CFF2C;
            //  15:   dout = 32'h0025F7DB;


/*after scaling*/
            0:    dout = 32'h061C061C;
            1:    dout = 32'hEE680050;
            2:    dout = 32'hFE36F592;
            3:    dout = 32'h12F6FE52;
            4:    dout = 32'h0C380000;
            5:    dout = 32'h12F6FE52;
            6:    dout = 32'hFE36F592;
            7:    dout = 32'hEE680050;
            8:    dout = 32'h061C061C;
            9:    dout = 32'h0050EE68;
            10:   dout = 32'hF592FE36;
            11:   dout = 32'hFE5212F6;
            12:   dout = 32'h00000C38;
            13:   dout = 32'hFE5212F6;
            14:   dout = 32'hF592FE36;
            15:   dout = 32'h0050EE68;

          default: dout = 32'h00000000;
    endcase

endmodule


