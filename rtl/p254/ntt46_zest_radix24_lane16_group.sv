module ntt46_zest_radix24_lane16_group #(
  parameter bit J_USE_DSP = 1'b0
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                radix2_mode,
  input  logic                                inverse,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x0_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x1_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x2_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x3_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     w1_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     w2_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     w3_in [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t     j_in,
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     y0_out [0:15],
  output ntt46_mrec_arith_pkg::mrec_res_t     y1_out [0:15],
  output ntt46_mrec_arith_pkg::mrec_res_t     y2_out [0:15],
  output ntt46_mrec_arith_pkg::mrec_res_t     y3_out [0:15]
);

  logic lane0_valid;
  (* keep = "true" *) logic in_valid_grp [0:1];

  assign in_valid_grp[0] = in_valid;
  assign in_valid_grp[1] = in_valid;

  generate
    for (genvar lane = 0; lane < 16; lane++) begin : g_lane
      if (lane == 0) begin : g_lane0
        ntt46_zest_radix24_bidir_bfly_lane_pipe #(
          .J_USE_DSP(J_USE_DSP)
        ) u_lane (
          .clk(clk),
          .rst(rst),
          .in_valid(in_valid_grp[lane >> 3]),
          .radix2_mode(radix2_mode),
          .inverse(inverse),
          .x0_in(x0_in[lane]),
          .x1_in(x1_in[lane]),
          .x2_in(x2_in[lane]),
          .x3_in(x3_in[lane]),
          .w1_in(w1_in[lane]),
          .w2_in(w2_in[lane]),
          .w3_in(w3_in[lane]),
          .j_in(j_in),
          .out_valid(lane0_valid),
          .y0_out(y0_out[lane]),
          .y1_out(y1_out[lane]),
          .y2_out(y2_out[lane]),
          .y3_out(y3_out[lane])
        );
      end else begin : g_lane_n
        ntt46_zest_radix24_bidir_bfly_lane_pipe #(
          .J_USE_DSP(J_USE_DSP)
        ) u_lane (
          .clk(clk),
          .rst(rst),
          .in_valid(in_valid_grp[lane >> 3]),
          .radix2_mode(radix2_mode),
          .inverse(inverse),
          .x0_in(x0_in[lane]),
          .x1_in(x1_in[lane]),
          .x2_in(x2_in[lane]),
          .x3_in(x3_in[lane]),
          .w1_in(w1_in[lane]),
          .w2_in(w2_in[lane]),
          .w3_in(w3_in[lane]),
          .j_in(j_in),
          .out_valid(),
          .y0_out(y0_out[lane]),
          .y1_out(y1_out[lane]),
          .y2_out(y2_out[lane]),
          .y3_out(y3_out[lane])
        );
      end
    end
  endgenerate

  assign out_valid = lane0_valid;

endmodule
