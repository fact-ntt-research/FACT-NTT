module ntt46_p520_ntt46_fact_pair_inverse_terminal_shared_r512 #(
  parameter int unsigned R = 512,  // FACT half transform size: 512, 256, or 128
  parameter int unsigned LANES = 16,
  parameter bit ENABLE_PRODUCT_ACCUM = 1'b0,
  parameter bit PRODUCT_MUL_EXTRA_STAGE = 1'b0,
  parameter bit PRODUCT_MUL_TIGHT = 1'b0,
  parameter bit PRODUCT_MUL_REUSE_STEP = 1'b0,
  parameter bit PRODUCT_REUSE_STEP4 = 1'b0,
  parameter bit PRODUCT_DUAL_BATCH = 1'b0,
  parameter bit TRANSFORM_J_USE_DSP = 1'b1,
  parameter bit TRANSFORM_J_LUT_FAST3 = 1'b0,
  parameter bit TRANSFORM_MUL_EXTRA_STAGE = 1'b0,
  parameter bit TRANSFORM_MUL_TIGHT = 1'b0,
  parameter bit TRANSFORM_J_MUL_TIGHT = TRANSFORM_MUL_TIGHT,
  parameter bit TRANSFORM_TWIDDLE_PRE_STAGE = 1'b0,
  parameter bit TRANSFORM_TWIDDLE_PREFETCH_STAGE = 1'b0,
  parameter bit STREAM_PRODUCT_DURING_RUN = 1'b0,
  parameter bit ENABLE_FORWARD_MODE = 1'b0,
  parameter bit RUNTIME_FORWARD_MODE = 1'b0,
  parameter bit FORWARD_ONLY = 1'b0,
  parameter bit LOAD_FORWARD_LAYOUT = FORWARD_ONLY,
  parameter bit SEPARATE_PRODUCT_STORE = 1'b0,
  parameter bit PRODUCT_STORE_DEPTH8 = 1'b0,
  parameter bit PRODUCT_STORE_DUAL_READ = 1'b0,
  parameter bit PRODUCT_READY_CLEAR_ON_ACCUM = 1'b0,
  parameter string PRODUCT_STORE_RAM_STYLE = "block",
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
  parameter bit STORE_USE_XPM = 1'b0,
  parameter bit FACT_AREA_TRIM_CTRL = 1'b0,
  parameter bit FACT_AREA_TRIM_CORE_DATA = FACT_AREA_TRIM_CTRL,
  parameter bit FACT_AREA_TRIM_STEP_DATA = FACT_AREA_TRIM_CTRL,
  parameter bit FACT_LOCAL_PREDECODE = 1'b0,
  parameter bit FACT_EXT_STAGE0_ENABLE = 1'b0,
  parameter int unsigned R512_L8_SCHED_MODE = 0
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                load_en,
  input  logic [8:0]                          load_idx,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     plus_load_data,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     minus_load_data,
  input  logic                                load16_en,
  input  logic [4:0]                          load16_idx,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     plus_load16_data [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     minus_load16_data [0:LANES-1],
  output logic                                ext_stage0_rd_en,
  output logic [$clog2(R/(2*LANES))-1:0]       ext_stage0_rd_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_plus_y3 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     ext_stage0_minus_y3 [0:LANES-1],
  input  logic                                product_in_valid,
  input  logic                                product_in_odd,
  input  logic                                product_in_clear_accum,
  input  logic [5:0]                          product_in_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product_x_data [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product_h_data [0:LANES-1],
  input  logic [5:0]                          product_in_batch1,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product_x1_data [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product_h1_data [0:LANES-1],
  input  logic                                product64_in_valid,
  input  logic                                product64_in_odd,
  input  logic                                product64_in_clear_accum,
  input  logic [5:0]                          product64_in_burst,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_x_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_x_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_x_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_x_y3 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_h_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_h_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_h_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product64_h_y3 [0:LANES-1],
  output logic                                product_out_valid,
  output logic                                product_out_odd,
  output logic [5:0]                          product_out_batch,
  output logic                                product_out_valid1,
  output logic [5:0]                          product_out_batch1,
  output logic                                product64_out_valid,
  output logic                                product64_out_odd,
  output logic [5:0]                          product64_out_burst,
  input  logic                                start,
  output logic                                busy,
  output logic                                done,
  output logic [15:0]                         compute_cycles,
  output logic                                out_valid,
  output logic [$clog2(R/(2*LANES))-1:0]      out_batch,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     low_y0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     high_y0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     low_y1 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     high_y1 [0:LANES-1],
  output logic                                forward_out_valid,
  output logic                                forward_out_radix2,
  output logic [3:0]                          forward_out_batch,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_plus_y0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_plus_y1 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_plus_y2 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_plus_y3 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_minus_y0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_minus_y1 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_minus_y2 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     forward_minus_y3 [0:LANES-1],
  input  logic                                run_forward
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;
  import ntt46_p520_ntt46_mrec_params_pkg::*;

  localparam int unsigned WORD_W = 4 * MREC_DATA_W;
  // Derive scheduling parameters from R
  localparam int unsigned LOG2_R = $clog2(R);
  localparam bit HAS_RADIX2_FIRST = LOG2_R[0];
  localparam int unsigned POSITIONS = (R == 512) ? 5 : 4;
  localparam int unsigned STAGE0_BATCHES = HAS_RADIX2_FIRST ? (R / (2 * LANES)) : (R / (4 * LANES));
  localparam int unsigned STAGE_BATCHES  = R / (4 * LANES);
  localparam int unsigned OUT_BATCHES = R / (2 * LANES);
  localparam int unsigned PRODUCT_BATCHES = 4 * STAGE_BATCHES;
  localparam int unsigned R256_STAGE0_STRIDE = (R == 256) ? (16 / LANES) : 1;
  localparam int unsigned DEPTH = STAGE0_BATCHES + (POSITIONS-1) * STAGE_BATCHES;
  localparam int unsigned ADDR_W = $clog2(DEPTH);    // 6 or 4
  localparam int unsigned BATCH_W = $clog2(STAGE0_BATCHES); // 4 or 2
  localparam int unsigned BATCH_COUNT_W = $clog2(STAGE0_BATCHES + 1);
  localparam int unsigned STAGE_BATCH_W = $clog2(STAGE_BATCHES);
  localparam int unsigned PRODUCT_BATCH_W = $clog2(PRODUCT_BATCHES);
  localparam int unsigned OUT_BATCH_W = $clog2(OUT_BATCHES);
  localparam int unsigned STAGE_W = $clog2(POSITIONS); // 3 or 2
  // Original: META_DEPTH=16, READY_DEPTH=8.
  // 126-case exact regression observed peak: meta=9, ready=3.
  // Reduced to tighten area; smoke-proven with full 126-case regression.
  localparam int unsigned META_DEPTH = META_DEPTH_CFG;  // safe upper bound, same for both R
  localparam int unsigned SLOT_DEPTH = (R == 128) ? 4 : SLOT_DEPTH_CFG;
  localparam int unsigned SLOT_ADDR_W = $clog2(SLOT_DEPTH);
  localparam int unsigned READY_DEPTH = ((R == 512) && (LANES == 8)) ? 8 : 4;
  localparam int unsigned READY_ADDR_W = $clog2(READY_DEPTH);
  localparam int unsigned PRODUCT_STORE_DEPTH = PRODUCT_STORE_DEPTH8 ? 8 : 16;
  localparam int unsigned PRODUCT_STORE_ADDR_W = $clog2(PRODUCT_STORE_DEPTH);
  localparam int unsigned STORE_DEPTH = HAS_RADIX2_FIRST ? STAGE0_BATCHES : STAGE_BATCHES;  // 16/4/4 for R=512/256/128
  localparam int unsigned STORE_ADDR_W = $clog2(STORE_DEPTH); // 4 or 2

  typedef enum logic {
    S_IDLE,
    S_RUN
  } state_t;

  typedef enum logic [2:0] {
    WR_NONE,
    WR_FWD0,
    WR_FWD1_INV2,
    WR_INV1,
    WR_R16,
    WR_R4
  } write_route_t;

  state_t state_q;
  logic forward_mode_q;
  logic done_q;
  logic scheduler_done_q;
  logic read_store1_q;
  logic read_product_q;
  logic read_valid_q;
  logic read_ext_stage0_q;
  logic [2:0] read_pos_q;
  logic [2:0] read_stage_q;
  logic [BATCH_W-1:0] read_batch_q;

  logic [15:0] compute_cycles_q;
  logic [5:0] term_count_q;
  logic [5:0] final_count_q;

  logic [BATCH_COUNT_W-1:0] issue_count_q [0:POSITIONS-1];
  logic       ready_q [0:POSITIONS-1][0:STAGE0_BATCHES-1];
  logic       product_plus_ready_q [0:PRODUCT_BATCHES-1];
  logic       product_minus_ready_q [0:PRODUCT_BATCHES-1];
  logic       product_accum_epoch_active_q;

  logic [2:0] meta_pos_q [0:META_DEPTH-1];
  logic [2:0] meta_stage_q [0:META_DEPTH-1];
  logic [BATCH_W-1:0] meta_batch_q [0:META_DEPTH-1];
  logic [BATCH_W-1:0] meta_group_q [0:META_DEPTH-1];
  logic [1:0] meta_off_q [0:META_DEPTH-1];
  logic [2:0] meta_group_size_q [0:META_DEPTH-1];
  logic [2:0] meta_ops_q [0:META_DEPTH-1];
  logic [6:0] meta_count_q;

  logic      slot_valid_q [0:SLOT_DEPTH-1];
  logic      slot_ready_q [0:SLOT_DEPTH-1];
  logic [2:0] slot_pos_q [0:SLOT_DEPTH-1];
  logic [BATCH_W-1:0] slot_group_q [0:SLOT_DEPTH-1];
  logic [2:0] slot_fill_q [0:SLOT_DEPTH-1];
  logic [2:0] slot_ops_q [0:SLOT_DEPTH-1];
  logic [1:0] slot_phase_q [0:SLOT_DEPTH-1];
  mrec_res_t  slot_plus_y0_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_plus_y1_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_plus_y2_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_plus_y3_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_minus_y0_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_minus_y1_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_minus_y2_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  mrec_res_t  slot_minus_y3_q [0:SLOT_DEPTH-1][0:3][0:LANES-1];
  // Physical hint only: keep slot-write CE decode local without adding cycles.
  (* max_fanout = 4 *) logic       slot_write_data_valid_q;
  (* max_fanout = 4 *) logic [SLOT_ADDR_W-1:0] slot_write_slot_q;
  (* max_fanout = 4 *) logic [1:0] slot_write_off_q;
  mrec_res_t slot_write_plus_y0_q [0:LANES-1];
  mrec_res_t slot_write_plus_y1_q [0:LANES-1];
  mrec_res_t slot_write_plus_y2_q [0:LANES-1];
  mrec_res_t slot_write_plus_y3_q [0:LANES-1];
  mrec_res_t slot_write_minus_y0_q [0:LANES-1];
  mrec_res_t slot_write_minus_y1_q [0:LANES-1];
  mrec_res_t slot_write_minus_y2_q [0:LANES-1];
  mrec_res_t slot_write_minus_y3_q [0:LANES-1];

  logic [READY_ADDR_W-1:0] ready_head_q;
  logic [READY_ADDR_W-1:0] ready_tail_q;
  logic [5:0]              ready_count_q;
  logic [SLOT_ADDR_W-1:0]  ready_slot_q [0:READY_DEPTH-1];

  logic [3:0] plus_store0_wr_en [0:LANES-1];
  logic [3:0] minus_store0_wr_en [0:LANES-1];
  logic [STORE_ADDR_W-1:0] store0_wr_addr [0:LANES-1];
  mrec_res_t plus_store0_wr_data [0:LANES-1][0:3];
  mrec_res_t minus_store0_wr_data [0:LANES-1][0:3];
  logic store0_rd_en;
  logic [STORE_ADDR_W-1:0] store0_rd_addr [0:LANES-1];
  logic [WORD_W-1:0] plus_store0_rd_word [0:LANES-1];
  logic [WORD_W-1:0] minus_store0_rd_word [0:LANES-1];

  logic [3:0] plus_store1_wr_en [0:LANES-1];
  logic [3:0] minus_store1_wr_en [0:LANES-1];
  logic [STORE_ADDR_W-1:0] store1_wr_addr [0:LANES-1];
  mrec_res_t plus_store1_wr_data [0:LANES-1][0:3];
  mrec_res_t minus_store1_wr_data [0:LANES-1][0:3];
  logic store1_rd_en;
  logic [STORE_ADDR_W-1:0] store1_rd_addr [0:LANES-1];
  logic [WORD_W-1:0] plus_store1_rd_word [0:LANES-1];
  logic [WORD_W-1:0] minus_store1_rd_word [0:LANES-1];

  logic [3:0] plus_product_wr_en [0:LANES-1];
  logic [3:0] minus_product_wr_en [0:LANES-1];
  logic [PRODUCT_STORE_ADDR_W-1:0] product_store_wr_addr [0:LANES-1];
  mrec_res_t plus_product_wr_data [0:LANES-1][0:3];
  mrec_res_t minus_product_wr_data [0:LANES-1][0:3];
  logic product_store_rd_en;
  logic [PRODUCT_STORE_ADDR_W-1:0] product_store_rd_addr [0:LANES-1];
  logic [WORD_W-1:0] plus_product_rd_word [0:LANES-1];
  logic [WORD_W-1:0] minus_product_rd_word [0:LANES-1];
  logic product_inv_store_rd_en;
  logic [PRODUCT_STORE_ADDR_W-1:0] product_inv_store_rd_addr [0:LANES-1];
  logic [WORD_W-1:0] plus_product_inv_rd_word [0:LANES-1];
  logic [WORD_W-1:0] minus_product_inv_rd_word [0:LANES-1];

  logic [3:0] writer_wr_en_c [0:LANES-1];
  logic [STORE_ADDR_W-1:0] writer_wr_addr_c [0:LANES-1];
  mrec_res_t writer_plus_wr_data_c [0:LANES-1][0:3];
  mrec_res_t writer_minus_wr_data_c [0:LANES-1][0:3];
  logic       wr_pipe_valid_q;
  logic       wr_pipe_store1_q;
  logic [2:0] wr_pipe_pos_q;
  logic [STORE_ADDR_W-1:0] wr_pipe_dest_q;
  logic [3:0] wr_pipe_en_q [0:LANES-1];
  logic [STORE_ADDR_W-1:0] wr_pipe_addr_q [0:LANES-1];
  mrec_res_t  wr_pipe_plus_data_q [0:LANES-1][0:3];
  mrec_res_t  wr_pipe_minus_data_q [0:LANES-1][0:3];

  logic step_in_valid;
  logic plus_step_in_valid;
  logic minus_step_in_valid;
  logic step_radix2;
  logic [ADDR_W-1:0] step_twiddle_addr;
  logic [ADDR_W-1:0] step_twiddle_prefetch_addr;
  logic plus_step_product_mode_c;
  logic minus_step_product_mode_c;
  logic plus_step_product4_mode_c;
  logic minus_step_product4_mode_c;
  mrec_res_t plus_step_product_w0_c [0:LANES-1];
  mrec_res_t plus_step_product_w1_c [0:LANES-1];
  mrec_res_t plus_step_product_w2_c [0:LANES-1];
  mrec_res_t plus_step_product_w3_c [0:LANES-1];
  mrec_res_t minus_step_product_w0_c [0:LANES-1];
  mrec_res_t minus_step_product_w1_c [0:LANES-1];
  mrec_res_t minus_step_product_w2_c [0:LANES-1];
  mrec_res_t minus_step_product_w3_c [0:LANES-1];
  logic step_raw_inv_out_valid;
  logic step_raw_fwd_out_valid;
  logic plus_step_eff_fwd_out_valid;
  logic plus_step_raw_out_valid;
  logic plus_step_raw_fwd_out_valid;
  logic plus_step_raw_inv_out_valid;
  logic minus_step_raw_out_valid;
  logic minus_step_raw_fwd_out_valid;
  logic minus_step_raw_inv_out_valid;
  logic step_out_valid;
  mrec_res_t plus_step_x0 [0:LANES-1];
  mrec_res_t plus_step_x1 [0:LANES-1];
  mrec_res_t plus_step_x2 [0:LANES-1];
  mrec_res_t plus_step_x3 [0:LANES-1];
  mrec_res_t minus_step_x0 [0:LANES-1];
  mrec_res_t minus_step_x1 [0:LANES-1];
  mrec_res_t minus_step_x2 [0:LANES-1];
  mrec_res_t minus_step_x3 [0:LANES-1];
  mrec_res_t plus_step_raw_y0 [0:LANES-1];
  mrec_res_t plus_step_raw_y1 [0:LANES-1];
  mrec_res_t plus_step_raw_y2 [0:LANES-1];
  mrec_res_t plus_step_raw_y3 [0:LANES-1];
  mrec_res_t plus_step_eff_y0 [0:LANES-1];
  mrec_res_t plus_step_eff_y1 [0:LANES-1];
  mrec_res_t plus_step_eff_y2 [0:LANES-1];
  mrec_res_t plus_step_eff_y3 [0:LANES-1];
  mrec_res_t minus_step_raw_y0 [0:LANES-1];
  mrec_res_t minus_step_raw_y1 [0:LANES-1];
  mrec_res_t minus_step_raw_y2 [0:LANES-1];
  mrec_res_t minus_step_raw_y3 [0:LANES-1];
  mrec_res_t plus_step_y0 [0:LANES-1];
  mrec_res_t plus_step_y1 [0:LANES-1];
  mrec_res_t plus_step_y2 [0:LANES-1];
  mrec_res_t plus_step_y3 [0:LANES-1];
  mrec_res_t minus_step_y0 [0:LANES-1];
  mrec_res_t minus_step_y1 [0:LANES-1];
  mrec_res_t minus_step_y2 [0:LANES-1];
  mrec_res_t minus_step_y3 [0:LANES-1];
  logic step_out_pipe_valid_q;
  mrec_res_t plus_step_out_pipe_y0_q [0:LANES-1];
  mrec_res_t plus_step_out_pipe_y1_q [0:LANES-1];
  mrec_res_t plus_step_out_pipe_y2_q [0:LANES-1];
  mrec_res_t plus_step_out_pipe_y3_q [0:LANES-1];
  mrec_res_t minus_step_out_pipe_y0_q [0:LANES-1];
  mrec_res_t minus_step_out_pipe_y1_q [0:LANES-1];
  mrec_res_t minus_step_out_pipe_y2_q [0:LANES-1];
  mrec_res_t minus_step_out_pipe_y3_q [0:LANES-1];
  logic forward_out_valid_q;
  logic forward_out_radix2_q;
  logic [3:0] forward_out_batch_q;
  mrec_res_t forward_plus_y0_q [0:LANES-1];
  mrec_res_t forward_plus_y1_q [0:LANES-1];
  mrec_res_t forward_plus_y2_q [0:LANES-1];
  mrec_res_t forward_plus_y3_q [0:LANES-1];
  mrec_res_t forward_minus_y0_q [0:LANES-1];
  mrec_res_t forward_minus_y1_q [0:LANES-1];
  mrec_res_t forward_minus_y2_q [0:LANES-1];
  mrec_res_t forward_minus_y3_q [0:LANES-1];

  logic issue_fire_c;
  logic [2:0] issue_pos_c;
  logic [2:0] issue_stage_c;
  logic [BATCH_W-1:0] issue_batch_c;
  logic [BATCH_COUNT_W-1:0] issue_batches_c;

  logic product_accept_c;
  logic product64_accept_global_c;
  logic product_acc_read_c;
  logic [3:0] product_read_addr_c;
  logic product_write_valid_c;
  logic product_write_odd_c;
  logic product_write_clear_c;
  logic [5:0] product_write_batch_c;
  mrec_res_t product_write_data_c [0:LANES-1];
  logic product_write_valid1_c;
  logic product_write_odd1_c;
  logic [5:0] product_write_batch1_c;
  mrec_res_t product_write_data1_c [0:LANES-1];
  logic product64_write_valid_c;
  logic product64_write_odd_c;
  logic product64_write_clear_c;
  logic [5:0] product64_write_burst_c;
  mrec_res_t product64_x_y0_q [0:LANES-1];
  mrec_res_t product64_x_y1_q [0:LANES-1];
  mrec_res_t product64_x_y2_q [0:LANES-1];
  mrec_res_t product64_x_y3_q [0:LANES-1];
  mrec_res_t product64_h_y0_q [0:LANES-1];
  mrec_res_t product64_h_y1_q [0:LANES-1];
  mrec_res_t product64_h_y2_q [0:LANES-1];
  mrec_res_t product64_h_y3_q [0:LANES-1];
  mrec_res_t product64_write_y0_c [0:LANES-1];
  mrec_res_t product64_write_y1_c [0:LANES-1];
  mrec_res_t product64_write_y2_c [0:LANES-1];
  mrec_res_t product64_write_y3_c [0:LANES-1];
  logic product_step_busy_c;

  logic writer_valid_c;
  logic [SLOT_ADDR_W-1:0] writer_slot_c;
  logic [2:0] writer_pos_c;
  logic [2:0] writer_stage_c;
  logic [3:0] writer_group_c;
  logic [1:0] writer_phase_c;
  logic [STORE_ADDR_W-1:0] writer_dest_c;

  logic writer_sel_valid_q;
  logic [SLOT_ADDR_W-1:0] writer_sel_slot_q;
  logic [2:0] writer_sel_pos_q;
  logic [2:0] writer_sel_stage_q;
  logic [3:0] writer_sel_group_q;
  logic [1:0] writer_sel_phase_q;
  logic [STORE_ADDR_W-1:0] writer_sel_dest_q;
  write_route_t writer_sel_route_q;
  write_route_t writer_route_c;

  logic term_in_valid;
  logic term_base_valid;
  logic [OUT_BATCH_W-1:0] term_in_batch_c;
  logic term_out_valid;
  logic [OUT_BATCH_W-1:0] term_out_batch;
  mrec_res_t term_plus_y0_c [0:LANES-1];
  mrec_res_t term_plus_y1_c [0:LANES-1];
  mrec_res_t term_minus_y0_c [0:LANES-1];
  mrec_res_t term_minus_y1_c [0:LANES-1];
  logic term_crt_in_valid;
  logic [OUT_BATCH_W-1:0] term_crt_in_batch_c;
  mrec_res_t term_crt_plus_y0_c [0:LANES-1];
  mrec_res_t term_crt_plus_y1_c [0:LANES-1];
  mrec_res_t term_crt_minus_y0_c [0:LANES-1];
  mrec_res_t term_crt_minus_y1_c [0:LANES-1];
  mrec_res_t term_low_y0 [0:LANES-1];
  mrec_res_t term_high_y0 [0:LANES-1];
  mrec_res_t term_low_y1 [0:LANES-1];
  mrec_res_t term_high_y1 [0:LANES-1];

  localparam int unsigned TERM_FIFO_DEPTH = (R == 256) ? OUT_BATCHES : 8;
  localparam int unsigned TERM_FIFO_AW = $clog2(TERM_FIFO_DEPTH);
  localparam int unsigned TERM_FIFO_COUNT_W = $clog2(TERM_FIFO_DEPTH + 3);
  logic [TERM_FIFO_AW-1:0] term_fifo_head_q;
  logic [TERM_FIFO_AW-1:0] term_fifo_head_batch_q;
  (* equivalent_register_removal = "no" *) logic [TERM_FIFO_AW-1:0] term_fifo_head_lane_q [0:LANES-1];
  logic [TERM_FIFO_AW-1:0] term_fifo_tail_q;
  logic [TERM_FIFO_COUNT_W-1:0] term_fifo_count_q;
  logic [OUT_BATCH_W-1:0] term_fifo_batch_q [0:TERM_FIFO_DEPTH-1];
  mrec_res_t term_fifo_plus_y0_q [0:TERM_FIFO_DEPTH-1][0:LANES-1];
  mrec_res_t term_fifo_plus_y1_q [0:TERM_FIFO_DEPTH-1][0:LANES-1];
  mrec_res_t term_fifo_minus_y0_q [0:TERM_FIFO_DEPTH-1][0:LANES-1];
  mrec_res_t term_fifo_minus_y1_q [0:TERM_FIFO_DEPTH-1][0:LANES-1];

  assign busy = (state_q != S_IDLE);
  assign done = done_q;
  assign compute_cycles = compute_cycles_q;
  assign product64_accept_global_c = product64_in_valid &&
    ((state_q == S_IDLE) ||
     (STREAM_PRODUCT_DURING_RUN && (state_q == S_RUN) &&
      (product64_in_clear_accum || SEPARATE_PRODUCT_STORE)));
  assign writer_route_c = FACT_LOCAL_PREDECODE ? writer_sel_route_q :
                                                   write_route_for(!forward_mode_q, writer_sel_stage_q);
  assign step_in_valid = read_valid_q;
  assign plus_step_in_valid = step_in_valid || plus_step_product_mode_c || plus_step_product4_mode_c;
  assign minus_step_in_valid = step_in_valid || minus_step_product_mode_c || minus_step_product4_mode_c;
  assign step_radix2 = HAS_RADIX2_FIRST && (read_stage_q == 3'd0);
  assign step_twiddle_addr = stage_addr_base_for(read_stage_q) + ADDR_W'(read_batch_q);
  assign step_twiddle_prefetch_addr = stage_addr_base_for(issue_stage_c) + ADDR_W'(issue_batch_c);
  assign step_raw_inv_out_valid = plus_step_raw_inv_out_valid && minus_step_raw_inv_out_valid;
  assign plus_step_eff_fwd_out_valid = plus_step_raw_fwd_out_valid;
  assign step_raw_fwd_out_valid = plus_step_eff_fwd_out_valid && minus_step_raw_fwd_out_valid;
  assign step_out_valid = forward_mode_q ? step_raw_fwd_out_valid :
                           (INVERSE_OUTPUT_PIPELINE ? step_out_pipe_valid_q
                                                    : step_raw_inv_out_valid);
  assign out_valid = term_out_valid;
  assign out_batch = term_out_batch;
  assign product_out_valid = product_write_valid_c;
  assign product_out_odd = product_write_odd_c;
  assign product_out_batch = product_write_batch_c;
  assign product_out_valid1 = product_write_valid1_c;
  assign product_out_batch1 = product_write_batch1_c;
  assign product64_out_valid = product64_write_valid_c;
  assign product64_out_odd = product64_write_odd_c;
  assign product64_out_burst = product64_write_burst_c;

  for (genvar lane_out = 0; lane_out < LANES; lane_out++) begin : g_out
    assign low_y0[lane_out] = term_low_y0[lane_out];
    assign high_y0[lane_out] = term_high_y0[lane_out];
    assign low_y1[lane_out] = term_low_y1[lane_out];
    assign high_y1[lane_out] = term_high_y1[lane_out];
  end

  generate
    if (FORWARD_OUTPUT_PIPELINE) begin : g_forward_output_pipe
      assign forward_out_valid = forward_out_valid_q;
      assign forward_out_radix2 = forward_out_radix2_q;
      assign forward_out_batch = forward_out_batch_q;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
        assign forward_plus_y0[lane] = forward_plus_y0_q[lane];
        assign forward_plus_y1[lane] = forward_plus_y1_q[lane];
        assign forward_plus_y2[lane] = forward_plus_y2_q[lane];
        assign forward_plus_y3[lane] = forward_plus_y3_q[lane];
        assign forward_minus_y0[lane] = forward_minus_y0_q[lane];
        assign forward_minus_y1[lane] = forward_minus_y1_q[lane];
        assign forward_minus_y2[lane] = forward_minus_y2_q[lane];
        assign forward_minus_y3[lane] = forward_minus_y3_q[lane];
      end
    end else begin : g_forward_output_direct
      assign forward_out_valid = forward_mode_q && step_out_valid && (meta_pos_q[0] == (POSITIONS - 1));
      assign forward_out_radix2 = (meta_stage_q[0] == 3'd0);
      assign forward_out_batch = forward_batch_out_for(meta_batch_q[0]);
      for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
        assign forward_plus_y0[lane] = plus_step_y0[lane];
        assign forward_plus_y1[lane] = plus_step_y1[lane];
        assign forward_plus_y2[lane] = plus_step_y2[lane];
        assign forward_plus_y3[lane] = plus_step_y3[lane];
        assign forward_minus_y0[lane] = minus_step_y0[lane];
        assign forward_minus_y1[lane] = minus_step_y1[lane];
        assign forward_minus_y2[lane] = minus_step_y2[lane];
        assign forward_minus_y3[lane] = minus_step_y3[lane];
      end
    end
  endgenerate

  function automatic logic [STAGE_W-1:0] stage_for_pos(input logic inv, input logic [STAGE_W-1:0] pos);
    begin
      stage_for_pos = inv ? (STAGE_W'(POSITIONS-1) - pos) : pos;
    end
  endfunction

  function automatic logic [3:0] product_bank_for(
    input logic [5:0] batch,
    input logic [3:0] lane
  );
    int unsigned banks_per_product_sub;
    begin
      banks_per_product_sub = LANES / 4;
      product_bank_for = (batch[1:0] * banks_per_product_sub) + (lane >> 2);
    end
  endfunction

  function automatic logic [STORE_ADDR_W-1:0] product_addr_for(input logic [5:0] batch);
    begin
      product_addr_for = STORE_ADDR_W'(batch >> 2);
    end
  endfunction

  function automatic logic [PRODUCT_STORE_ADDR_W-1:0] product_store_addr_for(
    input logic [5:0] batch
  );
    begin
      product_store_addr_for = PRODUCT_STORE_ADDR_W'(batch >> 2);
    end
  endfunction

  function automatic logic [PRODUCT_STORE_ADDR_W-1:0] product_store_stage_addr_for(
    input logic [BATCH_W-1:0] batch
  );
    begin
      product_store_stage_addr_for = PRODUCT_STORE_ADDR_W'(batch);
    end
  endfunction

  function automatic logic [1:0] product_slot_for(input logic [3:0] lane);
    begin
      product_slot_for = lane[1:0];
    end
  endfunction

  function automatic logic product_stage_ready_for(input logic [STAGE_BATCH_W-1:0] stage_batch);
    logic [5:0] product_idx;
    begin
      product_stage_ready_for = 1'b1;
      for (int sub = 0; sub < 4; sub++) begin
        product_idx = 6'((int'(stage_batch) * 4) + sub);
        product_stage_ready_for &=
          product_plus_ready_q[product_idx] &&
          product_minus_ready_q[product_idx];
      end
    end
  endfunction

  function automatic logic [3:0] forward_batch_out_for(input logic [BATCH_W-1:0] batch);
    begin
      forward_batch_out_for = 4'(batch);
    end
  endfunction

  function automatic logic [OUT_BATCH_W-1:0] batch_to_out(input logic [BATCH_W-1:0] batch);
    begin
      batch_to_out = OUT_BATCH_W'(batch);
    end
  endfunction

  function automatic logic [BATCH_COUNT_W-1:0] batches_for(input logic [STAGE_W-1:0] stage);
    begin
      batches_for = BATCH_COUNT_W'((stage == {STAGE_W{1'b0}}) ? STAGE0_BATCHES : STAGE_BATCHES);
    end
  endfunction

  function automatic logic [2:0] group_size_for(input logic inv, input logic [STAGE_W-1:0] stage);
    begin
      if (R == 128) begin
        if (!inv && (stage == 2'd0))
          group_size_for = 3'd4;
        else if ((!inv && (stage == 2'd1)) || (inv && (stage == 2'd2))) begin
          if (LANES == 4)
            group_size_for = 3'd4;
          else if (LANES == 8)
            group_size_for = 3'd2;
          else
            group_size_for = 3'd1;
        end
        else if (inv && (stage == 2'd1))
          group_size_for = 3'd2;
        else
          group_size_for = 3'd1;
      end else if (R == 256) begin
        if ((!inv && (stage == STAGE_W'(3))) || (inv && (stage == STAGE_W'(0))))
          group_size_for = 3'd1;
        else if ((!inv && (stage == STAGE_W'(0))) || (inv && (stage == STAGE_W'(1))))
          group_size_for = 3'd4;
        else if ((LANES == 8) &&
                 ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2)))))
          group_size_for = 3'd2;
        else
          group_size_for = 3'd1;
      end else begin
        if      (!inv && (stage == 3'd0)) group_size_for = 3'd4;
        else if (!inv && (stage == 3'd1)) group_size_for = 3'd4;
        else if ((LANES == 8) &&
                 ((!inv && (stage == 3'd2)) || (inv && (stage == 3'd3))))
          group_size_for = 3'd2;
        else if ( inv && (stage == 3'd2)) group_size_for = 3'd4;
        else if ( inv && (stage == 3'd1)) group_size_for = 3'd2;
        else                               group_size_for = 3'd1;
      end
    end
  endfunction

  function automatic logic [2:0] ops_per_group_for(input logic inv, input logic [STAGE_W-1:0] stage);
    begin
      if (R == 128) begin
        if (!inv && (stage == 2'd0))
          ops_per_group_for = 3'd2;
        else if ((!inv && (stage == 2'd1)) || (inv && (stage == 2'd2))) begin
          if (LANES == 4)
            ops_per_group_for = 3'd4;
          else if (LANES == 8)
            ops_per_group_for = 3'd2;
          else
            ops_per_group_for = 3'd1;
        end
        else if (inv && (stage == 2'd1))
          ops_per_group_for = 3'd4;
        else
          ops_per_group_for = 3'd1;
      end else if (R == 256) begin
        if ((!inv && (stage == STAGE_W'(3))) || (inv && (stage == STAGE_W'(0))))
          ops_per_group_for = 3'd1;
        else if ((!inv && (stage == STAGE_W'(0))) || (inv && (stage == STAGE_W'(1))))
          ops_per_group_for = 3'd4;
        else if ((LANES == 8) &&
                 ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2)))))
          ops_per_group_for = 3'd2;
        else
          ops_per_group_for = 3'd1;
      end else begin
        if      (!inv && (stage == 3'd0)) ops_per_group_for = 3'd2;
        else if (!inv && (stage == 3'd1)) ops_per_group_for = 3'd4;
        else if ((LANES == 8) &&
                 ((!inv && (stage == 3'd2)) || (inv && (stage == 3'd3))))
          ops_per_group_for = 3'd2;
        else if ( inv && (stage == 3'd2)) ops_per_group_for = 3'd4;
        else if ( inv && (stage == 3'd1)) ops_per_group_for = 3'd4;
        else                               ops_per_group_for = 3'd1;
      end
    end
  endfunction

  function automatic write_route_t write_route_for(input logic inv, input logic [STAGE_W-1:0] stage);
    logic [STAGE_W-1:0] last_stage;
    begin
      last_stage = STAGE_W'(POSITIONS-1);
      if (R == 128) begin
        if ((!inv && (stage == last_stage)) || (inv && (stage == {STAGE_W{1'b0}}))) begin
          write_route_for = WR_NONE;
        end else if (!inv && (stage == STAGE_W'(0))) begin
          write_route_for = WR_FWD0;
        end else if ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2)))) begin
          write_route_for = (LANES == 4) ? WR_FWD1_INV2 : WR_R16;
        end else if ((!inv && (stage == STAGE_W'(2))) || (inv && (stage == STAGE_W'(3)))) begin
          write_route_for = WR_R4;
        end else begin
          write_route_for = WR_FWD1_INV2;
        end
      end else if (R == 256) begin
        if ((!inv && (stage == last_stage)) || (inv && (stage == {STAGE_W{1'b0}}))) begin
          write_route_for = WR_NONE;
        end else if ((!inv && (stage == STAGE_W'(0))) || (inv && (stage == STAGE_W'(1)))) begin
          write_route_for = WR_FWD1_INV2;
        end else if ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2)))) begin
          write_route_for = WR_R16;
        end else begin
          write_route_for = WR_R4;
        end
      end else begin
        if ((!inv && (stage == last_stage)) || (inv && (stage == {STAGE_W{1'b0}}))) begin
          write_route_for = WR_NONE;
        end else if (!inv && (stage == {STAGE_W{1'b0}})) begin
          write_route_for = WR_FWD0;
        end else if ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(POSITIONS-3)))) begin
          write_route_for = WR_FWD1_INV2;
        end else if (inv && (stage == STAGE_W'(POSITIONS-4))) begin
          write_route_for = WR_INV1;
        end else if ((!inv && (stage == STAGE_W'(POSITIONS-3))) || (inv && (stage == STAGE_W'(POSITIONS-2)))) begin
          write_route_for = WR_R16;
        end else begin
          write_route_for = WR_R4;
        end
      end
    end
  endfunction

  function automatic logic [ADDR_W-1:0] stage_addr_base_for(input logic [STAGE_W-1:0] stage);
    int unsigned base;
    begin
      base = 0;
      for (int s = 0; s < POSITIONS; s++) begin
        if (stage == STAGE_W'(s)) begin
          stage_addr_base_for = ADDR_W'(base);
          break;
        end
        base += (s == 0) ? STAGE0_BATCHES : STAGE_BATCHES;
      end
    end
  endfunction

  // R=128: direct indexing suffices ??smaller batches, simpler organization.
  // R=512: bit-manipulation for the 5-stage radix-24 data layout.

  function automatic logic [BATCH_W-1:0] scheduled_batch_for(
    input logic inv,
    input logic [STAGE_W-1:0] stage,
    input logic [4:0] issue_idx
  );
    begin
      if (R == 128) begin
        if ((LANES == 4) && !inv && (stage == 2'd0))
          scheduled_batch_for = {issue_idx[1:0], issue_idx[3:2]};
        else if ((LANES == 8) && !inv && (stage == 2'd0))
          scheduled_batch_for = {issue_idx[1:0], issue_idx[2]};
        else
          scheduled_batch_for = issue_idx[BATCH_W-1:0];
      end else if (R == 256) begin
        scheduled_batch_for = issue_idx[BATCH_W-1:0];
      end else begin
        if (!inv && (stage == 3'd0)) begin
          if (LANES == 8)
            scheduled_batch_for = BATCH_W'({issue_idx[1:0], issue_idx[4:2]});
          else
            scheduled_batch_for = BATCH_W'({issue_idx[1:0], issue_idx[3:2]});
        end else if (!inv && (stage == 3'd1) && (LANES == 8)) begin
          if ((R512_L8_SCHED_MODE == 1) || (R512_L8_SCHED_MODE == 2) ||
              (R512_L8_SCHED_MODE == 4))
            scheduled_batch_for = BATCH_W'(issue_idx[3:0]);
          else
            scheduled_batch_for = BATCH_W'({issue_idx[3], issue_idx[1:0], issue_idx[2]});
        end else if (!inv && (stage == 3'd2) && (LANES == 8) &&
                     ((R512_L8_SCHED_MODE == 2) || (R512_L8_SCHED_MODE == 4))) begin
          scheduled_batch_for = BATCH_W'({issue_idx[3], issue_idx[1:0], issue_idx[2]});
        end else if (inv && (stage == 3'd2) && (LANES == 8)) begin
          scheduled_batch_for = BATCH_W'({issue_idx[3], issue_idx[1:0], issue_idx[2]});
        end else if (inv && (stage == 3'd1)) begin
          if (LANES == 8)
            scheduled_batch_for = ((R512_L8_SCHED_MODE == 3) || (R512_L8_SCHED_MODE == 4)) ?
                                  BATCH_W'(issue_idx[3:0]) :
                                  BATCH_W'({1'b0, issue_idx[0], issue_idx[3:1]});
          else
            scheduled_batch_for = BATCH_W'({1'b0, issue_idx[0], issue_idx[2:1]});
        end else if (inv && (stage == 3'd0) && (LANES == 8)) begin
          scheduled_batch_for = BATCH_W'({issue_idx[1:0], issue_idx[4:2]});
        end else begin
          scheduled_batch_for = issue_idx[BATCH_W-1:0];
        end
      end
    end
  endfunction

  function automatic logic [2:0] r512_l8_sched_pos_for(
    input logic inv,
    input logic [2:0] pri
  );
    begin
      if (R512_L8_SCHED_MODE == 6) begin
        r512_l8_sched_pos_for = 3'(POSITIONS - 1) - pri;
      end else if (!inv) begin
        unique case (pri)
          3'd0: r512_l8_sched_pos_for = 3'd2;
          3'd1: r512_l8_sched_pos_for = 3'd3;
          3'd2: r512_l8_sched_pos_for = 3'd4;
          3'd3: r512_l8_sched_pos_for = 3'd1;
          default: r512_l8_sched_pos_for = 3'd0;
        endcase
      end else begin
        unique case (pri)
          3'd0: r512_l8_sched_pos_for = 3'd3;
          3'd1: r512_l8_sched_pos_for = 3'd4;
          3'd2: r512_l8_sched_pos_for = 3'd2;
          3'd3: r512_l8_sched_pos_for = 3'd1;
          default: r512_l8_sched_pos_for = 3'd0;
        endcase
      end
    end
  endfunction

  function automatic logic [BATCH_W-1:0] batch_group_for(
    input logic inv,
    input logic [STAGE_W-1:0] stage,
    input logic [BATCH_W-1:0] batch
  );
    begin
      if (R == 128) begin
        if (!inv && (stage == 2'd0)) begin
          if (LANES == 4)
            batch_group_for = BATCH_W'({2'b00, batch[1:0]});
          else if (LANES == 8)
            batch_group_for = BATCH_W'({3'b000, batch[0]});
          else
            batch_group_for = '0;
        end
        else if (inv && (stage == 2'd1)) begin
          if (LANES == 4)
            batch_group_for = BATCH_W'({2'b00, batch[1:0]});
          else if (LANES == 8)
            batch_group_for = BATCH_W'({3'b000, batch[0]});
          else
            batch_group_for = batch >> 1;
        end
        else if ((!inv && (stage == 2'd1)) || (inv && (stage == 2'd2))) begin
          if (LANES == 4)
            batch_group_for = batch >> 2;
          else if (LANES == 8)
            batch_group_for = batch >> 1;
          else
            batch_group_for = batch;
        end
        else
          batch_group_for = batch;
      end else if (R == 256) begin
        if ((!inv && (stage == STAGE_W'(0))) || (inv && (stage == STAGE_W'(1)))) begin
          batch_group_for = batch % BATCH_W'(R256_STAGE0_STRIDE);
        end else if ((LANES == 8) &&
                     ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2))))) begin
          batch_group_for = batch >> 1;
        end else begin
          batch_group_for = batch;
        end
      end else begin
        if (!inv && (stage == 3'd0)) begin
          if (LANES == 8)
            batch_group_for = BATCH_W'({2'b00, batch[2:0]});
          else
            batch_group_for = BATCH_W'({2'b00, batch[1:0]});
        end else if (!inv && (stage == 3'd1)) begin
          if (LANES == 8)
            batch_group_for = BATCH_W'({2'b00, batch[3], batch[0]});
          else
            batch_group_for = BATCH_W'({3'b000, batch[2]});
        end else if (inv && (stage == 3'd2)) begin
          if (LANES == 8)
            batch_group_for = BATCH_W'({2'b00, batch[3], batch[0]});
          else
            batch_group_for = BATCH_W'({3'b000, batch[2]});
        end else if ((LANES == 8) &&
                     ((!inv && (stage == 3'd2)) || (inv && (stage == 3'd3)))) begin
          batch_group_for = batch >> 1;
        end else if (inv && (stage == 3'd1)) begin
          if (LANES == 8)
            batch_group_for = BATCH_W'({2'b00, batch[2:0]});
          else
            batch_group_for = BATCH_W'({2'b00, batch[1:0]});
        end else begin
          batch_group_for = batch;
        end
      end
    end
  endfunction

  function automatic logic [1:0] batch_offset_for(
    input logic inv,
    input logic [STAGE_W-1:0] stage,
    input logic [BATCH_W-1:0] batch
  );
    begin
      if (R == 128) begin
        if (!inv && (stage == 2'd0)) begin
          if (LANES == 4)
            batch_offset_for = batch[3:2];
          else if (LANES == 8)
            batch_offset_for = batch[2:1];
          else
            batch_offset_for = batch[1:0];
        end
        else if (inv && (stage == 2'd1)) begin
          if (LANES == 4)
            batch_offset_for = {1'b0, batch[2]};
          else if (LANES == 8)
            batch_offset_for = {1'b0, batch[1]};
          else
            batch_offset_for = {1'b0, batch[0]};
        end
        else if ((!inv && (stage == 2'd1)) || (inv && (stage == 2'd2))) begin
          if (LANES == 4)
            batch_offset_for = batch[1:0];
          else if (LANES == 8)
            batch_offset_for = {1'b0, batch[0]};
          else
            batch_offset_for = 2'd0;
        end
        else
          batch_offset_for = 2'd0;
      end else if (R == 256) begin
        if ((!inv && (stage == STAGE_W'(0))) || (inv && (stage == STAGE_W'(1)))) begin
          batch_offset_for = 2'((batch / BATCH_W'(R256_STAGE0_STRIDE)));
        end else if ((LANES == 8) &&
                     ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2))))) begin
          batch_offset_for = {1'b0, batch[0]};
        end else begin
          batch_offset_for = 2'd0;
        end
      end else begin
        if (!inv && (stage == 3'd0)) begin
          batch_offset_for = (LANES == 8) ? batch[4:3] : batch[3:2];
        end else if (!inv && (stage == 3'd1)) begin
          batch_offset_for = (LANES == 8) ? batch[2:1] : batch[1:0];
        end else if (inv && (stage == 3'd2)) begin
          batch_offset_for = (LANES == 8) ? batch[2:1] : batch[1:0];
        end else if ((LANES == 8) &&
                     ((!inv && (stage == 3'd2)) || (inv && (stage == 3'd3)))) begin
          batch_offset_for = {1'b0, batch[0]};
        end else if (inv && (stage == 3'd1)) begin
          batch_offset_for = (LANES == 8) ? {1'b0, batch[3]} : {1'b0, batch[2]};
        end else begin
          batch_offset_for = 2'd0;
        end
      end
    end
  endfunction

  function automatic logic [STORE_ADDR_W-1:0] write_dest_for(
    input logic inv,
    input logic [STAGE_W-1:0] stage,
    input logic [BATCH_W-1:0] group,
    input logic [1:0] phase
  );
    begin
      if (R == 128) begin
        if (!inv && (stage == 2'd0)) begin
          if (LANES == 4)
            write_dest_for = STORE_ADDR_W'({1'b0, phase[0], group[1:0]});
          else if (LANES == 8)
            write_dest_for = STORE_ADDR_W'({phase[0], group[0]});
          else
            write_dest_for = STORE_ADDR_W'(phase[0]);
        end
        else if (inv && (stage == 2'd1)) begin
          if (LANES == 4)
            write_dest_for = STORE_ADDR_W'((phase * 4) + group);
          else if (LANES == 8)
            write_dest_for = STORE_ADDR_W'((phase * 2) + group);
          else
            write_dest_for = STORE_ADDR_W'((group * 4) + phase);
        end
        else if ((!inv && (stage == 2'd1)) || (inv && (stage == 2'd2))) begin
          if (LANES == 4)
            write_dest_for = STORE_ADDR_W'((group * 4) + phase);
          else if (LANES == 8)
            write_dest_for = STORE_ADDR_W'((group * 2) + phase[0]);
          else
            write_dest_for = group;
        end
        else
          write_dest_for = group;
      end else if (R == 256) begin
        if ((!inv && (stage == STAGE_W'(0))) || (inv && (stage == STAGE_W'(1)))) begin
          write_dest_for = STORE_ADDR_W'((phase * R256_STAGE0_STRIDE) + group);
        end else if ((LANES == 8) &&
                     ((!inv && (stage == STAGE_W'(1))) || (inv && (stage == STAGE_W'(2))))) begin
          write_dest_for = STORE_ADDR_W'((group * 2) + phase[0]);
        end else begin
          write_dest_for = group;
        end
      end else begin
        if (!inv && (stage == 3'd0)) begin
          if (LANES == 8)
            write_dest_for = STORE_ADDR_W'((phase[0] * 8) + group[2:0]);
          else
            write_dest_for = STORE_ADDR_W'((phase[0] * 4) + group[1:0]);
        end else if (!inv && (stage == 3'd1)) begin
          if (LANES == 8)
            write_dest_for = STORE_ADDR_W'((group[1] * 8) + (phase * 2) + group[0]);
          else
            write_dest_for = STORE_ADDR_W'((group[0] * 4) + phase);
        end else if (inv && (stage == 3'd2)) begin
          if (LANES == 8)
            write_dest_for = STORE_ADDR_W'((group[1] * 8) + (phase * 2) + group[0]);
          else
            write_dest_for = STORE_ADDR_W'((group[0] * 4) + phase);
        end else if ((LANES == 8) &&
                     ((!inv && (stage == 3'd2)) || (inv && (stage == 3'd3)))) begin
          write_dest_for = STORE_ADDR_W'((group * 2) + phase[0]);
        end else if (inv && (stage == 3'd1)) begin
          if (LANES == 8)
            write_dest_for = STORE_ADDR_W'((phase * 8) + group[2:0]);
          else
            write_dest_for = STORE_ADDR_W'((phase * 4) + group[1:0]);
        end else begin
          write_dest_for = group;
        end
      end
    end
  endfunction

  function automatic mrec_res_t pick_plus_buf_slot(
    input logic [SLOT_ADDR_W-1:0] slot,
    input logic [1:0] slot_sel,
    input logic [1:0] batch_off,
    input int lane
  );
    begin
      unique case (slot_sel)
        2'd0: pick_plus_buf_slot = slot_plus_y0_q[slot][batch_off][lane];
        2'd1: pick_plus_buf_slot = slot_plus_y1_q[slot][batch_off][lane];
        2'd2: pick_plus_buf_slot = slot_plus_y2_q[slot][batch_off][lane];
        default: pick_plus_buf_slot = slot_plus_y3_q[slot][batch_off][lane];
      endcase
    end
  endfunction

  function automatic mrec_res_t pick_minus_buf_slot(
    input logic [SLOT_ADDR_W-1:0] slot,
    input logic [1:0] slot_sel,
    input logic [1:0] batch_off,
    input int lane
  );
    begin
      unique case (slot_sel)
        2'd0: pick_minus_buf_slot = slot_minus_y0_q[slot][batch_off][lane];
        2'd1: pick_minus_buf_slot = slot_minus_y1_q[slot][batch_off][lane];
        2'd2: pick_minus_buf_slot = slot_minus_y2_q[slot][batch_off][lane];
        default: pick_minus_buf_slot = slot_minus_y3_q[slot][batch_off][lane];
      endcase
    end
  endfunction

  generate
    if (ENABLE_PRODUCT_ACCUM) begin : g_product_accum
      if (PRODUCT_REUSE_STEP4) begin : g_reuse_step4
        localparam int unsigned PRODUCT4_REUSE_LAT = TRANSFORM_TWIDDLE_PRE_STAGE ? 5 : 4;

        logic product64_accept_c;
        logic product64_step_valid_q;
        logic product64_step_odd_q;
        logic product64_step_clear_q;
        logic [5:0] product64_step_burst_q;
        logic product64_valid_pipe_q [0:PRODUCT4_REUSE_LAT-1];
        logic product64_odd_pipe_q [0:PRODUCT4_REUSE_LAT-1];
        logic product64_clear_pipe_q [0:PRODUCT4_REUSE_LAT-1];
        logic [5:0] product64_burst_pipe_q [0:PRODUCT4_REUSE_LAT-1];
        mrec_res_t product64_old_pipe_q [0:PRODUCT4_REUSE_LAT-1][0:LANES-1][0:3];
        logic product64_raw_valid_c;
        logic product64_raw_odd_c;
        logic product64_raw_clear_c;
        logic [5:0] product64_raw_burst_c;
        mrec_res_t product64_raw_y0_c [0:LANES-1];
        mrec_res_t product64_raw_y1_c [0:LANES-1];
        mrec_res_t product64_raw_y2_c [0:LANES-1];
        mrec_res_t product64_raw_y3_c [0:LANES-1];
        logic product64_prod_valid_q;
        logic product64_prod_odd_q;
        logic product64_prod_clear_q;
        logic [5:0] product64_prod_burst_q;
        mrec_res_t product64_prod_old_q [0:LANES-1][0:3];
        mrec_res_t product64_prod_y0_q [0:LANES-1];
        mrec_res_t product64_prod_y1_q [0:LANES-1];
        mrec_res_t product64_prod_y2_q [0:LANES-1];
        mrec_res_t product64_prod_y3_q [0:LANES-1];
        mrec_res_t product64_accum_y0_c [0:LANES-1];
        mrec_res_t product64_accum_y1_c [0:LANES-1];
        mrec_res_t product64_accum_y2_c [0:LANES-1];
        mrec_res_t product64_accum_y3_c [0:LANES-1];
        logic product64_wr_valid_q;
        logic product64_wr_odd_q;
        logic product64_wr_clear_q;
        logic [5:0] product64_wr_burst_q;
        mrec_res_t product64_wr_y0_q [0:LANES-1];
        mrec_res_t product64_wr_y1_q [0:LANES-1];
        mrec_res_t product64_wr_y2_q [0:LANES-1];
        mrec_res_t product64_wr_y3_q [0:LANES-1];
        assign product64_accept_c = product64_in_valid &&
          ((state_q == S_IDLE) ||
           (STREAM_PRODUCT_DURING_RUN && (state_q == S_RUN) &&
            (product64_in_clear_accum || SEPARATE_PRODUCT_STORE)));
        assign product_step_busy_c = product64_step_valid_q;
        assign product_acc_read_c = product64_accept_c && !product64_in_clear_accum;
        assign product_read_addr_c = product_store_stage_addr_for(BATCH_W'(product64_in_burst));
        assign plus_step_product_mode_c = 1'b0;
        assign minus_step_product_mode_c = 1'b0;
        assign plus_step_product4_mode_c = product64_step_valid_q && !product64_step_odd_q;
        assign minus_step_product4_mode_c = product64_step_valid_q && product64_step_odd_q;
        assign product_write_valid_c = 1'b0;
        assign product_write_odd_c = 1'b0;
        assign product_write_clear_c = 1'b0;
        assign product_write_batch_c = '0;
        assign product_write_valid1_c = 1'b0;
        assign product_write_odd1_c = 1'b0;
        assign product_write_batch1_c = '0;
        assign product64_raw_valid_c =
          product64_valid_pipe_q[PRODUCT4_REUSE_LAT-1] &&
          (product64_odd_pipe_q[PRODUCT4_REUSE_LAT-1] ? minus_step_raw_out_valid
                                                       : plus_step_raw_out_valid);
        assign product64_raw_odd_c = product64_odd_pipe_q[PRODUCT4_REUSE_LAT-1];
        assign product64_raw_clear_c = product64_clear_pipe_q[PRODUCT4_REUSE_LAT-1];
        assign product64_raw_burst_c = product64_burst_pipe_q[PRODUCT4_REUSE_LAT-1];
        assign product64_write_valid_c = product64_wr_valid_q;
        assign product64_write_odd_c = product64_wr_odd_q;
        assign product64_write_clear_c = product64_wr_clear_q;
        assign product64_write_burst_c = product64_wr_burst_q;

        for (genvar lane = 0; lane < LANES; lane++) begin : g_reuse4_lane
          assign plus_step_product_w0_c[lane] = product64_h_y0_q[lane];
          assign plus_step_product_w1_c[lane] = product64_h_y1_q[lane];
          assign plus_step_product_w2_c[lane] = product64_h_y2_q[lane];
          assign plus_step_product_w3_c[lane] = product64_h_y3_q[lane];
          assign minus_step_product_w0_c[lane] = product64_h_y0_q[lane];
          assign minus_step_product_w1_c[lane] = product64_h_y1_q[lane];
          assign minus_step_product_w2_c[lane] = product64_h_y2_q[lane];
          assign minus_step_product_w3_c[lane] = product64_h_y3_q[lane];
          assign product_write_data_c[lane] = '0;
          assign product_write_data1_c[lane] = '0;
          assign product64_raw_y0_c[lane] =
            product64_raw_odd_c ? minus_step_raw_y0[lane] : plus_step_raw_y0[lane];
          assign product64_raw_y1_c[lane] =
            product64_raw_odd_c ? minus_step_raw_y1[lane] : plus_step_raw_y1[lane];
          assign product64_raw_y2_c[lane] =
            product64_raw_odd_c ? minus_step_raw_y2[lane] : plus_step_raw_y2[lane];
          assign product64_raw_y3_c[lane] =
            product64_raw_odd_c ? minus_step_raw_y3[lane] : plus_step_raw_y3[lane];
          assign product64_accum_y0_c[lane] =
            product64_prod_clear_q ? product64_prod_y0_q[lane]
                                   : mod_add(product64_prod_old_q[lane][0], product64_prod_y0_q[lane]);
          assign product64_accum_y1_c[lane] =
            product64_prod_clear_q ? product64_prod_y1_q[lane]
                                   : mod_add(product64_prod_old_q[lane][1], product64_prod_y1_q[lane]);
          assign product64_accum_y2_c[lane] =
            product64_prod_clear_q ? product64_prod_y2_q[lane]
                                   : mod_add(product64_prod_old_q[lane][2], product64_prod_y2_q[lane]);
          assign product64_accum_y3_c[lane] =
            product64_prod_clear_q ? product64_prod_y3_q[lane]
                                   : mod_add(product64_prod_old_q[lane][3], product64_prod_y3_q[lane]);
          assign product64_write_y0_c[lane] = product64_wr_y0_q[lane];
          assign product64_write_y1_c[lane] = product64_wr_y1_q[lane];
          assign product64_write_y2_c[lane] = product64_wr_y2_q[lane];
          assign product64_write_y3_c[lane] = product64_wr_y3_q[lane];
        end

        always_ff @(posedge clk) begin
          if (rst) begin
            product64_step_valid_q <= 1'b0;
            product64_step_odd_q <= 1'b0;
            product64_step_clear_q <= 1'b0;
            product64_step_burst_q <= '0;
            product64_prod_valid_q <= 1'b0;
            product64_prod_odd_q <= 1'b0;
            product64_prod_clear_q <= 1'b0;
            product64_prod_burst_q <= '0;
            product64_wr_valid_q <= 1'b0;
            product64_wr_odd_q <= 1'b0;
            product64_wr_clear_q <= 1'b0;
            product64_wr_burst_q <= '0;
            for (int lane = 0; lane < LANES; lane++) begin
              product64_x_y0_q[lane] <= '0;
              product64_x_y1_q[lane] <= '0;
              product64_x_y2_q[lane] <= '0;
              product64_x_y3_q[lane] <= '0;
              product64_h_y0_q[lane] <= '0;
              product64_h_y1_q[lane] <= '0;
              product64_h_y2_q[lane] <= '0;
              product64_h_y3_q[lane] <= '0;
              product64_prod_y0_q[lane] <= '0;
              product64_prod_y1_q[lane] <= '0;
              product64_prod_y2_q[lane] <= '0;
              product64_prod_y3_q[lane] <= '0;
              product64_wr_y0_q[lane] <= '0;
              product64_wr_y1_q[lane] <= '0;
              product64_wr_y2_q[lane] <= '0;
              product64_wr_y3_q[lane] <= '0;
              for (int slot = 0; slot < 4; slot++) begin
                product64_prod_old_q[lane][slot] <= '0;
              end
            end
            for (int stage = 0; stage < PRODUCT4_REUSE_LAT; stage++) begin
              product64_valid_pipe_q[stage] <= 1'b0;
              product64_odd_pipe_q[stage] <= 1'b0;
              product64_clear_pipe_q[stage] <= 1'b0;
              product64_burst_pipe_q[stage] <= '0;
              for (int lane = 0; lane < LANES; lane++) begin
                for (int slot = 0; slot < 4; slot++) begin
                  product64_old_pipe_q[stage][lane][slot] <= '0;
                end
              end
            end
          end else begin
            product64_wr_valid_q <= product64_prod_valid_q;
            product64_wr_odd_q <= product64_prod_odd_q;
            product64_wr_clear_q <= product64_prod_clear_q;
            product64_wr_burst_q <= product64_prod_burst_q;
            for (int lane = 0; lane < LANES; lane++) begin
              product64_wr_y0_q[lane] <= product64_accum_y0_c[lane];
              product64_wr_y1_q[lane] <= product64_accum_y1_c[lane];
              product64_wr_y2_q[lane] <= product64_accum_y2_c[lane];
              product64_wr_y3_q[lane] <= product64_accum_y3_c[lane];
            end

            product64_prod_valid_q <= product64_raw_valid_c;
            product64_prod_odd_q <= product64_raw_odd_c;
            product64_prod_clear_q <= product64_raw_clear_c;
            product64_prod_burst_q <= product64_raw_burst_c;
            for (int lane = 0; lane < LANES; lane++) begin
              product64_prod_y0_q[lane] <= product64_raw_y0_c[lane];
              product64_prod_y1_q[lane] <= product64_raw_y1_c[lane];
              product64_prod_y2_q[lane] <= product64_raw_y2_c[lane];
              product64_prod_y3_q[lane] <= product64_raw_y3_c[lane];
              for (int slot = 0; slot < 4; slot++) begin
                product64_prod_old_q[lane][slot] <= product64_old_pipe_q[PRODUCT4_REUSE_LAT-1][lane][slot];
              end
            end

            product64_step_valid_q <= product64_accept_c;
            product64_step_odd_q <= product64_in_odd;
            product64_step_clear_q <= product64_in_clear_accum;
            product64_step_burst_q <= product64_in_burst;
            if (product64_accept_c) begin
              for (int lane = 0; lane < LANES; lane++) begin
                product64_x_y0_q[lane] <= product64_x_y0[lane];
                product64_x_y1_q[lane] <= product64_x_y1[lane];
                product64_x_y2_q[lane] <= product64_x_y2[lane];
                product64_x_y3_q[lane] <= product64_x_y3[lane];
                product64_h_y0_q[lane] <= product64_h_y0[lane];
                product64_h_y1_q[lane] <= product64_h_y1[lane];
                product64_h_y2_q[lane] <= product64_h_y2[lane];
                product64_h_y3_q[lane] <= product64_h_y3[lane];
              end
            end

            product64_valid_pipe_q[0] <= product64_step_valid_q;
            product64_odd_pipe_q[0] <= product64_step_odd_q;
            product64_clear_pipe_q[0] <= product64_step_clear_q;
            product64_burst_pipe_q[0] <= product64_step_burst_q;
            for (int lane = 0; lane < LANES; lane++) begin
              logic [WORD_W-1:0] old_word;
              old_word = product64_step_odd_q
                         ? (SEPARATE_PRODUCT_STORE ? minus_product_rd_word[lane]
                                                   : minus_store0_rd_word[lane])
                         : (SEPARATE_PRODUCT_STORE ? plus_product_rd_word[lane]
                                                   : plus_store0_rd_word[lane]);
              for (int slot = 0; slot < 4; slot++) begin
                product64_old_pipe_q[0][lane][slot] <= old_word[(slot * MREC_DATA_W) +: MREC_DATA_W];
              end
            end

            for (int stage = 1; stage < PRODUCT4_REUSE_LAT; stage++) begin
              product64_valid_pipe_q[stage] <= product64_valid_pipe_q[stage-1];
              product64_odd_pipe_q[stage] <= product64_odd_pipe_q[stage-1];
              product64_clear_pipe_q[stage] <= product64_clear_pipe_q[stage-1];
              product64_burst_pipe_q[stage] <= product64_burst_pipe_q[stage-1];
              for (int lane = 0; lane < LANES; lane++) begin
                for (int slot = 0; slot < 4; slot++) begin
                  product64_old_pipe_q[stage][lane][slot] <= product64_old_pipe_q[stage-1][lane][slot];
                end
              end
            end
          end
        end
      end else if (PRODUCT_MUL_REUSE_STEP) begin : g_reuse_step
        localparam int unsigned PRODUCT_REUSE_LAT = 8;

        mrec_res_t product_prod_c [0:LANES-1];
        mrec_res_t product_old_pipe_q [0:PRODUCT_REUSE_LAT-1][0:LANES-1];
        logic product_accept_q;
        logic product_odd_q;
        logic product_clear_q;
        logic [5:0] product_batch_q;
        logic product_store_rd_odd_q;
        logic [5:0] product_store_rd_batch_q;
        logic product_valid_pipe_q [0:PRODUCT_REUSE_LAT-1];
        logic product_odd_pipe_q [0:PRODUCT_REUSE_LAT-1];
        logic product_clear_pipe_q [0:PRODUCT_REUSE_LAT-1];
        logic [5:0] product_batch_pipe_q [0:PRODUCT_REUSE_LAT-1];

        assign product_accept_c = product_in_valid &&
          ((state_q == S_IDLE) ||
           (STREAM_PRODUCT_DURING_RUN && (state_q == S_RUN) &&
            (product_in_clear_accum || SEPARATE_PRODUCT_STORE)));
        assign product_acc_read_c = product_accept_c && !product_in_clear_accum;
        assign product_read_addr_c = product_addr_for(product_in_batch);
        assign plus_step_product_mode_c = product_accept_c && !product_in_odd;
        assign minus_step_product_mode_c = product_accept_c && product_in_odd;
        assign plus_step_product4_mode_c = 1'b0;
        assign minus_step_product4_mode_c = 1'b0;
        assign product_write_valid_c =
          product_valid_pipe_q[PRODUCT_REUSE_LAT-1] &&
          (product_odd_pipe_q[PRODUCT_REUSE_LAT-1] ? minus_step_raw_fwd_out_valid
                                                   : plus_step_raw_fwd_out_valid);
        assign product_write_odd_c = product_odd_pipe_q[PRODUCT_REUSE_LAT-1];
        assign product_write_clear_c = product_clear_pipe_q[PRODUCT_REUSE_LAT-1];
        assign product_write_batch_c = product_batch_pipe_q[PRODUCT_REUSE_LAT-1];
        assign product_write_valid1_c = 1'b0;
        assign product_write_odd1_c = 1'b0;
        assign product_write_batch1_c = '0;
        assign product64_write_valid_c = 1'b0;
        assign product64_write_odd_c = 1'b0;
        assign product64_write_clear_c = 1'b0;
        assign product64_write_burst_c = '0;
        assign product_step_busy_c = 1'b0;

        for (genvar lane = 0; lane < LANES; lane++) begin : g_reuse_lane
          assign plus_step_product_w0_c[lane] = product_h_data[lane];
          assign plus_step_product_w1_c[lane] = product_h_data[lane];
          assign plus_step_product_w2_c[lane] = product_h_data[lane];
          assign plus_step_product_w3_c[lane] = product_h_data[lane];
          assign minus_step_product_w0_c[lane] = product_h_data[lane];
          assign minus_step_product_w1_c[lane] = product_h_data[lane];
          assign minus_step_product_w2_c[lane] = product_h_data[lane];
          assign minus_step_product_w3_c[lane] = product_h_data[lane];
          assign product_prod_c[lane] = product_write_odd_c ? minus_step_raw_y1[lane]
                                                            : plus_step_raw_y1[lane];
          assign product_write_data_c[lane] =
            product_write_clear_c
              ? product_prod_c[lane]
              : mod_add(product_old_pipe_q[PRODUCT_REUSE_LAT-1][lane], product_prod_c[lane]);
          assign product_write_data1_c[lane] = '0;
          assign product64_write_y0_c[lane] = '0;
          assign product64_write_y1_c[lane] = '0;
          assign product64_write_y2_c[lane] = '0;
          assign product64_write_y3_c[lane] = '0;
        end

        always_ff @(posedge clk) begin
          if (rst) begin
            product_accept_q <= 1'b0;
            product_odd_q <= 1'b0;
            product_clear_q <= 1'b0;
            product_batch_q <= '0;
            product_store_rd_odd_q <= 1'b0;
            product_store_rd_batch_q <= '0;
            for (int stage = 0; stage < PRODUCT_REUSE_LAT; stage++) begin
              product_valid_pipe_q[stage] <= 1'b0;
              product_odd_pipe_q[stage] <= 1'b0;
              product_clear_pipe_q[stage] <= 1'b0;
              product_batch_pipe_q[stage] <= '0;
              for (int lane = 0; lane < LANES; lane++) begin
                product_old_pipe_q[stage][lane] <= '0;
              end
            end
          end else begin
            product_accept_q <= product_accept_c;
            product_store_rd_odd_q <= product_in_odd;
            product_store_rd_batch_q <= product_in_batch;

            if (product_accept_c) begin
              product_odd_q <= product_in_odd;
              product_clear_q <= product_in_clear_accum;
              product_batch_q <= product_in_batch;
            end

            product_valid_pipe_q[0] <= product_accept_q;
            product_odd_pipe_q[0] <= product_odd_q;
            product_clear_pipe_q[0] <= product_clear_q;
            product_batch_pipe_q[0] <= product_batch_q;
            for (int lane = 0; lane < LANES; lane++) begin
              logic [3:0] lane_idx;
              logic [3:0] bank_idx;
              logic [1:0] slot_idx;
              logic [WORD_W-1:0] old_word;
              lane_idx = lane[3:0];
              bank_idx = product_bank_for(product_store_rd_batch_q, lane_idx);
              slot_idx = product_slot_for(lane_idx);
              old_word = product_store_rd_odd_q
                         ? (SEPARATE_PRODUCT_STORE ? minus_product_rd_word[bank_idx]
                                                   : minus_store0_rd_word[bank_idx])
                         : (SEPARATE_PRODUCT_STORE ? plus_product_rd_word[bank_idx]
                                                   : plus_store0_rd_word[bank_idx]);
              product_old_pipe_q[0][lane] <= old_word[(slot_idx * MREC_DATA_W) +: MREC_DATA_W];
            end

            for (int stage = 1; stage < PRODUCT_REUSE_LAT; stage++) begin
              product_valid_pipe_q[stage] <= product_valid_pipe_q[stage-1];
              product_odd_pipe_q[stage] <= product_odd_pipe_q[stage-1];
              product_clear_pipe_q[stage] <= product_clear_pipe_q[stage-1];
              product_batch_pipe_q[stage] <= product_batch_pipe_q[stage-1];
              for (int lane = 0; lane < LANES; lane++) begin
                product_old_pipe_q[stage][lane] <= product_old_pipe_q[stage-1][lane];
              end
            end
          end
        end
      end else begin : g_dedicated_mul
        localparam int unsigned PRODUCT_MUL_LAT = PRODUCT_MUL_EXTRA_STAGE ? 4 : 3;

        mrec_res_t product_prod [0:LANES-1];
        mrec_res_t product_prod1 [0:LANES-1];
        mrec_res_t product_old_pipe_q [0:PRODUCT_MUL_LAT-1][0:LANES-1];
        mrec_res_t product_old1_pipe_q [0:PRODUCT_MUL_LAT-1][0:LANES-1];
        mrec_res_t product_x_q [0:LANES-1];
        mrec_res_t product_h_q [0:LANES-1];
        mrec_res_t product_x1_q [0:LANES-1];
        mrec_res_t product_h1_q [0:LANES-1];
        logic product_mul_in_valid_q;
        logic product_odd_q;
        logic product_clear_q;
        logic [5:0] product_batch_q;
        logic [5:0] product_batch1_q;
        logic product_store_rd_odd_q;
        logic [5:0] product_store_rd_batch_q;
        logic [5:0] product_store_rd_batch1_q;
        logic product_valid_pipe_q [0:PRODUCT_MUL_LAT-1];
        logic product_odd_pipe_q [0:PRODUCT_MUL_LAT-1];
        logic product_clear_pipe_q [0:PRODUCT_MUL_LAT-1];
        logic [5:0] product_batch_pipe_q [0:PRODUCT_MUL_LAT-1];
        logic [5:0] product_batch1_pipe_q [0:PRODUCT_MUL_LAT-1];

        assign product_accept_c = product_in_valid &&
          ((state_q == S_IDLE) ||
           (STREAM_PRODUCT_DURING_RUN && (state_q == S_RUN) &&
            (product_in_clear_accum || SEPARATE_PRODUCT_STORE)));
        assign product_acc_read_c = product_accept_c && !product_in_clear_accum;
        assign product_read_addr_c = product_addr_for(product_in_batch);
        assign plus_step_product_mode_c = 1'b0;
        assign minus_step_product_mode_c = 1'b0;
        assign plus_step_product4_mode_c = 1'b0;
        assign minus_step_product4_mode_c = 1'b0;
        assign product_write_valid_c = product_valid_pipe_q[PRODUCT_MUL_LAT-1];
        assign product_write_odd_c = product_odd_pipe_q[PRODUCT_MUL_LAT-1];
        assign product_write_clear_c = product_clear_pipe_q[PRODUCT_MUL_LAT-1];
        assign product_write_batch_c = product_batch_pipe_q[PRODUCT_MUL_LAT-1];
        assign product_write_valid1_c = PRODUCT_DUAL_BATCH ? product_valid_pipe_q[PRODUCT_MUL_LAT-1] : 1'b0;
        assign product_write_odd1_c = product_odd_pipe_q[PRODUCT_MUL_LAT-1];
        assign product_write_batch1_c = product_batch1_pipe_q[PRODUCT_MUL_LAT-1];
        assign product64_write_valid_c = 1'b0;
        assign product64_write_odd_c = 1'b0;
        assign product64_write_clear_c = 1'b0;
        assign product64_write_burst_c = '0;
        assign product_step_busy_c = 1'b0;

        for (genvar lane = 0; lane < LANES; lane++) begin : g_product_mul
          assign plus_step_product_w0_c[lane] = '0;
          assign plus_step_product_w1_c[lane] = '0;
          assign plus_step_product_w2_c[lane] = '0;
          assign plus_step_product_w3_c[lane] = '0;
          assign minus_step_product_w0_c[lane] = '0;
          assign minus_step_product_w1_c[lane] = '0;
          assign minus_step_product_w2_c[lane] = '0;
          assign minus_step_product_w3_c[lane] = '0;
          if (PRODUCT_MUL_TIGHT) begin : g_tight
            ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
              .EXTRA_STAGE(PRODUCT_MUL_EXTRA_STAGE)
            ) u_mul (
              .clk(clk),
              .rst(rst),
              .in_valid(product_mul_in_valid_q),
              .a_in(product_x_q[lane]),
              .b_in(product_h_q[lane]),
              .out_valid(),
              .p_out(product_prod[lane])
            );
          end else begin : g_generic
            ntt46_p520_ntt46_mrec_modmul_pipe #(
              .EXTRA_STAGE(PRODUCT_MUL_EXTRA_STAGE)
            ) u_mul (
              .clk(clk),
              .rst(rst),
              .in_valid(product_mul_in_valid_q),
              .a_in(product_x_q[lane]),
              .b_in(product_h_q[lane]),
              .out_valid(),
              .p_out(product_prod[lane])
            );
          end

          assign product_write_data_c[lane] =
            product_write_clear_c
              ? product_prod[lane]
              : mod_add(product_old_pipe_q[PRODUCT_MUL_LAT-1][lane], product_prod[lane]);
          assign product_write_data1_c[lane] =
            product_write_clear_c
              ? product_prod1[lane]
              : mod_add(product_old1_pipe_q[PRODUCT_MUL_LAT-1][lane], product_prod1[lane]);
          assign product64_write_y0_c[lane] = '0;
          assign product64_write_y1_c[lane] = '0;
          assign product64_write_y2_c[lane] = '0;
          assign product64_write_y3_c[lane] = '0;
        end

        if (PRODUCT_DUAL_BATCH) begin : g_product_mul1
          for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
            if (PRODUCT_MUL_TIGHT) begin : g_tight
              ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
                .EXTRA_STAGE(PRODUCT_MUL_EXTRA_STAGE)
              ) u_mul (
                .clk(clk),
                .rst(rst),
                .in_valid(product_mul_in_valid_q),
                .a_in(product_x1_q[lane]),
                .b_in(product_h1_q[lane]),
                .out_valid(),
                .p_out(product_prod1[lane])
              );
            end else begin : g_generic
              ntt46_p520_ntt46_mrec_modmul_pipe #(
                .EXTRA_STAGE(PRODUCT_MUL_EXTRA_STAGE)
              ) u_mul (
                .clk(clk),
                .rst(rst),
                .in_valid(product_mul_in_valid_q),
                .a_in(product_x1_q[lane]),
                .b_in(product_h1_q[lane]),
                .out_valid(),
                .p_out(product_prod1[lane])
              );
            end
          end
        end else begin : g_no_product_mul1
          for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
            assign product_prod1[lane] = '0;
          end
        end

        always_ff @(posedge clk) begin
          if (rst) begin
            product_mul_in_valid_q <= 1'b0;
            product_odd_q <= 1'b0;
            product_clear_q <= 1'b0;
            product_batch_q <= '0;
            product_batch1_q <= '0;
            product_store_rd_odd_q <= 1'b0;
            product_store_rd_batch_q <= '0;
            product_store_rd_batch1_q <= '0;
            for (int stage = 0; stage < PRODUCT_MUL_LAT; stage++) begin
              product_valid_pipe_q[stage] <= 1'b0;
              product_odd_pipe_q[stage] <= 1'b0;
              product_clear_pipe_q[stage] <= 1'b0;
              product_batch_pipe_q[stage] <= '0;
              product_batch1_pipe_q[stage] <= '0;
              if (!FACT_AREA_TRIM_CORE_DATA) begin
                for (int lane = 0; lane < LANES; lane++) begin
                  product_old_pipe_q[stage][lane] <= '0;
                  product_old1_pipe_q[stage][lane] <= '0;
                end
              end
            end
            if (!FACT_AREA_TRIM_CORE_DATA) begin
              for (int lane = 0; lane < LANES; lane++) begin
                product_x_q[lane] <= '0;
                product_h_q[lane] <= '0;
                product_x1_q[lane] <= '0;
                product_h1_q[lane] <= '0;
              end
            end
          end else begin
            product_mul_in_valid_q <= product_accept_c;
            product_store_rd_odd_q <= product_in_odd;
            product_store_rd_batch_q <= product_in_batch;
            product_store_rd_batch1_q <= product_in_batch1;

            if (product_accept_c) begin
              product_odd_q <= product_in_odd;
              product_clear_q <= product_in_clear_accum;
              product_batch_q <= product_in_batch;
              product_batch1_q <= product_in_batch1;
              for (int lane = 0; lane < LANES; lane++) begin
                product_x_q[lane] <= product_x_data[lane];
                product_h_q[lane] <= product_h_data[lane];
                product_x1_q[lane] <= product_x1_data[lane];
                product_h1_q[lane] <= product_h1_data[lane];
              end
            end

            product_valid_pipe_q[0] <= product_mul_in_valid_q;
            product_odd_pipe_q[0] <= product_odd_q;
            product_clear_pipe_q[0] <= product_clear_q;
            product_batch_pipe_q[0] <= product_batch_q;
            product_batch1_pipe_q[0] <= product_batch1_q;
            for (int lane = 0; lane < LANES; lane++) begin
              logic [3:0] lane_idx;
              logic [3:0] bank_idx;
              logic [3:0] bank1_idx;
              logic [1:0] slot_idx;
              logic [1:0] slot1_idx;
              logic [WORD_W-1:0] old_word;
              logic [WORD_W-1:0] old1_word;
              lane_idx = lane[3:0];
              bank_idx = product_bank_for(product_store_rd_batch_q, lane_idx);
              bank1_idx = product_bank_for(product_store_rd_batch1_q, lane_idx);
              slot_idx = product_slot_for(lane_idx);
              slot1_idx = product_slot_for(lane_idx);
              old_word = product_store_rd_odd_q
                         ? (SEPARATE_PRODUCT_STORE ? minus_product_rd_word[bank_idx]
                                                   : minus_store0_rd_word[bank_idx])
                         : (SEPARATE_PRODUCT_STORE ? plus_product_rd_word[bank_idx]
                                                   : plus_store0_rd_word[bank_idx]);
              old1_word = product_store_rd_odd_q
                          ? (SEPARATE_PRODUCT_STORE ? minus_product_rd_word[bank1_idx]
                                                    : minus_store0_rd_word[bank1_idx])
                          : (SEPARATE_PRODUCT_STORE ? plus_product_rd_word[bank1_idx]
                                                    : plus_store0_rd_word[bank1_idx]);
              product_old_pipe_q[0][lane] <= old_word[(slot_idx * MREC_DATA_W) +: MREC_DATA_W];
              product_old1_pipe_q[0][lane] <= old1_word[(slot1_idx * MREC_DATA_W) +: MREC_DATA_W];
            end

            for (int stage = 1; stage < PRODUCT_MUL_LAT; stage++) begin
              product_valid_pipe_q[stage] <= product_valid_pipe_q[stage-1];
              product_odd_pipe_q[stage] <= product_odd_pipe_q[stage-1];
              product_clear_pipe_q[stage] <= product_clear_pipe_q[stage-1];
              product_batch_pipe_q[stage] <= product_batch_pipe_q[stage-1];
              product_batch1_pipe_q[stage] <= product_batch1_pipe_q[stage-1];
              for (int lane = 0; lane < LANES; lane++) begin
                product_old_pipe_q[stage][lane] <= product_old_pipe_q[stage-1][lane];
                product_old1_pipe_q[stage][lane] <= product_old1_pipe_q[stage-1][lane];
              end
            end
          end
        end
      end
    end else begin : g_no_product_accum
      assign product_accept_c = 1'b0;
      assign product_acc_read_c = 1'b0;
      assign product_read_addr_c = '0;
      assign product_write_valid_c = 1'b0;
      assign product_write_odd_c = 1'b0;
      assign product_write_clear_c = 1'b0;
      assign product_write_batch_c = '0;
      assign product_write_valid1_c = 1'b0;
      assign product_write_odd1_c = 1'b0;
      assign product_write_batch1_c = '0;
      assign product64_write_valid_c = 1'b0;
      assign product64_write_odd_c = 1'b0;
      assign product64_write_clear_c = 1'b0;
      assign product64_write_burst_c = '0;
      assign product_step_busy_c = 1'b0;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_product_zero
        assign product_write_data_c[lane] = '0;
        assign product_write_data1_c[lane] = '0;
        assign plus_step_product_w0_c[lane] = '0;
        assign plus_step_product_w1_c[lane] = '0;
        assign plus_step_product_w2_c[lane] = '0;
        assign plus_step_product_w3_c[lane] = '0;
        assign minus_step_product_w0_c[lane] = '0;
        assign minus_step_product_w1_c[lane] = '0;
        assign minus_step_product_w2_c[lane] = '0;
        assign minus_step_product_w3_c[lane] = '0;
        assign product64_write_y0_c[lane] = '0;
        assign product64_write_y1_c[lane] = '0;
        assign product64_write_y2_c[lane] = '0;
        assign product64_write_y3_c[lane] = '0;
      end
      assign plus_step_product_mode_c = 1'b0;
      assign minus_step_product_mode_c = 1'b0;
      assign plus_step_product4_mode_c = 1'b0;
      assign minus_step_product4_mode_c = 1'b0;
    end
  endgenerate

  always_comb begin
    issue_fire_c = 1'b0;
    issue_pos_c = '0;
    issue_stage_c = '0;
    issue_batch_c = '0;
    issue_batches_c = '0;
    if ((state_q == S_RUN) && !scheduler_done_q &&
        !(PRODUCT_REUSE_STEP4 && product64_in_valid) && !product_step_busy_c) begin
      if ((R == 512) && (LANES == 8) &&
          ((forward_mode_q && ((R512_L8_SCHED_MODE == 5) ||
                               (R512_L8_SCHED_MODE == 6) ||
                               (R512_L8_SCHED_MODE == 7))) ||
           (!forward_mode_q && ((R512_L8_SCHED_MODE == 5) ||
                                (R512_L8_SCHED_MODE == 6) ||
                                (R512_L8_SCHED_MODE == 8))))) begin
        for (int pri = 0; pri < POSITIONS; pri++) begin
          logic [2:0] pos_sel;
          logic [2:0] st;
          logic [BATCH_COUNT_W-1:0] batches;
          logic [BATCH_W-1:0] batch;
          pos_sel = r512_l8_sched_pos_for(!forward_mode_q, pri[2:0]);
          st = stage_for_pos(!forward_mode_q, pos_sel);
          batches = batches_for(st);
          if (!issue_fire_c && (issue_count_q[pos_sel] < batches)) begin
            for (int idx = 0; idx < STAGE0_BATCHES; idx++) begin
              batch = scheduled_batch_for(!forward_mode_q, st, 5'(idx));
              if (!issue_fire_c && (idx < batches) && ready_q[pos_sel][batch] &&
                  !(SEPARATE_PRODUCT_STORE && !PRODUCT_STORE_DUAL_READ &&
                    !forward_mode_q && (pos_sel == 3'd0) && product_acc_read_c)) begin
                issue_fire_c = 1'b1;
                issue_pos_c = pos_sel;
                issue_stage_c = st;
                issue_batch_c = batch;
                issue_batches_c = batches;
              end
            end
          end
        end
      end else if ((R == 512) && (LANES == 8) && forward_mode_q) begin
        logic [2:0] st;
        logic [BATCH_COUNT_W-1:0] batches;
        logic [BATCH_W-1:0] batch;
        st = stage_for_pos(1'b0, 3'd2);
        batches = batches_for(st);
        batch = scheduled_batch_for(1'b0, st, issue_count_q[2]);
        if ((issue_count_q[2] < batches) && ready_q[2][batch]) begin
          issue_fire_c = 1'b1;
          issue_pos_c = 3'd2;
          issue_stage_c = st;
          issue_batch_c = batch;
          issue_batches_c = batches;
        end else begin
          st = stage_for_pos(1'b0, 3'd3);
          batches = batches_for(st);
          batch = scheduled_batch_for(1'b0, st, issue_count_q[3]);
          if ((issue_count_q[3] < batches) && ready_q[3][batch]) begin
            issue_fire_c = 1'b1;
            issue_pos_c = 3'd3;
            issue_stage_c = st;
            issue_batch_c = batch;
            issue_batches_c = batches;
          end
        end
      end else if ((R == 512) && (LANES == 8) && !forward_mode_q) begin
        logic [2:0] st;
        logic [BATCH_COUNT_W-1:0] batches;
        logic [BATCH_W-1:0] batch;
        st = stage_for_pos(1'b1, 3'd3);
        batches = batches_for(st);
        batch = scheduled_batch_for(1'b1, st, issue_count_q[3]);
        if ((issue_count_q[3] < batches) && ready_q[3][batch]) begin
          issue_fire_c = 1'b1;
          issue_pos_c = 3'd3;
          issue_stage_c = st;
          issue_batch_c = batch;
          issue_batches_c = batches;
        end
      end
      for (int pos = POSITIONS - 1; pos >= 0; pos--) begin
        logic [2:0] st;
        logic [BATCH_COUNT_W-1:0] batches;
        logic [BATCH_W-1:0] batch;
        st = stage_for_pos(!forward_mode_q, pos[2:0]);
        batches = batches_for(st);
        batch = scheduled_batch_for(!forward_mode_q, st, issue_count_q[pos]);
        if (!issue_fire_c && (issue_count_q[pos] < batches) && ready_q[pos][batch] &&
            !(SEPARATE_PRODUCT_STORE && !PRODUCT_STORE_DUAL_READ &&
              !forward_mode_q && (pos[2:0] == 3'd0) && product_acc_read_c)) begin
          issue_fire_c = 1'b1;
          issue_pos_c = pos[2:0];
          issue_stage_c = st;
          issue_batch_c = batch;
          issue_batches_c = batches;
        end
      end
    end
  end

  always_comb begin
    writer_valid_c = 1'b0;
    writer_slot_c = '0;
    writer_pos_c = '0;
    writer_stage_c = '0;
    writer_group_c = '0;
    writer_phase_c = '0;
    writer_dest_c = '0;
    if ((state_q == S_RUN) && (ready_count_q != 6'd0)) begin
      writer_valid_c = 1'b1;
      writer_slot_c = ready_slot_q[ready_head_q];
      writer_pos_c = slot_pos_q[ready_slot_q[ready_head_q]];
      writer_stage_c = stage_for_pos(!forward_mode_q, slot_pos_q[ready_slot_q[ready_head_q]]);
      writer_group_c = slot_group_q[ready_slot_q[ready_head_q]];
      writer_phase_c = slot_phase_q[ready_slot_q[ready_head_q]];
      writer_dest_c = write_dest_for(
        !forward_mode_q,
        stage_for_pos(!forward_mode_q, slot_pos_q[ready_slot_q[ready_head_q]]),
        slot_group_q[ready_slot_q[ready_head_q]],
        slot_phase_q[ready_slot_q[ready_head_q]]
      );
    end
  end

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(STORE_DEPTH),
    .ADDR_W(STORE_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE("block"),
    .USE_XPM(STORE_USE_XPM)
  ) u_plus_store0 (
    .clk(clk),
    .wr_en(plus_store0_wr_en),
    .wr_addr(store0_wr_addr),
    .wr_data(plus_store0_wr_data),
    .rd_en(store0_rd_en),
    .rd_addr(store0_rd_addr),
    .rd_word(plus_store0_rd_word)
  );

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(STORE_DEPTH),
    .ADDR_W(STORE_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE("block"),
    .USE_XPM(STORE_USE_XPM)
  ) u_plus_store1 (
    .clk(clk),
    .wr_en(plus_store1_wr_en),
    .wr_addr(store1_wr_addr),
    .wr_data(plus_store1_wr_data),
    .rd_en(store1_rd_en),
    .rd_addr(store1_rd_addr),
    .rd_word(plus_store1_rd_word)
  );

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(STORE_DEPTH),
    .ADDR_W(STORE_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE("block"),
    .USE_XPM(STORE_USE_XPM)
  ) u_minus_store0 (
    .clk(clk),
    .wr_en(minus_store0_wr_en),
    .wr_addr(store0_wr_addr),
    .wr_data(minus_store0_wr_data),
    .rd_en(store0_rd_en),
    .rd_addr(store0_rd_addr),
    .rd_word(minus_store0_rd_word)
  );

  ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(STORE_DEPTH),
    .ADDR_W(STORE_ADDR_W),
    .LANES(LANES),
    .RAM_STYLE("block"),
    .USE_XPM(STORE_USE_XPM)
  ) u_minus_store1 (
    .clk(clk),
    .wr_en(minus_store1_wr_en),
    .wr_addr(store1_wr_addr),
    .wr_data(minus_store1_wr_data),
    .rd_en(store1_rd_en),
    .rd_addr(store1_rd_addr),
    .rd_word(minus_store1_rd_word)
  );

  generate
    if (SEPARATE_PRODUCT_STORE) begin : g_separate_product_store
      ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
        .DEPTH(PRODUCT_STORE_DEPTH),
        .ADDR_W(PRODUCT_STORE_ADDR_W),
        .LANES(LANES),
        .RAM_STYLE(PRODUCT_STORE_RAM_STYLE),
        .SPLIT_SLOTS(PRODUCT_STORE_SPLIT_SLOTS),
        .USE_XPM(STORE_USE_XPM)
      ) u_plus_product_store (
        .clk(clk),
        .wr_en(plus_product_wr_en),
        .wr_addr(product_store_wr_addr),
        .wr_data(plus_product_wr_data),
        .rd_en(product_store_rd_en),
        .rd_addr(product_store_rd_addr),
        .rd_word(plus_product_rd_word)
      );

      ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
        .DEPTH(PRODUCT_STORE_DEPTH),
        .ADDR_W(PRODUCT_STORE_ADDR_W),
        .LANES(LANES),
        .RAM_STYLE(PRODUCT_STORE_RAM_STYLE),
        .SPLIT_SLOTS(PRODUCT_STORE_SPLIT_SLOTS),
        .USE_XPM(STORE_USE_XPM)
      ) u_minus_product_store (
        .clk(clk),
        .wr_en(minus_product_wr_en),
        .wr_addr(product_store_wr_addr),
        .wr_data(minus_product_wr_data),
        .rd_en(product_store_rd_en),
        .rd_addr(product_store_rd_addr),
        .rd_word(minus_product_rd_word)
      );

      if (PRODUCT_STORE_DUAL_READ) begin : g_dual_read
        ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
          .DEPTH(PRODUCT_STORE_DEPTH),
          .ADDR_W(PRODUCT_STORE_ADDR_W),
          .LANES(LANES),
          .RAM_STYLE(PRODUCT_STORE_RAM_STYLE),
          .SPLIT_SLOTS(PRODUCT_STORE_SPLIT_SLOTS),
          .USE_XPM(STORE_USE_XPM)
        ) u_plus_product_inv_store (
          .clk(clk),
          .wr_en(plus_product_wr_en),
          .wr_addr(product_store_wr_addr),
          .wr_data(plus_product_wr_data),
          .rd_en(product_inv_store_rd_en),
          .rd_addr(product_inv_store_rd_addr),
          .rd_word(plus_product_inv_rd_word)
        );

        ntt46_p520_ntt46_zest_slot16_store_sameaddr #(
          .DEPTH(PRODUCT_STORE_DEPTH),
          .ADDR_W(PRODUCT_STORE_ADDR_W),
          .LANES(LANES),
          .RAM_STYLE(PRODUCT_STORE_RAM_STYLE),
          .SPLIT_SLOTS(PRODUCT_STORE_SPLIT_SLOTS),
          .USE_XPM(STORE_USE_XPM)
        ) u_minus_product_inv_store (
          .clk(clk),
          .wr_en(minus_product_wr_en),
          .wr_addr(product_store_wr_addr),
          .wr_data(minus_product_wr_data),
          .rd_en(product_inv_store_rd_en),
          .rd_addr(product_inv_store_rd_addr),
          .rd_word(minus_product_inv_rd_word)
        );
      end else begin : g_single_read
        for (genvar bank = 0; bank < LANES; bank++) begin : g_bank
          assign plus_product_inv_rd_word[bank] = plus_product_rd_word[bank];
          assign minus_product_inv_rd_word[bank] = minus_product_rd_word[bank];
        end
      end
    end else begin : g_no_separate_product_store
      for (genvar bank = 0; bank < LANES; bank++) begin : g_zero_product_rd
        assign plus_product_rd_word[bank] = '0;
        assign minus_product_rd_word[bank] = '0;
        assign plus_product_inv_rd_word[bank] = '0;
        assign minus_product_inv_rd_word[bank] = '0;
      end
    end
  endgenerate

  ntt46_p520_ntt46_zest_radix24_step16 #(
    .DEPTH(DEPTH),
    .ADDR_W(ADDR_W),
    .LANES(LANES),
    .FWD_MEM_FILE((R==128 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r128_l4.mem" :
                  (R==128 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r128_l8.mem" :
                  (R==128) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r128.mem" :
                  (R==256 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r256_l8.mem" :
                  (R==256 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r256_l4.mem" :
                  (R==256) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r256.mem" :
                  (R==512 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r512_l8.mem" :
                  (R==512 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r512_l4.mem" :
                             "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r512.mem"),
    .INV_MEM_FILE((R==128 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r128_l4.mem" :
                  (R==128 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r128_l8.mem" :
                  (R==128) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r128.mem" :
                  (R==256 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r256_l8.mem" :
                  (R==256 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r256_l4.mem" :
                  (R==256) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r256.mem" :
                  (R==512 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r512_l8.mem" :
                  (R==512 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r512_l4.mem" :
                             "rom_p520/zest_schedule/zest_radix24_twiddle_inv_r512.mem"),
    .J_USE_DSP(TRANSFORM_J_USE_DSP),
    .J_LUT_FAST3(TRANSFORM_J_LUT_FAST3),
    .USE_UNIFIED_LANE(1'b1),
    .MUL_EXTRA_STAGE(TRANSFORM_MUL_EXTRA_STAGE),
    .INVERSE_J_PRE_STAGE(1'b1),
    .USE_TIGHT_MUL(TRANSFORM_MUL_TIGHT),
    .J_USE_TIGHT_MUL(TRANSFORM_J_MUL_TIGHT),
    .TWIDDLE_PRE_STAGE(TRANSFORM_TWIDDLE_PRE_STAGE),
    .TWIDDLE_PREFETCH_STAGE(TRANSFORM_TWIDDLE_PREFETCH_STAGE),
    .INVERSE_TWIDDLE_ONLY(!ENABLE_FORWARD_MODE),
    .ENABLE_PRODUCT4_MODE(PRODUCT_REUSE_STEP4),
    .RESET_DATA_ARRAYS(!FACT_AREA_TRIM_STEP_DATA)
  ) u_plus_step (
    .clk(clk),
    .rst(rst),
    .in_valid(plus_step_in_valid),
    .inverse(!forward_mode_q && !(plus_step_product_mode_c || plus_step_product4_mode_c)),
    .coset_untwist(1'b0),
    .radix2_mode((plus_step_product_mode_c || plus_step_product4_mode_c) ? 1'b1 : step_radix2),
    .product_mode(plus_step_product_mode_c),
    .product4_mode(plus_step_product4_mode_c),
    .twiddle_addr(step_twiddle_addr),
    .twiddle_prefetch_valid(issue_fire_c),
    .twiddle_prefetch_addr(step_twiddle_prefetch_addr),
    .x0_in(plus_step_x0),
    .x1_in(plus_step_x1),
    .x2_in(plus_step_x2),
    .x3_in(plus_step_x3),
    .product_w0_in(plus_step_product_w0_c),
    .product_w1_in(plus_step_product_w1_c),
    .product_w2_in(plus_step_product_w2_c),
    .product_w3_in(plus_step_product_w3_c),
    .out_valid(plus_step_raw_out_valid),
    .fwd_out_valid(plus_step_raw_fwd_out_valid),
    .inv_out_valid(plus_step_raw_inv_out_valid),
    .y0_out(plus_step_raw_y0),
    .y1_out(plus_step_raw_y1),
    .y2_out(plus_step_raw_y2),
    .y3_out(plus_step_raw_y3)
  );

  ntt46_p520_ntt46_zest_radix24_step16 #(
    .DEPTH(DEPTH),
    .ADDR_W(ADDR_W),
    .LANES(LANES),
    .FWD_MEM_FILE((R==128 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r128_l4.mem" :
                  (R==128 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r128_l8.mem" :
                  (R==128) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r128.mem" :
                  (R==256 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r256_l8.mem" :
                  (R==256 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r256_l4.mem" :
                  (R==256) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r256.mem" :
                  (R==512 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r512_l8.mem" :
                  (R==512 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r512_l4.mem" :
                             "rom_p520/zest_schedule/zest_radix24_twiddle_fwd_r512.mem"),
    .INV_MEM_FILE((R==128 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r128_l4.mem" :
                  (R==128 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r128_l8.mem" :
                  (R==128) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r128.mem" :
                  (R==256 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r256_l8.mem" :
                  (R==256 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r256_l4.mem" :
                  (R==256) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r256.mem" :
                  (R==512 && LANES==8) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r512_l8.mem" :
                  (R==512 && LANES==4) ? "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r512_l4.mem" :
                             "rom_p520/zest_schedule/zest_radix24_twiddle_inv_coset_r512.mem"),
    .J_USE_DSP(TRANSFORM_J_USE_DSP),
    .J_LUT_FAST3(TRANSFORM_J_LUT_FAST3),
    .USE_UNIFIED_LANE(1'b1),
    .MUL_EXTRA_STAGE(TRANSFORM_MUL_EXTRA_STAGE),
    .INVERSE_J_PRE_STAGE(1'b1),
    .USE_TIGHT_MUL(TRANSFORM_MUL_TIGHT),
    .J_USE_TIGHT_MUL(TRANSFORM_J_MUL_TIGHT),
    .TWIDDLE_PRE_STAGE(TRANSFORM_TWIDDLE_PRE_STAGE),
    .TWIDDLE_PREFETCH_STAGE(TRANSFORM_TWIDDLE_PREFETCH_STAGE),
    .INVERSE_TWIDDLE_ONLY(!ENABLE_FORWARD_MODE),
    .ENABLE_PRODUCT4_MODE(PRODUCT_REUSE_STEP4),
    .RESET_DATA_ARRAYS(!FACT_AREA_TRIM_STEP_DATA)
  ) u_minus_step (
    .clk(clk),
    .rst(rst),
    .in_valid(minus_step_in_valid),
    .inverse(!forward_mode_q && !(minus_step_product_mode_c || minus_step_product4_mode_c)),
    .coset_untwist((minus_step_product_mode_c || minus_step_product4_mode_c) ? 1'b0 :
                   (!forward_mode_q && step_radix2)),
    .radix2_mode((minus_step_product_mode_c || minus_step_product4_mode_c) ? 1'b1 : step_radix2),
    .product_mode(minus_step_product_mode_c),
    .product4_mode(minus_step_product4_mode_c),
    .twiddle_addr(step_twiddle_addr),
    .twiddle_prefetch_valid(issue_fire_c),
    .twiddle_prefetch_addr(step_twiddle_prefetch_addr),
    .x0_in(minus_step_x0),
    .x1_in(minus_step_x1),
    .x2_in(minus_step_x2),
    .x3_in(minus_step_x3),
    .product_w0_in(minus_step_product_w0_c),
    .product_w1_in(minus_step_product_w1_c),
    .product_w2_in(minus_step_product_w2_c),
    .product_w3_in(minus_step_product_w3_c),
    .out_valid(minus_step_raw_out_valid),
    .fwd_out_valid(minus_step_raw_fwd_out_valid),
    .inv_out_valid(minus_step_raw_inv_out_valid),
    .y0_out(minus_step_raw_y0),
    .y1_out(minus_step_raw_y1),
    .y2_out(minus_step_raw_y2),
    .y3_out(minus_step_raw_y3)
  );

  ntt46_p520_ntt46_fact_terminal_crt_recombine32_r512 #(
    .LANES(LANES),
    .BATCH_W(OUT_BATCH_W),
    .INPUT_PIPELINE(TERMINAL_INPUT_PIPELINE),
    .RESET_DATA_ARRAYS(TERMINAL_RESET_DATA_ARRAYS)
  ) u_terminal_crt (
    .clk(clk),
    .rst(rst),
    .clear(start && (state_q == S_IDLE)),
    .in_valid(term_crt_in_valid),
    .in_batch(term_crt_in_batch_c),
    .plus_y0(term_crt_plus_y0_c),
    .plus_y1(term_crt_plus_y1_c),
    .minus_untwisted_y0(term_crt_minus_y0_c),
    .minus_untwisted_y1(term_crt_minus_y1_c),
    .out_valid(term_out_valid),
    .out_batch(term_out_batch),
    .low_y0(term_low_y0),
    .high_y0(term_high_y0),
    .low_y1(term_low_y1),
    .high_y1(term_high_y1)
  );

  always_comb begin
    for (int lane = 0; lane < LANES; lane++) begin
      logic [WORD_W-1:0] plus_word;
      logic [WORD_W-1:0] minus_word;
      plus_word = read_product_q ? plus_product_inv_rd_word[lane] :
                  (read_store1_q ? plus_store1_rd_word[lane] : plus_store0_rd_word[lane]);
      minus_word = read_product_q ? minus_product_inv_rd_word[lane] :
                   (read_store1_q ? minus_store1_rd_word[lane] : minus_store0_rd_word[lane]);
      if (plus_step_product4_mode_c) begin
        plus_step_x0[lane] = product64_x_y0_q[lane];
        plus_step_x1[lane] = product64_x_y1_q[lane];
        plus_step_x2[lane] = product64_x_y2_q[lane];
        plus_step_x3[lane] = product64_x_y3_q[lane];
      end else if (plus_step_product_mode_c) begin
        plus_step_x0[lane] = product_x_data[lane];
        plus_step_x1[lane] = '0;
        plus_step_x2[lane] = '0;
        plus_step_x3[lane] = '0;
      end else if (read_ext_stage0_q) begin
        plus_step_x0[lane] = ext_stage0_plus_y0[lane];
        plus_step_x1[lane] = ext_stage0_plus_y1[lane];
        plus_step_x2[lane] = ext_stage0_plus_y2[lane];
        plus_step_x3[lane] = ext_stage0_plus_y3[lane];
      end else begin
        plus_step_x0[lane] = plus_word[0 +: MREC_DATA_W];
        plus_step_x1[lane] = plus_word[MREC_DATA_W +: MREC_DATA_W];
        plus_step_x2[lane] = plus_word[(2 * MREC_DATA_W) +: MREC_DATA_W];
        plus_step_x3[lane] = plus_word[(3 * MREC_DATA_W) +: MREC_DATA_W];
      end
      if (minus_step_product4_mode_c) begin
        minus_step_x0[lane] = product64_x_y0_q[lane];
        minus_step_x1[lane] = product64_x_y1_q[lane];
        minus_step_x2[lane] = product64_x_y2_q[lane];
        minus_step_x3[lane] = product64_x_y3_q[lane];
      end else if (minus_step_product_mode_c) begin
        minus_step_x0[lane] = product_x_data[lane];
        minus_step_x1[lane] = '0;
        minus_step_x2[lane] = '0;
        minus_step_x3[lane] = '0;
      end else if (read_ext_stage0_q) begin
        minus_step_x0[lane] = ext_stage0_minus_y0[lane];
        minus_step_x1[lane] = ext_stage0_minus_y1[lane];
        minus_step_x2[lane] = ext_stage0_minus_y2[lane];
        minus_step_x3[lane] = ext_stage0_minus_y3[lane];
      end else begin
        minus_step_x0[lane] = minus_word[0 +: MREC_DATA_W];
        minus_step_x1[lane] = minus_word[MREC_DATA_W +: MREC_DATA_W];
        minus_step_x2[lane] = minus_word[(2 * MREC_DATA_W) +: MREC_DATA_W];
        minus_step_x3[lane] = minus_word[(3 * MREC_DATA_W) +: MREC_DATA_W];
      end

      plus_step_eff_y0[lane] = plus_step_raw_y0[lane];
      plus_step_eff_y1[lane] = plus_step_raw_y1[lane];
      plus_step_eff_y2[lane] = plus_step_raw_y2[lane];
      plus_step_eff_y3[lane] = plus_step_raw_y3[lane];
      plus_step_y0[lane] = forward_mode_q ? plus_step_eff_y0[lane] :
                            (INVERSE_OUTPUT_PIPELINE ? plus_step_out_pipe_y0_q[lane] : plus_step_raw_y0[lane]);
      plus_step_y1[lane] = forward_mode_q ? plus_step_eff_y1[lane] :
                            (INVERSE_OUTPUT_PIPELINE ? plus_step_out_pipe_y1_q[lane] : plus_step_raw_y1[lane]);
      plus_step_y2[lane] = forward_mode_q ? plus_step_eff_y2[lane] :
                            (INVERSE_OUTPUT_PIPELINE ? plus_step_out_pipe_y2_q[lane] : plus_step_raw_y2[lane]);
      plus_step_y3[lane] = forward_mode_q ? plus_step_eff_y3[lane] :
                            (INVERSE_OUTPUT_PIPELINE ? plus_step_out_pipe_y3_q[lane] : plus_step_raw_y3[lane]);
      minus_step_y0[lane] = forward_mode_q ? minus_step_raw_y0[lane] :
                             (INVERSE_OUTPUT_PIPELINE ? minus_step_out_pipe_y0_q[lane] : minus_step_raw_y0[lane]);
      minus_step_y1[lane] = forward_mode_q ? minus_step_raw_y1[lane] :
                             (INVERSE_OUTPUT_PIPELINE ? minus_step_out_pipe_y1_q[lane] : minus_step_raw_y1[lane]);
      minus_step_y2[lane] = forward_mode_q ? minus_step_raw_y2[lane] :
                             (INVERSE_OUTPUT_PIPELINE ? minus_step_out_pipe_y2_q[lane] : minus_step_raw_y2[lane]);
      minus_step_y3[lane] = forward_mode_q ? minus_step_raw_y3[lane] :
                             (INVERSE_OUTPUT_PIPELINE ? minus_step_out_pipe_y3_q[lane] : minus_step_raw_y3[lane]);
    end
  end

  always_comb begin
    store0_rd_en = 1'b0;
    store1_rd_en = 1'b0;
    ext_stage0_rd_en = 1'b0;
    ext_stage0_rd_batch = '0;
    product_store_rd_en = 1'b0;
    product_inv_store_rd_en = 1'b0;
    for (int bank = 0; bank < LANES; bank++) begin
      plus_store0_wr_en[bank] = '0;
      minus_store0_wr_en[bank] = '0;
      plus_store1_wr_en[bank] = '0;
      minus_store1_wr_en[bank] = '0;
      plus_product_wr_en[bank] = '0;
      minus_product_wr_en[bank] = '0;
      store0_wr_addr[bank] = '0;
      store1_wr_addr[bank] = '0;
      product_store_wr_addr[bank] = '0;
      writer_wr_en_c[bank] = '0;
      writer_wr_addr_c[bank] = '0;
      store0_rd_addr[bank] = issue_batch_c;
      store1_rd_addr[bank] = issue_batch_c;
      product_store_rd_addr[bank] = issue_batch_c;
      product_inv_store_rd_addr[bank] = issue_batch_c;
      for (int slot = 0; slot < 4; slot++) begin
        plus_store0_wr_data[bank][slot] = '0;
        plus_store1_wr_data[bank][slot] = '0;
        plus_product_wr_data[bank][slot] = '0;
        minus_store0_wr_data[bank][slot] = '0;
        minus_store1_wr_data[bank][slot] = '0;
        minus_product_wr_data[bank][slot] = '0;
        writer_plus_wr_data_c[bank][slot] = '0;
        writer_minus_wr_data_c[bank][slot] = '0;
      end
    end

    if (product_acc_read_c && SEPARATE_PRODUCT_STORE) begin
      product_store_rd_en = 1'b1;
      for (int bank = 0; bank < LANES; bank++) begin
        product_store_rd_addr[bank] = product_store_addr_for(product_in_batch);
      end
      if (PRODUCT_DUAL_BATCH) begin
        for (int lane = 0; lane < LANES; lane++) begin
          logic [3:0] bank1_idx;
          bank1_idx = product_bank_for(product_in_batch1, lane[3:0]);
          product_store_rd_addr[bank1_idx] = product_store_addr_for(product_in_batch1);
        end
      end
    end

    if (product_acc_read_c && !SEPARATE_PRODUCT_STORE) begin
      store0_rd_en = 1'b1;
      for (int bank = 0; bank < LANES; bank++) begin
        store0_rd_addr[bank] = product_read_addr_c;
      end
      if (PRODUCT_DUAL_BATCH) begin
        for (int lane = 0; lane < LANES; lane++) begin
          logic [3:0] bank1_idx;
          bank1_idx = product_bank_for(product_in_batch1, lane[3:0]);
          store0_rd_addr[bank1_idx] = product_addr_for(product_in_batch1);
        end
      end
    end

    if (issue_fire_c) begin
      if (SEPARATE_PRODUCT_STORE && !forward_mode_q && (issue_pos_c == 3'd0)) begin
        if (PRODUCT_STORE_DUAL_READ) begin
          product_inv_store_rd_en = 1'b1;
          for (int bank = 0; bank < LANES; bank++) begin
            product_inv_store_rd_addr[bank] = product_store_stage_addr_for(issue_batch_c);
          end
        end else if (!product_acc_read_c) begin
          product_store_rd_en = 1'b1;
          for (int bank = 0; bank < LANES; bank++) begin
            product_store_rd_addr[bank] = product_store_stage_addr_for(issue_batch_c);
          end
        end
      end else if (FACT_EXT_STAGE0_ENABLE && forward_mode_q && (issue_pos_c == 3'd0)) begin
        ext_stage0_rd_en = 1'b1;
        ext_stage0_rd_batch = issue_batch_c;
      end else if (issue_pos_c[0]) begin
        store1_rd_en = 1'b1;
      end else begin
        store0_rd_en = 1'b1;
      end
    end

    if (ENABLE_LOAD16 && (state_q == S_IDLE) && load16_en) begin
      int addr16_i;
      int slot16_i;
      addr16_i = load16_idx % STORE_DEPTH;
      slot16_i = load16_idx / STORE_DEPTH;
      for (int bank_i = 0; bank_i < LANES; bank_i++) begin
        plus_store0_wr_en[bank_i][slot16_i] = 1'b1;
        minus_store0_wr_en[bank_i][slot16_i] = 1'b1;
        store0_wr_addr[bank_i] = STORE_ADDR_W'(addr16_i);
        plus_store0_wr_data[bank_i][slot16_i] = plus_load16_data[bank_i];
        minus_store0_wr_data[bank_i][slot16_i] = minus_load16_data[bank_i];
      end
    end else if ((state_q == S_IDLE) && load_en) begin
      int bank_i;
      int addr_i;
      int slot_i;
      if (LOAD_FORWARD_LAYOUT) begin
        bank_i = load_idx % LANES;
        addr_i = (load_idx / LANES) % STORE_DEPTH;
        slot_i = load_idx / (LANES * STORE_DEPTH);
      end else begin
        bank_i = (load_idx / 4) % LANES;
        addr_i = load_idx / (4 * LANES);
        slot_i = load_idx % 4;
      end
      plus_store0_wr_en[bank_i][slot_i] = 1'b1;
      minus_store0_wr_en[bank_i][slot_i] = 1'b1;
      store0_wr_addr[bank_i] = STORE_ADDR_W'(addr_i);
      plus_store0_wr_data[bank_i][slot_i] = plus_load_data;
      minus_store0_wr_data[bank_i][slot_i] = minus_load_data;
    end else if (wr_pipe_valid_q) begin
      for (int bank = 0; bank < LANES; bank++) begin
        if (wr_pipe_store1_q) begin
          plus_store1_wr_en[bank] = wr_pipe_en_q[bank];
          minus_store1_wr_en[bank] = wr_pipe_en_q[bank];
          store1_wr_addr[bank] = wr_pipe_addr_q[bank];
          for (int slot = 0; slot < 4; slot++) begin
            plus_store1_wr_data[bank][slot] = wr_pipe_plus_data_q[bank][slot];
            minus_store1_wr_data[bank][slot] = wr_pipe_minus_data_q[bank][slot];
          end
        end else begin
          plus_store0_wr_en[bank] = wr_pipe_en_q[bank];
          minus_store0_wr_en[bank] = wr_pipe_en_q[bank];
          store0_wr_addr[bank] = wr_pipe_addr_q[bank];
          for (int slot = 0; slot < 4; slot++) begin
            plus_store0_wr_data[bank][slot] = wr_pipe_plus_data_q[bank][slot];
            minus_store0_wr_data[bank][slot] = wr_pipe_minus_data_q[bank][slot];
          end
        end
      end
    end

    if (product_write_valid_c) begin
      for (int lane = 0; lane < LANES; lane++) begin
        logic [3:0] lane_idx;
        logic [3:0] bank_idx;
        logic [1:0] slot_idx;
        lane_idx = lane[3:0];
        bank_idx = product_bank_for(product_write_batch_c, lane_idx);
        slot_idx = product_slot_for(lane_idx);
        if (SEPARATE_PRODUCT_STORE) begin
          product_store_wr_addr[bank_idx] = product_store_addr_for(product_write_batch_c);
        end else begin
          store0_wr_addr[bank_idx] = product_addr_for(product_write_batch_c);
        end
        if (product_write_odd_c) begin
          if (SEPARATE_PRODUCT_STORE) begin
            minus_product_wr_en[bank_idx][slot_idx] = 1'b1;
            minus_product_wr_data[bank_idx][slot_idx] = product_write_data_c[lane];
          end else begin
            minus_store0_wr_en[bank_idx][slot_idx] = 1'b1;
            minus_store0_wr_data[bank_idx][slot_idx] = product_write_data_c[lane];
          end
        end else begin
          if (SEPARATE_PRODUCT_STORE) begin
            plus_product_wr_en[bank_idx][slot_idx] = 1'b1;
            plus_product_wr_data[bank_idx][slot_idx] = product_write_data_c[lane];
          end else begin
            plus_store0_wr_en[bank_idx][slot_idx] = 1'b1;
            plus_store0_wr_data[bank_idx][slot_idx] = product_write_data_c[lane];
          end
        end
      end
    end

    if (product_write_valid1_c) begin
      for (int lane = 0; lane < LANES; lane++) begin
        logic [3:0] lane_idx;
        logic [3:0] bank_idx;
        logic [1:0] slot_idx;
        lane_idx = lane[3:0];
        bank_idx = product_bank_for(product_write_batch1_c, lane_idx);
        slot_idx = product_slot_for(lane_idx);
        if (SEPARATE_PRODUCT_STORE) begin
          product_store_wr_addr[bank_idx] = product_store_addr_for(product_write_batch1_c);
        end else begin
          store0_wr_addr[bank_idx] = product_addr_for(product_write_batch1_c);
        end
        if (product_write_odd1_c) begin
          if (SEPARATE_PRODUCT_STORE) begin
            minus_product_wr_en[bank_idx][slot_idx] = 1'b1;
            minus_product_wr_data[bank_idx][slot_idx] = product_write_data1_c[lane];
          end else begin
            minus_store0_wr_en[bank_idx][slot_idx] = 1'b1;
            minus_store0_wr_data[bank_idx][slot_idx] = product_write_data1_c[lane];
          end
        end else begin
          if (SEPARATE_PRODUCT_STORE) begin
            plus_product_wr_en[bank_idx][slot_idx] = 1'b1;
            plus_product_wr_data[bank_idx][slot_idx] = product_write_data1_c[lane];
          end else begin
            plus_store0_wr_en[bank_idx][slot_idx] = 1'b1;
            plus_store0_wr_data[bank_idx][slot_idx] = product_write_data1_c[lane];
          end
        end
      end
    end

    if (product64_write_valid_c) begin
      for (int lane = 0; lane < LANES; lane++) begin
        if (SEPARATE_PRODUCT_STORE) begin
          product_store_wr_addr[lane] = product_store_stage_addr_for(BATCH_W'(product64_write_burst_c));
        end else begin
          store0_wr_addr[lane] = STORE_ADDR_W'(product64_write_burst_c);
        end
        if (product64_write_odd_c) begin
          if (SEPARATE_PRODUCT_STORE) begin
            minus_product_wr_en[lane] = 4'b1111;
            minus_product_wr_data[lane][0] = product64_write_y0_c[lane];
            minus_product_wr_data[lane][1] = product64_write_y1_c[lane];
            minus_product_wr_data[lane][2] = product64_write_y2_c[lane];
            minus_product_wr_data[lane][3] = product64_write_y3_c[lane];
          end else begin
            minus_store0_wr_en[lane] = 4'b1111;
            minus_store0_wr_data[lane][0] = product64_write_y0_c[lane];
            minus_store0_wr_data[lane][1] = product64_write_y1_c[lane];
            minus_store0_wr_data[lane][2] = product64_write_y2_c[lane];
            minus_store0_wr_data[lane][3] = product64_write_y3_c[lane];
          end
        end else begin
          if (SEPARATE_PRODUCT_STORE) begin
            plus_product_wr_en[lane] = 4'b1111;
            plus_product_wr_data[lane][0] = product64_write_y0_c[lane];
            plus_product_wr_data[lane][1] = product64_write_y1_c[lane];
            plus_product_wr_data[lane][2] = product64_write_y2_c[lane];
            plus_product_wr_data[lane][3] = product64_write_y3_c[lane];
          end else begin
            plus_store0_wr_en[lane] = 4'b1111;
            plus_store0_wr_data[lane][0] = product64_write_y0_c[lane];
            plus_store0_wr_data[lane][1] = product64_write_y1_c[lane];
            plus_store0_wr_data[lane][2] = product64_write_y2_c[lane];
            plus_store0_wr_data[lane][3] = product64_write_y3_c[lane];
          end
        end
      end
    end

    if (writer_sel_valid_q) begin
      for (int bank = 0; bank < LANES; bank++) begin
        logic [3:0] wr_en_c;
        logic [STORE_ADDR_W-1:0] wr_addr_c;
        mrec_res_t wr_plus_data_c [0:3];
        mrec_res_t wr_minus_data_c [0:3];
        int r16_group_i;
        int r16_off_i;
        int r16_banks_per_sel_i;
        int r16_sel_i;
        int r16_bank_i;
        int r16_lane_i;
        int r16_l8_sel_i;
        int inv1_sel_i;
        int r4_slot_i;
        int r4_base_i;
        logic [1:0] off0;
        logic [1:0] off1;

        wr_en_c = '0;
        wr_addr_c = writer_sel_dest_q;
        for (int slot = 0; slot < 4; slot++) begin
          wr_plus_data_c[slot] = '0;
          wr_minus_data_c[slot] = '0;
        end

        r16_banks_per_sel_i = LANES / 4;
        r16_sel_i = bank / r16_banks_per_sel_i;
        r16_bank_i = bank % r16_banks_per_sel_i;
        r16_group_i = r16_sel_i;
        r16_off_i = r16_bank_i;
        r4_slot_i = bank & 3;
        r4_base_i = (bank >> 2) << 2;

        unique case (writer_route_c)
          WR_FWD0: begin
            wr_en_c = 4'b1111;
            for (int slot = 0; slot < 4; slot++) begin
              off0 = slot[1:0];
              wr_plus_data_c[slot] = writer_sel_phase_q[0] ? slot_plus_y1_q[writer_sel_slot_q][off0][bank] :
                                                              slot_plus_y0_q[writer_sel_slot_q][off0][bank];
              wr_minus_data_c[slot] = writer_sel_phase_q[0] ? slot_minus_y1_q[writer_sel_slot_q][off0][bank] :
                                                               slot_minus_y0_q[writer_sel_slot_q][off0][bank];
            end
          end

          WR_FWD1_INV2: begin
            if (R == 128 && forward_mode_q && (LANES == 4)) begin
              wr_en_c = 4'b1111;
              for (int slot = 0; slot < 4; slot++) begin
                off0 = slot[1:0];
                wr_plus_data_c[slot] = pick_plus_buf_slot(writer_sel_slot_q, writer_sel_phase_q, off0, bank);
                wr_minus_data_c[slot] = pick_minus_buf_slot(writer_sel_slot_q, writer_sel_phase_q, off0, bank);
              end
            end else if (R == 128 && forward_mode_q) begin
              wr_en_c = 4'b1111;
              off0 = writer_sel_phase_q[0] ? 2'd1 : 2'd0;
              for (int slot = 0; slot < 4; slot++) begin
                wr_plus_data_c[slot] = pick_plus_buf_slot(writer_sel_slot_q, slot[1:0], off0, bank);
                wr_minus_data_c[slot] = pick_minus_buf_slot(writer_sel_slot_q, slot[1:0], off0, bank);
              end
            end else if (R == 128 && !forward_mode_q && (writer_sel_stage_q == 2'd1)) begin
              wr_en_c = 4'b0011;
              for (int slot = 0; slot < 2; slot++) begin
                off0 = slot[1:0];
                wr_plus_data_c[slot] = pick_plus_buf_slot(writer_sel_slot_q, writer_sel_phase_q, off0, bank);
                wr_minus_data_c[slot] = pick_minus_buf_slot(writer_sel_slot_q, writer_sel_phase_q, off0, bank);
              end
            end else begin
              wr_en_c = 4'b1111;
              for (int slot = 0; slot < 4; slot++) begin
                off0 = slot[1:0];
                wr_plus_data_c[slot] = pick_plus_buf_slot(writer_sel_slot_q, writer_sel_phase_q, off0, bank);
                wr_minus_data_c[slot] = pick_minus_buf_slot(writer_sel_slot_q, writer_sel_phase_q, off0, bank);
              end
            end
          end

          WR_INV1: begin
            wr_en_c = 4'b0011;
            off0 = 2'd0;
            off1 = 2'd1;
            inv1_sel_i = int'(writer_sel_phase_q);
            wr_plus_data_c[0] = pick_plus_buf_slot(writer_sel_slot_q, inv1_sel_i[1:0], off0, bank);
            wr_plus_data_c[1] = pick_plus_buf_slot(writer_sel_slot_q, inv1_sel_i[1:0], off1, bank);
            wr_minus_data_c[0] = pick_minus_buf_slot(writer_sel_slot_q, inv1_sel_i[1:0], off0, bank);
            wr_minus_data_c[1] = pick_minus_buf_slot(writer_sel_slot_q, inv1_sel_i[1:0], off1, bank);
          end

          WR_R16: begin
            wr_en_c = 4'b1111;
            off0 = 2'd0;
            if (((((R == 256) || (R == 128)) && (LANES == 8)) &&
                 ((forward_mode_q && (writer_sel_stage_q == STAGE_W'(1))) ||
                  (!forward_mode_q && (writer_sel_stage_q == STAGE_W'(2))))) ||
                (((R == 512) && (LANES == 8)) &&
                 ((forward_mode_q && (writer_sel_stage_q == STAGE_W'(POSITIONS - 3))) ||
                  (!forward_mode_q && (writer_sel_stage_q == STAGE_W'(POSITIONS - 2)))))) begin
              r16_l8_sel_i = (writer_sel_phase_q[0] ? 2 : 0) + (bank >> 2);
              for (int slot = 0; slot < 4; slot++) begin
                off0 = {1'b0, slot[1]};
                r16_lane_i = (bank & 3) + ((slot & 1) * 4);
                wr_plus_data_c[slot] =
                  pick_plus_buf_slot(writer_sel_slot_q, r16_l8_sel_i[1:0], off0, r16_lane_i);
                wr_minus_data_c[slot] =
                  pick_minus_buf_slot(writer_sel_slot_q, r16_l8_sel_i[1:0], off0, r16_lane_i);
              end
            end else begin
              for (int slot = 0; slot < 4; slot++) begin
                r16_lane_i = r16_bank_i + (slot * r16_banks_per_sel_i);
                wr_plus_data_c[slot] =
                  pick_plus_buf_slot(writer_sel_slot_q, r16_sel_i[1:0], off0, r16_lane_i);
                wr_minus_data_c[slot] =
                  pick_minus_buf_slot(writer_sel_slot_q, r16_sel_i[1:0], off0, r16_lane_i);
              end
            end
          end

          WR_R4: begin
            wr_en_c = 4'b1111;
            off0 = 2'd0;
            wr_plus_data_c[0] = pick_plus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 0);
            wr_plus_data_c[1] = pick_plus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 1);
            wr_plus_data_c[2] = pick_plus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 2);
            wr_plus_data_c[3] = pick_plus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 3);
            wr_minus_data_c[0] = pick_minus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 0);
            wr_minus_data_c[1] = pick_minus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 1);
            wr_minus_data_c[2] = pick_minus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 2);
            wr_minus_data_c[3] = pick_minus_buf_slot(writer_sel_slot_q, r4_slot_i[1:0], off0, r4_base_i + 3);
          end

          default: begin
            wr_en_c = '0;
          end
        endcase

        writer_wr_en_c[bank] = wr_en_c;
        writer_wr_addr_c[bank] = wr_addr_c;
        for (int slot = 0; slot < 4; slot++) begin
          writer_plus_wr_data_c[bank][slot] = wr_plus_data_c[slot];
          writer_minus_wr_data_c[bank][slot] = wr_minus_data_c[slot];
        end
      end
    end
  end

  assign term_base_valid = !forward_mode_q &&
                           step_out_valid &&
                           (meta_pos_q[0] == (POSITIONS - 1)) &&
                           (meta_stage_q[0] == 3'd0);

  always_comb begin
    term_in_valid = term_base_valid;
    term_in_batch_c = batch_to_out(meta_batch_q[0]);
    for (int lane = 0; lane < LANES; lane++) begin
      term_plus_y0_c[lane] = plus_step_y0[lane];
      term_plus_y1_c[lane] = plus_step_y1[lane];
      term_minus_y0_c[lane] = minus_step_y0[lane];
      term_minus_y1_c[lane] = minus_step_y1[lane];
    end
    if (R == 256) begin
      term_in_valid = (term_fifo_count_q != 4'd0);
      term_in_batch_c = term_fifo_batch_q[term_fifo_head_batch_q];
      for (int lane = 0; lane < LANES; lane++) begin
        term_plus_y0_c[lane] = term_fifo_plus_y0_q[term_fifo_head_lane_q[lane]][lane];
        term_plus_y1_c[lane] = term_fifo_plus_y1_q[term_fifo_head_lane_q[lane]][lane];
        term_minus_y0_c[lane] = term_fifo_minus_y0_q[term_fifo_head_lane_q[lane]][lane];
        term_minus_y1_c[lane] = term_fifo_minus_y1_q[term_fifo_head_lane_q[lane]][lane];
      end
    end
  end

  generate
    if (R == 256) begin : g_r256_term_untwist
      localparam int unsigned TERM_UNTWIST_LAT = 3;
      localparam int unsigned PSI_WORD_W = LANES * MREC_DATA_W;

      logic [PSI_WORD_W-1:0] psi_inv_word_q [0:(R/LANES)-1];
      logic term_valid_pipe_q [0:TERM_UNTWIST_LAT-1];
      logic [3:0] term_batch_pipe_q [0:TERM_UNTWIST_LAT-1];
      mrec_res_t term_plus_y0_pipe_q [0:TERM_UNTWIST_LAT-1][0:LANES-1];
      mrec_res_t term_plus_y1_pipe_q [0:TERM_UNTWIST_LAT-1][0:LANES-1];
      mrec_res_t minus_y0_untwisted [0:LANES-1];
      mrec_res_t minus_y1_untwisted [0:LANES-1];

      initial begin
        if (LANES == 16) begin
          $readmemh("rom_p520/fact/fact_psi_inv_word16_r256.mem", psi_inv_word_q);
        end else if (LANES == 8) begin
          $readmemh("rom_p520/fact/fact_psi_inv_word8_r256_l8.mem", psi_inv_word_q);
        end else begin
          $readmemh("rom_p520/fact/fact_psi_inv_word4_r256_l4.mem", psi_inv_word_q);
        end
      end

      function automatic mrec_res_t psi_for(
        input logic [4:0] word_idx,
        input int unsigned lane
      );
        begin
          psi_for = mrec_res_t'(psi_inv_word_q[word_idx][(lane * MREC_DATA_W) +: MREC_DATA_W]);
        end
      endfunction

      for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
        ntt46_p520_ntt46_mrec_modmul_pipe u_minus_y0_mul (
          .clk(clk),
          .rst(rst),
          .in_valid(term_in_valid),
          .a_in(term_minus_y0_c[lane]),
          .b_in(psi_for(term_in_batch_c, lane)),
          .out_valid(),
          .p_out(minus_y0_untwisted[lane])
        );

        ntt46_p520_ntt46_mrec_modmul_pipe u_minus_y1_mul (
          .clk(clk),
          .rst(rst),
          .in_valid(term_in_valid),
          .a_in(term_minus_y1_c[lane]),
          .b_in(psi_for(term_in_batch_c + OUT_BATCHES[4:0], lane)),
          .out_valid(),
          .p_out(minus_y1_untwisted[lane])
        );

        assign term_crt_plus_y0_c[lane] = term_plus_y0_pipe_q[TERM_UNTWIST_LAT-1][lane];
        assign term_crt_plus_y1_c[lane] = term_plus_y1_pipe_q[TERM_UNTWIST_LAT-1][lane];
        assign term_crt_minus_y0_c[lane] = minus_y0_untwisted[lane];
        assign term_crt_minus_y1_c[lane] = minus_y1_untwisted[lane];
      end

      assign term_crt_in_valid = term_valid_pipe_q[TERM_UNTWIST_LAT-1];
      assign term_crt_in_batch_c = term_batch_pipe_q[TERM_UNTWIST_LAT-1];

      always_ff @(posedge clk) begin
        if (rst || (start && (state_q == S_IDLE))) begin
          for (int idx = 0; idx < TERM_UNTWIST_LAT; idx++) begin
            term_valid_pipe_q[idx] <= 1'b0;
            term_batch_pipe_q[idx] <= '0;
            if (!FACT_AREA_TRIM_CORE_DATA) begin
              for (int lane = 0; lane < LANES; lane++) begin
                term_plus_y0_pipe_q[idx][lane] <= '0;
                term_plus_y1_pipe_q[idx][lane] <= '0;
              end
            end
          end
        end else begin
          term_valid_pipe_q[0] <= term_in_valid;
          term_batch_pipe_q[0] <= term_in_batch_c;
          for (int lane = 0; lane < LANES; lane++) begin
            term_plus_y0_pipe_q[0][lane] <= term_plus_y0_c[lane];
            term_plus_y1_pipe_q[0][lane] <= term_plus_y1_c[lane];
          end
          for (int idx = 1; idx < TERM_UNTWIST_LAT; idx++) begin
            term_valid_pipe_q[idx] <= term_valid_pipe_q[idx-1];
            term_batch_pipe_q[idx] <= term_batch_pipe_q[idx-1];
            for (int lane = 0; lane < LANES; lane++) begin
              term_plus_y0_pipe_q[idx][lane] <= term_plus_y0_pipe_q[idx-1][lane];
              term_plus_y1_pipe_q[idx][lane] <= term_plus_y1_pipe_q[idx-1][lane];
            end
          end
        end
      end
    end else begin : g_direct_term_crt
      assign term_crt_in_valid = term_in_valid;
      assign term_crt_in_batch_c = term_in_batch_c;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
        assign term_crt_plus_y0_c[lane] = term_plus_y0_c[lane];
        assign term_crt_plus_y1_c[lane] = term_plus_y1_c[lane];
        assign term_crt_minus_y0_c[lane] = term_minus_y0_c[lane];
        assign term_crt_minus_y1_c[lane] = term_minus_y1_c[lane];
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      forward_mode_q <= 1'b0;
      done_q <= 1'b0;
      scheduler_done_q <= 1'b0;
      read_store1_q <= 1'b0;
      read_product_q <= 1'b0;
      read_valid_q <= 1'b0;
      read_ext_stage0_q <= 1'b0;
      read_pos_q <= '0;
      read_stage_q <= '0;
      read_batch_q <= '0;
      compute_cycles_q <= '0;
      term_count_q <= '0;
      final_count_q <= '0;
      ready_head_q <= '0;
      ready_tail_q <= '0;
      ready_count_q <= '0;
      wr_pipe_valid_q <= 1'b0;
      wr_pipe_store1_q <= 1'b0;
      wr_pipe_pos_q <= '0;
      wr_pipe_dest_q <= '0;
      writer_sel_valid_q <= 1'b0;
      writer_sel_slot_q <= '0;
      writer_sel_pos_q <= '0;
      writer_sel_stage_q <= '0;
      writer_sel_group_q <= '0;
      writer_sel_phase_q <= '0;
      writer_sel_dest_q <= '0;
      meta_count_q <= '0;
      step_out_pipe_valid_q <= 1'b0;
      slot_write_data_valid_q <= 1'b0;
      slot_write_slot_q <= '0;
      slot_write_off_q <= '0;
      forward_out_valid_q <= 1'b0;
      forward_out_radix2_q <= 1'b0;
      forward_out_batch_q <= '0;
      for (int pos = 0; pos < POSITIONS; pos++) begin
        issue_count_q[pos] <= '0;
        for (int batch = 0; batch < STAGE0_BATCHES; batch++) begin
          ready_q[pos][batch] <= 1'b0;
        end
      end
      for (int idx = 0; idx < META_DEPTH; idx++) begin
        meta_pos_q[idx] <= '0;
        meta_stage_q[idx] <= '0;
        meta_batch_q[idx] <= '0;
        meta_group_q[idx] <= '0;
        meta_off_q[idx] <= '0;
        meta_group_size_q[idx] <= '0;
        meta_ops_q[idx] <= '0;
      end
      for (int idx = 0; idx < SLOT_DEPTH; idx++) begin
        slot_valid_q[idx] <= 1'b0;
        slot_ready_q[idx] <= 1'b0;
        slot_pos_q[idx] <= '0;
        slot_group_q[idx] <= '0;
        slot_fill_q[idx] <= '0;
        slot_ops_q[idx] <= '0;
        slot_phase_q[idx] <= '0;
      end
      for (int idx = 0; idx < READY_DEPTH; idx++) begin
        ready_slot_q[idx] <= '0;
      end
      for (int idx = 0; idx < PRODUCT_BATCHES; idx++) begin
        product_plus_ready_q[idx] <= 1'b0;
        product_minus_ready_q[idx] <= 1'b0;
      end
      product_accum_epoch_active_q <= 1'b0;
      term_fifo_head_q <= '0;
      term_fifo_head_batch_q <= '0;
      term_fifo_tail_q <= '0;
      term_fifo_count_q <= '0;
      for (int idx = 0; idx < TERM_FIFO_DEPTH; idx++) begin
        term_fifo_batch_q[idx] <= '0;
        if (!FACT_AREA_TRIM_CORE_DATA) begin
          for (int lane = 0; lane < LANES; lane++) begin
            term_fifo_plus_y0_q[idx][lane] <= '0;
            term_fifo_plus_y1_q[idx][lane] <= '0;
            term_fifo_minus_y0_q[idx][lane] <= '0;
            term_fifo_minus_y1_q[idx][lane] <= '0;
          end
        end
      end
      for (int lane = 0; lane < LANES; lane++) begin
        term_fifo_head_lane_q[lane] <= '0;
      end
      if (!FACT_AREA_TRIM_CORE_DATA) begin
        for (int lane = 0; lane < LANES; lane++) begin
          if (INVERSE_OUTPUT_PIPELINE) begin
            plus_step_out_pipe_y0_q[lane] <= '0;
            plus_step_out_pipe_y1_q[lane] <= '0;
            plus_step_out_pipe_y2_q[lane] <= '0;
            plus_step_out_pipe_y3_q[lane] <= '0;
            minus_step_out_pipe_y0_q[lane] <= '0;
            minus_step_out_pipe_y1_q[lane] <= '0;
            minus_step_out_pipe_y2_q[lane] <= '0;
            minus_step_out_pipe_y3_q[lane] <= '0;
          end
          forward_plus_y0_q[lane] <= '0;
          forward_plus_y1_q[lane] <= '0;
          forward_plus_y2_q[lane] <= '0;
          forward_plus_y3_q[lane] <= '0;
          forward_minus_y0_q[lane] <= '0;
          forward_minus_y1_q[lane] <= '0;
          forward_minus_y2_q[lane] <= '0;
          forward_minus_y3_q[lane] <= '0;
        end
      end
      if (RESET_WR_PIPE_DATA) begin
        for (int bank = 0; bank < LANES; bank++) begin
          wr_pipe_en_q[bank] <= '0;
          wr_pipe_addr_q[bank] <= '0;
          for (int slot = 0; slot < 4; slot++) begin
            wr_pipe_plus_data_q[bank][slot] <= '0;
            wr_pipe_minus_data_q[bank][slot] <= '0;
          end
        end
      end
    end else begin
      logic [6:0] meta_count_next;
      logic [2:0] step_pos_c;
      logic [2:0] step_stage_c;
      logic [BATCH_W-1:0] step_batch_c;
      logic [BATCH_W-1:0] step_group_c;
      logic [1:0] step_off_c;
      logic [2:0] step_group_size_c;
      logic [2:0] step_ops_c;
      logic [BATCH_W-1:0] cap_group_c;
      logic [1:0] cap_off_c;
      logic [2:0] cap_fill_next_c;
      logic [2:0] cap_ops_c;
      logic [SLOT_ADDR_W-1:0] cap_slot_c;
      logic cap_slot_found_c;
      logic cap_slot_existing_c;
      logic [READY_ADDR_W-1:0] ready_tail_next_c;
      logic [5:0] ready_count_next_c;
      logic [STAGE_BATCH_W-1:0] product_stage_batch_c;
      logic product_stage_ready_next_c;
      logic term_fifo_pop_c;
      logic term_fifo_push_c;
      logic [TERM_FIFO_AW-1:0] term_tail0_c;
      logic [TERM_FIFO_AW-1:0] term_tail1_c;
      logic [TERM_FIFO_COUNT_W-1:0] term_fifo_count_next_c;

      done_q <= 1'b0;
      forward_out_valid_q <= 1'b0;
      step_out_pipe_valid_q <= INVERSE_OUTPUT_PIPELINE ? step_raw_inv_out_valid : 1'b0;
      slot_write_data_valid_q <= 1'b0;
      if (INVERSE_OUTPUT_PIPELINE) begin
        for (int lane = 0; lane < LANES; lane++) begin
          plus_step_out_pipe_y0_q[lane] <= plus_step_raw_y0[lane];
          plus_step_out_pipe_y1_q[lane] <= plus_step_raw_y1[lane];
          plus_step_out_pipe_y2_q[lane] <= plus_step_raw_y2[lane];
          plus_step_out_pipe_y3_q[lane] <= plus_step_raw_y3[lane];
          minus_step_out_pipe_y0_q[lane] <= minus_step_raw_y0[lane];
          minus_step_out_pipe_y1_q[lane] <= minus_step_raw_y1[lane];
          minus_step_out_pipe_y2_q[lane] <= minus_step_raw_y2[lane];
          minus_step_out_pipe_y3_q[lane] <= minus_step_raw_y3[lane];
        end
      end

      if (state_q != S_IDLE) begin
        compute_cycles_q <= compute_cycles_q + 16'd1;
      end

      writer_sel_valid_q <= writer_valid_c;
      writer_sel_slot_q <= writer_slot_c;
      writer_sel_pos_q <= writer_pos_c;
      writer_sel_stage_q <= writer_stage_c;
      writer_sel_group_q <= writer_group_c;
      writer_sel_phase_q <= writer_phase_c;
      writer_sel_dest_q <= writer_dest_c;
      writer_sel_route_q <= write_route_for(!forward_mode_q, writer_stage_c);
      wr_pipe_valid_q <= writer_sel_valid_q;
      wr_pipe_store1_q <= !writer_sel_pos_q[0];
      wr_pipe_pos_q <= writer_sel_pos_q;
      wr_pipe_dest_q <= writer_sel_dest_q;
      for (int bank = 0; bank < LANES; bank++) begin
        wr_pipe_en_q[bank] <= writer_wr_en_c[bank];
        wr_pipe_addr_q[bank] <= writer_wr_addr_c[bank];
        for (int slot = 0; slot < 4; slot++) begin
          wr_pipe_plus_data_q[bank][slot] <= writer_plus_wr_data_c[bank][slot];
          wr_pipe_minus_data_q[bank][slot] <= writer_minus_wr_data_c[bank][slot];
        end
      end
      if (SLOT_WRITE_PIPELINE && slot_write_data_valid_q) begin
        for (int lane = 0; lane < LANES; lane++) begin
          slot_plus_y0_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_plus_y0_q[lane];
          slot_plus_y1_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_plus_y1_q[lane];
          slot_plus_y2_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_plus_y2_q[lane];
          slot_plus_y3_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_plus_y3_q[lane];
          slot_minus_y0_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_minus_y0_q[lane];
          slot_minus_y1_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_minus_y1_q[lane];
          slot_minus_y2_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_minus_y2_q[lane];
          slot_minus_y3_q[slot_write_slot_q][slot_write_off_q][lane] <= slot_write_minus_y3_q[lane];
        end
      end

      read_valid_q <= issue_fire_c;
      read_ext_stage0_q <= issue_fire_c && FACT_EXT_STAGE0_ENABLE &&
                            forward_mode_q && (issue_pos_c == 3'd0);
      if (issue_fire_c) begin
        read_pos_q <= issue_pos_c;
        read_stage_q <= issue_stage_c;
        read_batch_q <= issue_batch_c;
        read_store1_q <= issue_pos_c[0];
        read_product_q <= SEPARATE_PRODUCT_STORE && !forward_mode_q && (issue_pos_c == 3'd0);
        issue_count_q[issue_pos_c] <= issue_count_q[issue_pos_c] + 5'd1;
        ready_q[issue_pos_c][issue_batch_c] <= 1'b0;
      end

      meta_count_next = meta_count_q;
      step_pos_c = meta_pos_q[0];
      step_stage_c = meta_stage_q[0];
      step_batch_c = meta_batch_q[0];
      step_group_c = meta_group_q[0];
      step_off_c = meta_off_q[0];
      step_group_size_c = meta_group_size_q[0];
      step_ops_c = meta_ops_q[0];
      if (step_out_valid) begin
        for (int idx = 0; idx < META_DEPTH - 1; idx++) begin
          meta_pos_q[idx] <= meta_pos_q[idx + 1];
          meta_stage_q[idx] <= meta_stage_q[idx + 1];
          meta_batch_q[idx] <= meta_batch_q[idx + 1];
          meta_group_q[idx] <= meta_group_q[idx + 1];
          meta_off_q[idx] <= meta_off_q[idx + 1];
          meta_group_size_q[idx] <= meta_group_size_q[idx + 1];
          meta_ops_q[idx] <= meta_ops_q[idx + 1];
        end
        meta_count_next = meta_count_next - 7'd1;
      end
      if (read_valid_q) begin
        meta_pos_q[meta_count_next] <= read_pos_q;
        meta_stage_q[meta_count_next] <= read_stage_q;
        meta_batch_q[meta_count_next] <= read_batch_q;
        meta_group_q[meta_count_next] <= batch_group_for(!forward_mode_q, read_stage_q, read_batch_q);
        meta_off_q[meta_count_next] <= batch_offset_for(!forward_mode_q, read_stage_q, read_batch_q);
        meta_group_size_q[meta_count_next] <= group_size_for(!forward_mode_q, read_stage_q);
        meta_ops_q[meta_count_next] <= ops_per_group_for(!forward_mode_q, read_stage_q);
        meta_count_next = meta_count_next + 7'd1;
      end
      meta_count_q <= meta_count_next;

      ready_tail_next_c = ready_tail_q;
      ready_count_next_c = ready_count_q;

      if (writer_valid_c) begin
        if ((slot_phase_q[writer_slot_c] + 2'd1) == slot_ops_q[writer_slot_c][1:0]) begin
          ready_head_q <= ready_head_q + {{(READY_ADDR_W-1){1'b0}}, 1'b1};
          ready_count_next_c = ready_count_next_c - 6'd1;
          slot_ready_q[writer_slot_c] <= 1'b0;
        end else begin
          slot_phase_q[writer_slot_c] <= slot_phase_q[writer_slot_c] + 2'd1;
        end
      end

      if (writer_sel_valid_q && !slot_ready_q[writer_sel_slot_q] &&
          ((writer_sel_phase_q + 2'd1) == slot_ops_q[writer_sel_slot_q][1:0])) begin
        slot_valid_q[writer_sel_slot_q] <= 1'b0;
      end
      if (wr_pipe_valid_q) begin
        if ((wr_pipe_pos_q + 3'd1) < POSITIONS) begin
          ready_q[wr_pipe_pos_q + 3'd1][wr_pipe_dest_q] <= 1'b1;
        end
      end

      if (step_out_valid) begin
        if (step_pos_c == (POSITIONS - 1)) begin
          if (forward_mode_q) begin
            forward_out_valid_q <= 1'b1;
            forward_out_radix2_q <= (step_stage_c == 3'd0);
            forward_out_batch_q <= forward_batch_out_for(step_batch_c);
            for (int lane = 0; lane < LANES; lane++) begin
              forward_plus_y0_q[lane] <= plus_step_y0[lane];
              forward_plus_y1_q[lane] <= plus_step_y1[lane];
              forward_plus_y2_q[lane] <= plus_step_y2[lane];
              forward_plus_y3_q[lane] <= plus_step_y3[lane];
              forward_minus_y0_q[lane] <= minus_step_y0[lane];
              forward_minus_y1_q[lane] <= minus_step_y1[lane];
              forward_minus_y2_q[lane] <= minus_step_y2[lane];
              forward_minus_y3_q[lane] <= minus_step_y3[lane];
            end
          end
          final_count_q <= final_count_q + 5'd1;
          if ((final_count_q + 5'd1) == batches_for(step_stage_c)) begin
            if (forward_mode_q) begin
              done_q <= 1'b1;
              state_q <= S_IDLE;
            end else begin
              scheduler_done_q <= 1'b1;
            end
          end
        end else begin
          cap_group_c = step_group_c;
          cap_off_c = step_off_c;
          cap_slot_c = '0;
          cap_slot_found_c = 1'b0;
          cap_slot_existing_c = 1'b0;
          for (int slot = 0; slot < SLOT_DEPTH; slot++) begin
            if (!cap_slot_found_c && slot_valid_q[slot] &&
                (slot_pos_q[slot] == step_pos_c) &&
                (slot_group_q[slot] == cap_group_c)) begin
              cap_slot_c = slot[SLOT_ADDR_W-1:0];
              cap_slot_found_c = 1'b1;
              cap_slot_existing_c = 1'b1;
            end
          end
          for (int slot = 0; slot < SLOT_DEPTH; slot++) begin
            if (!cap_slot_found_c && !slot_valid_q[slot]) begin
              cap_slot_c = slot[SLOT_ADDR_W-1:0];
              cap_slot_found_c = 1'b1;
            end
          end

          if (!cap_slot_existing_c) begin
            slot_valid_q[cap_slot_c] <= 1'b1;
            slot_ready_q[cap_slot_c] <= 1'b0;
            slot_pos_q[cap_slot_c] <= step_pos_c;
            slot_group_q[cap_slot_c] <= cap_group_c;
            slot_fill_q[cap_slot_c] <= 3'd1;
            slot_phase_q[cap_slot_c] <= 2'd0;
          end else begin
            slot_fill_q[cap_slot_c] <= slot_fill_q[cap_slot_c] + 3'd1;
          end
          cap_fill_next_c = cap_slot_existing_c ? (slot_fill_q[cap_slot_c] + 3'd1) : 3'd1;
          if (SLOT_WRITE_PIPELINE) begin
            slot_write_data_valid_q <= 1'b1;
            slot_write_slot_q <= cap_slot_c;
            slot_write_off_q <= cap_off_c;
            for (int lane = 0; lane < LANES; lane++) begin
              slot_write_plus_y0_q[lane] <= plus_step_y0[lane];
              slot_write_plus_y1_q[lane] <= plus_step_y1[lane];
              slot_write_plus_y2_q[lane] <= plus_step_y2[lane];
              slot_write_plus_y3_q[lane] <= plus_step_y3[lane];
              slot_write_minus_y0_q[lane] <= minus_step_y0[lane];
              slot_write_minus_y1_q[lane] <= minus_step_y1[lane];
              slot_write_minus_y2_q[lane] <= minus_step_y2[lane];
              slot_write_minus_y3_q[lane] <= minus_step_y3[lane];
            end
          end else begin
            for (int lane = 0; lane < LANES; lane++) begin
              slot_plus_y0_q[cap_slot_c][cap_off_c][lane] <= plus_step_y0[lane];
              slot_plus_y1_q[cap_slot_c][cap_off_c][lane] <= plus_step_y1[lane];
              slot_plus_y2_q[cap_slot_c][cap_off_c][lane] <= plus_step_y2[lane];
              slot_plus_y3_q[cap_slot_c][cap_off_c][lane] <= plus_step_y3[lane];
              slot_minus_y0_q[cap_slot_c][cap_off_c][lane] <= minus_step_y0[lane];
              slot_minus_y1_q[cap_slot_c][cap_off_c][lane] <= minus_step_y1[lane];
              slot_minus_y2_q[cap_slot_c][cap_off_c][lane] <= minus_step_y2[lane];
              slot_minus_y3_q[cap_slot_c][cap_off_c][lane] <= minus_step_y3[lane];
            end
          end
          if ((cap_fill_next_c >= step_group_size_c) &&
              !slot_ready_q[cap_slot_c]) begin
            cap_ops_c = step_ops_c;
            slot_ready_q[cap_slot_c] <= 1'b1;
            slot_ops_q[cap_slot_c] <= cap_ops_c;
            slot_phase_q[cap_slot_c] <= 2'd0;
            ready_slot_q[ready_tail_next_c] <= cap_slot_c;
            ready_tail_next_c = ready_tail_next_c + {{(READY_ADDR_W-1){1'b0}}, 1'b1};
            ready_count_next_c = ready_count_next_c + 6'd1;
          end
        end
      end

      ready_tail_q <= ready_tail_next_c;
      ready_count_q <= ready_count_next_c;

      term_fifo_pop_c = (R == 256) && (term_fifo_count_q != 4'd0);
      term_fifo_push_c = (R == 256) && term_base_valid;
      term_tail0_c = term_fifo_tail_q;
      term_tail1_c = term_fifo_tail_q + {{(TERM_FIFO_AW-1){1'b0}}, 1'b1};
      term_fifo_count_next_c = term_fifo_count_q -
                               (term_fifo_pop_c ? TERM_FIFO_COUNT_W'(1) : '0) +
                               (term_fifo_push_c ? TERM_FIFO_COUNT_W'(2) : '0);
      if (term_fifo_pop_c) begin
        term_fifo_head_q <= term_fifo_head_q + {{(TERM_FIFO_AW-1){1'b0}}, 1'b1};
        term_fifo_head_batch_q <= term_fifo_head_batch_q + {{(TERM_FIFO_AW-1){1'b0}}, 1'b1};
        for (int lane = 0; lane < LANES; lane++) begin
          term_fifo_head_lane_q[lane] <= term_fifo_head_lane_q[lane] + {{(TERM_FIFO_AW-1){1'b0}}, 1'b1};
        end
      end
      if (term_fifo_push_c) begin
        term_fifo_batch_q[term_tail0_c] <= 4'(meta_batch_q[0]);
        term_fifo_batch_q[term_tail1_c] <= 4'(meta_batch_q[0]) + 4'(STAGE_BATCHES);
        for (int lane = 0; lane < LANES; lane++) begin
          term_fifo_plus_y0_q[term_tail0_c][lane] <= plus_step_y0[lane];
          term_fifo_plus_y1_q[term_tail0_c][lane] <= plus_step_y2[lane];
          term_fifo_minus_y0_q[term_tail0_c][lane] <= minus_step_y0[lane];
          term_fifo_minus_y1_q[term_tail0_c][lane] <= minus_step_y2[lane];
          term_fifo_plus_y0_q[term_tail1_c][lane] <= plus_step_y1[lane];
          term_fifo_plus_y1_q[term_tail1_c][lane] <= plus_step_y3[lane];
          term_fifo_minus_y0_q[term_tail1_c][lane] <= minus_step_y1[lane];
          term_fifo_minus_y1_q[term_tail1_c][lane] <= minus_step_y3[lane];
        end
        term_fifo_tail_q <= term_fifo_tail_q + TERM_FIFO_AW'(2);
      end
      term_fifo_count_q <= term_fifo_count_next_c;

      if (term_out_valid) begin
        term_count_q <= term_count_q + 5'd1;
        if (term_count_q == (OUT_BATCHES - 1)) begin
          done_q <= 1'b1;
          state_q <= S_IDLE;
        end
      end

      if (start && (state_q == S_IDLE)) begin
        state_q <= S_RUN;
        forward_mode_q <= RUNTIME_FORWARD_MODE ? run_forward : FORWARD_ONLY;
        scheduler_done_q <= 1'b0;
        compute_cycles_q <= '0;
        term_count_q <= '0;
        final_count_q <= '0;
        forward_out_valid_q <= 1'b0;
        forward_out_radix2_q <= 1'b0;
        forward_out_batch_q <= '0;
        read_store1_q <= 1'b0;
        read_product_q <= 1'b0;
        read_valid_q <= 1'b0;
        read_ext_stage0_q <= 1'b0;
        read_pos_q <= '0;
        read_stage_q <= '0;
        read_batch_q <= '0;
        ready_head_q <= '0;
        ready_tail_q <= '0;
        ready_count_q <= '0;
        term_fifo_head_q <= '0;
        term_fifo_head_batch_q <= '0;
        term_fifo_tail_q <= '0;
        term_fifo_count_q <= '0;
        wr_pipe_valid_q <= 1'b0;
        wr_pipe_store1_q <= 1'b0;
        wr_pipe_pos_q <= '0;
        wr_pipe_dest_q <= '0;
        writer_sel_valid_q <= 1'b0;
        writer_sel_slot_q <= '0;
        writer_sel_pos_q <= '0;
        writer_sel_stage_q <= '0;
        writer_sel_group_q <= '0;
        writer_sel_phase_q <= '0;
        writer_sel_dest_q <= '0;
        writer_sel_route_q <= WR_NONE;
        meta_count_q <= '0;
        step_out_pipe_valid_q <= 1'b0;
        slot_write_data_valid_q <= 1'b0;
        slot_write_slot_q <= '0;
        slot_write_off_q <= '0;
        for (int lane = 0; lane < LANES; lane++) begin
          term_fifo_head_lane_q[lane] <= '0;
        end
        for (int pos = 0; pos < POSITIONS; pos++) begin
          issue_count_q[pos] <= '0;
          for (int batch = 0; batch < STAGE0_BATCHES; batch++) begin
            if (pos == 0) begin
              ready_q[pos][batch] <=
                (RUNTIME_FORWARD_MODE ? run_forward : FORWARD_ONLY) ||
                !(ENABLE_PRODUCT_ACCUM && STREAM_PRODUCT_DURING_RUN) ||
                ((batch < STAGE_BATCHES) && product_stage_ready_for(STAGE_BATCH_W'(batch)));
            end else begin
              ready_q[pos][batch] <= 1'b0;
            end
          end
        end
        for (int slot = 0; slot < SLOT_DEPTH; slot++) begin
          slot_valid_q[slot] <= 1'b0;
          slot_ready_q[slot] <= 1'b0;
          slot_pos_q[slot] <= '0;
          slot_group_q[slot] <= '0;
          slot_fill_q[slot] <= '0;
          slot_ops_q[slot] <= '0;
          slot_phase_q[slot] <= '0;
        end
      end

      if (PRODUCT_READY_CLEAR_ON_ACCUM &&
          ((product_accept_c && product_in_clear_accum && !product_in_odd &&
            (product_in_batch == 0)) ||
           (product64_accept_global_c && product64_in_clear_accum && !product64_in_odd &&
            (product64_in_burst == 0)))) begin
        product_accum_epoch_active_q <= 1'b0;
        for (int idx = 0; idx < PRODUCT_BATCHES; idx++) begin
          product_plus_ready_q[idx] <= 1'b0;
          product_minus_ready_q[idx] <= 1'b0;
        end
      end

      if (PRODUCT_READY_CLEAR_ON_ACCUM &&
          ((product_write_valid_c && product_write_clear_c) ||
           (product64_write_valid_c && product64_write_clear_c))) begin
        product_accum_epoch_active_q <= 1'b0;
      end

      if (PRODUCT_READY_CLEAR_ON_ACCUM && product_acc_read_c &&
          !product_accum_epoch_active_q) begin
        product_accum_epoch_active_q <= 1'b1;
        for (int idx = 0; idx < PRODUCT_BATCHES; idx++) begin
          product_plus_ready_q[idx] <= 1'b0;
          product_minus_ready_q[idx] <= 1'b0;
        end
      end

      if (ENABLE_PRODUCT_ACCUM && STREAM_PRODUCT_DURING_RUN && product_write_valid_c) begin
        product_stage_batch_c = STAGE_BATCH_W'(product_write_batch_c >> 2);
        product_stage_ready_next_c = 1'b1;
        for (int sub = 0; sub < 4; sub++) begin
          logic [5:0] product_idx_c;
          logic plus_ready_c;
          logic minus_ready_c;
          product_idx_c = 6'((int'(product_stage_batch_c) * 4) + sub);
          plus_ready_c = product_plus_ready_q[product_idx_c] ||
                         (!product_write_odd_c && (product_write_batch_c == product_idx_c)) ||
                         (product_write_valid1_c && !product_write_odd1_c &&
                          (product_write_batch1_c == product_idx_c));
          minus_ready_c = product_minus_ready_q[product_idx_c] ||
                          (product_write_odd_c && (product_write_batch_c == product_idx_c)) ||
                          (product_write_valid1_c && product_write_odd1_c &&
                           (product_write_batch1_c == product_idx_c));
          product_stage_ready_next_c &= plus_ready_c && minus_ready_c;
        end
        if (product_write_odd_c) begin
          product_minus_ready_q[product_write_batch_c] <= 1'b1;
        end else begin
          product_plus_ready_q[product_write_batch_c] <= 1'b1;
        end
        if (product_write_valid1_c) begin
          if (product_write_odd1_c) begin
            product_minus_ready_q[product_write_batch1_c] <= 1'b1;
          end else begin
            product_plus_ready_q[product_write_batch1_c] <= 1'b1;
          end
        end
        if (product_stage_ready_next_c) begin
          ready_q[0][product_stage_batch_c] <= 1'b1;
        end
      end

      if (ENABLE_PRODUCT_ACCUM && STREAM_PRODUCT_DURING_RUN && product64_write_valid_c) begin
        product_stage_batch_c = STAGE_BATCH_W'(product64_write_burst_c);
        product_stage_ready_next_c = 1'b1;
        for (int sub = 0; sub < 4; sub++) begin
          logic [5:0] product_idx_c;
          logic plus_ready_c;
          logic minus_ready_c;
          product_idx_c = 6'((int'(product64_write_burst_c) * 4) + sub);
          plus_ready_c = product_plus_ready_q[product_idx_c] ||
                         (!product64_write_odd_c);
          minus_ready_c = product_minus_ready_q[product_idx_c] ||
                          (product64_write_odd_c);
          product_stage_ready_next_c &= plus_ready_c && minus_ready_c;
          if (product64_write_odd_c) begin
            product_minus_ready_q[product_idx_c] <= 1'b1;
          end else begin
            product_plus_ready_q[product_idx_c] <= 1'b1;
          end
        end
        if (product_stage_ready_next_c) begin
          ready_q[0][product_stage_batch_c] <= 1'b1;
        end
      end
    end
  end

endmodule

