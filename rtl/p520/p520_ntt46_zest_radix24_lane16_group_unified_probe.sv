module ntt46_p520_ntt46_zest_radix24_lane16_group_unified_probe #(
  parameter int unsigned LANES = 16,
  parameter bit J_USE_DSP = 1'b1,
  parameter bit J_LUT_FAST3 = 1'b0,
  parameter bit MUL_EXTRA_STAGE = 1'b1,
  parameter bit J_PRE_STAGE = 1'b0,
  parameter bit INVERSE_J_PRE_STAGE = 1'b0,
  parameter bit COSET_J_PRE_STAGE = 1'b0,
  parameter bit USE_TIGHT_MUL = 1'b0,
  parameter bit J_USE_TIGHT_MUL = USE_TIGHT_MUL,
  parameter bit ENABLE_PRODUCT4_MODE = 1'b1,
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
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x0_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x1_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x2_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x3_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     product_w0_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w1_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w2_in [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w3_in [0:LANES-1],
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
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y0_out [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y1_out [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y2_out [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y3_out [0:LANES-1]
);

  logic lane0_valid;
  logic lane0_fwd_valid;
  logic lane0_inv_valid;
  (* keep = "true" *) logic in_valid_grp [0:1];

  assign in_valid_grp[0] = in_valid;
  assign in_valid_grp[1] = in_valid;

  generate
    for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
      if (lane == 0) begin : g_lane0
        ntt46_p520_ntt46_zest_radix24_bidir_bfly_lane_unified_pipe #(
          .J_USE_DSP(J_USE_DSP),
          .J_LUT_FAST3(J_LUT_FAST3),
          .MUL_EXTRA_STAGE(MUL_EXTRA_STAGE),
          .J_PRE_STAGE(J_PRE_STAGE),
          .INVERSE_J_PRE_STAGE(INVERSE_J_PRE_STAGE),
          .COSET_J_PRE_STAGE(COSET_J_PRE_STAGE),
          .USE_TIGHT_MUL(USE_TIGHT_MUL),
          .J_USE_TIGHT_MUL(J_USE_TIGHT_MUL),
          .ENABLE_PRODUCT4_MODE(ENABLE_PRODUCT4_MODE),
          .LANE_IDX(0),
          .USE_SHARED_TWIDDLE(USE_SHARED_TWIDDLE),
          .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS)
        ) u_lane (
          .clk(clk),
          .rst(rst),
          .in_valid(in_valid_grp[lane >> 3]),
          .radix2_mode(radix2_mode),
          .inverse(inverse),
          .coset_untwist(coset_untwist),
          .product4_mode(product4_mode),
          .x0_in(x0_in[lane]),
          .x1_in(x1_in[lane]),
          .x2_in(x2_in[lane]),
          .x3_in(x3_in[lane]),
          .product_w0_in(product_w0_in[lane]),
          .w1_in(w1_in[lane]),
          .w2_in(w2_in[lane]),
          .w3_in(w3_in[lane]),
          .j_in(j_in),
          .shared_w1_early(shared_w1_early),
          .shared_w2_early(shared_w2_early),
          .shared_w3_early(shared_w3_early),
          .shared_w1_late(shared_w1_late),
          .shared_w2_late(shared_w2_late),
          .shared_w3_late(shared_w3_late),
          .out_valid(lane0_valid),
          .fwd_out_valid(lane0_fwd_valid),
          .inv_out_valid(lane0_inv_valid),
          .y0_out(y0_out[lane]),
          .y1_out(y1_out[lane]),
          .y2_out(y2_out[lane]),
          .y3_out(y3_out[lane])
        );
      end else begin : g_lane_n
        ntt46_p520_ntt46_zest_radix24_bidir_bfly_lane_unified_pipe #(
          .J_USE_DSP(J_USE_DSP),
          .J_LUT_FAST3(J_LUT_FAST3),
          .MUL_EXTRA_STAGE(MUL_EXTRA_STAGE),
          .J_PRE_STAGE(J_PRE_STAGE),
          .INVERSE_J_PRE_STAGE(INVERSE_J_PRE_STAGE),
          .COSET_J_PRE_STAGE(COSET_J_PRE_STAGE),
          .USE_TIGHT_MUL(USE_TIGHT_MUL),
          .J_USE_TIGHT_MUL(J_USE_TIGHT_MUL),
          .ENABLE_PRODUCT4_MODE(ENABLE_PRODUCT4_MODE),
          .LANE_IDX(lane),
          .USE_SHARED_TWIDDLE(USE_SHARED_TWIDDLE),
          .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS)
        ) u_lane (
          .clk(clk),
          .rst(rst),
          .in_valid(in_valid_grp[lane >> 3]),
          .radix2_mode(radix2_mode),
          .inverse(inverse),
          .coset_untwist(coset_untwist),
          .product4_mode(product4_mode),
          .x0_in(x0_in[lane]),
          .x1_in(x1_in[lane]),
          .x2_in(x2_in[lane]),
          .x3_in(x3_in[lane]),
          .product_w0_in(product_w0_in[lane]),
          .w1_in(w1_in[lane]),
          .w2_in(w2_in[lane]),
          .w3_in(w3_in[lane]),
          .j_in(j_in),
          .shared_w1_early(shared_w1_early),
          .shared_w2_early(shared_w2_early),
          .shared_w3_early(shared_w3_early),
          .shared_w1_late(shared_w1_late),
          .shared_w2_late(shared_w2_late),
          .shared_w3_late(shared_w3_late),
          .out_valid(),
          .fwd_out_valid(),
          .inv_out_valid(),
          .y0_out(y0_out[lane]),
          .y1_out(y1_out[lane]),
          .y2_out(y2_out[lane]),
          .y3_out(y3_out[lane])
        );
      end
    end
  endgenerate

  assign out_valid = lane0_valid;
  assign fwd_out_valid = lane0_fwd_valid;
  assign inv_out_valid = lane0_inv_valid;

endmodule

