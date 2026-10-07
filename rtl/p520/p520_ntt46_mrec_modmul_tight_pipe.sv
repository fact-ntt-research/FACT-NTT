module ntt46_p520_ntt46_mrec_modmul_tight_pipe #(
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

  ntt46_p520_ntt46_mrec_modmul_pipe #(
    .EXTRA_STAGE(EXTRA_STAGE)
  ) u_mul (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .a_in(a_in),
    .b_in(b_in),
    .out_valid(out_valid),
    .p_out(p_out)
  );

endmodule

