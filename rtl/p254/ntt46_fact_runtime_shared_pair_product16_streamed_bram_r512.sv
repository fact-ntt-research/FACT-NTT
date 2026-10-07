module ntt46_fact_runtime_shared_pair_product16_streamed_bram_r512 #(
  parameter int unsigned R = 512,
  parameter int unsigned LANES = 16,
  parameter bit PRODUCT_STORE_DEPTH8 = 1'b0,
  parameter bit PRODUCT_MUL_TIGHT = 1'b1,
  parameter bit PRODUCT_MUL_REUSE_STEP = 1'b0,
  parameter bit USE_PRODUCT32_STREAM = 1'b0,
  parameter bit PRODUCT32_RESET_DATA_ARRAYS = 1'b1,
  parameter bit PRODUCT32_USE_PACKED_FIFO = 1'b0,
  parameter bit PRODUCT32_INPUT_PIPELINE = 1'b0,
  parameter bit PRODUCT32_ZERO_INVALID_OUTPUTS = 1'b1,
  parameter bit USE_PRODUCT64_STREAM = 1'b0,
  parameter bit PRODUCT64_DRAIN_DURING_INVERSE = 1'b0,
  parameter bit TRANSFORM_J_USE_DSP = 1'b1,
  parameter bit TRANSFORM_J_LUT_FAST3 = 1'b0,
  parameter bit TRANSFORM_TWIDDLE_PRE_STAGE = 1'b1,
  parameter bit TRANSFORM_TWIDDLE_PREFETCH_STAGE = 1'b0,
  parameter bit TRANSFORM_FWD_TWIDDLE_PRE_STAGE = 1'b0,
  parameter bit TRANSFORM_MINUS_FWD_TWIDDLE_PRE_STAGE = 1'b0,
  parameter bit TRANSFORM_MUL_EXTRA_STAGE = 1'b0,
  parameter bit TRANSFORM_J_MUL_TIGHT = 1'b1,
  parameter bit ENABLE_LOAD16 = 1'b0,
  parameter bit SLOT_WRITE_PIPELINE = 1'b1,
  parameter bit INVERSE_OUTPUT_PIPELINE = 1'b1,
  parameter bit RESET_WR_PIPE_DATA = 1'b1,
  parameter bit FORWARD_OUTPUT_PIPELINE = 1'b1,
  parameter int unsigned SLOT_DEPTH_CFG = 3,
  parameter int unsigned META_DEPTH_CFG = 16,
  parameter bit TERMINAL_INPUT_PIPELINE = 1'b1,
  parameter bit TERMINAL_RESET_DATA_ARRAYS = 1'b1,
  parameter bit PRODUCT_STORE_SPLIT_SLOTS = 1'b0,
  parameter bit PRODUCT_STORE_DUAL_READ = 1'b0,
  parameter bit PRODUCT_READY_CLEAR_ON_ACCUM = 1'b0,
  parameter bit STORE_USE_XPM = 1'b0,
  parameter bit FACT_AREA_TRIM_CTRL = 1'b0,
  parameter bit FACT_AREA_TRIM_CORE_DATA = FACT_AREA_TRIM_CTRL,
  parameter bit FACT_AREA_TRIM_STEP_DATA = FACT_AREA_TRIM_CTRL,
  parameter bit FACT_LOCAL_PREDECODE = 1'b0,
  parameter bit FACT_EXT_STAGE0_ENABLE = 1'b0,
  parameter int unsigned R512_L8_SCHED_MODE = 0,
  parameter bit ENABLE_DEBUG_OUTPUTS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                load_en,
  input  logic [8:0]                          load_idx,
  input  ntt46_mrec_arith_pkg::mrec_res_t     plus_load_data,
  input  ntt46_mrec_arith_pkg::mrec_res_t     minus_load_data,
  input  logic                                load16_en,
  input  logic [4:0]                          load16_idx,
  input  ntt46_mrec_arith_pkg::mrec_res_t     plus_load16_data [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     minus_load16_data [0:LANES-1],
  output logic                                ext_stage0_rd_en,
  output logic [$clog2(R/(2*LANES))-1:0]      ext_stage0_rd_batch,
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y0 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y1 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y2 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y3 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y0 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y1 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y2 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y3 [0:LANES-1],
  input  logic                                start,
  input  logic                                run_forward,
  input  logic                                forward_product_odd,
  input  logic                                forward_clear_accum,
  output logic                                busy,
  output logic                                done,
  output logic [15:0]                         compute_cycles,
  output logic                                out_valid,
  output logic [$clog2(R/(2*LANES))-1:0]      out_batch,
  output ntt46_mrec_arith_pkg::mrec_res_t     low_y0 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     high_y0 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     low_y1 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     high_y1 [0:LANES-1],
  output logic                                stream_batch_mismatch,
  output logic                                stream_radix2_seen,
  output logic [5:0]                          product_stream_queued,
  output logic                                product_write_valid,
  output logic                                product_write_odd,
  output logic [5:0]                          product_write_batch
);

  import ntt46_mrec_arith_pkg::*;

  mrec_res_t zero_lane [0:LANES-1];

  logic fwd_valid;
  logic fwd_radix2;
  logic [3:0] fwd_batch;
  mrec_res_t fwd_plus_y0 [0:LANES-1];
  mrec_res_t fwd_plus_y1 [0:LANES-1];
  mrec_res_t fwd_plus_y2 [0:LANES-1];
  mrec_res_t fwd_plus_y3 [0:LANES-1];
  mrec_res_t fwd_minus_y0 [0:LANES-1];
  mrec_res_t fwd_minus_y1 [0:LANES-1];
  mrec_res_t fwd_minus_y2 [0:LANES-1];
  mrec_res_t fwd_minus_y3 [0:LANES-1];

  logic stream_valid;
  logic stream_odd;
  logic stream_clear_accum;
  logic [5:0] stream_batch;
  logic [5:0] stream_batch1;
  mrec_res_t stream_x_data [0:LANES-1];
  mrec_res_t stream_h_data [0:LANES-1];
  mrec_res_t stream_x1_data [0:LANES-1];
  mrec_res_t stream_h1_data [0:LANES-1];
  logic [5:0] stream_x_queued;
  logic [5:0] stream_h_queued;
  logic [4:0] stream32_x_queued;
  logic [4:0] stream32_h_queued;
  logic stream_batch_mismatch_raw;
  logic stream_radix2_seen_raw;

  logic product64_stream_valid;
  logic product64_stream_odd;
  logic product64_stream_clear_accum;
      logic [5:0] product64_stream_burst;
  mrec_res_t product64_stream_x_y0 [0:LANES-1];
  mrec_res_t product64_stream_x_y1 [0:LANES-1];
  mrec_res_t product64_stream_x_y2 [0:LANES-1];
  mrec_res_t product64_stream_x_y3 [0:LANES-1];
  mrec_res_t product64_stream_h_y0 [0:LANES-1];
  mrec_res_t product64_stream_h_y1 [0:LANES-1];
  mrec_res_t product64_stream_h_y2 [0:LANES-1];
  mrec_res_t product64_stream_h_y3 [0:LANES-1];
  logic [5:0] product64_stream_queued;
  logic core_product_write_valid;
  logic core_product_write_odd;
  logic [5:0] core_product_write_batch;

  for (genvar lane = 0; lane < LANES; lane++) begin : g_zero
    assign zero_lane[lane] = '0;
  end

  assign stream_batch_mismatch = ENABLE_DEBUG_OUTPUTS ? stream_batch_mismatch_raw : 1'b0;
  assign stream_radix2_seen = ENABLE_DEBUG_OUTPUTS ? stream_radix2_seen_raw : 1'b0;
  assign product_stream_queued = ENABLE_DEBUG_OUTPUTS ? (USE_PRODUCT64_STREAM ? product64_stream_queued : stream_x_queued) : '0;
  assign product_write_valid = ENABLE_DEBUG_OUTPUTS ? core_product_write_valid : 1'b0;
  assign product_write_odd = ENABLE_DEBUG_OUTPUTS ? core_product_write_odd : 1'b0;
  assign product_write_batch = ENABLE_DEBUG_OUTPUTS ? core_product_write_batch : '0;

  generate
    if (USE_PRODUCT64_STREAM) begin : g_product64_direct_stream
      assign stream_valid = 1'b0;
      assign stream_odd = 1'b0;
      assign stream_clear_accum = 1'b0;
      assign stream_batch = '0;
      assign stream_batch1 = '0;
      assign stream_x_queued = '0;
      assign stream_h_queued = '0;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_zero_stream
        assign stream_x_data[lane] = '0;
        assign stream_h_data[lane] = '0;
        assign stream_x1_data[lane] = '0;
        assign stream_h1_data[lane] = '0;
      end

      ntt46_fact_forward_pair_to_product64_stream_bram_r512 #(
        .LANES(LANES),
        .BURSTS(R / (4 * LANES))
      ) u_pair_stream64 (
        .clk(clk),
        .rst(rst),
        .clear(start && run_forward),
        .drain_enable((!busy && run_forward) || (PRODUCT64_DRAIN_DURING_INVERSE && !run_forward)),
        .x_valid(fwd_valid),
        .x_radix2(fwd_radix2),
        .x_batch(fwd_batch),
        .x_y0(fwd_plus_y0),
        .x_y1(fwd_plus_y1),
        .x_y2(fwd_plus_y2),
        .x_y3(fwd_plus_y3),
        .h_valid(fwd_valid),
        .h_radix2(fwd_radix2),
        .h_batch(fwd_batch),
        .h_y0(fwd_minus_y0),
        .h_y1(fwd_minus_y1),
        .h_y2(fwd_minus_y2),
        .h_y3(fwd_minus_y3),
        .in_odd(forward_product_odd),
        .in_clear_accum(forward_clear_accum),
        .out_valid(product64_stream_valid),
        .out_odd(product64_stream_odd),
        .out_clear_accum(product64_stream_clear_accum),
        .out_burst(product64_stream_burst),
        .out_x_y0(product64_stream_x_y0),
        .out_x_y1(product64_stream_x_y1),
        .out_x_y2(product64_stream_x_y2),
        .out_x_y3(product64_stream_x_y3),
        .out_h_y0(product64_stream_h_y0),
        .out_h_y1(product64_stream_h_y1),
        .out_h_y2(product64_stream_h_y2),
        .out_h_y3(product64_stream_h_y3),
        .batch_mismatch(stream_batch_mismatch_raw),
        .radix2_seen(stream_radix2_seen_raw),
        .queued(product64_stream_queued)
      );
    end else if (USE_PRODUCT32_STREAM) begin : g_product32_pair_stream
      assign product64_stream_valid = 1'b0;
      assign product64_stream_odd = 1'b0;
      assign product64_stream_clear_accum = 1'b0;
      assign product64_stream_burst = '0;
      assign product64_stream_queued = '0;
      assign stream_x_queued = {1'b0, stream32_x_queued};
      assign stream_h_queued = {1'b0, stream32_h_queued};
      for (genvar lane = 0; lane < LANES; lane++) begin : g_zero_product64
        assign product64_stream_x_y0[lane] = '0;
        assign product64_stream_x_y1[lane] = '0;
        assign product64_stream_x_y2[lane] = '0;
        assign product64_stream_x_y3[lane] = '0;
        assign product64_stream_h_y0[lane] = '0;
        assign product64_stream_h_y1[lane] = '0;
        assign product64_stream_h_y2[lane] = '0;
        assign product64_stream_h_y3[lane] = '0;
      end

      ntt46_fact_forward_pair_to_product32_stream_r512 #(
        .LANES(LANES),
        .RESET_DATA_ARRAYS(PRODUCT32_RESET_DATA_ARRAYS),
        .USE_PACKED_FIFO(PRODUCT32_USE_PACKED_FIFO),
        .INPUT_PIPELINE(PRODUCT32_INPUT_PIPELINE),
        .ZERO_INVALID_OUTPUTS(PRODUCT32_ZERO_INVALID_OUTPUTS)
      ) u_pair_stream32 (
        .clk(clk),
        .rst(rst),
        .clear(start && run_forward),
        .x_valid(fwd_valid),
        .x_radix2(fwd_radix2),
        .x_batch(fwd_batch),
        .x_y0(fwd_plus_y0),
        .x_y1(fwd_plus_y1),
        .x_y2(fwd_plus_y2),
        .x_y3(fwd_plus_y3),
        .h_valid(fwd_valid),
        .h_radix2(fwd_radix2),
        .h_batch(fwd_batch),
        .h_y0(fwd_minus_y0),
        .h_y1(fwd_minus_y1),
        .h_y2(fwd_minus_y2),
        .h_y3(fwd_minus_y3),
        .in_odd(forward_product_odd),
        .in_clear_accum(forward_clear_accum),
        .out_valid(stream_valid),
        .out_odd(stream_odd),
        .out_clear_accum(stream_clear_accum),
        .out_batch0(stream_batch),
        .out_batch1(stream_batch1),
        .out_x_data0(stream_x_data),
        .out_x_data1(stream_x1_data),
        .out_h_data0(stream_h_data),
        .out_h_data1(stream_h1_data),
        .batch_mismatch(stream_batch_mismatch_raw),
        .radix2_seen(stream_radix2_seen_raw),
        .x_queued(stream32_x_queued),
        .h_queued(stream32_h_queued)
      );
    end else begin : g_product16_pair_stream
      assign product64_stream_valid = 1'b0;
      assign product64_stream_odd = 1'b0;
      assign product64_stream_clear_accum = 1'b0;
      assign product64_stream_burst = '0;
      assign product64_stream_queued = '0;
      assign stream32_x_queued = '0;
      assign stream32_h_queued = '0;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_zero_product64
        assign product64_stream_x_y0[lane] = '0;
        assign product64_stream_x_y1[lane] = '0;
        assign product64_stream_x_y2[lane] = '0;
        assign product64_stream_x_y3[lane] = '0;
        assign product64_stream_h_y0[lane] = '0;
        assign product64_stream_h_y1[lane] = '0;
        assign product64_stream_h_y2[lane] = '0;
        assign product64_stream_h_y3[lane] = '0;
        assign stream_x1_data[lane] = '0;
        assign stream_h1_data[lane] = '0;
      end
      assign stream_batch1 = '0;

      ntt46_fact_forward_pair_to_product16_stream_bram_r512 #(
        .ENABLE_DEBUG_OUTPUTS(ENABLE_DEBUG_OUTPUTS)
      ) u_pair_stream (
        .clk(clk),
        .rst(rst),
        .clear(start && run_forward),
        .x_valid(fwd_valid),
        .x_radix2(fwd_radix2),
        .x_batch(fwd_batch),
        .x_y0(fwd_plus_y0),
        .x_y1(fwd_plus_y1),
        .x_y2(fwd_plus_y2),
        .x_y3(fwd_plus_y3),
        .h_valid(fwd_valid),
        .h_radix2(fwd_radix2),
        .h_batch(fwd_batch),
        .h_y0(fwd_minus_y0),
        .h_y1(fwd_minus_y1),
        .h_y2(fwd_minus_y2),
        .h_y3(fwd_minus_y3),
        .in_odd(forward_product_odd),
        .in_clear_accum(forward_clear_accum),
        .out_valid(stream_valid),
        .out_odd(stream_odd),
        .out_clear_accum(stream_clear_accum),
        .out_batch(stream_batch),
        .out_x_data(stream_x_data),
        .out_h_data(stream_h_data),
        .batch_mismatch(stream_batch_mismatch_raw),
        .radix2_seen(stream_radix2_seen_raw),
        .x_queued(stream_x_queued),
        .h_queued(stream_h_queued)
      );
    end
  endgenerate

  ntt46_fact_pair_inverse_terminal_shared_r512 #(
    .R(R),
    .LANES(LANES),
    .ENABLE_PRODUCT_ACCUM(1'b1),
    .PRODUCT_MUL_TIGHT(PRODUCT_MUL_TIGHT),
    .PRODUCT_MUL_REUSE_STEP(PRODUCT_MUL_REUSE_STEP),
    .PRODUCT_REUSE_STEP4(USE_PRODUCT64_STREAM),
    .PRODUCT_DUAL_BATCH(USE_PRODUCT32_STREAM),
    .TRANSFORM_J_USE_DSP(TRANSFORM_J_USE_DSP),
    .TRANSFORM_J_LUT_FAST3(TRANSFORM_J_LUT_FAST3),
    .TRANSFORM_MUL_EXTRA_STAGE(TRANSFORM_MUL_EXTRA_STAGE),
    .TRANSFORM_MUL_TIGHT(1'b1),
    .TRANSFORM_J_MUL_TIGHT(TRANSFORM_J_MUL_TIGHT),
    .TRANSFORM_TWIDDLE_PRE_STAGE(TRANSFORM_TWIDDLE_PRE_STAGE),
    .TRANSFORM_TWIDDLE_PREFETCH_STAGE(TRANSFORM_TWIDDLE_PREFETCH_STAGE),
    .STREAM_PRODUCT_DURING_RUN(1'b1),
    .ENABLE_FORWARD_MODE(1'b1),
    .RUNTIME_FORWARD_MODE(1'b1),
    .FORWARD_ONLY(1'b0),
    .LOAD_FORWARD_LAYOUT(1'b1),
    .SEPARATE_PRODUCT_STORE(1'b1),
    .PRODUCT_STORE_DEPTH8(PRODUCT_STORE_DEPTH8),
    .ENABLE_LOAD16(ENABLE_LOAD16),
    .SLOT_WRITE_PIPELINE(SLOT_WRITE_PIPELINE),
    .INVERSE_OUTPUT_PIPELINE(INVERSE_OUTPUT_PIPELINE),
    .RESET_WR_PIPE_DATA(RESET_WR_PIPE_DATA),
    .FORWARD_OUTPUT_PIPELINE(FORWARD_OUTPUT_PIPELINE),
    .SLOT_DEPTH_CFG(SLOT_DEPTH_CFG),
    .META_DEPTH_CFG(META_DEPTH_CFG),
    .TERMINAL_INPUT_PIPELINE(TERMINAL_INPUT_PIPELINE),
    .TERMINAL_RESET_DATA_ARRAYS(TERMINAL_RESET_DATA_ARRAYS),
    .PRODUCT_STORE_SPLIT_SLOTS(PRODUCT_STORE_SPLIT_SLOTS),
    .PRODUCT_STORE_DUAL_READ(PRODUCT_STORE_DUAL_READ),
    .PRODUCT_READY_CLEAR_ON_ACCUM(PRODUCT_READY_CLEAR_ON_ACCUM),
    .STORE_USE_XPM(STORE_USE_XPM),
    .FACT_AREA_TRIM_CTRL(FACT_AREA_TRIM_CTRL),
    .FACT_AREA_TRIM_CORE_DATA(FACT_AREA_TRIM_CORE_DATA),
    .FACT_AREA_TRIM_STEP_DATA(FACT_AREA_TRIM_STEP_DATA),
    .FACT_LOCAL_PREDECODE(FACT_LOCAL_PREDECODE),
    .FACT_EXT_STAGE0_ENABLE(FACT_EXT_STAGE0_ENABLE),
    .R512_L8_SCHED_MODE(R512_L8_SCHED_MODE)
  ) u_core (
    .clk(clk),
    .rst(rst),
    .load_en(load_en),
    .load_idx(load_idx),
    .plus_load_data(plus_load_data),
    .minus_load_data(minus_load_data),
    .load16_en(load16_en),
    .load16_idx(load16_idx),
    .plus_load16_data(plus_load16_data),
    .minus_load16_data(minus_load16_data),
    .ext_stage0_rd_en(ext_stage0_rd_en),
    .ext_stage0_rd_batch(ext_stage0_rd_batch),
    .ext_stage0_plus_y0(ext_stage0_plus_y0),
    .ext_stage0_plus_y1(ext_stage0_plus_y1),
    .ext_stage0_plus_y2(ext_stage0_plus_y2),
    .ext_stage0_plus_y3(ext_stage0_plus_y3),
    .ext_stage0_minus_y0(ext_stage0_minus_y0),
    .ext_stage0_minus_y1(ext_stage0_minus_y1),
    .ext_stage0_minus_y2(ext_stage0_minus_y2),
    .ext_stage0_minus_y3(ext_stage0_minus_y3),
    .product_in_valid(stream_valid),
    .product_in_odd(stream_odd),
    .product_in_clear_accum(stream_clear_accum),
    .product_in_batch(stream_batch),
    .product_x_data(stream_x_data),
    .product_h_data(stream_h_data),
    .product_in_batch1(stream_batch1),
    .product_x1_data(stream_x1_data),
    .product_h1_data(stream_h1_data),
    .product64_in_valid(product64_stream_valid),
    .product64_in_odd(product64_stream_odd),
    .product64_in_clear_accum(product64_stream_clear_accum),
    .product64_in_burst(product64_stream_burst),
    .product64_x_y0(product64_stream_x_y0),
    .product64_x_y1(product64_stream_x_y1),
    .product64_x_y2(product64_stream_x_y2),
    .product64_x_y3(product64_stream_x_y3),
    .product64_h_y0(product64_stream_h_y0),
    .product64_h_y1(product64_stream_h_y1),
    .product64_h_y2(product64_stream_h_y2),
    .product64_h_y3(product64_stream_h_y3),
    .product_out_valid(core_product_write_valid),
    .product_out_odd(core_product_write_odd),
    .product_out_batch(core_product_write_batch),
    .product_out_valid1(),
    .product_out_batch1(),
    .product64_out_valid(),
    .product64_out_odd(),
    .product64_out_burst(),
    .start(start),
    .busy(busy),
    .done(done),
    .compute_cycles(compute_cycles),
    .out_valid(out_valid),
    .out_batch(out_batch),
    .low_y0(low_y0),
    .high_y0(high_y0),
    .low_y1(low_y1),
    .high_y1(high_y1),
    .forward_out_valid(fwd_valid),
    .forward_out_radix2(fwd_radix2),
    .forward_out_batch(fwd_batch),
    .forward_plus_y0(fwd_plus_y0),
    .forward_plus_y1(fwd_plus_y1),
    .forward_plus_y2(fwd_plus_y2),
    .forward_plus_y3(fwd_plus_y3),
    .forward_minus_y0(fwd_minus_y0),
    .forward_minus_y1(fwd_minus_y1),
    .forward_minus_y2(fwd_minus_y2),
    .forward_minus_y3(fwd_minus_y3),
    .run_forward(run_forward)
  );

endmodule
