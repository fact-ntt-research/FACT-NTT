module ntt46_zero_pad_p520_n1024_local_core (
  input  logic               clk,
  input  logic               rst,
  input  logic               start,
  input  logic [8:0]         cfg_nh,
  input  logic [2:0]         cfg_cin,
  input  logic               preload_valid,
  input  logic               preload_is_h,
  input  logic [1:0]         preload_cin,
  input  logic [8:0]         preload_idx,
  input  logic signed [18:0] preload_data,
  input  logic               y_read_en,
  input  logic [9:0]         y_read_idx,
  output logic               y_read_valid,
  output logic signed [31:0] y_read_data,
  output logic               busy,
  output logic               done,
  output logic               cfg_error,
  output logic [15:0]        compute_cycles
);

  import ntt46_mrec_params_pkg::*;
  import ntt46_mrec_arith_pkg::*;

  localparam int WORD_W = 32 * MREC_DATA_W;
  localparam int BATCH_W = 4 * WORD_W;

  typedef enum logic [1:0] {S_IDLE, S_LOAD_CH0, S_START_TILE, S_RUN} state_t;
  state_t state_q;
  logic [8:0] nh_q;
  logic [2:0] cin_q;
  logic [2:0] load_batch_q;
  logic tile_start;
  logic tile_done;
  logic [15:0] tile_compute_cycles;
  logic tile_final_valid;
  logic [2:0] tile_final_idx;
  logic [BATCH_W-1:0] tile_final_data;
  logic tile_reload_valid;
  logic [1:0] tile_reload_chan;
  logic [2:0] tile_reload_idx;

  logic [WORD_W-1:0] x_block0 [0:3];
  logic [WORD_W-1:0] x_block1 [0:3];
  logic [WORD_W-1:0] h_block0 [0:3];
  logic [WORD_W-1:0] h_block1 [0:3];
  logic [BATCH_W-1:0] ch0_x_batch;
  logic [BATCH_W-1:0] ch0_h_batch;
  logic [BATCH_W-1:0] reload_x_batch;
  logic [BATCH_W-1:0] reload_h_batch;
  logic [2:0] store_rd_word_idx;
  mrec_res_t preload_residue;

  logic [WORD_W-1:0] result_word [0:3];
  logic [WORD_W-1:0] selected_result_word;
  logic [WORD_W-1:0] read_word_q;
  logic [4:0] read_lane_q;
  logic read_word_valid_q;
  mrec_res_t read_raw_q;
  logic read_raw_valid_q;
  mrec_res_t read_scaled;
  logic read_scaled_valid;

  assign busy = (state_q != S_IDLE);
  assign compute_cycles = tile_compute_cycles;
  assign tile_start = (state_q == S_START_TILE);
  assign store_rd_word_idx = (state_q == S_LOAD_CH0) ? load_batch_q : tile_reload_idx;
  assign preload_residue = preload_data[18] ? mrec_res_t'(MREC_P + preload_data) : mrec_res_t'(preload_data);

  generate
    for (genvar channel = 0; channel < 4; channel++) begin : g_input_store
      ntt46_mrec_direct_input_channel_store #(.WORDS(8)) u_x_store (
        .clk(clk),
        .rst(rst),
        .clear(1'b0),
        .wr_scalar_en(preload_valid && !preload_is_h && (preload_cin == channel[1:0])),
        .wr_block_idx(preload_idx[8]),
        .wr_word_idx(preload_idx[7:5]),
        .wr_lane_idx(preload_idx[4:0]),
        .wr_scalar_data(preload_residue),
        .rd_word_idx(store_rd_word_idx),
        .rd_block0_word(x_block0[channel]),
        .rd_block1_word(x_block1[channel])
      );

      ntt46_mrec_direct_input_channel_store #(.WORDS(8)) u_h_store (
        .clk(clk),
        .rst(rst),
        .clear(1'b0),
        .wr_scalar_en(preload_valid && preload_is_h && (preload_cin == channel[1:0])),
        .wr_block_idx(preload_idx[8]),
        .wr_word_idx(preload_idx[7:5]),
        .wr_lane_idx(preload_idx[4:0]),
        .wr_scalar_data(preload_residue),
        .rd_word_idx(store_rd_word_idx),
        .rd_block0_word(h_block0[channel]),
        .rd_block1_word(h_block1[channel])
      );
    end
  endgenerate

  function automatic logic [BATCH_W-1:0] make_x_batch(input logic [1:0] channel);
    logic [BATCH_W-1:0] value;
    begin
      value = '0;
      value[0 +: WORD_W] = x_block0[channel];
      value[WORD_W +: WORD_W] = x_block1[channel];
      return value;
    end
  endfunction

  function automatic logic [BATCH_W-1:0] make_h_batch(input logic [1:0] channel);
    logic [BATCH_W-1:0] value;
    int pos0;
    int pos1;
    begin
      value = '0;
      for (int lane = 0; lane < 32; lane++) begin
        pos0 = (store_rd_word_idx * 32) + lane;
        pos1 = 256 + (store_rd_word_idx * 32) + lane;
        if (pos0 < nh_q) value[(lane * MREC_DATA_W) +: MREC_DATA_W] = h_block0[channel][(lane * MREC_DATA_W) +: MREC_DATA_W];
        if (pos1 < nh_q) value[WORD_W + (lane * MREC_DATA_W) +: MREC_DATA_W] = h_block1[channel][(lane * MREC_DATA_W) +: MREC_DATA_W];
      end
      return value;
    end
  endfunction

  always_comb begin
    ch0_x_batch = make_x_batch(2'd0);
    ch0_h_batch = make_h_batch(2'd0);
    reload_x_batch = make_x_batch(tile_reload_chan);
    reload_h_batch = make_h_batch(tile_reload_chan);
  end

  ntt46_zero_pad_n1024_multicin_conv_tile u_tile (
    .clk(clk),
    .rst(rst),
    .start(tile_start),
    .cfg_cin(cin_q),
    .x_batch_load_en(state_q == S_LOAD_CH0),
    .x_batch_load_idx(load_batch_q),
    .x_batch_load_data(ch0_x_batch),
    .h_batch_load_en(state_q == S_LOAD_CH0),
    .h_batch_load_idx(load_batch_q),
    .h_batch_load_data(ch0_h_batch),
    .reload_batch_req_valid(tile_reload_valid),
    .reload_batch_req_chan(tile_reload_chan),
    .reload_batch_req_idx(tile_reload_idx),
    .x_batch_reload_data(reload_x_batch),
    .h_batch_reload_data(reload_h_batch),
    .final_batch_valid(tile_final_valid),
    .final_batch_idx(tile_final_idx),
    .final_batch_data(tile_final_data),
    .busy(),
    .done(tile_done),
    .compute_cycles(tile_compute_cycles)
  );

  generate
    for (genvar slot = 0; slot < 4; slot++) begin : g_result_store
      ntt46_mrec_word_store #(
        .WORDS(8),
        .USE_VALID(1'b0)
      ) u_result_store (
        .clk(clk),
        .rst(rst),
        .clear(1'b0),
        .wr_en(tile_final_valid),
        .wr_word_idx(tile_final_idx),
        .wr_word_data(tile_final_data[(slot * WORD_W) +: WORD_W]),
        .rd_word_idx(y_read_idx[7:5]),
        .rd_word_data(result_word[slot])
      );
    end
  endgenerate

  always_comb begin
    selected_result_word = result_word[y_read_idx[9:8]];
  end

  ntt46_mrec_modmul_const_pipe #(
    .B_CONST(MREC_NINV_1024)
  ) u_read_scale (
    .clk(clk),
    .rst(rst),
    .in_valid(read_raw_valid_q),
    .a_in(read_raw_q),
    .out_valid(read_scaled_valid),
    .p_out(read_scaled)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      nh_q <= 9'd1;
      cin_q <= 3'd1;
      load_batch_q <= '0;
      done <= 1'b0;
      cfg_error <= 1'b0;
      y_read_valid <= 1'b0;
      y_read_data <= '0;
      read_word_q <= '0;
      read_lane_q <= '0;
      read_word_valid_q <= 1'b0;
      read_raw_q <= '0;
      read_raw_valid_q <= 1'b0;
    end else begin
      done <= 1'b0;
      read_word_valid_q <= y_read_en;
      if (y_read_en) begin
        read_word_q <= selected_result_word;
        read_lane_q <= y_read_idx[4:0];
      end
      read_raw_valid_q <= read_word_valid_q;
      if (read_word_valid_q) begin
        read_raw_q <= read_word_q[(read_lane_q * MREC_DATA_W) +: MREC_DATA_W];
      end
      y_read_valid <= read_scaled_valid;
      if (read_scaled_valid) begin
        y_read_data <= (read_scaled > (MREC_P / 2))
                     ? $signed({1'b0, read_scaled}) - $signed(MREC_P)
                     : $signed({1'b0, read_scaled});
      end

      unique case (state_q)
        S_IDLE: begin
          if (start) begin
            cfg_error <= !(cfg_cin inside {3'd1, 3'd2, 3'd4}) || (cfg_nh < 1) || (cfg_nh >= 512);
            if (!(cfg_cin inside {3'd1, 3'd2, 3'd4}) || (cfg_nh < 1) || (cfg_nh >= 512)) begin
              done <= 1'b1;
            end else begin
              nh_q <= cfg_nh;
              cin_q <= cfg_cin;
              load_batch_q <= 3'd0;
              state_q <= S_LOAD_CH0;
            end
          end
        end
        S_LOAD_CH0: begin
          if (load_batch_q == 3'd7) begin
            load_batch_q <= 3'd0;
            state_q <= S_START_TILE;
          end else begin
            load_batch_q <= load_batch_q + 3'd1;
          end
        end
        S_START_TILE: state_q <= S_RUN;
        S_RUN: begin
          if (tile_done) begin
            done <= 1'b1;
            state_q <= S_IDLE;
          end
        end
        default: state_q <= S_IDLE;
      endcase
    end
  end

endmodule
