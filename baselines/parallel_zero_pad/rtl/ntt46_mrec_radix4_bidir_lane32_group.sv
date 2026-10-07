module ntt46_mrec_radix4_bidir_lane32_group #(
  parameter bit USE_STAGE0_MASK = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                inverse,
  input  logic [3:0]                          stage0_active_mask,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x0_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x1_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x2_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x3_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     w1_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     w2_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     w3_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     j_in,
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     y0_out [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t     y1_out [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t     y2_out [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t     y3_out [0:31]
);

  logic lane0_valid;
  (* keep = "true" *) logic in_valid_grp [0:3];

  generate
    for (genvar grp = 0; grp < 4; grp++) begin : g_valid_grp
      assign in_valid_grp[grp] = in_valid;
    end
  endgenerate

  generate
    for (genvar lane = 0; lane < 32; lane++) begin : g_lane
      if (lane == 0) begin : g_lane0
        ntt46_mrec_radix4_bidir_bfly_lane_pipe #(
          .USE_STAGE0_MASK(USE_STAGE0_MASK)
        ) u_lane (
          .clk(clk),
          .rst(rst),
          .in_valid(in_valid_grp[lane >> 3]),
          .inverse(inverse),
          .stage0_active_mask(stage0_active_mask),
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
      ntt46_mrec_radix4_bidir_bfly_lane_pipe #(
        .USE_STAGE0_MASK(USE_STAGE0_MASK)
      ) u_lane (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid_grp[lane >> 3]),
        .inverse(inverse),
        .stage0_active_mask(stage0_active_mask),
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
