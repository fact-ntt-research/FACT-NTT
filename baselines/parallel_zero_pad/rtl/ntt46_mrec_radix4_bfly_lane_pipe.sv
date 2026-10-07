module ntt46_mrec_radix4_bfly_lane_pipe #(
  parameter bit USE_STAGE0_MASK = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic [3:0]                          stage0_active_mask,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x0_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x1_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x2_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x3_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     w1_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     w2_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     w3_in,
  input  ntt46_mrec_arith_pkg::mrec_res_t     j_in,
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     y0_out,
  output ntt46_mrec_arith_pkg::mrec_res_t     y1_out,
  output ntt46_mrec_arith_pkg::mrec_res_t     y2_out,
  output ntt46_mrec_arith_pkg::mrec_res_t     y3_out
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  localparam int unsigned J_LAT = 4;
  localparam int unsigned MUL_LAT = 3;

  mrec_res_t s02_c;
  mrec_res_t d02_c;
  mrec_res_t s13_c;
  mrec_res_t d13_c;
  logic      pre_valid_q;
  mrec_res_t s02_pre_q;
  mrec_res_t d02_pre_q;
  mrec_res_t s13_pre_q;
  mrec_res_t d13_pre_q;
  mrec_res_t w1_pre_q;
  mrec_res_t w2_pre_q;
  mrec_res_t w3_pre_q;
  mrec_res_t y0_pre_c;
  mrec_res_t y2_pre_c;
  logic      j_valid_c;
  mrec_res_t jd13_c;
  logic      j_stage1_valid_q;
  logic      j_stage1_neg_q;
  logic [MREC_PROD_W-1:0] j_stage1_raw_q;
  logic      j_stage2_valid_q;
  logic      j_stage2_neg_q;
  logic [MREC_REDUCE_W-1:0] j_stage2_fold_q;
  logic      j_stage3_valid_q;
  logic      j_stage3_neg_q;
  logic [MREC_REDUCE_W-1:0] j_stage3_fold_q;
  logic [MREC_REDUCE_W-1:0] j_fold34_c;
  mrec_res_t j_norm_c;
  mrec_res_t j_norm_neg_c;
  logic      mul_valid_pipe_q [0:MUL_LAT-1];

  mrec_res_t d02_pipe_q [0:J_LAT-1];
  mrec_res_t y0_pipe_q  [0:J_LAT-1];
  mrec_res_t y2_pipe_q  [0:J_LAT-1];
  mrec_res_t w1_pipe_q  [0:J_LAT-1];
  mrec_res_t w2_pipe_q  [0:J_LAT-1];
  mrec_res_t w3_pipe_q  [0:J_LAT-1];
  mrec_res_t y0_mul_pipe_q [0:MUL_LAT-1];

  mrec_res_t y1_pre_c;
  mrec_res_t y2_mid_c;
  mrec_res_t y3_pre_c;
  logic      launch_valid_q;
  mrec_res_t y0_launch_q;
  mrec_res_t y1_launch_q;
  mrec_res_t y2_launch_q;
  mrec_res_t y3_launch_q;
  mrec_res_t w1_launch_q;
  mrec_res_t w2_launch_q;
  mrec_res_t w3_launch_q;

  generate
    if (USE_STAGE0_MASK) begin : g_masked_stage0
      // Stage-0 support-aware bypass is kept for compact branch cores.
      always_comb begin
        unique case (stage0_active_mask)
          4'b0001: begin
            s02_c = x0_in;
            d02_c = x0_in;
            s13_c = '0;
            d13_c = '0;
          end

          4'b0011: begin
            s02_c = x0_in;
            d02_c = x0_in;
            s13_c = x1_in;
            d13_c = x1_in;
          end

          4'b0111: begin
            s02_c = mod_add(x0_in, x2_in);
            d02_c = mod_sub(x0_in, x2_in);
            s13_c = x1_in;
            d13_c = x1_in;
          end

          default: begin
            s02_c = mod_add(x0_in, x2_in);
            d02_c = mod_sub(x0_in, x2_in);
            s13_c = mod_add(x1_in, x3_in);
            d13_c = mod_sub(x1_in, x3_in);
          end
        endcase
      end
    end else begin : g_full_stage0
      always_comb begin
        s02_c = mod_add(x0_in, x2_in);
        d02_c = mod_sub(x0_in, x2_in);
        s13_c = mod_add(x1_in, x3_in);
        d13_c = mod_sub(x1_in, x3_in);
      end
    end
  endgenerate

  assign y0_pre_c = mod_add(s02_pre_q, s13_pre_q);
  assign y2_pre_c = mod_sub(s02_pre_q, s13_pre_q);

  assign y1_pre_c = mod_add(d02_pipe_q[J_LAT-1], jd13_c);
  assign y2_mid_c = y2_pipe_q[J_LAT-1];
  assign y3_pre_c = mod_sub(d02_pipe_q[J_LAT-1], jd13_c);
  assign out_valid = mul_valid_pipe_q[MUL_LAT-1];
  assign y0_out = y0_mul_pipe_q[MUL_LAT-1];
  assign j_fold34_c = j_stage3_fold_q;
  assign j_norm_c = pseudo_mersenne_normalize(j_fold34_c);
  assign j_norm_neg_c = pseudo_mersenne_normalize_neg(j_fold34_c);

  ntt46_mrec_modmul_pipe u_w1_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(launch_valid_q),
    .a_in(y1_launch_q),
    .b_in(w1_launch_q),
    .out_valid(),
    .p_out(y1_out)
  );

  ntt46_mrec_modmul_pipe u_w2_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(launch_valid_q),
    .a_in(y2_launch_q),
    .b_in(w2_launch_q),
    .out_valid(),
    .p_out(y2_out)
  );

  ntt46_mrec_modmul_pipe u_w3_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(launch_valid_q),
    .a_in(y3_launch_q),
    .b_in(w3_launch_q),
    .out_valid(),
    .p_out(y3_out)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      launch_valid_q <= 1'b0;
      pre_valid_q <= 1'b0;
      s02_pre_q <= '0;
      d02_pre_q <= '0;
      s13_pre_q <= '0;
      d13_pre_q <= '0;
      w1_pre_q <= '0;
      w2_pre_q <= '0;
      w3_pre_q <= '0;
      y0_launch_q <= '0;
      y1_launch_q <= '0;
      y2_launch_q <= '0;
      y3_launch_q <= '0;
      w1_launch_q <= '0;
      w2_launch_q <= '0;
      w3_launch_q <= '0;
      for (int idx = 0; idx < J_LAT; idx++) begin
        d02_pipe_q[idx] <= '0;
        y0_pipe_q[idx] <= '0;
        y2_pipe_q[idx] <= '0;
        w1_pipe_q[idx] <= '0;
        w2_pipe_q[idx] <= '0;
        w3_pipe_q[idx] <= '0;
      end
      for (int idx = 0; idx < MUL_LAT; idx++) begin
        y0_mul_pipe_q[idx] <= '0;
        mul_valid_pipe_q[idx] <= 1'b0;
      end
      j_stage1_valid_q <= 1'b0;
      j_stage1_neg_q <= 1'b0;
      j_stage1_raw_q <= '0;
      j_stage2_valid_q <= 1'b0;
      j_stage2_neg_q <= 1'b0;
      j_stage2_fold_q <= '0;
      j_stage3_valid_q <= 1'b0;
      j_stage3_neg_q <= 1'b0;
      j_stage3_fold_q <= '0;
      j_valid_c <= 1'b0;
      jd13_c <= '0;
    end else begin
      pre_valid_q <= in_valid;
      s02_pre_q <= s02_c;
      d02_pre_q <= d02_c;
      s13_pre_q <= s13_c;
      d13_pre_q <= d13_c;
      w1_pre_q <= w1_in;
      w2_pre_q <= w2_in;
      w3_pre_q <= w3_in;

      d02_pipe_q[0] <= d02_pre_q;
      y0_pipe_q[0] <= y0_pre_c;
      y2_pipe_q[0] <= y2_pre_c;
      w1_pipe_q[0] <= w1_pre_q;
      w2_pipe_q[0] <= w2_pre_q;
      w3_pipe_q[0] <= w3_pre_q;
      for (int idx = 1; idx < J_LAT; idx++) begin
        d02_pipe_q[idx] <= d02_pipe_q[idx-1];
        y0_pipe_q[idx] <= y0_pipe_q[idx-1];
        y2_pipe_q[idx] <= y2_pipe_q[idx-1];
        w1_pipe_q[idx] <= w1_pipe_q[idx-1];
        w2_pipe_q[idx] <= w2_pipe_q[idx-1];
        w3_pipe_q[idx] <= w3_pipe_q[idx-1];
      end

      j_stage1_valid_q <= pre_valid_q;
      j_stage1_neg_q <= (j_in == mrec_res_t'(MREC_J_INV));
      j_stage1_raw_q <= mul_const_j_raw(d13_pre_q);
      j_stage2_valid_q <= j_stage1_valid_q;
      j_stage2_neg_q <= j_stage1_neg_q;
      j_stage2_fold_q <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_product(j_stage1_raw_q));
      j_stage3_valid_q <= j_stage2_valid_q;
      j_stage3_neg_q <= j_stage2_neg_q;
      j_stage3_fold_q <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_reduced(j_stage2_fold_q));
      j_valid_c <= j_stage3_valid_q;
      jd13_c <= j_stage3_neg_q ? j_norm_neg_c : j_norm_c;

      launch_valid_q <= j_valid_c;
      if (j_valid_c) begin
        y0_launch_q <= y0_pipe_q[J_LAT-1];
        y1_launch_q <= y1_pre_c;
        y2_launch_q <= y2_mid_c;
        y3_launch_q <= y3_pre_c;
        w1_launch_q <= w1_pipe_q[J_LAT-1];
        w2_launch_q <= w2_pipe_q[J_LAT-1];
        w3_launch_q <= w3_pipe_q[J_LAT-1];
      end else begin
        y0_launch_q <= '0;
        y1_launch_q <= '0;
        y2_launch_q <= '0;
        y3_launch_q <= '0;
        w1_launch_q <= '0;
        w2_launch_q <= '0;
        w3_launch_q <= '0;
      end

      y0_mul_pipe_q[0] <= launch_valid_q ? y0_launch_q : '0;
      mul_valid_pipe_q[0] <= launch_valid_q;
      for (int idx = 1; idx < MUL_LAT; idx++) begin
        y0_mul_pipe_q[idx] <= y0_mul_pipe_q[idx-1];
        mul_valid_pipe_q[idx] <= mul_valid_pipe_q[idx-1];
      end
    end
  end

endmodule
