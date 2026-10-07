module ntt46_p520_ntt46_zest_radix24_bidir_bfly_lane_unified_pipe #(
  parameter bit J_USE_DSP = 1'b1,
  parameter bit J_LUT_FAST3 = 1'b0,
  parameter bit MUL_EXTRA_STAGE = 1'b1,
  parameter bit J_PRE_STAGE = 1'b0,
  parameter bit INVERSE_J_PRE_STAGE = 1'b0,
  parameter bit COSET_J_PRE_STAGE = 1'b0,
  parameter bit USE_TIGHT_MUL = 1'b0,
  parameter bit J_USE_TIGHT_MUL = USE_TIGHT_MUL,
  parameter bit ENABLE_PRODUCT4_MODE = 1'b1,
  parameter int unsigned LANE_IDX = 0,
  parameter bit USE_SHARED_TWIDDLE = 1'b0,
  parameter bit RESET_DATA_ARRAYS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                radix2_mode,
  input  logic                                inverse,
  input  logic                                coset_untwist,
  input  logic                                product4_mode,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x0_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x1_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x2_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x3_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product_w0_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w1_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w2_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w3_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     j_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     shared_w1_early,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     shared_w2_early,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     shared_w3_early,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     shared_w1_late,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     shared_w2_late,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     shared_w3_late,
  output logic                                out_valid,
  output logic                                fwd_out_valid,
  output logic                                inv_out_valid,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y0_out,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y1_out,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y2_out,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y3_out
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;
  import ntt46_p520_ntt46_mrec_params_pkg::*;

  localparam int unsigned MUL_LAT = MUL_EXTRA_STAGE ? 4 : 3;
  localparam int unsigned J_LAT = ((J_USE_DSP && !MUL_EXTRA_STAGE) || (!J_USE_DSP && J_LUT_FAST3)) ? 3 : 4;
  localparam int unsigned SIDE_LAT = J_LAT + ((J_PRE_STAGE || INVERSE_J_PRE_STAGE || COSET_J_PRE_STAGE) ? 1 : 0);

  logic fwd_in_valid_c;
  logic inv_in_valid_c;
  logic product4_mode_eff_c;
  logic product4_in_valid_c;
  logic product4_out_valid_c;
  logic inv_data_sel_c;
  logic inv_mul_valid_c;
  logic fwd_mul_valid_c;
  logic bfly_in_valid_c;
  logic bfly_inverse_c;
  logic bfly_radix2_c;
  logic bfly_coset_c;
  logic bfly_j_neg_c;
  mrec_res_t bfly_x0_c;
  mrec_res_t bfly_x1_c;
  mrec_res_t bfly_x2_c;
  mrec_res_t bfly_x3_c;
  mrec_res_t bfly_s02_c;
  mrec_res_t bfly_d02_c;
  mrec_res_t bfly_s13_c;
  mrec_res_t bfly_d13_c;

  logic bfly_valid_q;
  logic bfly_inverse_q;
  logic bfly_radix2_q;
  logic bfly_coset_q;
  logic bfly_j_neg_q;
  mrec_res_t bfly_s02_q;
  mrec_res_t bfly_d02_q;
  mrec_res_t bfly_s13_q;
  mrec_res_t bfly_d13_q;
  mrec_res_t bfly_w1_q;
  mrec_res_t bfly_w2_q;
  mrec_res_t bfly_w3_q;

  logic side_valid_q [0:SIDE_LAT-1];
  logic side_inverse_q [0:SIDE_LAT-1];
  logic side_radix2_q [0:SIDE_LAT-1];
  logic side_coset_q [0:SIDE_LAT-1];
  mrec_res_t side_s02_q [0:SIDE_LAT-1];
  mrec_res_t side_d02_q [0:SIDE_LAT-1];
  mrec_res_t side_s13_q [0:SIDE_LAT-1];
  mrec_res_t side_w1_q [0:SIDE_LAT-1];
  mrec_res_t side_w2_q [0:SIDE_LAT-1];
  mrec_res_t side_w3_q [0:SIDE_LAT-1];

  logic j_launch_valid_c;
  logic j_launch_pre_c;
  logic j_direct_valid_c;
  logic j_launch_neg_c;
  mrec_res_t j_launch_operand_c;
  mrec_res_t j_launch_const_c;
  mrec_res_t j_direct_operand_c;
  mrec_res_t j_direct_const_c;
  logic j_pre_valid_q;
  logic j_pre_neg_q;
  mrec_res_t j_pre_operand_q;
  mrec_res_t j_pre_const_q;
  logic j_in_valid_c;
  logic j_sched_valid_c;
  logic j_neg_c;
  logic j_sched_neg_c;
  logic j_out_valid;
  logic post_early_valid_c;
  logic post_late_valid_c;
  logic post_early_needs_j_c;
  logic post_late_needs_j_c;
  logic post_select_late_c;
  logic post_valid_c;
  logic post_inverse_c;
  logic post_radix2_c;
  logic post_coset_c;
  logic post_needs_j_c;
  mrec_res_t j_const_c;
  mrec_res_t j_sched_const_c;
  mrec_res_t j_operand_c;
  mrec_res_t j_sched_operand_c;
  mrec_res_t jd13_c;
  mrec_res_t post_y0_c;
  mrec_res_t post_y1_c;
  mrec_res_t post_y2_c;
  mrec_res_t post_y3_c;
  mrec_res_t post_s02_c;
  mrec_res_t post_d02_c;
  mrec_res_t post_s13_c;
  mrec_res_t post_w1_c;
  mrec_res_t post_w2_c;
  mrec_res_t post_w3_c;
  logic side_load_valid_c;
  logic side_load_inverse_c;
  logic side_load_radix2_c;
  logic side_load_coset_c;
  mrec_res_t side_load_s02_c;
  mrec_res_t side_load_d02_c;
  mrec_res_t side_load_s13_c;
  mrec_res_t side_load_w1_c;
  mrec_res_t side_load_w2_c;
  mrec_res_t side_load_w3_c;

  logic fwd_launch_valid_q;
  mrec_res_t fwd_y0_launch_q;
  mrec_res_t fwd_y1_launch_q;
  mrec_res_t fwd_y2_launch_q;
  mrec_res_t fwd_y3_launch_q;
  mrec_res_t fwd_w1_launch_q;
  mrec_res_t fwd_w2_launch_q;
  mrec_res_t fwd_w3_launch_q;
  mrec_res_t fwd_y0_mul_pipe_q [0:MUL_LAT-1];

  logic mul_in_valid_c;
  mrec_res_t mul_a1_c;
  mrec_res_t mul_a2_c;
  mrec_res_t mul_a3_c;
  mrec_res_t mul_b1_c;
  mrec_res_t mul_b2_c;
  mrec_res_t mul_b3_c;
  logic mul_out_valid_c;
  mrec_res_t mul_y1_c;
  mrec_res_t mul_y2_c;
  mrec_res_t mul_y3_c;
  logic mul_inverse_pipe_q [0:MUL_LAT-1];
  logic mul_product4_pipe_q [0:MUL_LAT-1];
  logic mul_radix2_pipe_q [0:MUL_LAT-1];
  logic mul_coset_pipe_q [0:MUL_LAT-1];
  logic mul_j_neg_pipe_q [0:MUL_LAT-1];
  mrec_res_t inv_x0_pipe_q [0:MUL_LAT-1];
  mrec_res_t inv_w3_pipe_q [0:MUL_LAT-1];

  assign product4_mode_eff_c = ENABLE_PRODUCT4_MODE && product4_mode;
  assign fwd_in_valid_c = in_valid && !inverse && !product4_mode_eff_c;
  assign inv_in_valid_c = in_valid && inverse && !product4_mode_eff_c;
  generate
    if (ENABLE_PRODUCT4_MODE) begin : g_product4_valid
      assign product4_in_valid_c = in_valid && product4_mode_eff_c;
    end else begin : g_no_product4_valid
      assign product4_in_valid_c = 1'b0;
    end
  endgenerate

  assign inv_mul_valid_c = mul_out_valid_c && mul_inverse_pipe_q[MUL_LAT-1];
  generate
    if (ENABLE_PRODUCT4_MODE) begin : g_product4_out
      assign product4_out_valid_c = mul_out_valid_c && mul_product4_pipe_q[MUL_LAT-1] && j_out_valid;
      assign fwd_mul_valid_c = mul_out_valid_c && !mul_inverse_pipe_q[MUL_LAT-1] &&
                               !mul_product4_pipe_q[MUL_LAT-1];
    end else begin : g_no_product4_out
      assign product4_out_valid_c = 1'b0;
      assign fwd_mul_valid_c = mul_out_valid_c && !mul_inverse_pipe_q[MUL_LAT-1];
    end
  endgenerate
  assign inv_data_sel_c = mul_inverse_pipe_q[MUL_LAT-1];

  assign bfly_in_valid_c = inv_mul_valid_c || fwd_in_valid_c;
  assign bfly_inverse_c = inv_data_sel_c;
  assign bfly_radix2_c = inv_data_sel_c ? mul_radix2_pipe_q[MUL_LAT-1] : radix2_mode;
  assign bfly_coset_c = inv_data_sel_c && mul_coset_pipe_q[MUL_LAT-1];
  assign bfly_j_neg_c = inv_data_sel_c ? mul_j_neg_pipe_q[MUL_LAT-1] : (j_in == mrec_res_t'(MREC_J_INV));
  assign bfly_x0_c = inv_data_sel_c ? (bfly_coset_c ? mul_y2_c : inv_x0_pipe_q[MUL_LAT-1]) : x0_in;
  assign bfly_x1_c = inv_data_sel_c ? mul_y1_c : x1_in;
  assign bfly_x2_c = inv_data_sel_c ? mul_y2_c : x2_in;
  assign bfly_x3_c = inv_data_sel_c ? mul_y3_c : x3_in;

  always_comb begin
    if (bfly_radix2_c) begin
      bfly_s02_c = mod_add(bfly_x0_c, bfly_x1_c);
      bfly_d02_c = mod_sub(bfly_x0_c, bfly_x1_c);
      bfly_s13_c = '0;
      bfly_d13_c = '0;
    end else begin
      bfly_s02_c = mod_add(bfly_x0_c, bfly_x2_c);
      bfly_d02_c = mod_sub(bfly_x0_c, bfly_x2_c);
      bfly_s13_c = mod_add(bfly_x1_c, bfly_x3_c);
      bfly_d13_c = mod_sub(bfly_x1_c, bfly_x3_c);
    end
  end

  assign side_load_valid_c = inv_mul_valid_c || (bfly_valid_q && !bfly_inverse_q);
  assign side_load_inverse_c = inv_mul_valid_c;
  assign side_load_radix2_c = inv_mul_valid_c ? bfly_radix2_c : bfly_radix2_q;
  assign side_load_coset_c = inv_mul_valid_c ? bfly_coset_c : bfly_coset_q;
  assign side_load_s02_c = inv_mul_valid_c ? bfly_s02_c : bfly_s02_q;
  assign side_load_d02_c = inv_mul_valid_c ? bfly_d02_c : bfly_d02_q;
  assign side_load_s13_c = inv_mul_valid_c ? bfly_s13_c : bfly_s13_q;
  generate
    if (!USE_SHARED_TWIDDLE) begin : g_local_twiddle_load
      assign side_load_w1_c = inv_mul_valid_c ? '0 : bfly_w1_q;
      assign side_load_w2_c = inv_mul_valid_c ? '0 : bfly_w2_q;
      assign side_load_w3_c = inv_mul_valid_c ? inv_w3_pipe_q[MUL_LAT-1] : bfly_w3_q;
    end else begin : g_shared_twiddle_load
      assign side_load_w1_c = '0;
      assign side_load_w2_c = '0;
      assign side_load_w3_c = '0;
    end
  endgenerate

  assign j_launch_valid_c = side_load_valid_c && (!side_load_radix2_c || side_load_coset_c);
  assign j_launch_pre_c = J_PRE_STAGE ||
                          (INVERSE_J_PRE_STAGE && side_load_inverse_c) ||
                          (COSET_J_PRE_STAGE && side_load_coset_c);
  assign j_direct_valid_c = j_launch_valid_c && !j_launch_pre_c;
  assign j_launch_neg_c = inv_mul_valid_c ? bfly_j_neg_c : bfly_j_neg_q;
  assign j_launch_operand_c = side_load_coset_c ? side_load_d02_c :
                              inv_mul_valid_c ? bfly_d13_c : bfly_d13_q;
  assign j_launch_const_c = side_load_coset_c ? side_load_w3_c :
                            j_launch_neg_c ? mrec_res_t'(MREC_J_INV) : mrec_res_t'(MREC_J);
  assign j_direct_operand_c = INVERSE_J_PRE_STAGE ? bfly_d13_q :
                              inv_mul_valid_c ? bfly_d13_c : bfly_d13_q;
  assign j_direct_const_c = (INVERSE_J_PRE_STAGE ? bfly_j_neg_q : j_launch_neg_c)
                            ? mrec_res_t'(MREC_J_INV) : mrec_res_t'(MREC_J);

  generate
    if (J_PRE_STAGE) begin : g_j_pre_stage
      assign j_sched_valid_c = j_pre_valid_q;
      assign j_sched_operand_c = j_pre_operand_q;
      assign j_sched_const_c = j_pre_const_q;
      assign j_sched_neg_c = j_pre_neg_q;
    end else if (INVERSE_J_PRE_STAGE || COSET_J_PRE_STAGE) begin : g_selective_j_pre_stage
      assign j_sched_valid_c = j_pre_valid_q || j_direct_valid_c;
      assign j_sched_operand_c = j_pre_valid_q ? j_pre_operand_q : j_direct_operand_c;
      assign j_sched_const_c = j_pre_valid_q ? j_pre_const_q : j_direct_const_c;
      assign j_sched_neg_c = j_pre_valid_q ? j_pre_neg_q : j_launch_neg_c;
    end else begin : g_no_j_pre_stage
      assign j_sched_valid_c = j_launch_valid_c;
      assign j_sched_operand_c = j_launch_operand_c;
      assign j_sched_const_c = j_launch_const_c;
      assign j_sched_neg_c = j_launch_neg_c;
    end
  endgenerate

  generate
    if (ENABLE_PRODUCT4_MODE) begin : g_product4_j_in
      assign j_in_valid_c = product4_in_valid_c || j_sched_valid_c;
      assign j_operand_c = product4_in_valid_c ? x0_in : j_sched_operand_c;
      assign j_const_c = product4_in_valid_c ? product_w0_in : j_sched_const_c;
      assign j_neg_c = product4_in_valid_c ? 1'b0 : j_sched_neg_c;
    end else begin : g_no_product4_j_in
      assign j_in_valid_c = j_sched_valid_c;
      assign j_operand_c = j_sched_operand_c;
      assign j_const_c = j_sched_const_c;
      assign j_neg_c = j_sched_neg_c;
    end
  endgenerate

  generate
    if (J_USE_DSP) begin : g_j_dsp
      if (J_USE_TIGHT_MUL) begin : g_tight
        ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
          .EXTRA_STAGE(MUL_EXTRA_STAGE)
        ) u_j_mul (
          .clk(clk),
          .rst(rst),
          .in_valid(j_in_valid_c),
          .a_in(j_operand_c),
          .b_in(j_const_c),
          .out_valid(j_out_valid),
          .p_out(jd13_c)
        );
      end else begin : g_generic
        ntt46_p520_ntt46_mrec_modmul_pipe #(
          .EXTRA_STAGE(MUL_EXTRA_STAGE)
        ) u_j_mul (
          .clk(clk),
          .rst(rst),
          .in_valid(j_in_valid_c),
          .a_in(j_operand_c),
          .b_in(j_const_c),
          .out_valid(j_out_valid),
          .p_out(jd13_c)
        );
      end
    end else begin : g_j_lut
      if (J_LUT_FAST3) begin : g_fast3
        ntt46_p520_ntt46_mrec_modmul_j_fast3_pipe u_j_mul (
          .clk(clk),
          .rst(rst),
          .in_valid(j_in_valid_c),
          .negate(j_neg_c),
          .a_in(j_operand_c),
          .out_valid(j_out_valid),
          .p_out(jd13_c)
        );
      end else begin : g_safe4
        ntt46_p520_ntt46_mrec_modmul_j_pipe u_j_mul (
          .clk(clk),
          .rst(rst),
          .in_valid(j_in_valid_c),
          .negate(j_neg_c),
          .a_in(j_operand_c),
          .out_valid(j_out_valid),
          .p_out(jd13_c)
        );
      end
    end
  endgenerate

  assign post_early_needs_j_c = !side_radix2_q[J_LAT-1] || side_coset_q[J_LAT-1];
  assign post_late_needs_j_c = !side_radix2_q[SIDE_LAT-1] || side_coset_q[SIDE_LAT-1];
  assign post_early_valid_c = side_valid_q[J_LAT-1] && !J_PRE_STAGE &&
                              !(INVERSE_J_PRE_STAGE && side_inverse_q[J_LAT-1]) &&
                              !(COSET_J_PRE_STAGE && side_coset_q[J_LAT-1]) &&
                              (!post_early_needs_j_c || j_out_valid);
  assign post_late_valid_c = side_valid_q[SIDE_LAT-1] &&
                             (J_PRE_STAGE ||
                              (INVERSE_J_PRE_STAGE && side_inverse_q[SIDE_LAT-1]) ||
                              (COSET_J_PRE_STAGE && side_coset_q[SIDE_LAT-1])) &&
                             (!post_late_needs_j_c || j_out_valid);
  assign post_select_late_c = post_late_valid_c;
  assign post_valid_c = post_late_valid_c || post_early_valid_c;
  assign post_inverse_c = post_select_late_c ? side_inverse_q[SIDE_LAT-1] : side_inverse_q[J_LAT-1];
  assign post_radix2_c = post_select_late_c ? side_radix2_q[SIDE_LAT-1] : side_radix2_q[J_LAT-1];
  assign post_coset_c = post_select_late_c ? side_coset_q[SIDE_LAT-1] : side_coset_q[J_LAT-1];
  assign post_needs_j_c = post_select_late_c ? post_late_needs_j_c : post_early_needs_j_c;
  assign post_s02_c = post_select_late_c ? side_s02_q[SIDE_LAT-1] : side_s02_q[J_LAT-1];
  assign post_d02_c = post_select_late_c ? side_d02_q[SIDE_LAT-1] : side_d02_q[J_LAT-1];
  assign post_s13_c = post_select_late_c ? side_s13_q[SIDE_LAT-1] : side_s13_q[J_LAT-1];
  generate
    if (USE_SHARED_TWIDDLE) begin : g_shared_twiddle_post
      assign post_w1_c = post_select_late_c ? shared_w1_late : shared_w1_early;
      assign post_w2_c = post_select_late_c ? shared_w2_late : shared_w2_early;
      assign post_w3_c = post_select_late_c ? shared_w3_late : shared_w3_early;
    end else begin : g_local_twiddle_post
      assign post_w1_c = post_select_late_c ? side_w1_q[SIDE_LAT-1] : side_w1_q[J_LAT-1];
      assign post_w2_c = post_select_late_c ? side_w2_q[SIDE_LAT-1] : side_w2_q[J_LAT-1];
      assign post_w3_c = post_select_late_c ? side_w3_q[SIDE_LAT-1] : side_w3_q[J_LAT-1];
    end
  endgenerate

  always_comb begin
    if (post_radix2_c) begin
      post_y0_c = post_s02_c;
      post_y1_c = post_coset_c ? jd13_c : post_d02_c;
      post_y2_c = '0;
      post_y3_c = '0;
    end else begin
      post_y0_c = mod_add(post_s02_c, post_s13_c);
      post_y1_c = mod_add(post_d02_c, jd13_c);
      post_y2_c = mod_sub(post_s02_c, post_s13_c);
      post_y3_c = mod_sub(post_d02_c, jd13_c);
    end
  end

  generate
    if (ENABLE_PRODUCT4_MODE) begin : g_product4_mul_in
      assign mul_in_valid_c = product4_in_valid_c || inv_in_valid_c || fwd_launch_valid_q;
      assign mul_a1_c = product4_in_valid_c ? x1_in :
                        inv_in_valid_c ? x1_in : fwd_y1_launch_q;
      assign mul_a2_c = product4_in_valid_c ? x2_in :
                        inv_in_valid_c ? (coset_untwist ? x0_in : x2_in) : fwd_y2_launch_q;
      assign mul_a3_c = product4_in_valid_c ? x3_in :
                        inv_in_valid_c ? x3_in : fwd_y3_launch_q;
      assign mul_b1_c = product4_in_valid_c ? w1_in :
                        inv_in_valid_c ? w1_in : fwd_w1_launch_q;
      assign mul_b2_c = product4_in_valid_c ? w2_in :
                        inv_in_valid_c ? w2_in : fwd_w2_launch_q;
      assign mul_b3_c = product4_in_valid_c ? w3_in :
                        inv_in_valid_c ? w3_in : fwd_w3_launch_q;
    end else begin : g_no_product4_mul_in
      assign mul_in_valid_c = inv_in_valid_c || fwd_launch_valid_q;
      assign mul_a1_c = inv_in_valid_c ? x1_in : fwd_y1_launch_q;
      assign mul_a2_c = inv_in_valid_c ? (coset_untwist ? x0_in : x2_in) : fwd_y2_launch_q;
      assign mul_a3_c = inv_in_valid_c ? x3_in : fwd_y3_launch_q;
      assign mul_b1_c = inv_in_valid_c ? w1_in : fwd_w1_launch_q;
      assign mul_b2_c = inv_in_valid_c ? w2_in : fwd_w2_launch_q;
      assign mul_b3_c = inv_in_valid_c ? w3_in : fwd_w3_launch_q;
    end
  endgenerate

  generate
    if (USE_TIGHT_MUL) begin : g_tight_mul
      ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
        .EXTRA_STAGE(MUL_EXTRA_STAGE)
      ) u_mul1 (
        .clk(clk),
        .rst(rst),
        .in_valid(mul_in_valid_c),
        .a_in(mul_a1_c),
        .b_in(mul_b1_c),
        .out_valid(mul_out_valid_c),
        .p_out(mul_y1_c)
      );

      ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
        .EXTRA_STAGE(MUL_EXTRA_STAGE)
      ) u_mul2 (
        .clk(clk),
        .rst(rst),
        .in_valid(mul_in_valid_c),
        .a_in(mul_a2_c),
        .b_in(mul_b2_c),
        .out_valid(),
        .p_out(mul_y2_c)
      );

      ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
        .EXTRA_STAGE(MUL_EXTRA_STAGE)
      ) u_mul3 (
        .clk(clk),
        .rst(rst),
        .in_valid(mul_in_valid_c),
        .a_in(mul_a3_c),
        .b_in(mul_b3_c),
        .out_valid(),
        .p_out(mul_y3_c)
      );
    end else begin : g_generic_mul
      ntt46_p520_ntt46_mrec_modmul_pipe #(
        .EXTRA_STAGE(MUL_EXTRA_STAGE)
      ) u_mul1 (
        .clk(clk),
        .rst(rst),
        .in_valid(mul_in_valid_c),
        .a_in(mul_a1_c),
        .b_in(mul_b1_c),
        .out_valid(mul_out_valid_c),
        .p_out(mul_y1_c)
      );

      ntt46_p520_ntt46_mrec_modmul_pipe #(
        .EXTRA_STAGE(MUL_EXTRA_STAGE)
      ) u_mul2 (
        .clk(clk),
        .rst(rst),
        .in_valid(mul_in_valid_c),
        .a_in(mul_a2_c),
        .b_in(mul_b2_c),
        .out_valid(),
        .p_out(mul_y2_c)
      );

      ntt46_p520_ntt46_mrec_modmul_pipe #(
        .EXTRA_STAGE(MUL_EXTRA_STAGE)
      ) u_mul3 (
        .clk(clk),
        .rst(rst),
        .in_valid(mul_in_valid_c),
        .a_in(mul_a3_c),
        .b_in(mul_b3_c),
        .out_valid(),
        .p_out(mul_y3_c)
      );
    end
  endgenerate

  generate
    if (LANE_IDX == 0) begin : g_valid_outs
      assign inv_out_valid = post_valid_c && post_inverse_c;
      assign fwd_out_valid = fwd_mul_valid_c;
      assign out_valid = inv_out_valid || fwd_out_valid || product4_out_valid_c;
    end else begin : g_no_valid_outs
      assign inv_out_valid = 1'b0;
      assign fwd_out_valid = 1'b0;
      assign out_valid = 1'b0;
    end
  endgenerate

  generate
    if (ENABLE_PRODUCT4_MODE) begin : g_product4_output_sel
      always_comb begin
        if (mul_product4_pipe_q[MUL_LAT-1]) begin
          y0_out = jd13_c;
          y1_out = mul_y1_c;
          y2_out = mul_y2_c;
          y3_out = mul_y3_c;
        end else if (post_valid_c && post_inverse_c) begin
          y0_out = post_y0_c;
          y1_out = post_y1_c;
          y2_out = post_y2_c;
          y3_out = post_y3_c;
        end else begin
          y0_out = fwd_y0_mul_pipe_q[MUL_LAT-1];
          y1_out = mul_y1_c;
          y2_out = mul_y2_c;
          y3_out = mul_y3_c;
        end
      end
    end else begin : g_no_product4_output_sel
      always_comb begin
        if (post_valid_c && post_inverse_c) begin
          y0_out = post_y0_c;
          y1_out = post_y1_c;
          y2_out = post_y2_c;
          y3_out = post_y3_c;
        end else begin
          y0_out = fwd_y0_mul_pipe_q[MUL_LAT-1];
          y1_out = mul_y1_c;
          y2_out = mul_y2_c;
          y3_out = mul_y3_c;
        end
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst) begin
      bfly_valid_q <= 1'b0;
      bfly_inverse_q <= 1'b0;
      bfly_radix2_q <= 1'b0;
      bfly_coset_q <= 1'b0;
      bfly_j_neg_q <= 1'b0;
      fwd_launch_valid_q <= 1'b0;
      j_pre_valid_q <= 1'b0;
      j_pre_neg_q <= 1'b0;
      for (int idx = 0; idx < SIDE_LAT; idx++) begin
        side_valid_q[idx] <= 1'b0;
        side_inverse_q[idx] <= 1'b0;
        side_radix2_q[idx] <= 1'b0;
        side_coset_q[idx] <= 1'b0;
      end
      for (int idx = 0; idx < MUL_LAT; idx++) begin
        mul_inverse_pipe_q[idx] <= 1'b0;
        mul_product4_pipe_q[idx] <= 1'b0;
        mul_radix2_pipe_q[idx] <= 1'b0;
        mul_coset_pipe_q[idx] <= 1'b0;
        mul_j_neg_pipe_q[idx] <= 1'b0;
      end
      if (RESET_DATA_ARRAYS) begin
        bfly_s02_q <= '0;
        bfly_d02_q <= '0;
        bfly_s13_q <= '0;
        bfly_d13_q <= '0;
        bfly_w1_q <= '0;
        bfly_w2_q <= '0;
        bfly_w3_q <= '0;
        j_pre_operand_q <= '0;
        j_pre_const_q <= '0;
        fwd_y0_launch_q <= '0;
        fwd_y1_launch_q <= '0;
        fwd_y2_launch_q <= '0;
        fwd_y3_launch_q <= '0;
        fwd_w1_launch_q <= '0;
        fwd_w2_launch_q <= '0;
        fwd_w3_launch_q <= '0;
        for (int idx = 0; idx < SIDE_LAT; idx++) begin
          side_s02_q[idx] <= '0;
          side_d02_q[idx] <= '0;
          side_s13_q[idx] <= '0;
          side_w1_q[idx] <= '0;
          side_w2_q[idx] <= '0;
          side_w3_q[idx] <= '0;
        end
        for (int idx = 0; idx < MUL_LAT; idx++) begin
          fwd_y0_mul_pipe_q[idx] <= '0;
          inv_x0_pipe_q[idx] <= '0;
          inv_w3_pipe_q[idx] <= '0;
        end
      end
    end else begin
      bfly_valid_q <= bfly_in_valid_c;
      if (bfly_in_valid_c) begin
        bfly_inverse_q <= bfly_inverse_c;
        bfly_radix2_q <= bfly_radix2_c;
        bfly_coset_q <= bfly_coset_c;
        bfly_j_neg_q <= bfly_j_neg_c;
        bfly_s02_q <= bfly_s02_c;
        bfly_d02_q <= bfly_d02_c;
        bfly_s13_q <= bfly_s13_c;
        bfly_d13_q <= bfly_d13_c;
        bfly_w1_q <= w1_in;
        bfly_w2_q <= w2_in;
        bfly_w3_q <= w3_in;
      end

      side_valid_q[0] <= side_load_valid_c;
      side_inverse_q[0] <= side_load_inverse_c;
      side_radix2_q[0] <= side_load_radix2_c;
      side_coset_q[0] <= side_load_coset_c;
      side_s02_q[0] <= side_load_s02_c;
      side_d02_q[0] <= side_load_d02_c;
      side_s13_q[0] <= side_load_s13_c;
      side_w1_q[0] <= side_load_w1_c;
      side_w2_q[0] <= side_load_w2_c;
      side_w3_q[0] <= side_load_w3_c;
      for (int idx = 1; idx < SIDE_LAT; idx++) begin
        side_valid_q[idx] <= side_valid_q[idx-1];
        side_inverse_q[idx] <= side_inverse_q[idx-1];
        side_radix2_q[idx] <= side_radix2_q[idx-1];
        side_coset_q[idx] <= side_coset_q[idx-1];
        side_s02_q[idx] <= side_s02_q[idx-1];
        side_d02_q[idx] <= side_d02_q[idx-1];
        side_s13_q[idx] <= side_s13_q[idx-1];
        side_w1_q[idx] <= side_w1_q[idx-1];
        side_w2_q[idx] <= side_w2_q[idx-1];
        side_w3_q[idx] <= side_w3_q[idx-1];
      end

      fwd_launch_valid_q <= post_valid_c && !post_inverse_c;
      if (post_valid_c && !post_inverse_c) begin
        fwd_y0_launch_q <= post_y0_c;
        fwd_y1_launch_q <= post_y1_c;
        fwd_y2_launch_q <= post_y2_c;
        fwd_y3_launch_q <= post_y3_c;
        fwd_w1_launch_q <= post_w1_c;
        fwd_w2_launch_q <= post_w2_c;
        fwd_w3_launch_q <= post_w3_c;
      end

      j_pre_valid_q <= j_launch_valid_c && j_launch_pre_c;
      if (j_launch_valid_c && j_launch_pre_c) begin
        j_pre_neg_q <= j_launch_neg_c;
        j_pre_operand_q <= j_launch_operand_c;
        j_pre_const_q <= j_launch_const_c;
      end

      fwd_y0_mul_pipe_q[0] <= fwd_launch_valid_q ? fwd_y0_launch_q : '0;
      for (int idx = 1; idx < MUL_LAT; idx++) begin
        fwd_y0_mul_pipe_q[idx] <= fwd_y0_mul_pipe_q[idx-1];
      end

      mul_inverse_pipe_q[0] <= inv_in_valid_c;
      mul_product4_pipe_q[0] <= product4_in_valid_c;
      mul_radix2_pipe_q[0] <= radix2_mode;
      mul_coset_pipe_q[0] <= inv_in_valid_c && coset_untwist;
      mul_j_neg_pipe_q[0] <= (j_in == mrec_res_t'(MREC_J_INV));
      inv_x0_pipe_q[0] <= inv_in_valid_c ? x0_in : '0;
      inv_w3_pipe_q[0] <= inv_in_valid_c ? w3_in : '0;
      for (int idx = 1; idx < MUL_LAT; idx++) begin
        mul_inverse_pipe_q[idx] <= mul_inverse_pipe_q[idx-1];
        mul_product4_pipe_q[idx] <= mul_product4_pipe_q[idx-1];
        mul_radix2_pipe_q[idx] <= mul_radix2_pipe_q[idx-1];
        mul_coset_pipe_q[idx] <= mul_coset_pipe_q[idx-1];
        mul_j_neg_pipe_q[idx] <= mul_j_neg_pipe_q[idx-1];
        inv_x0_pipe_q[idx] <= inv_x0_pipe_q[idx-1];
        inv_w3_pipe_q[idx] <= inv_w3_pipe_q[idx-1];
      end
    end
  end

endmodule

