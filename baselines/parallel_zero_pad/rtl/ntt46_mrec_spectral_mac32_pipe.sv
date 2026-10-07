module ntt46_mrec_spectral_mac32_pipe #(
  parameter int unsigned LANES = 32
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                clear_accum,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     h_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     accum_in [0:LANES-1],
  output logic                                out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     accum_out [0:LANES-1]
);

  import ntt46_mrec_arith_pkg::*;

  localparam int unsigned MUL_LAT = 3;

  logic in_valid_q;
  logic clear_accum_q;
  mrec_res_t x_q [0:LANES-1];
  mrec_res_t h_q [0:LANES-1];
  mrec_res_t accum_q [0:LANES-1];
  logic valid_pipe_q [0:MUL_LAT-1];
  mrec_res_t prod [0:LANES-1];
  mrec_res_t accum_pipe_q [0:MUL_LAT-1][0:LANES-1];
  logic clear_pipe_q [0:MUL_LAT-1];

  generate
    for (genvar lane = 0; lane < LANES; lane++) begin : g_mul
      ntt46_mrec_modmul_pipe u_mul (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid_q),
        .a_in(x_q[lane]),
        .b_in(h_q[lane]),
        .out_valid(),
        .p_out(prod[lane])
      );

      assign accum_out[lane] = clear_pipe_q[MUL_LAT-1]
                             ? prod[lane]
                             : mod_add(accum_pipe_q[MUL_LAT-1][lane], prod[lane]);
    end
  endgenerate

  assign out_valid = valid_pipe_q[MUL_LAT-1];

  always_ff @(posedge clk) begin
    if (rst) begin
      in_valid_q <= 1'b0;
      clear_accum_q <= 1'b0;
      for (int idx = 0; idx < LANES; idx++) begin
        x_q[idx] <= '0;
        h_q[idx] <= '0;
        accum_q[idx] <= '0;
      end
      for (int stage = 0; stage < MUL_LAT; stage++) begin
        valid_pipe_q[stage] <= 1'b0;
        clear_pipe_q[stage] <= 1'b0;
        for (int idx = 0; idx < LANES; idx++) begin
          accum_pipe_q[stage][idx] <= '0;
        end
      end
    end else begin
      in_valid_q <= in_valid;
      clear_accum_q <= clear_accum;
      for (int idx = 0; idx < LANES; idx++) begin
        x_q[idx] <= x_in[idx];
        h_q[idx] <= h_in[idx];
        accum_q[idx] <= accum_in[idx];
      end
      valid_pipe_q[0] <= in_valid_q;
      clear_pipe_q[0] <= clear_accum_q;
      for (int idx = 0; idx < LANES; idx++) begin
        accum_pipe_q[0][idx] <= accum_q[idx];
      end
      for (int stage = 1; stage < MUL_LAT; stage++) begin
        valid_pipe_q[stage] <= valid_pipe_q[stage-1];
        clear_pipe_q[stage] <= clear_pipe_q[stage-1];
        for (int idx = 0; idx < LANES; idx++) begin
          accum_pipe_q[stage][idx] <= accum_pipe_q[stage-1][idx];
        end
      end
    end
  end

endmodule
