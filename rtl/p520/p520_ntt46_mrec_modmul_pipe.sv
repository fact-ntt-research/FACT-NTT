module ntt46_p520_ntt46_mrec_modmul_pipe #(
  parameter bit EXTRA_STAGE = 1'b0
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     a_in,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     b_in,
  output logic                                out_valid,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     p_out
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;
  import ntt46_p520_ntt46_mrec_params_pkg::*;

  logic valid_s1;
  logic valid_s2;
  (* use_dsp = "yes" *) logic [MREC_PROD_W-1:0] product_s1;
  logic [MREC_REDUCE_W-1:0] fold12_s2;

  generate
    if (EXTRA_STAGE) begin : g_extra_stage
      logic valid_s3;
      logic [MREC_REDUCE_W-1:0] fold34_s3;

      always_ff @(posedge clk) begin
        if (rst) begin
          valid_s1 <= 1'b0;
          valid_s2 <= 1'b0;
          valid_s3 <= 1'b0;
          product_s1 <= '0;
          fold12_s2 <= '0;
          fold34_s3 <= '0;
          out_valid <= 1'b0;
          p_out <= '0;
        end else begin
          valid_s1 <= in_valid;
          valid_s2 <= valid_s1;
          valid_s3 <= valid_s2;
          out_valid <= valid_s3;

          product_s1 <= a_in * b_in;
          fold12_s2 <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_product(product_s1));
          fold34_s3 <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_reduced(fold12_s2));
          p_out <= pseudo_mersenne_normalize(fold34_s3);
        end
      end
    end else begin : g_base_stage
      always_ff @(posedge clk) begin
        if (rst) begin
          valid_s1 <= 1'b0;
          valid_s2 <= 1'b0;
          product_s1 <= '0;
          fold12_s2 <= '0;
          out_valid <= 1'b0;
          p_out <= '0;
        end else begin
          valid_s1 <= in_valid;
          valid_s2 <= valid_s1;
          out_valid <= valid_s2;

          product_s1 <= a_in * b_in;
          fold12_s2 <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_product(product_s1));
          p_out <= pseudo_mersenne_normalize(
            pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_reduced(fold12_s2))
          );
        end
      end
    end
  endgenerate

endmodule

module ntt46_p520_ntt46_mrec_modmul_const_pipe #(
  parameter int unsigned B_CONST = 1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     a_in,
  output logic                                out_valid,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     p_out
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;

  ntt46_p520_ntt46_mrec_modmul_pipe u_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .a_in(a_in),
    .b_in(mrec_res_t'(B_CONST)),
    .out_valid(out_valid),
    .p_out(p_out)
  );

endmodule

