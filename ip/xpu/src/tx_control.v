// Xianjun jiao. putaoshu@msn.com; xianjun.jiao@imec.be;
`include "clock_speed.v"
`include "board_def.v"

`include "xpu_pre_def.v"

`ifdef XPU_ENABLE_DBG
`define DEBUG_PREFIX (*mark_debug="true",DONT_TOUCH="TRUE"*)
`else
`define DEBUG_PREFIX
`endif

`timescale 1 ns / 1 ps

	module tx_control #
	(
	   parameter integer RSSI_HALF_DB_WIDTH = 11,
	   parameter integer C_S00_AXIS_TDATA_WIDTH	= 64,
     parameter integer WIFI_TX_BRAM_ADDR_WIDTH = 10
	)
	(
        input wire clk,
        input wire rstn,
        
        input wire ack_tx_disable,
        input wire [6:0] preamble_sig_time,
        input wire [4:0] ofdm_symbol_time,
        input wire [6:0] sifs_time,
        input wire [3:0] max_num_retrans,
        input wire tx_pkt_need_ack,
        input wire [3:0] tx_pkt_retrans_limit,
        input wire tx_ht_aggr,
        `DEBUG_PREFIX input wire [6:0]  relative_decoding_latency,
        `DEBUG_PREFIX input wire [14:0] send_ack_wait_top,
        `DEBUG_PREFIX input wire [14:0] recv_ack_timeout_top_adj,
        `DEBUG_PREFIX input wire [14:0] recv_ack_sig_valid_timeout_top,
        input wire recv_ack_fcs_valid_disable,
	      `DEBUG_PREFIX input wire tx_core_is_ongoing,
        `DEBUG_PREFIX input wire pulse_tx_bb_end,
        `DEBUG_PREFIX input wire phy_tx_done,
        `DEBUG_PREFIX input wire sig_valid,
        `DEBUG_PREFIX input wire [7:0] signal_rate,
        `DEBUG_PREFIX input wire [15:0] signal_len,
        `DEBUG_PREFIX input wire fcs_valid,
        `DEBUG_PREFIX input wire fcs_in_strobe,
        `DEBUG_PREFIX input wire [1:0] FC_type,
        `DEBUG_PREFIX input wire [3:0] FC_subtype,
        input wire       FC_more_frag,
        input wire cts_torts_disable,
        input wire [4:0]  cts_torts_rate,
        input wire [15:0] duration_extra,
        input wire [15:0] duration,
        input wire [47:0] addr2,
        input wire [47:0] self_mac_addr,
        input wire [47:0] addr1,
        input wire [63:0] douta,
        input wire cts_toself_bb_is_ongoing,//this should rise before the phy tx end valid of phy tx IP core.
        `DEBUG_PREFIX input wire backoff_done,
        input wire [(WIFI_TX_BRAM_ADDR_WIDTH-1):0] bram_addr,

        input wire ampdu_rx_tid_disable,
        input wire [3:0] ampdu_rx_tid,
        input wire ampdu_rx_start,

        input wire [11:0] SC_seq_num,
        input wire rx_ht_aggr,
        input wire rx_ht_aggr_last,

        input wire [15:0] blk_ack_req_ctrl,
        input wire [15:0] blk_ack_req_ssc,
        input wire [11:0] blk_ack_resp_ssn,
        input wire [63:0] blk_ack_resp_bitmap,
        input wire [3:0] qos_tid,
        input wire [1:0] qos_ack_policy,

        output wire tx_control_state_idle,
        output wire ack_cts_is_ongoing,
        `DEBUG_PREFIX output reg retrans_in_progress,
        `DEBUG_PREFIX output reg start_retrans,
        `DEBUG_PREFIX input wire quit_retrans,
        `DEBUG_PREFIX output reg start_tx_ack,
        `DEBUG_PREFIX output reg retrans_trigger,
        `DEBUG_PREFIX output reg tx_try_complete,
        `DEBUG_PREFIX output reg [79:0] tx_status,
        `DEBUG_PREFIX output reg ack_tx_flag,
        `DEBUG_PREFIX output reg wea,
        `DEBUG_PREFIX output reg [9:0] addra,
        output reg [(C_S00_AXIS_TDATA_WIDTH-1):0] dina
	);

  localparam [3:0]    IDLE =                     4'b0000,
                      PREP_ACK=                  4'b0001,
                      SEND_DFL_ACK=              4'b0010,
                      SEND_BLK_ACK=              4'b0011,
                      RECV_ACK_WAIT_TX_BB_DONE = 4'b0100,
                      RECV_ACK_WAIT_SIG_VALID =  4'b0101,
                      RECV_ACK  =                4'b0110;

  `DEBUG_PREFIX wire [3:0] retrans_limit;
  `DEBUG_PREFIX reg [3:0] num_retrans;
  `DEBUG_PREFIX reg [14:0] ack_timeout_count;
  `DEBUG_PREFIX reg [2:0] send_ack_count;
  reg [47:0] ack_addr;
  reg signed [15:0] duration_received;
  reg signed [15:0] duration_standard;
  `DEBUG_PREFIX reg FC_more_frag_received;
  `DEBUG_PREFIX reg [3:0] tx_control_state;
  `DEBUG_PREFIX reg [3:0] tx_control_state_old;
  `DEBUG_PREFIX reg [3:0] num_retrans_lock;
  reg [11:0] blk_ack_resp_ssn_lock;
  reg [63:0] blk_ack_bitmap_lock;
  `DEBUG_PREFIX wire is_data;
  `DEBUG_PREFIX wire is_qosdata;
  `DEBUG_PREFIX wire is_management;
  `DEBUG_PREFIX wire is_blockackreq;
  `DEBUG_PREFIX wire is_blockackresp;
  `DEBUG_PREFIX wire is_pspoll;
  `DEBUG_PREFIX wire is_rts;
  `DEBUG_PREFIX wire is_ack;
  reg  [3:0] ackcts_rate;
  wire ackcts_signal_parity;
  wire [11:0] ackcts_signal_len;
  wire [11:0] blkack_signal_len;
  wire [3:0] blk_ack_req_tid;
  wire [11:0] blk_ack_req_ssn;
  reg [11:0] rx_ht_aggr_ssn;
  `DEBUG_PREFIX reg rx_ht_aggr_flag;
  `DEBUG_PREFIX reg rx_ht_aggr_last_flag;

  reg [6:0] bitmap_count;
  reg [127:0] blk_ack_bitmap_mem;
  `DEBUG_PREFIX reg ampdu_rx_start_reg;
  `DEBUG_PREFIX reg reset_blk_ack_bitmap_mem;

  `DEBUG_PREFIX reg [1:0] tx_dpram_op_counter;

  // `DEBUG_PREFIX wire [2:0] num_data_ofdm_symbol;
  // reg  [2:0] num_data_ofdm_symbol_reg;
  // `DEBUG_PREFIX wire [2:0] ackcts_n_sym;
  // reg  [2:0] ackcts_n_sym_reg;
  `DEBUG_PREFIX reg signed [8:0] ackcts_time;
  reg signed [7:0] sifs_time_reg;

  `DEBUG_PREFIX reg [14:0] recv_ack_timeout_top;

  `DEBUG_PREFIX reg [15:0] duration_new;
  `DEBUG_PREFIX reg [1:0]  FC_type_new;
  `DEBUG_PREFIX reg [3:0]  FC_subtype_new;
  `DEBUG_PREFIX reg is_data_received;
  `DEBUG_PREFIX reg is_management_received;
  `DEBUG_PREFIX reg is_blockackreq_received;
  `DEBUG_PREFIX reg is_pspoll_received;
  `DEBUG_PREFIX reg is_rts_received;

  reg [14:0] send_ack_wait_top_scale;
  reg [14:0] send_ack_wait_top_scale_lock;
  reg [14:0] recv_ack_sig_valid_timeout_top_scale;
  reg [14:0] recv_ack_timeout_top_adj_scale;
  `DEBUG_PREFIX reg retrans_started;

  assign tx_control_state_idle =((tx_control_state==IDLE) && (~retrans_started));

  assign retrans_limit = (max_num_retrans[3]?max_num_retrans[2:0]:tx_pkt_retrans_limit);

  assign is_data =        ((FC_type==2'b10)?1:0);
  assign is_qosdata =     (((FC_type==2'b10) && (FC_subtype[3]==1'b1))?1:0);
  assign is_management =  (((FC_type==2'b00) && (FC_subtype!=4'b1110))?1:0);
  assign is_blockackreq = (((FC_type==2'b01) && (FC_subtype==4'b1000))?1:0);
  assign is_blockackresp= (((FC_type==2'b01) && (FC_subtype==4'b1001) && (signal_len==32))?1:0);
  assign is_pspoll =      (((FC_type==2'b01) && (FC_subtype==4'b1010))?1:0);
  assign is_rts =         (((FC_type==2'b01) && (FC_subtype==4'b1011) && (signal_len==20))?1:0);
  assign is_ack =         (((FC_type==2'b01) && (FC_subtype==4'b1101) && (signal_len==14))?1:0);

  assign ack_cts_is_ongoing = ((tx_control_state==PREP_ACK) || (tx_control_state==SEND_DFL_ACK) || (tx_control_state==SEND_BLK_ACK));
  assign ackcts_signal_parity = (~(^ackcts_rate));//because the cts and ack pkt length field is always 14: 1110 that always has 3 1s
  assign ackcts_signal_len = 14;
  assign blkack_signal_len = 32;

  assign blk_ack_req_tid = blk_ack_req_ctrl[15:12];
  assign blk_ack_req_ssn = blk_ack_req_ssc[15:4];

  // // this is not needed. we should assume the peer always send us ack @ 6Mbps
  // n_sym_len14_pkt # (
  // ) n_sym_len14_pkt_i0 (
  //   .ht_flag(signal_rate[7]),
  //   .rate_mcs(signal_rate[3:0]),
  //   .n_sym(num_data_ofdm_symbol)
  // );

  // // this is not needed. we should assume the peer always send us ack @ 6Mbps
  // n_sym_len14_pkt # (
  // ) n_sym_len14_pkt_i1 (
  //   .ht_flag(0),
  //   .rate_mcs(ackcts_rate),
  //   .n_sym(ackcts_n_sym)
  // );

	always @(posedge clk)                                             
    begin
      if (!rstn)
      // Synchronous reset (active low)                                       
        begin
          wea<=0;
          addra<=0;
          dina<=0;
          ack_timeout_count<=0;
          ack_addr <=0;
          send_ack_count <= 0;
          ack_tx_flag<=0;
          tx_control_state  <= IDLE;
          tx_control_state_old <= IDLE;
          tx_try_complete<=0;
          tx_status<=0;
          num_retrans_lock <= 0;
          blk_ack_resp_ssn_lock <= 0;
          blk_ack_bitmap_lock <= 0;
          num_retrans<=0;
          start_retrans<=0;
          start_tx_ack<=0;
          retrans_started<=0;
          retrans_in_progress<=0;
          retrans_trigger<=0;
          tx_dpram_op_counter<=0;
          recv_ack_timeout_top<=0;
          duration_new<=0;
          FC_type_new<=0;
          FC_subtype_new<=0;
          duration_received<=0;
          duration_standard<=0;
          FC_more_frag_received<=0;
          is_data_received<=0;
          is_management_received<=0;
          is_blockackreq_received<=0;
          is_pspoll_received<=0;
          is_rts_received<=0;

          rx_ht_aggr_ssn<=0;
          rx_ht_aggr_flag<=0;
          rx_ht_aggr_last_flag<=0;

          // num_data_ofdm_symbol_reg <= 0;
          // ackcts_n_sym_reg <= 0;

          bitmap_count <=0;
          reset_blk_ack_bitmap_mem <=0;

          send_ack_wait_top_scale <=0;
          send_ack_wait_top_scale_lock <=0;
          recv_ack_sig_valid_timeout_top_scale <= 0;
          recv_ack_timeout_top_adj_scale <= 0;
        end
      else begin
        tx_control_state_old<=tx_control_state;
        
        // ackcts_rate <= (cts_torts_rate[4]?signal_rate[3:0]:cts_torts_rate[3:0]); // this is not needed. we should assume the peer always send us ack @ 6Mbps
        // ackcts_rate <= 4'b1011; //6Mbps.
        ackcts_rate <= cts_torts_rate[3:0];

        // ackcts_time <= preamble_sig_time + ofdm_symbol_time*({4'd0,ackcts_n_sym_reg}); 
        ackcts_time       <= preamble_sig_time + ofdm_symbol_time*({4'd0,3'd6}); // ack/cts use 6 ofdm symbols at 6Mbps
        sifs_time_reg     <= sifs_time;
        duration_standard <= (duration_received - ackcts_time - sifs_time_reg);

        tx_status <= {blk_ack_bitmap_lock, blk_ack_resp_ssn_lock, num_retrans_lock};

        // num_data_ofdm_symbol_reg <= num_data_ofdm_symbol;
        // ackcts_n_sym_reg <= ackcts_n_sym;

        send_ack_wait_top_scale <= ((send_ack_wait_top-relative_decoding_latency)*`COUNT_SCALE);
        recv_ack_sig_valid_timeout_top_scale <= (recv_ack_sig_valid_timeout_top*`COUNT_SCALE);
        recv_ack_timeout_top_adj_scale <= (recv_ack_timeout_top_adj*`COUNT_SCALE);

        ampdu_rx_start_reg <= ampdu_rx_start;
        blk_ack_bitmap_mem <= (ampdu_rx_start_reg == 0 && ampdu_rx_start == 1)?0:blk_ack_bitmap_mem;

        case (tx_control_state)
          IDLE: begin
            ack_tx_flag<=0;
            wea<=0;
            addra<=0;
            dina<=0;
            ack_timeout_count<=0;
            send_ack_count <= 0;
            tx_try_complete<=0;
            start_retrans<=0;
            start_tx_ack<=0;
            tx_dpram_op_counter<=0;
            retrans_trigger<=0;
            recv_ack_timeout_top<=0;
            duration_new<=0;
            FC_type_new<=0;
            FC_subtype_new<=0;
            ack_addr <= addr2;
            duration_received<=(duration[15]==0?duration[14:0]:0);
            FC_more_frag_received<=FC_more_frag;
            is_data_received<=is_data;
            is_management_received<=is_management;
            is_blockackreq_received<=is_blockackreq;
            is_pspoll_received<=is_pspoll;
            is_rts_received<=is_rts;
            // tx_status<=tx_status; //maintain status from state RECV_ACK for ARM reading
            // num_retrans<=num_retrans;
            // retrans_in_progress<=retrans_in_progress;
            bitmap_count <= 0;

            // This is the last packet of aggregation and fcs valid
            if ( rx_ht_aggr_last && fcs_valid && is_qosdata && (self_mac_addr==addr1) && (ampdu_rx_tid == qos_tid || ampdu_rx_tid_disable) )
              begin
                // In case the last packet from A-MPDU makes it through
                if(rx_ht_aggr_flag == 0) begin
                    rx_ht_aggr_flag <= 1;
                    rx_ht_aggr_ssn <= SC_seq_num;
                // Sometimes, MPDUs come out-of-order (i.e. random seq_no) and in such cases, the starting sequence number should take the smallest value
                end else if(SC_seq_num < rx_ht_aggr_ssn) begin
                    rx_ht_aggr_ssn <= SC_seq_num;
                end
                blk_ack_bitmap_mem[SC_seq_num[6:0]] <= 1'b1;
                rx_ht_aggr_last_flag <= 1;
                send_ack_wait_top_scale_lock <= send_ack_wait_top_scale;
                tx_control_state <= PREP_ACK;
              end
            // This is the last packet of aggregation and fcs NOT valid
            else if ( rx_ht_aggr_last && fcs_in_strobe == 1 && fcs_valid == 0 ) 
              begin
                // Since this MPDU is not valid, only send a block ack if there were previously received valid MPDUs
                if(rx_ht_aggr_flag == 1) begin
                    rx_ht_aggr_last_flag <= 1;
                    send_ack_wait_top_scale_lock <= send_ack_wait_top_scale;
                    tx_control_state <= PREP_ACK;
                end
              end
            //8.3.1.4 ACK frame format: The RA field of the ACK frame is copied from the Address 2 field of the immediately previous individually
            //addressed data, management, BlockAckReq, BlockAck, or PS-Poll frames.
            else if ( fcs_valid && ((is_data&&(~is_qosdata))||(is_qosdata&&(~^qos_ack_policy))||is_management||is_blockackreq||is_pspoll||(is_rts&&(!cts_torts_disable)))
                           && (self_mac_addr==addr1)) // send ACK will not back to this IDLE until the last IQ sample sent.
              begin
                  if(rx_ht_aggr && (ampdu_rx_tid == qos_tid || ampdu_rx_tid_disable)) begin
                      // First packet from aggregated A-MPDU
                      if(rx_ht_aggr_flag == 0) begin
                          rx_ht_aggr_flag <= 1;
                          rx_ht_aggr_ssn <= SC_seq_num;
                      // Sometimes, MPDUs come out-of-order (i.e. random seq_no) and in such cases, the starting sequence number should take the smallest value
                      end else if(SC_seq_num < rx_ht_aggr_ssn) begin
                          rx_ht_aggr_ssn <= SC_seq_num;
                      end
                      blk_ack_bitmap_mem[SC_seq_num[6:0]] <= 1'b1;
                  end else begin
                      send_ack_wait_top_scale_lock <= send_ack_wait_top_scale;
                      tx_control_state  <= (ack_tx_disable?tx_control_state:PREP_ACK); //we also send cts (if rts is received) in PREP_ACK status
                  end
              end
            //else if ( pulse_tx_bb_end && tx_pkt_type[0]==1 && (core_state_old!=PREP_ACK) )// need to recv ACK! We need to miss this pulse_tx_bb_end intentionally when send ACK, because ACK don't need ACK
            //else if ( phy_tx_done && (core_state_old!=PREP_ACK) )// need to recv ACK! We need to miss this pulse_tx_bb_end intentionally when send ACK, because ACK don't need ACK
            else if ( phy_tx_done && cts_toself_bb_is_ongoing==0 ) // because PREP_ACK won't be back until phy_tx_done. So here phy_tx_done must be from high layer
              begin
                  retrans_started<=0;
                  if (tx_pkt_need_ack==1) // continue to actual ACK receiving
                      begin
                      tx_control_state<= RECV_ACK_WAIT_TX_BB_DONE;
                      addra<=2;
                      tx_try_complete<=0;
                      retrans_in_progress<=1;
                      end
                  else
                      begin
                      tx_try_complete<=1;
                      num_retrans_lock <= num_retrans;
                      blk_ack_resp_ssn_lock <= 0;
                      blk_ack_bitmap_lock <= 1;
                      num_retrans<=0;
                      retrans_in_progress<=0;
                      end
              end
            else if ((quit_retrans == 1) && (retrans_in_progress == 1)) 
              begin 
                  tx_try_complete<=1;
                  num_retrans_lock <= num_retrans;
                  blk_ack_resp_ssn_lock <= 0;
                  blk_ack_bitmap_lock <= 0;
                  num_retrans<=0;
                  retrans_in_progress<=0;
                  retrans_started<=0;
              end 
            else if ((backoff_done==1) && (retrans_in_progress==1) && (retrans_started==0))
              begin
                  if(quit_retrans) begin
                    tx_try_complete<=1;
                    num_retrans_lock <= num_retrans;
                    blk_ack_resp_ssn_lock <= 0;
                    blk_ack_bitmap_lock <= 0;
                    num_retrans<=0;
                    retrans_in_progress<=0;
                    retrans_started<=0;
                  end else begin
                    start_retrans <= 1 ;
                    retrans_started <= 1;
                  end
              end
          end

          PREP_ACK: begin // data is calculated by calc_phy_header C program
            if (tx_core_is_ongoing) begin
              rx_ht_aggr_flag <= 0;
              rx_ht_aggr_last_flag <= 0;
              tx_control_state  <= IDLE;
            end else begin
              ack_tx_flag<=1;
              // ack_addr <= ack_addr;
              // tx_try_complete<=tx_try_complete;
              // tx_status<=tx_status; //maintain status from state RECV_ACK for ARM reading
              // num_retrans<=num_retrans;
              // start_retrans<=start_retrans;
              // retrans_in_progress<=retrans_in_progress;
              // tx_dpram_op_counter<=tx_dpram_op_counter;
              // recv_ack_timeout_top<=recv_ack_timeout_top;

              FC_type_new<=2'b01;
              if ((rx_ht_aggr_last_flag && (ampdu_rx_tid == qos_tid || ampdu_rx_tid_disable)) || (is_blockackreq_received && (ampdu_rx_tid == blk_ack_req_tid || ampdu_rx_tid_disable))) begin
                duration_new<= duration_extra+0;
                FC_subtype_new<=4'b1001;

                // Prepare block ack response bitmap
                if(rx_ht_aggr_last_flag) begin
                    blk_ack_bitmap_lock[bitmap_count[5:0]] <= blk_ack_bitmap_mem[(rx_ht_aggr_ssn[6:0]+bitmap_count)];
                    // Clear past bitmap history
                    if(bitmap_count < 32)
                        blk_ack_bitmap_mem[(rx_ht_aggr_ssn[6:0]+bitmap_count+7'd64)] <= 0;
                end else begin
                    blk_ack_bitmap_lock[bitmap_count[5:0]] <= blk_ack_bitmap_mem[(blk_ack_req_ssn[6:0]+bitmap_count)];
                    // Clear past bitmap history
                    if(bitmap_count < 32)
                        blk_ack_bitmap_mem[(blk_ack_req_ssn[6:0]+bitmap_count+7'd64)] <= 0;
                end
                if(bitmap_count < 63)
                    bitmap_count <= bitmap_count + 1;

              //standard: For ACK frames sent by non-QoS STAs, if the More Fragments bit was equal to 0 in the Frame Control field
              //of the immediately previous individually addressed data or management frame, the duration value is set to 0.
              end else begin
                FC_subtype_new <= (is_rts_received?(4'b1100):(4'b1101));

                //standard: In other ACK frames sent by non-QoS STAs, the duration value is the value obtained from the Duration/ID
                //field of the immediately previous data, management, PS-Poll, BlockAckReq, or BlockAck frame minus the
                //time, in microseconds, required to transmit the ACK frame and its SIFS interval.
                //we use 6M for ack(14byte): n_ofdm=6=(22+14*8)/24; time_us=20(preamble+SIGNAL)+6*4=44;
                if ( ((is_data_received||is_management_received)&&(FC_more_frag_received==1)) || is_rts_received ) begin
                  duration_new<= duration_extra+((duration_standard<=0)?0:duration_standard);
                end else begin //pspoll doesn't carry duration. instead it carries AID. no sense to calculate duration based on AID
                  duration_new<=duration_extra+0;
                end
              end

              ack_timeout_count <= ( ( ack_timeout_count != send_ack_wait_top_scale_lock )?(ack_timeout_count + 1):ack_timeout_count );
              tx_control_state  <= ( ( ack_timeout_count != send_ack_wait_top_scale_lock )?tx_control_state:((rx_ht_aggr_last_flag||is_blockackreq_received) ? SEND_BLK_ACK : SEND_DFL_ACK) );
              start_tx_ack <= ( ( ack_timeout_count != send_ack_wait_top_scale_lock )? 0:1);
            end
          end

          SEND_DFL_ACK: begin
            //send_ack_count <= ( send_ack_count!=4?(send_ack_count + 1):send_ack_count );
            // wea <= (send_ack_count<4?1:0);
            start_tx_ack <= 0; //wea <= 1; // replace wea by start_tx_ack, start_tx_ack is only one clock
            //addra <= send_ack_count; // no longer need addra, directly output to the tx core
            tx_control_state <=  (phy_tx_done?IDLE:tx_control_state);
            if(bram_addr==0) begin//if (send_ack_count==0) begin
                //dina<={32'h0, 32'h000001cb}; // rate 6M len 14
                dina<={32'h0, 14'd0, ackcts_signal_parity, ackcts_signal_len, 1'b0, ackcts_rate};
            end else if (bram_addr==2) begin//(send_ack_count==2) begin
                //dina<={ack_addr[31:0], 32'h000000d4};
                dina<={ack_addr[31:0], duration_new, 8'd0, FC_subtype_new, FC_type_new, 2'd0};
            end else if (bram_addr==3) begin//(send_ack_count==3) begin
                dina<={48'h0,ack_addr[47:32]};
            end
          end

          SEND_BLK_ACK: begin
            start_tx_ack <= 0;
            tx_control_state <= (phy_tx_done?IDLE:tx_control_state);
            rx_ht_aggr_flag <= (phy_tx_done?0:rx_ht_aggr_flag);
            rx_ht_aggr_last_flag <= (phy_tx_done?0:rx_ht_aggr_last_flag);
            if(bram_addr==0) begin
                dina<={32'h0, 14'd0, ackcts_signal_parity, blkack_signal_len, 1'b0, ackcts_rate};		// block ack and normal ack have identical signal parity and bit rate
            end else if (bram_addr==2) begin
                dina<={ack_addr[31:0], duration_new, 8'd0, FC_subtype_new, FC_type_new, 2'd0};
            end else if (bram_addr==3) begin
                dina<={self_mac_addr,ack_addr[47:32]};
            end else if (bram_addr==4) begin
                if(rx_ht_aggr_last_flag) begin
                    dina<={blk_ack_bitmap_lock[31:0], rx_ht_aggr_ssn, ampdu_rx_tid_disable?qos_tid:ampdu_rx_tid, 4'd0, 7'd0, 4'b0010, 1'd0};
                end else begin
                    dina<={blk_ack_bitmap_lock[31:0], blk_ack_req_ssn, ampdu_rx_tid_disable?blk_ack_req_tid:ampdu_rx_tid, 4'd0, 7'd0, 4'b0010, 1'd0};
                end
            end else if (bram_addr==5) begin
                dina<={32'h0, blk_ack_bitmap_lock[63:32]};
            end
          end

          RECV_ACK_WAIT_TX_BB_DONE: begin
            // ack_tx_flag<=ack_tx_flag;
            // recv_ack_timeout_top<=recv_ack_timeout_top;

            // addra<=addra;

            tx_dpram_op_counter <= ( tx_dpram_op_counter!=3?(tx_dpram_op_counter + 1):tx_dpram_op_counter );
            if(tx_ht_aggr==0 && tx_dpram_op_counter==2) begin
                wea <= 1;
                dina <= {douta[63:12], 1'b1, douta[10:0]};
            end else begin
                wea <= 0;
                dina <= douta;
            end

            // send_ack_count <= send_ack_count;
            // ack_addr <= ack_addr;
            // ack_timeout_count<=ack_timeout_count;
            // // tx_status<=tx_status; //maintain status from state RECV_ACK for ARM reading
            // num_retrans<=num_retrans;
            // tx_try_complete<=tx_try_complete;
            // start_retrans<=start_retrans;
            // retrans_in_progress<=retrans_in_progress;

            if (pulse_tx_bb_end) begin
                tx_control_state<= RECV_ACK_WAIT_SIG_VALID;
            end 
            // else begin
            //     tx_control_state<= tx_control_state;
            // end
            
          end

          RECV_ACK_WAIT_SIG_VALID: begin
            // ack_tx_flag<=ack_tx_flag;
            // wea<=wea;
            // addra<=addra;
            // dina<=dina;
            // send_ack_count <= send_ack_count;
            // ack_addr <= ack_addr;
            // tx_dpram_op_counter<=tx_dpram_op_counter;
            // recv_ack_timeout_top<=recv_ack_timeout_top;

            ack_timeout_count<= ( (sig_valid && (signal_len==14||signal_len==32))?0:(ack_timeout_count+1) );
            if ( (ack_timeout_count<recv_ack_sig_valid_timeout_top_scale) && sig_valid && (signal_len==14||signal_len==32) ) begin //before timeout, we detect a sig valid, signal length field is ACK/BLK_ACK
                tx_control_state<= RECV_ACK;
                // tx_try_complete<=tx_try_complete;
                // tx_status<=tx_status;
                // num_retrans<=num_retrans;
                // start_retrans<=start_retrans;
                // retrans_in_progress<=retrans_in_progress;
                // ack_timeout_count<=0;
                if(signal_len==14)
                   recv_ack_timeout_top <= (({4'd6, 2'd0})*`NUM_CLK_PER_US)+recv_ack_timeout_top_adj_scale;	// ack/cts uses 6 ofdm symbols at 6Mbps
                else if(signal_len==32)
                   recv_ack_timeout_top <= (({4'd12,2'd0})*`NUM_CLK_PER_US)+recv_ack_timeout_top_adj_scale;	// blk_ack_resp uses 12 ofdm symbols at 6Mbps
            end else if ( ack_timeout_count==recv_ack_sig_valid_timeout_top_scale ) begin // sig valid timeout
                tx_control_state<= IDLE;
                if  ((num_retrans==retrans_limit) || (retrans_limit==0)) begin// should not run into this state. but just in case
                    tx_try_complete<=1;
                    // tx_status<={1'b1,num_retrans};
                    num_retrans_lock <= num_retrans;
                    blk_ack_resp_ssn_lock <= 0;
                    blk_ack_bitmap_lock <= 0;
                    num_retrans<=0;
                    // start_retrans<=start_retrans;
                    retrans_in_progress<=0;
                end else begin
                    // tx_try_complete<=tx_try_complete;
                    // tx_status<=tx_status;
                    num_retrans<=num_retrans+1;
                    retrans_trigger<=1;// start retransmission if ack did not arrive in time --
                    // retrans_in_progress<=retrans_in_progress;
                end
            end 
            // else begin
            //     tx_control_state<= tx_control_state;
            //     tx_try_complete<=tx_try_complete;
            //     // tx_status<=tx_status; //maintain status from state RECV_ACK for ARM reading
            //     num_retrans<=num_retrans;
            //     start_retrans<=start_retrans;
            //     retrans_in_progress<=retrans_in_progress;
            // end
          end

          RECV_ACK: begin
            // ack_tx_flag<=ack_tx_flag;
            // wea<=wea;
            // addra<=addra;
            // dina<=dina;
            // send_ack_count <= send_ack_count;
            // ack_addr <= ack_addr;
            // tx_dpram_op_counter<=tx_dpram_op_counter;
            // recv_ack_timeout_top <= recv_ack_timeout_top;

            ack_timeout_count<=ack_timeout_count+1;
            // Detection of a normal ack packet is sufficient to acknowledge a traffic. However for aggregation traffic, a valid block ack response is required.
            if ( (ack_timeout_count<recv_ack_timeout_top) && (((recv_ack_fcs_valid_disable|fcs_in_strobe) && is_ack) || (fcs_valid && is_blockackresp)) && (self_mac_addr==addr1)) begin//before timeout, we detect a ACK type frame fcs valid
                tx_control_state<= IDLE;
                tx_try_complete<=1;
                // tx_status<={1'b0,num_retrans};
                num_retrans_lock <= num_retrans;
                if (is_blockackresp) begin
                    blk_ack_resp_ssn_lock <= blk_ack_resp_ssn;
                    blk_ack_bitmap_lock <= blk_ack_resp_bitmap;
                end else begin
                    blk_ack_resp_ssn_lock <= 0;
                    blk_ack_bitmap_lock <= 1;
                end
                num_retrans<=0;
                // start_retrans<=start_retrans;
                retrans_in_progress<=0;
            end else if ( ack_timeout_count==recv_ack_timeout_top ) begin// timeout
                tx_control_state<= IDLE;
                if  ((num_retrans==retrans_limit) || (retrans_limit==0)) begin// should not run into this state. but just in case
                    tx_try_complete<=1;
                    // tx_status<={1'b1,num_retrans};
                    num_retrans_lock <= num_retrans;
                    blk_ack_resp_ssn_lock <= 0;
                    blk_ack_bitmap_lock <= 0;
                    num_retrans<=0;
                    // start_retrans<=start_retrans;
                    retrans_in_progress<=0;
                end else begin
                    // tx_try_complete<=tx_try_complete;
                    // tx_status<=tx_status;
                    num_retrans<=num_retrans+1;
                    retrans_trigger<=1; // start retranmission if ack did not receive in time -- 
                    // retrans_in_progress<=retrans_in_progress;
                end
            end 
            // else begin
            //     tx_control_state<= tx_control_state;
            //     tx_try_complete<=tx_try_complete;
            //     // tx_status<=tx_status; //maintain status from state RECV_ACK for ARM reading
            //     num_retrans<=num_retrans;
            //     start_retrans<=start_retrans;
            //     retrans_in_progress<=retrans_in_progress;
            // end

          end

        endcase
      end
    end

	endmodule
