module ntt46_zero_pad_n1024_multicin_conv_tile #(
  parameter string TWIDDLE_FWD_MEM =
    "./rom/zero_pad_p520_schedule/twiddle_fwd_1024.mem",
  parameter string TWIDDLE_INV_MEM =
    "./rom/zero_pad_p520_schedule/twiddle_inv_1024.mem"
) (
  input  logic                                 clk,
  input  logic                                 rst,
  input  logic                                 start,
  input  logic [2:0]                           cfg_cin,
  input  logic                                 x_batch_load_en,
  input  logic [2:0]                           x_batch_load_idx,
  input  logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] x_batch_load_data,
  input  logic                                 h_batch_load_en,
  input  logic [2:0]                           h_batch_load_idx,
  input  logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] h_batch_load_data,
  output logic                                 reload_batch_req_valid,
  output logic [1:0]                           reload_batch_req_chan,
  output logic [2:0]                           reload_batch_req_idx,
  input  logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] x_batch_reload_data,
  input  logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] h_batch_reload_data,
  output logic                                 final_batch_valid,
  output logic [2:0]                           final_batch_idx,
  output logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] final_batch_data,
  output logic                                 busy,
  output logic                                 done,
  output logic [15:0]                          compute_cycles
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  localparam int WORD_W = 4 * MREC_DATA_W;
  localparam int VEC_W = 32 * MREC_DATA_W;
  localparam int BATCH_W = 4 * VEC_W;
  localparam int BATCHES = 8;
  localparam int MAC_LAT = 4;
  localparam int MAC_LANES = 16;
  localparam int MAC_OPS = BATCHES * 4 * (32 / MAC_LANES);
  localparam logic [6:0] MAC_OPS_COUNT = MAC_OPS;

  typedef enum logic [3:0] {
    S_IDLE,
    S_FWD,
    S_MAC_READ,
    S_MAC_ISSUE,
    S_MAC_DRAIN,
    S_NEXT_LOAD_REQ,
    S_NEXT_LOAD_CAP,
    S_NEXT_FWD_START,
    S_INV
  } state_t;

  state_t state_q;
  logic done_q;
  logic [15:0] compute_cycles_q;
  logic [2:0] cin_count_q;
  logic [1:0] channel_q;
  logic [2:0] reload_batch_q;

  logic fwd_start_c;
  logic x_bidir_start_c;
  logic x_bidir_inverse_c;
  logic x_bidir_valid;
  logic [2:0] x_bidir_idx;
  logic [BATCH_W-1:0] x_bidir_data;
  logic x_bidir_done;
  logic inv_done;
  logic h_fwd_valid;
  logic [2:0] h_fwd_idx;
  logic [BATCH_W-1:0] h_fwd_data;
  logic h_fwd_done;

  logic x_core_load_en_c;
  logic [2:0] x_core_load_idx_c;
  logic [BATCH_W-1:0] x_core_load_data_c;
  logic h_core_load_en_c;
  logic [2:0] h_core_load_idx_c;
  logic [BATCH_W-1:0] h_core_load_data_c;

  logic inv_start_q;
  logic inv_slot_load_en_c;
  logic [2:0] inv_slot_load_idx_c;
  logic [1:0] inv_slot_load_slot_c;
  logic [VEC_W-1:0] inv_slot_load_data_c;

  logic [3:0] x_spec_wr_en [0:31];
  logic [2:0] x_spec_wr_addr [0:31];
  mrec_res_t x_spec_wr_data [0:31][0:3];
  logic x_spec_rd_en;
  logic [2:0] x_spec_rd_addr [0:31];
  logic [WORD_W-1:0] x_spec_rd_word [0:31];

  logic [3:0] h_spec_wr_en [0:31];
  logic [2:0] h_spec_wr_addr [0:31];
  mrec_res_t h_spec_wr_data [0:31][0:3];
  logic h_spec_rd_en;
  logic [2:0] h_spec_rd_addr [0:31];
  logic [WORD_W-1:0] h_spec_rd_word [0:31];

  logic [3:0] acc_spec_wr_en [0:31];
  logic [2:0] acc_spec_wr_addr [0:31];
  mrec_res_t acc_spec_wr_data [0:31][0:3];
  logic acc_spec_rd_en;
  logic [2:0] acc_spec_rd_addr [0:31];
  logic [WORD_W-1:0] acc_spec_rd_word [0:31];

  logic spec_rd_en_c;
  logic [2:0] spec_rd_batch_c;
  logic mac_in_valid_c;
  logic [2:0] mac_batch_q;
  logic [1:0] mac_slot_q;
  logic mac_half_q;
  logic [6:0] mac_issued_count_q;
  logic [6:0] mac_loaded_count_q;
  logic [2:0] mac_batch_pipe_q [0:MAC_LAT-1];
  logic [1:0] mac_slot_pipe_q [0:MAC_LAT-1];
  logic mac_half_pipe_q [0:MAC_LAT-1];
  logic [MAC_LAT-1:0] mac_tag_valid_q;
  logic mac_out_valid;
  logic mac_clear_accum_c;
  mrec_res_t mac_x_vec [0:MAC_LANES-1];
  mrec_res_t mac_h_vec [0:MAC_LANES-1];
  mrec_res_t mac_accum_in [0:MAC_LANES-1];
  mrec_res_t mac_accum_out [0:MAC_LANES-1];
  mrec_res_t inv_slot_half_data_q [0:31];

  assign busy = (state_q != S_IDLE);
  assign done = done_q;
  assign compute_cycles = compute_cycles_q;
  assign reload_batch_req_valid = (state_q == S_NEXT_LOAD_REQ);
  assign reload_batch_req_chan = channel_q;
  assign reload_batch_req_idx = reload_batch_q;
  assign fwd_start_c = ((state_q == S_IDLE) && start) || (state_q == S_NEXT_FWD_START);
  assign x_bidir_start_c = fwd_start_c || inv_start_q;
  assign x_bidir_inverse_c = (state_q == S_INV);
  assign final_batch_valid = (state_q == S_INV) && x_bidir_valid;
  assign final_batch_idx = x_bidir_idx;
  assign final_batch_data = x_bidir_data;
  assign inv_done = (state_q == S_INV) && x_bidir_done;
  assign x_core_load_en_c = ((state_q == S_IDLE) && x_batch_load_en) || (state_q == S_NEXT_LOAD_CAP);
  assign x_core_load_idx_c = (state_q == S_NEXT_LOAD_CAP) ? reload_batch_q : x_batch_load_idx;
  assign x_core_load_data_c = (state_q == S_NEXT_LOAD_CAP) ? x_batch_reload_data : x_batch_load_data;
  assign h_core_load_en_c = ((state_q == S_IDLE) && h_batch_load_en) || (state_q == S_NEXT_LOAD_CAP);
  assign h_core_load_idx_c = (state_q == S_NEXT_LOAD_CAP) ? reload_batch_q : h_batch_load_idx;
  assign h_core_load_data_c = (state_q == S_NEXT_LOAD_CAP) ? h_batch_reload_data : h_batch_load_data;
  assign mac_clear_accum_c = (channel_q == 2'd0);

  ntt46_mrec_radix4_bidir_core_n1024 #(
    .TWIDDLE_FWD_MEM(TWIDDLE_FWD_MEM),
    .TWIDDLE_INV_MEM(TWIDDLE_INV_MEM)
  ) u_x_bidir (
    .clk(clk),
    .rst(rst),
    .start(x_bidir_start_c),
    .inverse(x_bidir_inverse_c),
    .batch_slot_load_en(inv_slot_load_en_c),
    .batch_slot_load_idx(inv_slot_load_idx_c),
    .batch_slot_load_slot(inv_slot_load_slot_c),
    .batch_slot_load_data(inv_slot_load_data_c),
    .batch_load_en(x_core_load_en_c),
    .batch_load_idx(x_core_load_idx_c),
    .batch_load_data(x_core_load_data_c),
    .final_batch_valid(x_bidir_valid),
    .final_batch_idx(x_bidir_idx),
    .final_batch_data(x_bidir_data),
    .busy(),
    .done(x_bidir_done)
  );

  ntt46_mrec_radix4_forward_core_n1024 #(
    .TWIDDLE_FWD_MEM(TWIDDLE_FWD_MEM)
  ) u_h_fwd (
    .clk(clk),
    .rst(rst),
    .start(fwd_start_c),
    .batch_slot_load_en(1'b0),
    .batch_slot_load_idx('0),
    .batch_slot_load_slot('0),
    .batch_slot_load_data('0),
    .batch_load_en(h_core_load_en_c),
    .batch_load_idx(h_core_load_idx_c),
    .batch_load_data(h_core_load_data_c),
    .final_batch_valid(h_fwd_valid),
    .final_batch_idx(h_fwd_idx),
    .final_batch_data(h_fwd_data),
    .busy(),
    .done(h_fwd_done)
  );

  ntt46_mrec_radix4_slot32_store_sameaddr #(
    .DEPTH(8)
  ) u_x_spec_store (
    .clk(clk),
    .wr_en(x_spec_wr_en),
    .wr_addr(x_spec_wr_addr),
    .wr_data(x_spec_wr_data),
    .rd_en(x_spec_rd_en),
    .rd_addr(x_spec_rd_addr),
    .rd_word(x_spec_rd_word)
  );

  ntt46_mrec_radix4_slot32_store_sameaddr #(
    .DEPTH(8)
  ) u_h_spec_store (
    .clk(clk),
    .wr_en(h_spec_wr_en),
    .wr_addr(h_spec_wr_addr),
    .wr_data(h_spec_wr_data),
    .rd_en(h_spec_rd_en),
    .rd_addr(h_spec_rd_addr),
    .rd_word(h_spec_rd_word)
  );

  ntt46_mrec_radix4_slot32_store_sameaddr #(
    .DEPTH(8)
  ) u_acc_spec_store (
    .clk(clk),
    .wr_en(acc_spec_wr_en),
    .wr_addr(acc_spec_wr_addr),
    .wr_data(acc_spec_wr_data),
    .rd_en(acc_spec_rd_en),
    .rd_addr(acc_spec_rd_addr),
    .rd_word(acc_spec_rd_word)
  );

  ntt46_mrec_spectral_mac32_pipe #(
    .LANES(MAC_LANES)
  ) u_mac (
    .clk(clk),
    .rst(rst),
    .in_valid(mac_in_valid_c),
    .clear_accum(mac_clear_accum_c),
    .x_in(mac_x_vec),
    .h_in(mac_h_vec),
    .accum_in(mac_accum_in),
    .out_valid(mac_out_valid),
    .accum_out(mac_accum_out)
  );

  always_comb begin
    spec_rd_en_c = (state_q == S_MAC_READ)
                || ((state_q == S_MAC_ISSUE) && mac_half_q && (mac_slot_q == 2'd3) && (mac_batch_q != 3'd7));
    spec_rd_batch_c = (state_q == S_MAC_READ) ? mac_batch_q : (mac_batch_q + 3'd1);
    mac_in_valid_c = (state_q == S_MAC_ISSUE);

    x_spec_rd_en = spec_rd_en_c;
    h_spec_rd_en = spec_rd_en_c;
    acc_spec_rd_en = spec_rd_en_c && (channel_q != 2'd0);
    for (int bank = 0; bank < 32; bank++) begin
      x_spec_rd_addr[bank] = spec_rd_batch_c;
      h_spec_rd_addr[bank] = spec_rd_batch_c;
      acc_spec_rd_addr[bank] = spec_rd_batch_c;
    end

    for (int lane = 0; lane < MAC_LANES; lane++) begin
      int bank;
      bank = lane + (mac_half_q ? MAC_LANES : 0);
      mac_x_vec[lane] = x_spec_rd_word[bank][(mac_slot_q * MREC_DATA_W) +: MREC_DATA_W];
      mac_h_vec[lane] = h_spec_rd_word[bank][(mac_slot_q * MREC_DATA_W) +: MREC_DATA_W];
      mac_accum_in[lane] = (channel_q != 2'd0)
                          ? acc_spec_rd_word[bank][(mac_slot_q * MREC_DATA_W) +: MREC_DATA_W]
                          : '0;
    end

    for (int lane = 0; lane < 32; lane++) begin
      if (lane < MAC_LANES) begin
        inv_slot_load_data_c[(lane * MREC_DATA_W) +: MREC_DATA_W] = inv_slot_half_data_q[lane];
      end else begin
        inv_slot_load_data_c[(lane * MREC_DATA_W) +: MREC_DATA_W] = mac_accum_out[lane-MAC_LANES];
      end
    end

    inv_slot_load_en_c = mac_out_valid && mac_half_pipe_q[MAC_LAT-1]
                           && ({1'b0, channel_q} == (cin_count_q - 3'd1));
    inv_slot_load_idx_c = mac_batch_pipe_q[MAC_LAT-1];
    inv_slot_load_slot_c = mac_slot_pipe_q[MAC_LAT-1];
  end

  always_comb begin
    for (int bank = 0; bank < 32; bank++) begin
      x_spec_wr_en[bank] = '0;
      h_spec_wr_en[bank] = '0;
      x_spec_wr_addr[bank] = '0;
      h_spec_wr_addr[bank] = '0;
      for (int slot = 0; slot < 4; slot++) begin
        x_spec_wr_data[bank][slot] = '0;
        h_spec_wr_data[bank][slot] = '0;
      end

      if ((state_q == S_FWD) && x_bidir_valid) begin
        x_spec_wr_en[bank] = 4'b1111;
        x_spec_wr_addr[bank] = x_bidir_idx;
        for (int slot = 0; slot < 4; slot++) begin
          x_spec_wr_data[bank][slot] = x_bidir_data[((slot * 32 + bank) * MREC_DATA_W) +: MREC_DATA_W];
        end
      end

      if (h_fwd_valid) begin
        h_spec_wr_en[bank] = 4'b1111;
        h_spec_wr_addr[bank] = h_fwd_idx;
        for (int slot = 0; slot < 4; slot++) begin
          h_spec_wr_data[bank][slot] = h_fwd_data[((slot * 32 + bank) * MREC_DATA_W) +: MREC_DATA_W];
        end
      end
    end
  end

  always_comb begin
    for (int bank = 0; bank < 32; bank++) begin
      acc_spec_wr_en[bank] = '0;
      acc_spec_wr_addr[bank] = '0;
      for (int slot = 0; slot < 4; slot++) begin
        acc_spec_wr_data[bank][slot] = '0;
      end

      if (mac_out_valid && ({1'b0, channel_q} != (cin_count_q - 3'd1))) begin
        for (int lane = 0; lane < MAC_LANES; lane++) begin
          int wr_bank;
          wr_bank = lane + (mac_half_pipe_q[MAC_LAT-1] ? MAC_LANES : 0);
          if (bank == wr_bank) begin
            acc_spec_wr_en[bank][mac_slot_pipe_q[MAC_LAT-1]] = 1'b1;
            acc_spec_wr_addr[bank] = mac_batch_pipe_q[MAC_LAT-1];
            acc_spec_wr_data[bank][mac_slot_pipe_q[MAC_LAT-1]] = mac_accum_out[lane];
          end
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      done_q <= 1'b0;
      compute_cycles_q <= '0;
      cin_count_q <= 3'd1;
      channel_q <= 2'd0;
      reload_batch_q <= '0;
      inv_start_q <= 1'b0;
      mac_batch_q <= '0;
      mac_slot_q <= '0;
      mac_half_q <= 1'b0;
      mac_issued_count_q <= '0;
      mac_loaded_count_q <= '0;
      mac_tag_valid_q <= '0;
      for (int idx = 0; idx < MAC_LAT; idx++) begin
        mac_batch_pipe_q[idx] <= '0;
        mac_slot_pipe_q[idx] <= '0;
        mac_half_pipe_q[idx] <= 1'b0;
      end
      for (int lane = 0; lane < 32; lane++) begin
        inv_slot_half_data_q[lane] <= '0;
      end
    end else begin
      done_q <= 1'b0;
      inv_start_q <= 1'b0;

      if (state_q != S_IDLE) begin
        compute_cycles_q <= compute_cycles_q + 16'd1;
      end

      mac_tag_valid_q[0] <= mac_in_valid_c;
      mac_batch_pipe_q[0] <= mac_batch_q;
      mac_slot_pipe_q[0] <= mac_slot_q;
      mac_half_pipe_q[0] <= mac_half_q;
      for (int idx = 1; idx < MAC_LAT; idx++) begin
        mac_tag_valid_q[idx] <= mac_tag_valid_q[idx-1];
        mac_batch_pipe_q[idx] <= mac_batch_pipe_q[idx-1];
        mac_slot_pipe_q[idx] <= mac_slot_pipe_q[idx-1];
        mac_half_pipe_q[idx] <= mac_half_pipe_q[idx-1];
      end

      if (mac_in_valid_c) begin
        mac_issued_count_q <= mac_issued_count_q + 7'd1;
      end
      if (mac_out_valid) begin
        mac_loaded_count_q <= mac_loaded_count_q + 7'd1;
        for (int lane = 0; lane < MAC_LANES; lane++) begin
          int out_bank;
          out_bank = lane + (mac_half_pipe_q[MAC_LAT-1] ? MAC_LANES : 0);
          inv_slot_half_data_q[out_bank] <= mac_accum_out[lane];
        end
      end

      unique case (state_q)
        S_IDLE: begin
          mac_batch_q <= '0;
          mac_slot_q <= '0;
          mac_half_q <= 1'b0;
          mac_issued_count_q <= '0;
          mac_loaded_count_q <= '0;
          mac_tag_valid_q <= '0;
          if (start) begin
            compute_cycles_q <= '0;
            cin_count_q <= cfg_cin;
            channel_q <= 2'd0;
            reload_batch_q <= '0;
            state_q <= S_FWD;
          end
        end

        S_FWD: begin
          if (x_bidir_done && h_fwd_done) begin
            state_q <= S_MAC_READ;
            mac_batch_q <= 3'd0;
            mac_slot_q <= 2'd0;
            mac_half_q <= 1'b0;
            mac_issued_count_q <= '0;
            mac_loaded_count_q <= '0;
          end
        end

        S_MAC_READ: begin
          state_q <= S_MAC_ISSUE;
          mac_slot_q <= 2'd0;
          mac_half_q <= 1'b0;
        end

        S_MAC_ISSUE: begin
          if ((mac_batch_q == 3'd7) && (mac_slot_q == 2'd3) && mac_half_q) begin
            state_q <= S_MAC_DRAIN;
          end else if (!mac_half_q) begin
            mac_half_q <= 1'b1;
          end else if (mac_slot_q == 2'd3) begin
            mac_batch_q <= mac_batch_q + 3'd1;
            mac_slot_q <= 2'd0;
            mac_half_q <= 1'b0;
          end else begin
            mac_slot_q <= mac_slot_q + 2'd1;
            mac_half_q <= 1'b0;
          end
        end

        S_MAC_DRAIN: begin
          if ((mac_loaded_count_q + (mac_out_valid ? 7'd1 : 7'd0)) == MAC_OPS_COUNT) begin
            if (({1'b0, channel_q} + 3'd1) < cin_count_q) begin
              channel_q <= channel_q + 2'd1;
              reload_batch_q <= '0;
              state_q <= S_NEXT_LOAD_REQ;
            end else begin
              state_q <= S_INV;
              inv_start_q <= 1'b1;
            end
          end
        end

        S_NEXT_LOAD_REQ: begin
          state_q <= S_NEXT_LOAD_CAP;
        end

        S_NEXT_LOAD_CAP: begin
          if (reload_batch_q == 3'd7) begin
            state_q <= S_NEXT_FWD_START;
            reload_batch_q <= '0;
          end else begin
            reload_batch_q <= reload_batch_q + 3'd1;
            state_q <= S_NEXT_LOAD_REQ;
          end
        end

        S_NEXT_FWD_START: begin
          state_q <= S_FWD;
          mac_batch_q <= '0;
          mac_slot_q <= '0;
          mac_half_q <= 1'b0;
          mac_issued_count_q <= '0;
          mac_loaded_count_q <= '0;
          mac_tag_valid_q <= '0;
        end

        S_INV: begin
          if (inv_done) begin
            state_q <= S_IDLE;
            done_q <= 1'b1;
          end
        end

        default: begin
          state_q <= S_IDLE;
        end
      endcase
    end
  end

endmodule
