module ntt46_mrec_modmul_j_pipe (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                negate,
  input  ntt46_mrec_arith_pkg::mrec_res_t     a_in,
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     p_out
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  logic valid_s1;
  logic negate_s1;
  logic [MREC_PROD_W-1:0] raw_s1;
  logic valid_s2;
  logic negate_s2;
  logic [MREC_REDUCE_W-1:0] fold12_s2;
  logic valid_s3;
  logic negate_s3;
  logic [MREC_REDUCE_W-1:0] fold34_s3;
  mrec_res_t norm_c;
  mrec_res_t norm_neg_c;

  assign norm_c = pseudo_mersenne_normalize(fold34_s3);
  assign norm_neg_c = pseudo_mersenne_normalize_neg(fold34_s3);

  always_ff @(posedge clk) begin
    if (rst) begin
      valid_s1 <= 1'b0;
      negate_s1 <= 1'b0;
      raw_s1 <= '0;
      valid_s2 <= 1'b0;
      negate_s2 <= 1'b0;
      fold12_s2 <= '0;
      valid_s3 <= 1'b0;
      negate_s3 <= 1'b0;
      fold34_s3 <= '0;
      out_valid <= 1'b0;
      p_out <= '0;
    end else begin
      valid_s1 <= in_valid;
      negate_s1 <= negate;
      raw_s1 <= mul_const_j_raw(a_in);

      valid_s2 <= valid_s1;
      negate_s2 <= negate_s1;
      fold12_s2 <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_product(raw_s1));

      valid_s3 <= valid_s2;
      negate_s3 <= negate_s2;
      fold34_s3 <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_reduced(fold12_s2));

      out_valid <= valid_s3;
      p_out <= negate_s3 ? norm_neg_c : norm_c;
    end
  end

endmodule
