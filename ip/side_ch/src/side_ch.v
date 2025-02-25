
// Xianjun jiao. putaoshu@msn.com; xianjun.jiao@imec.be;
`include "fpga_scale.v"
`include "has_side_ch_flag.v"
`include "side_ch_pre_def.v"

`timescale 1 ns / 1 ps

`ifdef SIDE_CH_ENABLE_DBG
`define DEBUG_PREFIX (*mark_debug="true",DONT_TOUCH="TRUE"*)
`else
`define DEBUG_PREFIX
`endif

	module side_ch #
	(
		parameter integer TSF_TIMER_WIDTH = 64, // according to 802.11 standard

    parameter integer GPIO_STATUS_WIDTH = 8,
    parameter integer RSSI_HALF_DB_WIDTH = 11,

		parameter integer ADC_PACK_DATA_WIDTH	= 64,
		parameter integer IQ_DATA_WIDTH	=     16,
		parameter integer RSSI_DATA_WIDTH	=     10,
		
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 7,

		parameter integer C_S00_AXIS_TDATA_WIDTH	= 64,
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 64,

`ifdef SIDE_CH_LESS_BRAM
		parameter integer MAX_NUM_DMA_SYMBOL = 4096, // the fifo depth inside m_axis
`else
		parameter integer MAX_NUM_DMA_SYMBOL = 8192,
`endif
    parameter integer WAIT_COUNT_BITS = 5,

		parameter integer COUNTER_WIDTH = 16
	)
	(
		// from pl
	  input wire [(GPIO_STATUS_WIDTH-1):0] gpio_status,
    input wire signed [(RSSI_HALF_DB_WIDTH-1):0] rssi_half_db,
		input wire [(TSF_TIMER_WIDTH-1):0]  tsf_runtime_val,
		input wire [(2*IQ_DATA_WIDTH-1):0] openofdm_tx_iq0,
		input wire [(2*IQ_DATA_WIDTH-1):0] openofdm_tx_iq1,
    input wire openofdm_tx_iq_valid,
		input wire [(2*IQ_DATA_WIDTH-1):0] tx_intf_iq0,
		input wire [(2*IQ_DATA_WIDTH-1):0] tx_intf_iq1,
    input wire tx_intf_iq_valid,
		input wire [(2*IQ_DATA_WIDTH-1):0] sample0_in,
		input wire [(2*IQ_DATA_WIDTH-1):0] sample1_in,
    input wire sample_in_strobe,

		input wire demod_is_ongoing,
		input wire ofdm_symbol_eq_out_pulse,
		input wire long_preamble_detected,
		input wire short_preamble_detected,
		input wire ht_unsupport,
		input wire [7:0] pkt_rate,
		input wire [15:0] pkt_len,
		input wire [(2*IQ_DATA_WIDTH-1):0] csi,
		input wire csi_valid,
		input wire signed [31:0] phase_offset_taken,
		input wire [(2*IQ_DATA_WIDTH-1):0] equalizer,
		input wire equalizer_valid,

		input wire pkt_header_valid,
		input wire pkt_header_valid_strobe,
		input wire [31:0] FC_DI,
		input wire FC_DI_valid,
		input wire [47:0] addr1,
		input wire addr1_valid,
		input wire [47:0] addr2,
		input wire addr2_valid,
		input wire [47:0] addr3,
		input wire addr3_valid,
		input wire pkt_for_me,

		input wire fcs_in_strobe,
		input wire fcs_ok,
		input wire block_rx_dma_to_ps,
    input wire block_rx_dma_to_ps_valid,

		// from tx
		input wire phy_tx_start,
		input wire tx_pkt_need_ack,
		input wire phy_tx_started,
		input wire phy_tx_done,
		input wire tx_bb_is_ongoing,
		input wire tx_rf_is_ongoing,

		// Ports of Axi Master Bus Interface M00_AXIS to PS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		`DEBUG_PREFIX output wire  m00_axis_tvalid,
		`DEBUG_PREFIX output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		`DEBUG_PREFIX output wire  m00_axis_tlast,
		`DEBUG_PREFIX input wire  m00_axis_tready,

		// Ports of Axi Slave Bus Interface S00_AXIS to PS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,

		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);

`ifdef HAS_SIDE_CH

	function integer clogb2 (input integer bit_depth);                                   
		begin                                                                              
			for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                                      
				bit_depth = bit_depth >> 1;                                                    
		end                                                                                
	endfunction   
	
	localparam integer MAX_BIT_NUM_DMA_SYMBOL  = clogb2(MAX_NUM_DMA_SYMBOL);
    
	wire       slv_reg_wren_signal;
	wire [4:0] axi_awaddr_core;

    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg0; 
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg1;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg2; 
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg3;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg4;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg5;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg6;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg7;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg8; 
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg9;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg10; 
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg11;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg12;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg13;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg14;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg15;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg16; 
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg17;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg18; 
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg19;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg20;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg21;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg22;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg23;
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg24; 
    // wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg25;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg26; 
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg27;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg28;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg29;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg30;
    wire [(C_S00_AXI_DATA_WIDTH-1):0] slv_reg31;

	wire s_axis_state;

	wire  [C_S00_AXIS_TDATA_WIDTH-1 : 0] data_to_pl;
	wire pl_ask_data;
	wire  [MAX_BIT_NUM_DMA_SYMBOL-1 : 0] s_axis_data_count;
	wire  emptyn_to_pl;

	wire m_axis_start_1trans;

	wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] data_to_ps;
	wire data_to_ps_valid;
	wire [MAX_BIT_NUM_DMA_SYMBOL-1 : 0] m_axis_data_count;
	wire fulln_to_pl;

	wire [1:0] FC_type;
	wire is_data;

	wire event0;
	wire event1;
	wire event2;
	wire event3;
	wire event4;
	wire event5;

	assign slv_reg20 = m_axis_data_count;

	assign FC_type =    FC_DI[3:2];
	assign is_data = (FC_type==2'b10);

	side_ch_counter_event_cfg # (
		.GPIO_STATUS_WIDTH(GPIO_STATUS_WIDTH),
		.RSSI_HALF_DB_WIDTH(RSSI_HALF_DB_WIDTH),
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH)
	) side_ch_counter_event_cfg_i	(
		.clk(m00_axis_aclk),
		.rstn(m00_axis_aresetn),

		// original event source
		.gain_th(slv_reg10[(GPIO_STATUS_WIDTH-2):0]),
		.rssi_half_db_th(slv_reg9[(RSSI_HALF_DB_WIDTH-1):0]),
		.gpio_status(gpio_status),
		.rssi_half_db(rssi_half_db),

		.short_preamble_detected(short_preamble_detected),
		.long_preamble_detected(long_preamble_detected),

		.pkt_header_valid_strobe(pkt_header_valid_strobe),
		.pkt_header_valid(pkt_header_valid),

		.addr2_target(slv_reg7),
		.addr2(addr2),
		.pkt_for_me(pkt_for_me),
		.is_data(is_data),

		.fcs_in_strobe(fcs_in_strobe),
		.fcs_ok(fcs_ok),

		.phy_tx_start(phy_tx_start),
		.phy_tx_done(phy_tx_done),
		.tx_pkt_need_ack(tx_pkt_need_ack),

		// from arm. event source select
	 	.event0_sel(slv_reg19[0]),
	 	.event1_sel(slv_reg19[4]),
	 	.event2_sel(slv_reg19[8]),
	 	.event3_sel(slv_reg19[12]),
	 	.event4_sel(slv_reg19[16]),
	 	.event5_sel(slv_reg19[20]),

		// counter++ event output
		.event0(event0),
		.event1(event1),
		.event2(event2),
		.event3(event3),
		.event4(event4),
		.event5(event5)
	);

	side_ch_counter # (
		.COUNTER_WIDTH(COUNTER_WIDTH)
	) side_ch_counter_i	(
		.clk(m00_axis_aclk),
		// .rstn(m00_axis_aresetn),

		// from arm. capture reg write to clear the corresponding counter
		.slv_reg_wren_signal(slv_reg_wren_signal),
		.axi_awaddr_core(axi_awaddr_core),

		.event0(event0),
		.event1(event1),
		.event2(event2),
		.event3(event3),
		.event4(event4),
		.event5(event5),

		// has to be slv_reg26 ~ 31 due to the internal logic
		.counter0(slv_reg26[(COUNTER_WIDTH-1):0]),
		.counter1(slv_reg27[(COUNTER_WIDTH-1):0]),
		.counter2(slv_reg28[(COUNTER_WIDTH-1):0]),
		.counter3(slv_reg29[(COUNTER_WIDTH-1):0]),
		.counter4(slv_reg30[(COUNTER_WIDTH-1):0]),
		.counter5(slv_reg31[(COUNTER_WIDTH-1):0])
	);

	side_ch_control # (
		.TSF_TIMER_WIDTH(TSF_TIMER_WIDTH),
		.GPIO_STATUS_WIDTH(GPIO_STATUS_WIDTH),
		.RSSI_HALF_DB_WIDTH(RSSI_HALF_DB_WIDTH),
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.IQ_DATA_WIDTH(IQ_DATA_WIDTH),
		.C_S_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
		.MAX_NUM_DMA_SYMBOL(MAX_NUM_DMA_SYMBOL),
		.MAX_BIT_NUM_DMA_SYMBOL(MAX_BIT_NUM_DMA_SYMBOL)
	) side_ch_control_i	(
		.clk(m00_axis_aclk),
		.rstn(m00_axis_aresetn&(~slv_reg0[2])),

		// from pl
		.gpio_status(gpio_status),
		.rssi_half_db(rssi_half_db),
		.tsf_runtime_val(tsf_runtime_val),
		.openofdm_tx_iq0(openofdm_tx_iq0),
		.openofdm_tx_iq1(openofdm_tx_iq1),
		.openofdm_tx_iq_valid(openofdm_tx_iq_valid),
		.tx_intf_iq0(tx_intf_iq0),
		.tx_intf_iq1(tx_intf_iq1),
		.tx_intf_iq_valid(tx_intf_iq_valid),
		.iq0({sample0_in[(IQ_DATA_WIDTH-1):0], sample0_in[(2*IQ_DATA_WIDTH-1):IQ_DATA_WIDTH]}),
		.iq1({sample1_in[(IQ_DATA_WIDTH-1):0], sample1_in[(2*IQ_DATA_WIDTH-1):IQ_DATA_WIDTH]}),
		.iq_strobe(sample_in_strobe),
		.demod_is_ongoing(demod_is_ongoing),
		.ofdm_symbol_eq_out_pulse(ofdm_symbol_eq_out_pulse),
		.long_preamble_detected(long_preamble_detected),
		.short_preamble_detected(short_preamble_detected),
		.ht_unsupport(ht_unsupport),
		.pkt_rate(pkt_rate),
		.pkt_len(pkt_len),
		.csi(csi),
		.csi_valid(csi_valid),
		.phase_offset_taken(phase_offset_taken),
		.equalizer(equalizer),
		.equalizer_valid(equalizer_valid),

		.pkt_header_valid(pkt_header_valid),
		.pkt_header_valid_strobe(pkt_header_valid_strobe),
		.FC_DI(FC_DI),
		.FC_DI_valid(FC_DI_valid),
		.addr1(addr1),
		.addr1_valid(addr1_valid),
		.addr2(addr2),
		.addr2_valid(addr2_valid),
		.addr3(addr3),
		.addr3_valid(addr3_valid),

		.fcs_in_strobe(fcs_in_strobe),
		.fcs_ok(fcs_ok),
		.block_rx_dma_to_ps(block_rx_dma_to_ps),
		.block_rx_dma_to_ps_valid(block_rx_dma_to_ps_valid),

		.phy_tx_start(phy_tx_start),
		.tx_pkt_need_ack(tx_pkt_need_ack),
		.phy_tx_started(phy_tx_started),
		.phy_tx_done(phy_tx_done),
		.tx_bb_is_ongoing(tx_bb_is_ongoing),
		.tx_rf_is_ongoing(tx_rf_is_ongoing),

		// from arm
		.slv_reg_wren_signal(slv_reg_wren_signal),
		.axi_awaddr_core(axi_awaddr_core),
		.iq_capture(slv_reg3[0]),
		.iq_capture_cfg(slv_reg3[5:4]),
		.iq_trigger_select(slv_reg8[4:0]),
		.iq_trigger_free_run_flag(slv_reg5[0]),
		.iq_source_select(slv_reg5[2:1]),
		.rssi_or_iq_th(slv_reg9[(IQ_DATA_WIDTH-1):0]),
		.gain_th(slv_reg10[(GPIO_STATUS_WIDTH-2):0]),
		.pre_trigger_len(slv_reg11[(MAX_BIT_NUM_DMA_SYMBOL-1):0]),
		.iq_len_target(slv_reg12[(MAX_BIT_NUM_DMA_SYMBOL-1):0]),
		.FC_target(slv_reg5[15:0]),
		.addr1_target(slv_reg6),
		.addr2_target(slv_reg7),
		.match_cfg(slv_reg1[15:12]),
		.num_eq(slv_reg4[3:0]),
		.m_axis_start_mode(slv_reg1[1:0]),
		.m_axis_start_ext_trigger(),
		// .data_transfer_control(),

		// s_axis
		.data_to_pl(data_to_pl),
		.pl_ask_data(pl_ask_data),
		.s_axis_data_count(s_axis_data_count),
		.emptyn_to_pl(emptyn_to_pl),

		.S_AXIS_TVALID(s00_axis_tvalid),
		.S_AXIS_TLAST(s00_axis_tlast),

		// m_axis
		.m_axis_start_1trans(m_axis_start_1trans),

		.data_to_ps(data_to_ps),
		.data_to_ps_valid(data_to_ps_valid),
		.m_axis_data_count(m_axis_data_count),
		.fulln_to_pl(fulln_to_pl),
        
		.MAX_NUM_DMA_SYMBOL_UDP_debug(slv_reg21),
		.MAX_NUM_DMA_SYMBOL_debug(slv_reg22),

		.M_AXIS_TVALID(m00_axis_tvalid),
		.M_AXIS_TLAST(m00_axis_tlast)
	);

	side_ch_m_axis # (
		// .WAIT_COUNT_BITS(WAIT_COUNT_BITS),
		.MAX_NUM_DMA_SYMBOL(MAX_NUM_DMA_SYMBOL),
		.MAX_BIT_NUM_DMA_SYMBOL(MAX_BIT_NUM_DMA_SYMBOL),
		.C_M_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH)
	) side_ch_m_axis_i (
		.m_axis_endless_mode(slv_reg1[4]),
		.M_AXIS_NUM_DMA_SYMBOL(slv_reg2[    MAX_BIT_NUM_DMA_SYMBOL-1  :  0]-1'b1),

		.m_axis_start_1trans(m_axis_start_1trans),

		.data_to_ps(data_to_ps),
		.data_to_ps_valid(data_to_ps_valid),
		.m_axis_data_count(m_axis_data_count),
		.fulln_to_pl(fulln_to_pl),

		.M_AXIS_ACLK(m00_axis_aclk),
		.M_AXIS_ARESETN( m00_axis_aresetn&(~slv_reg0[0]) ),
		.M_AXIS_TVALID(m00_axis_tvalid),
		.M_AXIS_TDATA(m00_axis_tdata),
		.M_AXIS_TSTRB(m00_axis_tstrb),
		.M_AXIS_TLAST(m00_axis_tlast),
		.M_AXIS_TREADY(m00_axis_tready)		
	);

	// side_ch_s_axis # (
	// 	.C_S_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
	// 	.MAX_NUM_DMA_SYMBOL(MAX_NUM_DMA_SYMBOL),
    //     .MAX_BIT_NUM_DMA_SYMBOL(MAX_BIT_NUM_DMA_SYMBOL)
    // ) side_ch_s_axis_i (
	// 	.s_axis_endless_mode(slv_reg1[8]),
	// 	.S_AXIS_NUM_DMA_SYMBOL(slv_reg5[    MAX_BIT_NUM_DMA_SYMBOL-1  :  0]-1'b1),
		
	// 	.s_axis_state(s_axis_state),

    //     .data_to_pl(data_to_pl),
    //     .pl_ask_data(pl_ask_data),
	// 	.s_axis_data_count(s_axis_data_count),
    //     .emptyn_to_pl(emptyn_to_pl),

	// 	.S_AXIS_ACLK(s00_axis_aclk),
	// 	.S_AXIS_ARESETN(s00_axis_aresetn&(~slv_reg0[1])),
	// 	.S_AXIS_TREADY(s00_axis_tready),
	// 	.S_AXIS_TDATA(s00_axis_tdata),
	// 	.S_AXIS_TSTRB(s00_axis_tstrb),
	// 	.S_AXIS_TLAST(s00_axis_tlast),
	// 	.S_AXIS_TVALID(s00_axis_tvalid)
	// );

	side_ch_s_axi # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) side_ch_s_axi_i (
		.slv_reg_wren_signal(slv_reg_wren_signal),
		.axi_awaddr_core(axi_awaddr_core),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),

		.SLV_REG0(slv_reg0),
		.SLV_REG1(slv_reg1),
		.SLV_REG2(slv_reg2),
		.SLV_REG3(slv_reg3),
		.SLV_REG4(slv_reg4),
        .SLV_REG5(slv_reg5),
        .SLV_REG6(slv_reg6),
        .SLV_REG7(slv_reg7),
		.SLV_REG8(slv_reg8),
        .SLV_REG9(slv_reg9),
        .SLV_REG10(slv_reg10),
        .SLV_REG11(slv_reg11),
        .SLV_REG12(slv_reg12),
        // .SLV_REG13(slv_reg13),
        //.SLV_REG14(slv_reg14),
        //.SLV_REG15(slv_reg15),
		// .SLV_REG16(slv_reg16),
        // .SLV_REG17(slv_reg17),
        // .SLV_REG18(slv_reg18),
        .SLV_REG19(slv_reg19),
        .SLV_REG20(slv_reg20),
        .SLV_REG21(slv_reg21),
        .SLV_REG22(slv_reg22),
        // .SLV_REG23(slv_reg23),
		// .SLV_REG24(slv_reg24),
        // .SLV_REG25(slv_reg25),
        .SLV_REG26(slv_reg26),
        .SLV_REG27(slv_reg27),
        .SLV_REG28(slv_reg28),
        .SLV_REG29(slv_reg29),
        .SLV_REG30(slv_reg30),
        .SLV_REG31(slv_reg31)
	);
`else

		assign m00_axis_tvalid = 0;
		assign m00_axis_tdata = 0;
		assign m00_axis_tstrb = 0;
		assign m00_axis_tlast = 0;
		assign s00_axis_tready = 0;
		assign s00_axi_awready = 0;
		assign s00_axi_wready = 0;
		assign s00_axi_bresp = 0;
		assign s00_axi_bvalid = 0;
		assign s00_axi_arready = 0;
		assign s00_axi_rdata = 0;
		assign s00_axi_rresp = 0;
		assign s00_axi_rvalid = 0;

`endif

	endmodule
