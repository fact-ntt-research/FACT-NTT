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

  ntt46_mrec_modmul_pipe #(
    .EXTRA_STAGE(1'b1)
  ) u_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .a_in(a_in),
    .b_in(negate ? mrec_res_t'(MREC_J_INV) : mrec_res_t'(MREC_J)),
    .out_valid(out_valid),
    .p_out(p_out)
  );

endmodule

module ntt46_mrec_modmul_j_fast3_pipe (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                negate,
  input  ntt46_mrec_arith_pkg::mrec_res_t     a_in,
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     p_out
);

  ntt46_mrec_modmul_j_pipe u_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .negate(negate),
    .a_in(a_in),
    .out_valid(out_valid),
    .p_out(p_out)
  );

endmodule
