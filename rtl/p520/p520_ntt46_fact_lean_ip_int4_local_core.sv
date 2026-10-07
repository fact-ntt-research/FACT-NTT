module ntt46_p520_ntt46_fact_lean_ip_int4_local_core #(
  parameter int unsigned R = 512,
  parameter int unsigned LANES = 16,
  parameter bit PRODUCT_STORE_DEPTH8 = 1'b1,
  parameter bit USE_PRODUCT32_STREAM = 1'b1,
  parameter bit PRODUCT32_USE_PACKED_FIFO = 1'b1,
  parameter bit PRODUCT32_RESET_DATA_ARRAYS = 1'b1,
  parameter bit PRODUCT32_INPUT_PIPELINE = 1'b0,
  parameter bit PRODUCT_READY_CLEAR_ON_ACCUM = 1'b1,
  parameter bit TRANSFORM_J_MUL_TIGHT = 1'b0,
  parameter bit TRANSFORM_TWIDDLE_PREFETCH_STAGE = 1'b1,
  parameter bit TERMINAL_INPUT_PIPELINE = 1'b1,
  parameter bit TERMINAL_RESET_DATA_ARRAYS = 1'b1,
  parameter bit RESET_WR_PIPE_DATA = 1'b1,
  parameter bit FACT_AREA_TRIM_CTRL = 1'b0,
  parameter bit FACT_AREA_TRIM_CORE_DATA = FACT_AREA_TRIM_CTRL,
  parameter bit FACT_AREA_TRIM_STEP_DATA = FACT_AREA_TRIM_CTRL,
  parameter bit USE_LOAD16 = 1'b1,
  parameter bit DIRECT_STAGE0_FROM_LOCAL = 1'b0,
  parameter int signed DIRECT_STAGE0_DRAIN_WAIT = -1,
  parameter int signed DIRECT_STAGE0_EVEN_WAIT = -1,
  parameter int signed DIRECT_STAGE0_TAIL_WAIT = -1,
  parameter int signed DIRECT_STAGE0_PRESTART_WAIT = -1,
  parameter string DIRECT_STAGE0_RAM_STYLE = "block",
  parameter int unsigned CIN_MAX = 4,
  parameter int unsigned COUT_MAX = 4,
  parameter bit READOUT_PIPELINE = 1'b0
) (
  input  logic                            clk,
  input  logic                            rst,
  input  logic [8:0]                      cfg_nh,
  input  logic [2:0]                      cfg_cin_tile,
  input  logic [2:0]                      cfg_cout_tile,
  input  logic                            preload_valid,
  input  logic                            preload_is_h,
  input  logic [1:0]                      preload_cin,
  input  logic [1:0]                      preload_cout,
  input  logic [8:0]                      preload_idx,
  input  logic signed [18:0]              preload_data,
  input  logic                            start,
  output logic                            busy,
  output logic                            done,
  output logic                            cfg_error,
  output logic [3:0]                      error_code,
  output logic [31:0]                     wall_cycles,
  output logic [31:0]                     core_compute_cycles,
  output logic [31:0]                     preload_cycles_est,
  output logic [31:0]                     readout_cycles_est,
  input  logic                            y_read_en,
  input  logic [1:0]                      y_read_cout,
  input  logic [9:0]                      y_read_idx,
  output logic                            y_read_valid,
  output logic signed [18:0]              y_read_data
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;
  import ntt46_p520_ntt46_mrec_params_pkg::*;

  localparam int unsigned N = 2 * R;
  localparam int unsigned ADDR_W = $clog2(R);
  localparam int unsigned N_W = $clog2(N);
  localparam int unsigned OUT_BATCHES = R / (2 * LANES);
  localparam int unsigned CIN_SLOTS = (CIN_MAX <= 1) ? 1 : ((CIN_MAX <= 2) ? 2 : 4);
  localparam int unsigned X_DEPTH = CIN_SLOTS * R;
  localparam int unsigned COUT_SLOTS = (COUT_MAX <= 1) ? 1 : ((COUT_MAX <= 2) ? 2 : 4);
  localparam int unsigned H_DEPTH = COUT_SLOTS * CIN_SLOTS * R;
  localparam int unsigned Y_DEPTH = COUT_SLOTS * OUT_BATCHES;
  localparam int unsigned LOAD16_BATCHES = R / LANES;
  localparam int unsigned LOAD16_STORE_DEPTH = R / (4 * LANES);
  localparam int unsigned LOG2_R = $clog2(R);
  localparam bit HAS_RADIX2_FIRST = LOG2_R[0];
  localparam int unsigned EXT_STAGE0_STORE_DEPTH = HAS_RADIX2_FIRST ? (R / (2 * LANES)) : (R / (4 * LANES));
  localparam int unsigned X16_DEPTH = CIN_SLOTS * LOAD16_BATCHES;
  localparam int unsigned H16_DEPTH = COUT_SLOTS * CIN_SLOTS * LOAD16_BATCHES;
  localparam int unsigned X_STAGE0_DEPTH = CIN_SLOTS * EXT_STAGE0_STORE_DEPTH;
  localparam int unsigned H_STAGE0_DEPTH = COUT_SLOTS * CIN_SLOTS * EXT_STAGE0_STORE_DEPTH;
  localparam int unsigned X16_ADDR_W = $clog2(X16_DEPTH);
  localparam int unsigned H16_ADDR_W = $clog2(H16_DEPTH);
  localparam int unsigned X_STAGE0_ADDR_W = $clog2(X_STAGE0_DEPTH);
  localparam int unsigned H_STAGE0_ADDR_W = $clog2(H_STAGE0_DEPTH);
  localparam int unsigned PRELOAD_TWIST_META_LAT = 3;
  localparam int unsigned PRESTART_FLUSH_CYCLES =
    (DIRECT_STAGE0_FROM_LOCAL && (DIRECT_STAGE0_PRESTART_WAIT >= 0)) ?
    int'(DIRECT_STAGE0_PRESTART_WAIT) :
    (DIRECT_STAGE0_FROM_LOCAL ? 0 : (PRELOAD_TWIST_META_LAT + 3));
  localparam int unsigned RES_W = $bits(mrec_res_t);
  localparam int unsigned OUT_WORD_W = LANES * RES_W;
  localparam int unsigned STAGE_WORD_W = 4 * RES_W;

  typedef logic [OUT_WORD_W-1:0] out_word_t;

  typedef enum logic [4:0] {
    S_IDLE,
    S_PRESTART_FLUSH,
    S_LOAD_EVEN,
    S_GAP_EVEN,
    S_START_EVEN,
    S_WAIT_EVEN,
    S_DRAIN_AFTER_EVEN,
    S_LOAD_ODD,
    S_GAP_ODD,
    S_START_ODD,
    S_WAIT_ODD,
    S_DRAIN_NEXT_CH,
    S_DRAIN_TAIL,
    S_START_INV,
    S_WAIT_INV,
    S_NEXT_COUT,
    S_DONE
  } state_t;

  state_t state_q, state_d;

  logic [ADDR_W-1:0] idx_q, idx_d;
  logic [7:0] wait_q, wait_d;
  logic [1:0] ch_q, ch_d;
  logic [1:0] cout_q, cout_d;
  logic [2:0] cfg_cin_q, cfg_cin_d;
  logic [2:0] cfg_cout_q, cfg_cout_d;
  logic [8:0] cfg_nh_q, cfg_nh_d;
  logic cfg_error_q, cfg_error_d;
  logic [3:0] error_code_q, error_code_d;
  logic [31:0] total_cycles_q, total_cycles_d;
  logic [31:0] core_compute_cycles_q, core_compute_cycles_d;
  logic [4:0] final_count_q;

  (* ram_style = "distributed" *) mrec_res_t x_mem [0:X_DEPTH-1];
  (* ram_style = "distributed" *) mrec_res_t x_odd_mem [0:X_DEPTH-1];
  (* ram_style = "distributed" *) mrec_res_t h_mem [0:H_DEPTH-1];
  (* ram_style = "distributed" *) mrec_res_t h_odd_mem [0:H_DEPTH-1];
  (* rom_style = "distributed" *) mrec_res_t psi_mem [0:R-1];
  (* ram_style = "distributed" *) out_word_t out_low0_mem [0:Y_DEPTH-1];
  (* ram_style = "distributed" *) out_word_t out_low1_mem [0:Y_DEPTH-1];
  (* ram_style = "distributed" *) out_word_t out_high0_mem [0:Y_DEPTH-1];
  (* ram_style = "distributed" *) out_word_t out_high1_mem [0:Y_DEPTH-1];

  function automatic logic valid_124(input logic [2:0] v);
    return (v == 3'd1) || (v == 3'd2) || (v == 3'd4);
  endfunction

  function automatic logic valid_cin_cfg(input logic [2:0] v);
    return valid_124(v) && (int'(v) <= CIN_SLOTS);
  endfunction

  function automatic logic valid_cout_cfg(input logic [2:0] v);
    return valid_124(v) && (int'(v) <= COUT_SLOTS);
  endfunction

  function automatic int unsigned x_addr(input logic [1:0] ch, input logic [ADDR_W-1:0] idx);
    return (int'(ch) * R) + int'(idx);
  endfunction

  function automatic int unsigned h_addr(
    input logic [1:0] co,
    input logic [1:0] ch,
    input logic [ADDR_W-1:0] idx
  );
    return (((int'(co) * CIN_SLOTS) + int'(ch)) * R) + int'(idx);
  endfunction

  function automatic int unsigned y_addr(input logic [1:0] co, input int unsigned batch);
    return (int'(co) * OUT_BATCHES) + batch;
  endfunction

  function automatic mrec_res_t to_res(input logic signed [18:0] v);
    if (v < 0) return mrec_res_t'(MREC_P + v);
    return mrec_res_t'(v);
  endfunction

  function automatic mrec_res_t omega_for_r;
    if (R == 512) return mrec_res_t'(MREC_OMEGA_1024);
    if (R == 256) return mrec_res_t'(MREC_OMEGA_512);
    if (R == 128) return mrec_res_t'(MREC_OMEGA_256);
    return mrec_res_t'(MREC_OMEGA_1024);
  endfunction

  function automatic mrec_res_t ninv_for_r;
    if (R == 512) return mrec_res_t'(MREC_NINV_512);
    if (R == 256) return mrec_res_t'(MREC_NINV_256);
    if (R == 128) return mrec_res_t'(MREC_NINV_128);
    return mrec_res_t'(MREC_NINV_512);
  endfunction

  function automatic int unsigned drain_wait_for(input logic [2:0] cin_v);
    if (DIRECT_STAGE0_FROM_LOCAL && (DIRECT_STAGE0_DRAIN_WAIT >= 0)) begin
      return int'(DIRECT_STAGE0_DRAIN_WAIT);
    end
    // In the IP wrapper the same FACT product store is reused across serial
    // Cout passes.  R512/Cin1 also needs the full product-tail guard before
    // inverse so a later Cout cannot observe stale ready/product state.
    if (R == 512) return 18;
    if (R == 256) return 17;
    if (R == 128) return 16;
    return 32;
  endfunction

  function automatic int unsigned direct_even_wait(input logic [2:0] cin_v);
    if (DIRECT_STAGE0_FROM_LOCAL && (DIRECT_STAGE0_EVEN_WAIT >= 0)) return int'(DIRECT_STAGE0_EVEN_WAIT);
    if (DIRECT_STAGE0_FROM_LOCAL) begin
      if (R == 128) return 8;
      return 9;
    end
    return drain_wait_for(cin_v);
  endfunction

  function automatic int unsigned direct_tail_wait(input logic [2:0] cin_v, input logic [2:0] cout_v);
    if (DIRECT_STAGE0_FROM_LOCAL && (DIRECT_STAGE0_TAIL_WAIT >= 0)) return int'(DIRECT_STAGE0_TAIL_WAIT);
    if (DIRECT_STAGE0_FROM_LOCAL) begin
      if (R == 128) begin
        // R128 can safely start inverse immediately for the single-output
        // Cin1/Cin2 paths after the shorter even guard.  Multi-Cout and Cin4
        // still need the conservative tail guard to avoid stale product-ready
        // state across serial Cout/channel reuse.
        if ((cout_v == 3'd1) && (cin_v <= 3'd2)) return 0;
        return 16;
      end
      // Serial Cout reuses the same product store for multiple independent
      // kernels.  Cin1 multi-Cout still needs the conservative tail guard;
      // otherwise the next Cout can observe stale product-ready state.
      // R256/R512 with Cin>1 has been verified to tolerate immediate inverse
      // start and saves controller wall cycles for the common Cin2/4 tile modes.
      if (cout_v > 3'd1) begin
        if ((R == 128) || (cin_v == 3'd1)) return drain_wait_for(cin_v);
        return 0;
      end
      return 0;
    end
    return drain_wait_for(cin_v);
  endfunction

  function automatic logic last_channel(input logic [1:0] ch, input logic [2:0] cin_v);
    return ({1'b0, ch} + 3'd1) >= cin_v;
  endfunction

  function automatic logic last_cout(input logic [1:0] co, input logic [2:0] cout_v);
    return ({1'b0, co} + 3'd1) >= cout_v;
  endfunction

  function automatic mrec_res_t word_lane(input out_word_t word, input int unsigned lane);
    return mrec_res_t'(word[(lane * RES_W) +: RES_W]);
  endfunction

  function automatic int unsigned load16_sample_idx(input logic [ADDR_W-1:0] group_idx, input int unsigned lane);
    int unsigned addr_i;
    int unsigned slot_i;
    addr_i = int'(group_idx) % LOAD16_STORE_DEPTH;
    slot_i = int'(group_idx) / LOAD16_STORE_DEPTH;
    return lane + (LANES * addr_i) + (LANES * LOAD16_STORE_DEPTH * slot_i);
  endfunction

  function automatic int unsigned stage0_sample_idx(
    input int unsigned batch_idx,
    input int unsigned slot_idx,
    input int unsigned lane
  );
    return lane + (LANES * batch_idx) + (LANES * LOAD16_STORE_DEPTH * slot_idx);
  endfunction

  function automatic int unsigned load16_group_for_sample(input logic [ADDR_W-1:0] sample_idx);
    int unsigned addr_i;
    int unsigned slot_i;
    addr_i = (int'(sample_idx) / LANES) % LOAD16_STORE_DEPTH;
    slot_i = int'(sample_idx) / (LANES * LOAD16_STORE_DEPTH);
    return (slot_i * LOAD16_STORE_DEPTH) + addr_i;
  endfunction

  function automatic int unsigned x16_addr(input logic [1:0] ch, input int unsigned group_idx);
    return (int'(ch) * LOAD16_BATCHES) + group_idx;
  endfunction

  function automatic int unsigned h16_addr(input logic [1:0] co, input logic [1:0] ch, input int unsigned group_idx);
    return (((int'(co) * CIN_SLOTS) + int'(ch)) * LOAD16_BATCHES) + group_idx;
  endfunction

  function automatic int unsigned x_stage0_addr(input logic [1:0] ch, input int unsigned batch_idx);
    return (int'(ch) * EXT_STAGE0_STORE_DEPTH) + batch_idx;
  endfunction

  function automatic int unsigned h_stage0_addr(
    input logic [1:0] co,
    input logic [1:0] ch,
    input int unsigned batch_idx
  );
    return (((int'(co) * CIN_SLOTS) + int'(ch)) * EXT_STAGE0_STORE_DEPTH) + batch_idx;
  endfunction

  initial begin
    psi_mem[0] = mrec_res_t'(1);
    for (int i = 1; i < R; i++) begin
      psi_mem[i] = mod_mul(psi_mem[i-1], omega_for_r());
    end
  end

  logic core_load_en;
  logic core_load16_en;
  logic [8:0] core_load_idx;
  logic [4:0] core_load16_idx;
  logic core_ext_stage0_rd_en;
  logic [$clog2(R/(2*LANES))-1:0] core_ext_stage0_rd_batch;
  mrec_res_t core_plus, core_minus;
  mrec_res_t core_plus16 [0:LANES-1];
  mrec_res_t core_minus16 [0:LANES-1];
  mrec_res_t core_ext_plus_y0 [0:LANES-1];
  mrec_res_t core_ext_plus_y1 [0:LANES-1];
  mrec_res_t core_ext_plus_y2 [0:LANES-1];
  mrec_res_t core_ext_plus_y3 [0:LANES-1];
  mrec_res_t core_ext_minus_y0 [0:LANES-1];
  mrec_res_t core_ext_minus_y1 [0:LANES-1];
  mrec_res_t core_ext_minus_y2 [0:LANES-1];
  mrec_res_t core_ext_minus_y3 [0:LANES-1];
  logic core_start, core_run_forward, core_fwd_odd, core_clear;
  logic core_busy, core_done, core_out_valid;
  logic [$clog2(R/(2*LANES))-1:0] core_out_batch;
  logic [15:0] core_cycles;
  mrec_res_t low_y0 [0:LANES-1];
  mrec_res_t high_y0 [0:LANES-1];
  mrec_res_t low_y1 [0:LANES-1];
  mrec_res_t high_y1 [0:LANES-1];

  ntt46_p520_ntt46_fact_top_prod_load16 #(
    .R(R),
    .LANES(LANES),
    .PRODUCT_STORE_DEPTH8(PRODUCT_STORE_DEPTH8),
    .USE_PRODUCT32_STREAM(USE_PRODUCT32_STREAM),
    .PRODUCT32_USE_PACKED_FIFO(PRODUCT32_USE_PACKED_FIFO),
    .PRODUCT32_RESET_DATA_ARRAYS(PRODUCT32_RESET_DATA_ARRAYS),
    .PRODUCT32_INPUT_PIPELINE(PRODUCT32_INPUT_PIPELINE),
    .PRODUCT_READY_CLEAR_ON_ACCUM(PRODUCT_READY_CLEAR_ON_ACCUM),
    .TRANSFORM_J_USE_DSP(1'b1),
    .TRANSFORM_J_MUL_TIGHT(TRANSFORM_J_MUL_TIGHT),
    .TRANSFORM_TWIDDLE_PREFETCH_STAGE(TRANSFORM_TWIDDLE_PREFETCH_STAGE),
    .TERMINAL_INPUT_PIPELINE(TERMINAL_INPUT_PIPELINE),
    .TERMINAL_RESET_DATA_ARRAYS(TERMINAL_RESET_DATA_ARRAYS),
    .RESET_WR_PIPE_DATA(RESET_WR_PIPE_DATA),
    .FACT_AREA_TRIM_CTRL(FACT_AREA_TRIM_CTRL),
    .FACT_AREA_TRIM_CORE_DATA(FACT_AREA_TRIM_CORE_DATA),
    .FACT_AREA_TRIM_STEP_DATA(FACT_AREA_TRIM_STEP_DATA),
    .FACT_EXT_STAGE0_ENABLE(DIRECT_STAGE0_FROM_LOCAL),
    .ENABLE_DEBUG_OUTPUTS(1'b0)
  ) u_prod (
    .clk(clk),
    .rst(rst),
    .load_en(core_load_en),
    .load_idx(core_load_idx),
    .plus_load_data(core_plus),
    .minus_load_data(core_minus),
    .load16_en(core_load16_en),
    .load16_idx(core_load16_idx),
    .plus_load16_data(core_plus16),
    .minus_load16_data(core_minus16),
    .ext_stage0_rd_en(core_ext_stage0_rd_en),
    .ext_stage0_rd_batch(core_ext_stage0_rd_batch),
    .ext_stage0_plus_y0(core_ext_plus_y0),
    .ext_stage0_plus_y1(core_ext_plus_y1),
    .ext_stage0_plus_y2(core_ext_plus_y2),
    .ext_stage0_plus_y3(core_ext_plus_y3),
    .ext_stage0_minus_y0(core_ext_minus_y0),
    .ext_stage0_minus_y1(core_ext_minus_y1),
    .ext_stage0_minus_y2(core_ext_minus_y2),
    .ext_stage0_minus_y3(core_ext_minus_y3),
    .start(core_start),
    .run_forward(core_run_forward),
    .forward_product_odd(core_fwd_odd),
    .forward_clear_accum(core_clear),
    .busy(core_busy),
    .done(core_done),
    .compute_cycles(core_cycles),
    .out_valid(core_out_valid),
    .out_batch(core_out_batch),
    .low_y0(low_y0),
    .high_y0(high_y0),
    .low_y1(low_y1),
    .high_y1(high_y1)
  );

  mrec_res_t preload_res_c, out_res_c, norm_c;
  logic preload_accept_c;
  out_word_t out_low0_pack_c, out_low1_pack_c, out_high0_pack_c, out_high1_pack_c;
  out_word_t out_word_c;
  int unsigned y_idx_int_c, y_half_int_c, y_batch_int_c, y_lane_int_c;
  logic y_read_valid_c;
  logic readout_valid_s1_q, readout_valid_s2_q;
  mrec_res_t readout_res_s1_q;
  logic readout_norm_valid;
  mrec_res_t readout_norm_res;
  logic signed [18:0] readout_data_s2_q;
  logic preload_twist_valid;
  mrec_res_t preload_twist_res;
  logic preload_store_valid_c;
  logic [$clog2(LANES)-1:0] preload_lane_c;
  logic [4:0] preload_group_c;
  logic x16_wr_en_c, h16_wr_en_c;
  logic [3:0] x_stage0_wr_en_c [0:LANES-1];
  logic [3:0] h_stage0_wr_en_c [0:LANES-1];
  logic [X16_ADDR_W-1:0] x16_wr_addr_c, x16_rd_addr_c;
  logic [H16_ADDR_W-1:0] h16_wr_addr_c, h16_rd_addr_c;
  logic [X_STAGE0_ADDR_W-1:0] x_stage0_wr_addr_c [0:LANES-1];
  logic [H_STAGE0_ADDR_W-1:0] h_stage0_wr_addr_c [0:LANES-1];
  logic [X_STAGE0_ADDR_W-1:0] x_stage0_rd_addr_c [0:LANES-1];
  logic [H_STAGE0_ADDR_W-1:0] h_stage0_rd_addr_c [0:LANES-1];
  mrec_res_t x_stage0_wr_data_c [0:LANES-1][0:3];
  mrec_res_t x_stage0_odd_wr_data_c [0:LANES-1][0:3];
  mrec_res_t h_stage0_wr_data_c [0:LANES-1][0:3];
  mrec_res_t h_stage0_odd_wr_data_c [0:LANES-1][0:3];
  logic [STAGE_WORD_W-1:0] x_stage0_rd_word [0:LANES-1];
  logic [STAGE_WORD_W-1:0] x_stage0_odd_rd_word [0:LANES-1];
  logic [STAGE_WORD_W-1:0] h_stage0_rd_word [0:LANES-1];
  logic [STAGE_WORD_W-1:0] h_stage0_odd_rd_word [0:LANES-1];
  mrec_res_t x16_wr_data_c, x16_odd_wr_data_c;
  mrec_res_t h16_wr_data_c, h16_odd_wr_data_c;
  mrec_res_t x16_rd_data [0:LANES-1];
  mrec_res_t x16_odd_rd_data [0:LANES-1];
  mrec_res_t h16_rd_data [0:LANES-1];
  mrec_res_t h16_odd_rd_data [0:LANES-1];
  logic preload_meta_valid_q [0:PRELOAD_TWIST_META_LAT];
  logic preload_meta_is_h_q [0:PRELOAD_TWIST_META_LAT];
  logic [1:0] preload_meta_cin_q [0:PRELOAD_TWIST_META_LAT];
  logic [1:0] preload_meta_cout_q [0:PRELOAD_TWIST_META_LAT];
  logic [ADDR_W-1:0] preload_meta_idx_q [0:PRELOAD_TWIST_META_LAT];
  mrec_res_t preload_meta_res_q [0:PRELOAD_TWIST_META_LAT];

  assign preload_accept_c = preload_valid && !busy && (preload_idx < R) &&
                            (int'(preload_cin) < CIN_SLOTS) &&
                            (!preload_is_h || (int'(preload_cout) < COUT_SLOTS));

  generate
    if (!DIRECT_STAGE0_FROM_LOCAL) begin : g_local_load16_keep
      for (genvar bank = 0; bank < LANES; bank++) begin : g_local_load16_banks
        ntt46_p520_ntt46_fact_lean_res_bank #(
          .DEPTH(X16_DEPTH),
          .ADDR_W(X16_ADDR_W)
        ) u_x_even (
          .clk(clk),
          .wr_en(x16_wr_en_c && (int'(preload_lane_c) == bank)),
          .wr_addr(x16_wr_addr_c),
          .wr_data(x16_wr_data_c),
          .rd_addr(x16_rd_addr_c),
          .rd_data(x16_rd_data[bank])
        );

        ntt46_p520_ntt46_fact_lean_res_bank #(
          .DEPTH(X16_DEPTH),
          .ADDR_W(X16_ADDR_W)
        ) u_x_odd (
          .clk(clk),
          .wr_en(x16_wr_en_c && (int'(preload_lane_c) == bank)),
          .wr_addr(x16_wr_addr_c),
          .wr_data(x16_odd_wr_data_c),
          .rd_addr(x16_rd_addr_c),
          .rd_data(x16_odd_rd_data[bank])
        );

        ntt46_p520_ntt46_fact_lean_res_bank #(
          .DEPTH(H16_DEPTH),
          .ADDR_W(H16_ADDR_W)
        ) u_h_even (
          .clk(clk),
          .wr_en(h16_wr_en_c && (int'(preload_lane_c) == bank)),
          .wr_addr(h16_wr_addr_c),
          .wr_data(h16_wr_data_c),
          .rd_addr(h16_rd_addr_c),
          .rd_data(h16_rd_data[bank])
        );

        ntt46_p520_ntt46_fact_lean_res_bank #(
          .DEPTH(H16_DEPTH),
          .ADDR_W(H16_ADDR_W)
        ) u_h_odd (
          .clk(clk),
          .wr_en(h16_wr_en_c && (int'(preload_lane_c) == bank)),
          .wr_addr(h16_wr_addr_c),
          .wr_data(h16_odd_wr_data_c),
          .rd_addr(h16_rd_addr_c),
          .rd_data(h16_odd_rd_data[bank])
        );
      end
    end else begin : g_local_load16_trim
      for (genvar bank = 0; bank < LANES; bank++) begin : g_trim_ties
        assign x16_rd_data[bank] = '0;
        assign x16_odd_rd_data[bank] = '0;
        assign h16_rd_data[bank] = '0;
        assign h16_odd_rd_data[bank] = '0;
      end
    end
  endgenerate

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(X_STAGE0_DEPTH),
    .ADDR_W(X_STAGE0_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE(DIRECT_STAGE0_RAM_STYLE)
  ) u_x_stage0_even (
    .clk(clk),
    .wr_en(x_stage0_wr_en_c),
    .wr_addr(x_stage0_wr_addr_c),
    .wr_data(x_stage0_wr_data_c),
    .rd_en(core_ext_stage0_rd_en),
    .rd_addr(x_stage0_rd_addr_c),
    .rd_word(x_stage0_rd_word)
  );

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(X_STAGE0_DEPTH),
    .ADDR_W(X_STAGE0_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE(DIRECT_STAGE0_RAM_STYLE)
  ) u_x_stage0_odd (
    .clk(clk),
    .wr_en(x_stage0_wr_en_c),
    .wr_addr(x_stage0_wr_addr_c),
    .wr_data(x_stage0_odd_wr_data_c),
    .rd_en(core_ext_stage0_rd_en),
    .rd_addr(x_stage0_rd_addr_c),
    .rd_word(x_stage0_odd_rd_word)
  );

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(H_STAGE0_DEPTH),
    .ADDR_W(H_STAGE0_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE(DIRECT_STAGE0_RAM_STYLE)
  ) u_h_stage0_even (
    .clk(clk),
    .wr_en(h_stage0_wr_en_c),
    .wr_addr(h_stage0_wr_addr_c),
    .wr_data(h_stage0_wr_data_c),
    .rd_en(core_ext_stage0_rd_en),
    .rd_addr(h_stage0_rd_addr_c),
    .rd_word(h_stage0_rd_word)
  );

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(H_STAGE0_DEPTH),
    .ADDR_W(H_STAGE0_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE(DIRECT_STAGE0_RAM_STYLE)
  ) u_h_stage0_odd (
    .clk(clk),
    .wr_en(h_stage0_wr_en_c),
    .wr_addr(h_stage0_wr_addr_c),
    .wr_data(h_stage0_odd_wr_data_c),
    .rd_en(core_ext_stage0_rd_en),
    .rd_addr(h_stage0_rd_addr_c),
    .rd_word(h_stage0_odd_rd_word)
  );

  ntt46_p520_ntt46_mrec_modmul_pipe #(
    .EXTRA_STAGE(1'b1)
  ) u_preload_twist_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(preload_accept_c),
    .a_in(preload_res_c),
    .b_in(psi_mem[preload_idx[ADDR_W-1:0]]),
    .out_valid(preload_twist_valid),
    .p_out(preload_twist_res)
  );

  ntt46_p520_ntt46_mrec_modmul_pipe #(
    .EXTRA_STAGE(1'b1)
  ) u_readout_norm_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(READOUT_PIPELINE ? readout_valid_s1_q : 1'b0),
    .a_in(readout_res_s1_q),
    .b_in(ninv_for_r()),
    .out_valid(readout_norm_valid),
    .p_out(readout_norm_res)
  );

  always_comb begin
    int unsigned preload_stage0_addr_i;
    int unsigned preload_stage0_slot_i;
    preload_res_c = to_res(preload_data);
    preload_store_valid_c = preload_meta_valid_q[PRELOAD_TWIST_META_LAT] && preload_twist_valid;
    preload_lane_c = int'(preload_meta_idx_q[PRELOAD_TWIST_META_LAT]) % LANES;
    preload_group_c = load16_group_for_sample(preload_meta_idx_q[PRELOAD_TWIST_META_LAT]);
    preload_stage0_addr_i = int'(preload_group_c) % EXT_STAGE0_STORE_DEPTH;
    preload_stage0_slot_i = int'(preload_group_c) / EXT_STAGE0_STORE_DEPTH;
    x16_wr_en_c = preload_store_valid_c && !preload_meta_is_h_q[PRELOAD_TWIST_META_LAT];
    h16_wr_en_c = preload_store_valid_c && preload_meta_is_h_q[PRELOAD_TWIST_META_LAT];
    x16_wr_addr_c = X16_ADDR_W'(x16_addr(preload_meta_cin_q[PRELOAD_TWIST_META_LAT], preload_group_c));
    h16_wr_addr_c = H16_ADDR_W'(h16_addr(
      preload_meta_cout_q[PRELOAD_TWIST_META_LAT],
      preload_meta_cin_q[PRELOAD_TWIST_META_LAT],
      preload_group_c
    ));
    x16_wr_data_c = preload_meta_res_q[PRELOAD_TWIST_META_LAT];
    x16_odd_wr_data_c = preload_twist_res;
    h16_wr_data_c = preload_meta_res_q[PRELOAD_TWIST_META_LAT];
    h16_odd_wr_data_c = preload_twist_res;
    x16_rd_addr_c = X16_ADDR_W'(x16_addr(ch_q, int'(idx_q)));
    h16_rd_addr_c = H16_ADDR_W'(h16_addr(cout_q, ch_q, int'(idx_q)));
    for (int lane = 0; lane < LANES; lane++) begin
      x_stage0_wr_en_c[lane] = 4'b0000;
      h_stage0_wr_en_c[lane] = 4'b0000;
      x_stage0_wr_addr_c[lane] = X_STAGE0_ADDR_W'(x_stage0_addr(preload_meta_cin_q[PRELOAD_TWIST_META_LAT], preload_stage0_addr_i));
      h_stage0_wr_addr_c[lane] = H_STAGE0_ADDR_W'(h_stage0_addr(
        preload_meta_cout_q[PRELOAD_TWIST_META_LAT],
        preload_meta_cin_q[PRELOAD_TWIST_META_LAT],
        preload_stage0_addr_i
      ));
      x_stage0_rd_addr_c[lane] = X_STAGE0_ADDR_W'(x_stage0_addr(ch_q, int'(core_ext_stage0_rd_batch)));
      h_stage0_rd_addr_c[lane] = H_STAGE0_ADDR_W'(h_stage0_addr(cout_q, ch_q, int'(core_ext_stage0_rd_batch)));
      for (int slot = 0; slot < 4; slot++) begin
        x_stage0_wr_data_c[lane][slot] = '0;
        x_stage0_odd_wr_data_c[lane][slot] = '0;
        h_stage0_wr_data_c[lane][slot] = '0;
        h_stage0_odd_wr_data_c[lane][slot] = '0;
      end
    end
    if (preload_store_valid_c) begin
      if (!preload_meta_is_h_q[PRELOAD_TWIST_META_LAT]) begin
        x_stage0_wr_en_c[preload_lane_c][preload_stage0_slot_i] = 1'b1;
        x_stage0_wr_data_c[preload_lane_c][preload_stage0_slot_i] = preload_meta_res_q[PRELOAD_TWIST_META_LAT];
        x_stage0_odd_wr_data_c[preload_lane_c][preload_stage0_slot_i] = preload_twist_res;
      end else begin
        h_stage0_wr_en_c[preload_lane_c][preload_stage0_slot_i] = 1'b1;
        h_stage0_wr_data_c[preload_lane_c][preload_stage0_slot_i] = preload_meta_res_q[PRELOAD_TWIST_META_LAT];
        h_stage0_odd_wr_data_c[preload_lane_c][preload_stage0_slot_i] = preload_twist_res;
      end
    end
    for (int lane = 0; lane < LANES; lane++) begin
      logic [STAGE_WORD_W-1:0] x_word_c;
      logic [STAGE_WORD_W-1:0] h_word_c;
      x_word_c = core_fwd_odd ? x_stage0_odd_rd_word[lane] : x_stage0_rd_word[lane];
      h_word_c = core_fwd_odd ? h_stage0_odd_rd_word[lane] : h_stage0_rd_word[lane];
      core_ext_plus_y0[lane] = mrec_res_t'(x_word_c[0 +: RES_W]);
      core_ext_plus_y1[lane] = mrec_res_t'(x_word_c[RES_W +: RES_W]);
      core_ext_plus_y2[lane] = (R == 512) ? '0 : mrec_res_t'(x_word_c[(2 * RES_W) +: RES_W]);
      core_ext_plus_y3[lane] = (R == 512) ? '0 : mrec_res_t'(x_word_c[(3 * RES_W) +: RES_W]);
      core_ext_minus_y0[lane] = mrec_res_t'(h_word_c[0 +: RES_W]);
      core_ext_minus_y1[lane] = mrec_res_t'(h_word_c[RES_W +: RES_W]);
      core_ext_minus_y2[lane] = (R == 512) ? '0 : mrec_res_t'(h_word_c[(2 * RES_W) +: RES_W]);
      core_ext_minus_y3[lane] = (R == 512) ? '0 : mrec_res_t'(h_word_c[(3 * RES_W) +: RES_W]);
    end

    y_idx_int_c = int'(y_read_idx);
    y_half_int_c = y_idx_int_c % (R/2);
    y_batch_int_c = y_half_int_c / LANES;
    y_lane_int_c = y_half_int_c % LANES;
    out_word_c = '0;
    y_read_valid_c = y_read_en && ({1'b0, y_read_cout} < cfg_cout_q) && (y_read_idx < N);
    if (y_read_valid_c) begin
      if (y_idx_int_c < (R/2)) begin
        out_word_c = out_low0_mem[y_addr(y_read_cout, y_batch_int_c)];
      end else if (y_idx_int_c < R) begin
        out_word_c = out_low1_mem[y_addr(y_read_cout, y_batch_int_c)];
      end else if (y_idx_int_c < (R + (R/2))) begin
        out_word_c = out_high0_mem[y_addr(y_read_cout, y_batch_int_c)];
      end else begin
        out_word_c = out_high1_mem[y_addr(y_read_cout, y_batch_int_c)];
      end
    end
    out_res_c = word_lane(out_word_c, y_lane_int_c);
    norm_c = mod_mul(out_res_c, ninv_for_r());

    out_low0_pack_c = '0;
    out_low1_pack_c = '0;
    out_high0_pack_c = '0;
    out_high1_pack_c = '0;
    for (int lane = 0; lane < LANES; lane++) begin
      out_low0_pack_c[(lane * RES_W) +: RES_W] = low_y0[lane];
      out_low1_pack_c[(lane * RES_W) +: RES_W] = low_y1[lane];
      out_high0_pack_c[(lane * RES_W) +: RES_W] = high_y0[lane];
      out_high1_pack_c[(lane * RES_W) +: RES_W] = high_y1[lane];
    end

    state_d = state_q;
    idx_d = idx_q;
    wait_d = wait_q;
    ch_d = ch_q;
    cout_d = cout_q;
    cfg_cin_d = cfg_cin_q;
    cfg_cout_d = cfg_cout_q;
    cfg_nh_d = cfg_nh_q;
    cfg_error_d = cfg_error_q;
    error_code_d = error_code_q;
    total_cycles_d = total_cycles_q;
    core_compute_cycles_d = core_compute_cycles_q;

    core_load_en = 1'b0;
    core_load16_en = 1'b0;
    core_load_idx = {{(9-ADDR_W){1'b0}}, idx_q};
    core_load16_idx = idx_q[4:0];
    core_plus = '0;
    core_minus = '0;
    for (int lane = 0; lane < LANES; lane++) begin
      core_plus16[lane] = '0;
      core_minus16[lane] = '0;
    end
    core_start = 1'b0;
    core_run_forward = 1'b1;
    core_fwd_odd = 1'b0;
    core_clear = 1'b0;

    done = 1'b0;
    if (READOUT_PIPELINE) begin
      y_read_valid = readout_valid_s2_q;
      y_read_data = readout_data_s2_q;
    end else begin
      y_read_valid = y_read_valid_c;
      y_read_data = residue_to_signed(norm_c);
    end

    if ((state_q != S_IDLE) && (state_q != S_DONE) && (total_cycles_q != 32'hffff_ffff)) begin
      total_cycles_d = total_cycles_q + 32'd1;
    end

    unique case (state_q)
      S_IDLE: begin
        idx_d = '0;
        wait_d = '0;
        ch_d = '0;
        cout_d = '0;
        if (start) begin
          total_cycles_d = '0;
          core_compute_cycles_d = '0;
          cfg_error_d = 1'b0;
          error_code_d = 4'd0;
          cfg_nh_d = cfg_nh;
          cfg_cin_d = cfg_cin_tile;
          cfg_cout_d = cfg_cout_tile;
          if ((cfg_nh == 9'd0) || (int'(cfg_nh) >= R)) begin
            cfg_error_d = 1'b1;
            error_code_d = 4'd1;
            state_d = S_DONE;
          end else if (!valid_cin_cfg(cfg_cin_tile)) begin
            cfg_error_d = 1'b1;
            error_code_d = 4'd2;
            state_d = S_DONE;
          end else if (!valid_cout_cfg(cfg_cout_tile)) begin
            cfg_error_d = 1'b1;
            error_code_d = 4'd3;
            state_d = S_DONE;
          end else begin
            wait_d = '0;
            if (DIRECT_STAGE0_FROM_LOCAL) begin
              state_d = (PRESTART_FLUSH_CYCLES == 0) ? S_START_EVEN : S_PRESTART_FLUSH;
            end else begin
              state_d = S_LOAD_EVEN;
            end
          end
        end
      end

      S_PRESTART_FLUSH: begin
        if ((PRESTART_FLUSH_CYCLES == 0) || (wait_q >= (PRESTART_FLUSH_CYCLES - 1))) begin
          wait_d = '0;
          state_d = S_START_EVEN;
        end else wait_d = wait_q + 1'b1;
      end

      S_LOAD_EVEN: begin
        core_fwd_odd = (ch_q != 2'd0);
        core_clear = (ch_q == 2'd1);
        if (USE_LOAD16) begin
          core_load16_en = 1'b1;
          for (int lane = 0; lane < LANES; lane++) begin
            int unsigned sample_i;
            sample_i = load16_sample_idx(idx_q, lane);
            core_plus16[lane] = x16_rd_data[lane];
            core_minus16[lane] = (sample_i >= int'(cfg_nh_q)) ? '0 : h16_rd_data[lane];
          end
          if (idx_q == LOAD16_BATCHES-1) begin
            idx_d = '0;
            state_d = S_GAP_EVEN;
          end else idx_d = idx_q + 1'b1;
        end else begin
          core_load_en = 1'b1;
          core_plus = x_mem[x_addr(ch_q, idx_q)];
          core_minus = ({1'b0, idx_q} >= cfg_nh_q) ? '0 : h_mem[h_addr(cout_q, ch_q, idx_q)];
          if (idx_q == R-1) begin
            idx_d = '0;
            state_d = S_GAP_EVEN;
          end else idx_d = idx_q + 1'b1;
        end
      end

      S_GAP_EVEN: begin
        core_fwd_odd = (ch_q != 2'd0);
        core_clear = (ch_q == 2'd1);
        state_d = S_START_EVEN;
      end

      S_START_EVEN: begin
        core_start = 1'b1;
        core_clear = (ch_q == 2'd0);
        state_d = S_WAIT_EVEN;
      end

      S_WAIT_EVEN: begin
        core_clear = (ch_q == 2'd0);
        if (core_done) begin
          core_compute_cycles_d = core_compute_cycles_q + core_cycles;
          if (DIRECT_STAGE0_FROM_LOCAL) begin
            wait_d = '0;
            state_d = S_DRAIN_AFTER_EVEN;
          end else begin
            state_d = S_LOAD_ODD;
          end
        end
      end

      S_DRAIN_AFTER_EVEN: begin
        core_clear = (ch_q == 2'd0);
        if ((direct_even_wait(cfg_cin_q) == 0) || (wait_q >= (direct_even_wait(cfg_cin_q) - 1))) begin
          wait_d = '0;
          state_d = S_START_ODD;
        end else wait_d = wait_q + 1'b1;
      end

      S_LOAD_ODD: begin
        core_clear = (ch_q == 2'd0);
        if (USE_LOAD16) begin
          core_load16_en = 1'b1;
          for (int lane = 0; lane < LANES; lane++) begin
            int unsigned sample_i;
            sample_i = load16_sample_idx(idx_q, lane);
            core_plus16[lane] = x16_odd_rd_data[lane];
            core_minus16[lane] = (sample_i >= int'(cfg_nh_q)) ? '0 : h16_odd_rd_data[lane];
          end
          if (idx_q == LOAD16_BATCHES-1) begin
            idx_d = '0;
            state_d = S_GAP_ODD;
          end else idx_d = idx_q + 1'b1;
        end else begin
          core_load_en = 1'b1;
          core_plus = x_odd_mem[x_addr(ch_q, idx_q)];
          core_minus = ({1'b0, idx_q} >= cfg_nh_q) ? '0 : h_odd_mem[h_addr(cout_q, ch_q, idx_q)];
          if (idx_q == R-1) begin
            idx_d = '0;
            state_d = S_GAP_ODD;
          end else idx_d = idx_q + 1'b1;
        end
      end

      S_GAP_ODD: begin
        core_clear = (ch_q == 2'd0);
        state_d = S_START_ODD;
      end

      S_START_ODD: begin
        core_start = 1'b1;
        core_fwd_odd = 1'b1;
        core_clear = (ch_q == 2'd0);
        state_d = S_WAIT_ODD;
      end

      S_WAIT_ODD: begin
        core_fwd_odd = 1'b1;
        core_clear = (ch_q == 2'd0);
        if (core_done) begin
          core_compute_cycles_d = core_compute_cycles_q + core_cycles;
          if (last_channel(ch_q, cfg_cin_q)) begin
            wait_d = '0;
            if (DIRECT_STAGE0_FROM_LOCAL && (direct_tail_wait(cfg_cin_q, cfg_cout_q) == 0)) begin
              state_d = S_START_INV;
            end else begin
              state_d = S_DRAIN_TAIL;
            end
          end else begin
            wait_d = '0;
            if (DIRECT_STAGE0_FROM_LOCAL) begin
              state_d = S_DRAIN_NEXT_CH;
            end else begin
              ch_d = ch_q + 1'b1;
              idx_d = '0;
              state_d = S_LOAD_EVEN;
            end
          end
        end
      end

      S_DRAIN_NEXT_CH: begin
        core_fwd_odd = 1'b1;
        core_clear = (ch_q == 2'd0);
        if ((direct_even_wait(cfg_cin_q) == 0) || (wait_q >= (direct_even_wait(cfg_cin_q) - 1))) begin
          wait_d = '0;
          ch_d = ch_q + 1'b1;
          idx_d = '0;
          state_d = S_START_EVEN;
        end else wait_d = wait_q + 1'b1;
      end

      S_DRAIN_TAIL: begin
        core_fwd_odd = 1'b1;
        core_clear = (cfg_cin_q == 3'd1);
        if ((direct_tail_wait(cfg_cin_q, cfg_cout_q) == 0) ||
            (wait_q >= (direct_tail_wait(cfg_cin_q, cfg_cout_q) - 1))) begin
          wait_d = '0;
          state_d = S_START_INV;
        end else wait_d = wait_q + 1'b1;
      end

      S_START_INV: begin
        core_start = 1'b1;
        core_run_forward = 1'b0;
        core_fwd_odd = 1'b1;
        core_clear = (cfg_cin_q == 3'd1);
        state_d = S_WAIT_INV;
      end

      S_WAIT_INV: begin
        core_run_forward = 1'b0;
        core_fwd_odd = 1'b1;
        core_clear = (cfg_cin_q == 3'd1);
        if (core_done && (final_count_q == OUT_BATCHES)) begin
          core_compute_cycles_d = core_compute_cycles_q + core_cycles;
          state_d = S_NEXT_COUT;
        end
      end

      S_NEXT_COUT: begin
        if (last_cout(cout_q, cfg_cout_q)) begin
          state_d = S_DONE;
        end else begin
          cout_d = cout_q + 1'b1;
          ch_d = '0;
          idx_d = '0;
          state_d = DIRECT_STAGE0_FROM_LOCAL ? S_START_EVEN : S_LOAD_EVEN;
        end
      end

      S_DONE: begin
        done = 1'b1;
        if (!start) state_d = S_IDLE;
      end

      default: state_d = S_IDLE;
    endcase
  end

  assign busy = (state_q != S_IDLE) && (state_q != S_DONE);
  assign cfg_error = cfg_error_q;
  assign error_code = error_code_q;
  assign wall_cycles = total_cycles_q;
  assign core_compute_cycles = core_compute_cycles_q;
  assign preload_cycles_est = (cfg_cin_q * R) + (cfg_cout_q * cfg_cin_q * R);
  assign readout_cycles_est = cfg_cout_q * N;

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      idx_q <= '0;
      wait_q <= '0;
      ch_q <= '0;
      cout_q <= '0;
      cfg_cin_q <= 3'd1;
      cfg_cout_q <= 3'd1;
      cfg_nh_q <= '0;
      cfg_error_q <= 1'b0;
      error_code_q <= '0;
      total_cycles_q <= '0;
      core_compute_cycles_q <= '0;
    end else begin
      state_q <= state_d;
      idx_q <= idx_d;
      wait_q <= wait_d;
      ch_q <= ch_d;
      cout_q <= cout_d;
      cfg_cin_q <= cfg_cin_d;
      cfg_cout_q <= cfg_cout_d;
      cfg_nh_q <= cfg_nh_d;
      cfg_error_q <= cfg_error_d;
      error_code_q <= error_code_d;
      total_cycles_q <= total_cycles_d;
      core_compute_cycles_q <= core_compute_cycles_d;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int pidx = 0; pidx <= PRELOAD_TWIST_META_LAT; pidx++) begin
        preload_meta_valid_q[pidx] <= 1'b0;
      end
    end else begin
      preload_meta_valid_q[0] <= preload_accept_c;
      preload_meta_is_h_q[0] <= preload_is_h;
      preload_meta_cin_q[0] <= preload_cin;
      preload_meta_cout_q[0] <= preload_cout;
      preload_meta_idx_q[0] <= preload_idx[ADDR_W-1:0];
      preload_meta_res_q[0] <= preload_res_c;
      for (int pidx = 1; pidx <= PRELOAD_TWIST_META_LAT; pidx++) begin
        preload_meta_valid_q[pidx] <= preload_meta_valid_q[pidx-1];
        preload_meta_is_h_q[pidx] <= preload_meta_is_h_q[pidx-1];
        preload_meta_cin_q[pidx] <= preload_meta_cin_q[pidx-1];
        preload_meta_cout_q[pidx] <= preload_meta_cout_q[pidx-1];
        preload_meta_idx_q[pidx] <= preload_meta_idx_q[pidx-1];
        preload_meta_res_q[pidx] <= preload_meta_res_q[pidx-1];
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst || (state_q == S_START_INV)) begin
      final_count_q <= '0;
    end else if (core_out_valid) begin
      final_count_q <= final_count_q + 1'b1;
      out_low0_mem[y_addr(cout_q, int'(core_out_batch))] <= out_low0_pack_c;
      out_low1_mem[y_addr(cout_q, int'(core_out_batch))] <= out_low1_pack_c;
      out_high0_mem[y_addr(cout_q, int'(core_out_batch))] <= out_high0_pack_c;
      out_high1_mem[y_addr(cout_q, int'(core_out_batch))] <= out_high1_pack_c;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      readout_valid_s1_q <= 1'b0;
      readout_valid_s2_q <= 1'b0;
      readout_res_s1_q <= '0;
      readout_data_s2_q <= '0;
    end else begin
      readout_valid_s1_q <= READOUT_PIPELINE ? y_read_valid_c : 1'b0;
      if (READOUT_PIPELINE && y_read_valid_c) begin
        readout_res_s1_q <= out_res_c;
      end
      readout_valid_s2_q <= READOUT_PIPELINE ? readout_norm_valid : 1'b0;
      if (READOUT_PIPELINE && readout_norm_valid) begin
        readout_data_s2_q <= residue_to_signed(readout_norm_res);
      end
    end
  end

endmodule

