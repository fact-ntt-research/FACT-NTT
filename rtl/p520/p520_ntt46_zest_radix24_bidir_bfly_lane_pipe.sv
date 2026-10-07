module ntt46_p520_ntt46_zest_radix24_bidir_bfly_lane_pipe #(
  parameter bit J_USE_DSP = 1'b0
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                radix2_mode,
  input  logic                                inverse,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x0_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x1_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x2_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x3_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w1_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w2_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     w3_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     j_in,
  output logic                                out_valid,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y0_out,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y1_out,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y2_out,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     y3_out
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;
  import ntt46_p520_ntt46_mrec_params_pkg::*;

  localparam int unsigned MUL_LAT = 4;
  localparam int unsigned J_LAT = 4;

  logic      fwd_in_valid_c;
  logic      inv_in_valid_c;

  mrec_res_t fwd_r4_s02_c;
  mrec_res_t fwd_r4_d02_c;
  mrec_res_t fwd_r4_s13_c;
  mrec_res_t fwd_r4_d13_c;
  mrec_res_t fwd_r2_s01_c;
  mrec_res_t fwd_r2_d01_c;
  logic      fwd_pre_valid_q;
  logic      fwd_radix2_pre_q;
  logic      fwd_j_neg_pre_q;
  mrec_res_t fwd_s02_pre_q;
  mrec_res_t fwd_d02_pre_q;
  mrec_res_t fwd_s13_pre_q;
  mrec_res_t fwd_d13_pre_q;
  mrec_res_t fwd_w1_pre_q;
  mrec_res_t fwd_w2_pre_q;
  mrec_res_t fwd_w3_pre_q;

  logic      fwd_side_valid_q [0:J_LAT-1];
  logic      fwd_side_radix2_q [0:J_LAT-1];
  mrec_res_t fwd_d02_pipe_q [0:J_LAT-1];
  mrec_res_t fwd_y0_pipe_q  [0:J_LAT-1];
  mrec_res_t fwd_y2_pipe_q  [0:J_LAT-1];
  mrec_res_t fwd_w1_pipe_q  [0:J_LAT-1];
  mrec_res_t fwd_w2_pipe_q  [0:J_LAT-1];
  mrec_res_t fwd_w3_pipe_q  [0:J_LAT-1];

  logic      fwd_launch_valid_c;
  logic      fwd_launch_valid_q;
  mrec_res_t fwd_y0_launch_q;
  mrec_res_t fwd_y1_launch_q;
  mrec_res_t fwd_y2_launch_q;
  mrec_res_t fwd_y3_launch_q;
  mrec_res_t fwd_w1_launch_q;
  mrec_res_t fwd_w2_launch_q;
  mrec_res_t fwd_w3_launch_q;
  logic      fwd_out_valid_c;
  mrec_res_t fwd_y0_mul_pipe_q [0:MUL_LAT-1];

  mrec_res_t inv_x1_tw_c;
  mrec_res_t inv_x2_tw_c;
  mrec_res_t inv_x3_tw_c;
  logic      mul_out_valid_c;
  logic      mul_inverse_pipe_q [0:MUL_LAT-1];
  logic      mul_radix2_pipe_q [0:MUL_LAT-1];
  logic      mul_j_neg_pipe_q [0:MUL_LAT-1];
  logic      inv_mul_valid_c;
  logic      inv_mul_radix2_c;
  logic      inv_j_neg_c;
  mrec_res_t inv_x0_pipe_q [0:MUL_LAT-1];
  mrec_res_t inv_s02_c;
  mrec_res_t inv_d02_c;
  mrec_res_t inv_s13_c;
  mrec_res_t inv_d13_c;
  logic      inv_side_valid_q [0:J_LAT-1];
  logic      inv_side_radix2_q [0:J_LAT-1];
  mrec_res_t inv_d02_pipe_q [0:J_LAT-1];
  mrec_res_t inv_s02_pipe_q [0:J_LAT-1];
  mrec_res_t inv_s13_pipe_q [0:J_LAT-1];
  logic      inv_out_valid_c;
  logic      inv_out_radix2_c;
  mrec_res_t inv_y0_c;
  mrec_res_t inv_y1_c;
  mrec_res_t inv_y2_c;
  mrec_res_t inv_y3_c;

  logic      j_in_valid_c;
  logic      j_negate_c;
  mrec_res_t j_operand_c;
  logic      j_out_valid;
  mrec_res_t jd13_c;
  mrec_res_t j_const_c;

  logic      mul_in_valid_c;
  mrec_res_t mul_a1_c;
  mrec_res_t mul_a2_c;
  mrec_res_t mul_a3_c;
  mrec_res_t mul_b1_c;
  mrec_res_t mul_b2_c;
  mrec_res_t mul_b3_c;
  mrec_res_t mul_y1_c;
  mrec_res_t mul_y2_c;
  mrec_res_t mul_y3_c;

  assign fwd_in_valid_c = in_valid && !inverse;
  assign inv_in_valid_c = in_valid && inverse;

  assign fwd_r4_s02_c = mod_add(x0_in, x2_in);
  assign fwd_r4_d02_c = mod_sub(x0_in, x2_in);
  assign fwd_r4_s13_c = mod_add(x1_in, x3_in);
  assign fwd_r4_d13_c = mod_sub(x1_in, x3_in);
  assign fwd_r2_s01_c = mod_add(x0_in, x1_in);
  assign fwd_r2_d01_c = mod_sub(x0_in, x1_in);

  assign j_in_valid_c = (fwd_pre_valid_q && !fwd_radix2_pre_q) ||
                        (inv_mul_valid_c && !inv_mul_radix2_c);
  assign inv_j_neg_c = mul_j_neg_pipe_q[MUL_LAT-1];
  assign j_negate_c = inv_mul_valid_c ? inv_j_neg_c : fwd_j_neg_pre_q;
  assign j_operand_c = inv_mul_valid_c ? inv_d13_c : fwd_d13_pre_q;
  assign j_const_c = j_negate_c ? mrec_res_t'(MREC_J_INV) : mrec_res_t'(MREC_J);

  generate
    if (J_USE_DSP) begin : g_j_dsp
      ntt46_p520_ntt46_mrec_modmul_pipe #(
        .EXTRA_STAGE(1'b1)
      ) u_j_mul (
        .clk(clk),
        .rst(rst),
        .in_valid(j_in_valid_c),
        .a_in(j_operand_c),
        .b_in(j_const_c),
        .out_valid(j_out_valid),
        .p_out(jd13_c)
      );
    end else begin : g_j_lut
      ntt46_p520_ntt46_mrec_modmul_j_pipe u_j_mul (
        .clk(clk),
        .rst(rst),
        .in_valid(j_in_valid_c),
        .negate(j_negate_c),
        .a_in(j_operand_c),
        .out_valid(j_out_valid),
        .p_out(jd13_c)
      );
    end
  endgenerate

  assign fwd_launch_valid_c =
      fwd_side_valid_q[J_LAT-1] &&
      (fwd_side_radix2_q[J_LAT-1] || j_out_valid);

  assign inv_out_radix2_c = inv_side_radix2_q[J_LAT-1];
  assign inv_out_valid_c =
      inv_side_valid_q[J_LAT-1] &&
      (inv_out_radix2_c || j_out_valid);

  assign inv_mul_valid_c = mul_out_valid_c && mul_inverse_pipe_q[MUL_LAT-1];
  assign inv_mul_radix2_c = mul_radix2_pipe_q[MUL_LAT-1];
  assign fwd_out_valid_c = mul_out_valid_c && !mul_inverse_pipe_q[MUL_LAT-1];
  assign mul_in_valid_c = inv_in_valid_c || fwd_launch_valid_q;

  assign mul_a1_c = inv_in_valid_c ? x1_in : fwd_y1_launch_q;
  assign mul_a2_c = inv_in_valid_c ? x2_in : fwd_y2_launch_q;
  assign mul_a3_c = inv_in_valid_c ? x3_in : fwd_y3_launch_q;
  assign mul_b1_c = inv_in_valid_c ? w1_in : fwd_w1_launch_q;
  assign mul_b2_c = inv_in_valid_c ? w2_in : fwd_w2_launch_q;
  assign mul_b3_c = inv_in_valid_c ? w3_in : fwd_w3_launch_q;

  ntt46_p520_ntt46_mrec_modmul_pipe #(
    .EXTRA_STAGE(1'b1)
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
    .EXTRA_STAGE(1'b1)
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
    .EXTRA_STAGE(1'b1)
  ) u_mul3 (
    .clk(clk),
    .rst(rst),
    .in_valid(mul_in_valid_c),
    .a_in(mul_a3_c),
    .b_in(mul_b3_c),
    .out_valid(),
    .p_out(mul_y3_c)
  );

  assign inv_x1_tw_c = mul_y1_c;
  assign inv_x2_tw_c = mul_y2_c;
  assign inv_x3_tw_c = mul_y3_c;

  always_comb begin
    if (inv_mul_radix2_c) begin
      inv_s02_c = mod_add(inv_x0_pipe_q[MUL_LAT-1], inv_x1_tw_c);
      inv_d02_c = mod_sub(inv_x0_pipe_q[MUL_LAT-1], inv_x1_tw_c);
      inv_s13_c = '0;
      inv_d13_c = '0;
    end else begin
      inv_s02_c = mod_add(inv_x0_pipe_q[MUL_LAT-1], inv_x2_tw_c);
      inv_d02_c = mod_sub(inv_x0_pipe_q[MUL_LAT-1], inv_x2_tw_c);
      inv_s13_c = mod_add(inv_x1_tw_c, inv_x3_tw_c);
      inv_d13_c = mod_sub(inv_x1_tw_c, inv_x3_tw_c);
    end
  end

  always_comb begin
    if (inv_out_radix2_c) begin
      inv_y0_c = inv_s02_pipe_q[J_LAT-1];
      inv_y1_c = inv_d02_pipe_q[J_LAT-1];
      inv_y2_c = '0;
      inv_y3_c = '0;
    end else begin
      inv_y0_c = mod_add(inv_s02_pipe_q[J_LAT-1], inv_s13_pipe_q[J_LAT-1]);
      inv_y1_c = mod_add(inv_d02_pipe_q[J_LAT-1], jd13_c);
      inv_y2_c = mod_sub(inv_s02_pipe_q[J_LAT-1], inv_s13_pipe_q[J_LAT-1]);
      inv_y3_c = mod_sub(inv_d02_pipe_q[J_LAT-1], jd13_c);
    end
  end

  assign out_valid = fwd_out_valid_c || inv_out_valid_c;

  always_comb begin
    if (inv_out_valid_c) begin
      y0_out = inv_y0_c;
      y1_out = inv_y1_c;
      y2_out = inv_y2_c;
      y3_out = inv_y3_c;
    end else begin
      y0_out = fwd_y0_mul_pipe_q[MUL_LAT-1];
      y1_out = mul_y1_c;
      y2_out = mul_y2_c;
      y3_out = mul_y3_c;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      fwd_pre_valid_q <= 1'b0;
      fwd_radix2_pre_q <= 1'b0;
      fwd_j_neg_pre_q <= 1'b0;
      fwd_s02_pre_q <= '0;
      fwd_d02_pre_q <= '0;
      fwd_s13_pre_q <= '0;
      fwd_d13_pre_q <= '0;
      fwd_w1_pre_q <= '0;
      fwd_w2_pre_q <= '0;
      fwd_w3_pre_q <= '0;
      fwd_y0_launch_q <= '0;
      fwd_y1_launch_q <= '0;
      fwd_y2_launch_q <= '0;
      fwd_y3_launch_q <= '0;
      fwd_w1_launch_q <= '0;
      fwd_w2_launch_q <= '0;
      fwd_w3_launch_q <= '0;
      fwd_launch_valid_q <= 1'b0;
      for (int idx = 0; idx < J_LAT; idx++) begin
        fwd_side_valid_q[idx] <= 1'b0;
        fwd_side_radix2_q[idx] <= 1'b0;
        fwd_d02_pipe_q[idx] <= '0;
        fwd_y0_pipe_q[idx] <= '0;
        fwd_y2_pipe_q[idx] <= '0;
        fwd_w1_pipe_q[idx] <= '0;
        fwd_w2_pipe_q[idx] <= '0;
        fwd_w3_pipe_q[idx] <= '0;
        inv_side_valid_q[idx] <= 1'b0;
        inv_side_radix2_q[idx] <= 1'b0;
        inv_d02_pipe_q[idx] <= '0;
        inv_s02_pipe_q[idx] <= '0;
        inv_s13_pipe_q[idx] <= '0;
      end
      for (int idx = 0; idx < MUL_LAT; idx++) begin
        fwd_y0_mul_pipe_q[idx] <= '0;
        inv_x0_pipe_q[idx] <= '0;
        mul_inverse_pipe_q[idx] <= 1'b0;
        mul_radix2_pipe_q[idx] <= 1'b0;
        mul_j_neg_pipe_q[idx] <= 1'b0;
      end
    end else begin
      fwd_pre_valid_q <= fwd_in_valid_c;
      if (fwd_in_valid_c) begin
        fwd_radix2_pre_q <= radix2_mode;
        fwd_j_neg_pre_q <= (j_in == mrec_res_t'(MREC_J_INV));
        fwd_s02_pre_q <= radix2_mode ? fwd_r2_s01_c : fwd_r4_s02_c;
        fwd_d02_pre_q <= radix2_mode ? fwd_r2_d01_c : fwd_r4_d02_c;
        fwd_s13_pre_q <= radix2_mode ? '0 : fwd_r4_s13_c;
        fwd_d13_pre_q <= radix2_mode ? '0 : fwd_r4_d13_c;
        fwd_w1_pre_q <= w1_in;
        fwd_w2_pre_q <= w2_in;
        fwd_w3_pre_q <= w3_in;
      end

      fwd_side_valid_q[0] <= fwd_pre_valid_q;
      fwd_side_radix2_q[0] <= fwd_radix2_pre_q;
      fwd_d02_pipe_q[0] <= fwd_d02_pre_q;
      fwd_y0_pipe_q[0] <= fwd_radix2_pre_q ? fwd_s02_pre_q : mod_add(fwd_s02_pre_q, fwd_s13_pre_q);
      fwd_y2_pipe_q[0] <= fwd_radix2_pre_q ? '0 : mod_sub(fwd_s02_pre_q, fwd_s13_pre_q);
      fwd_w1_pipe_q[0] <= fwd_w1_pre_q;
      fwd_w2_pipe_q[0] <= fwd_w2_pre_q;
      fwd_w3_pipe_q[0] <= fwd_w3_pre_q;
      for (int idx = 1; idx < J_LAT; idx++) begin
        fwd_side_valid_q[idx] <= fwd_side_valid_q[idx-1];
        fwd_side_radix2_q[idx] <= fwd_side_radix2_q[idx-1];
        fwd_d02_pipe_q[idx] <= fwd_d02_pipe_q[idx-1];
        fwd_y0_pipe_q[idx] <= fwd_y0_pipe_q[idx-1];
        fwd_y2_pipe_q[idx] <= fwd_y2_pipe_q[idx-1];
        fwd_w1_pipe_q[idx] <= fwd_w1_pipe_q[idx-1];
        fwd_w2_pipe_q[idx] <= fwd_w2_pipe_q[idx-1];
        fwd_w3_pipe_q[idx] <= fwd_w3_pipe_q[idx-1];
      end

      fwd_launch_valid_q <= fwd_launch_valid_c;
      if (fwd_launch_valid_c) begin
        fwd_y0_launch_q <= fwd_y0_pipe_q[J_LAT-1];
        fwd_y1_launch_q <= fwd_side_radix2_q[J_LAT-1] ?
                           fwd_d02_pipe_q[J_LAT-1] :
                           mod_add(fwd_d02_pipe_q[J_LAT-1], jd13_c);
        fwd_y2_launch_q <= fwd_side_radix2_q[J_LAT-1] ? '0 : fwd_y2_pipe_q[J_LAT-1];
        fwd_y3_launch_q <= fwd_side_radix2_q[J_LAT-1] ?
                           '0 :
                           mod_sub(fwd_d02_pipe_q[J_LAT-1], jd13_c);
        fwd_w1_launch_q <= fwd_w1_pipe_q[J_LAT-1];
        fwd_w2_launch_q <= fwd_w2_pipe_q[J_LAT-1];
        fwd_w3_launch_q <= fwd_w3_pipe_q[J_LAT-1];
      end

      fwd_y0_mul_pipe_q[0] <= fwd_launch_valid_q ? fwd_y0_launch_q : '0;
      for (int idx = 1; idx < MUL_LAT; idx++) begin
        fwd_y0_mul_pipe_q[idx] <= fwd_y0_mul_pipe_q[idx-1];
      end

      mul_inverse_pipe_q[0] <= inv_in_valid_c;
      mul_radix2_pipe_q[0] <= radix2_mode;
      mul_j_neg_pipe_q[0] <= (j_in == mrec_res_t'(MREC_J_INV));
      for (int idx = 1; idx < MUL_LAT; idx++) begin
        mul_inverse_pipe_q[idx] <= mul_inverse_pipe_q[idx-1];
        mul_radix2_pipe_q[idx] <= mul_radix2_pipe_q[idx-1];
        mul_j_neg_pipe_q[idx] <= mul_j_neg_pipe_q[idx-1];
      end

      inv_x0_pipe_q[0] <= inv_in_valid_c ? x0_in : '0;
      for (int idx = 1; idx < MUL_LAT; idx++) begin
        inv_x0_pipe_q[idx] <= inv_x0_pipe_q[idx-1];
      end

      inv_side_valid_q[0] <= inv_mul_valid_c;
      inv_side_radix2_q[0] <= inv_mul_radix2_c;
      inv_d02_pipe_q[0] <= inv_d02_c;
      inv_s02_pipe_q[0] <= inv_s02_c;
      inv_s13_pipe_q[0] <= inv_s13_c;
      for (int idx = 1; idx < J_LAT; idx++) begin
        inv_side_valid_q[idx] <= inv_side_valid_q[idx-1];
        inv_side_radix2_q[idx] <= inv_side_radix2_q[idx-1];
        inv_d02_pipe_q[idx] <= inv_d02_pipe_q[idx-1];
        inv_s02_pipe_q[idx] <= inv_s02_pipe_q[idx-1];
        inv_s13_pipe_q[idx] <= inv_s13_pipe_q[idx-1];
      end
    end
  end

endmodule

