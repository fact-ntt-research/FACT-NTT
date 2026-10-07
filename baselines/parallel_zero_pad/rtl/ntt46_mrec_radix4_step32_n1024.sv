module ntt46_mrec_radix4_step32_n1024 #(
  parameter string TWIDDLE_FWD_MEM =
    "./rom/mrec_schedule/mrec_compact_radix4_twiddle_fwd_1024.mem"
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic [3:0]                          stage0_active_mask,
  input  logic [5:0]                          twiddle_addr,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x0_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x1_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x2_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x3_in [0:31],
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     y0_out [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t     y1_out [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t     y2_out [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t     y3_out [0:31]
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  logic       valid_q;
  logic [3:0] stage0_active_mask_q;
  mrec_res_t  x0_q [0:31];
  mrec_res_t  x1_q [0:31];
  mrec_res_t  x2_q [0:31];
  mrec_res_t  x3_q [0:31];

  mrec_res_t fwd_w1 [0:31];
  mrec_res_t fwd_w2 [0:31];
  mrec_res_t fwd_w3 [0:31];

  ntt46_mrec_radix4_twiddle32_rom #(
    .DEPTH(40),
    .MEM_FILE(TWIDDLE_FWD_MEM)
  ) u_tw_fwd1024 (
    .clk(clk),
    .rd_en(in_valid),
    .rd_addr(twiddle_addr),
    .w1_out(fwd_w1),
    .w2_out(fwd_w2),
    .w3_out(fwd_w3)
  );

  ntt46_mrec_radix4_lane32_group #(
    .USE_STAGE0_MASK(1'b1)
  ) u_lane_group (
    .clk(clk),
    .rst(rst),
    .in_valid(valid_q),
    .stage0_active_mask(stage0_active_mask_q),
    .x0_in(x0_q),
    .x1_in(x1_q),
    .x2_in(x2_q),
    .x3_in(x3_q),
    .w1_in(fwd_w1),
    .w2_in(fwd_w2),
    .w3_in(fwd_w3),
    .j_in(mrec_res_t'(MREC_J)),
    .out_valid(out_valid),
    .y0_out(y0_out),
    .y1_out(y1_out),
    .y2_out(y2_out),
    .y3_out(y3_out)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      valid_q <= 1'b0;
      stage0_active_mask_q <= 4'b1111;
      for (int lane = 0; lane < 32; lane++) begin
        x0_q[lane] <= '0;
        x1_q[lane] <= '0;
        x2_q[lane] <= '0;
        x3_q[lane] <= '0;
      end
    end else begin
      valid_q <= in_valid;
      if (in_valid) begin
        stage0_active_mask_q <= stage0_active_mask;
        for (int lane = 0; lane < 32; lane++) begin
          x0_q[lane] <= x0_in[lane];
          x1_q[lane] <= x1_in[lane];
          x2_q[lane] <= x2_in[lane];
          x3_q[lane] <= x3_in[lane];
        end
      end
    end
  end

endmodule
