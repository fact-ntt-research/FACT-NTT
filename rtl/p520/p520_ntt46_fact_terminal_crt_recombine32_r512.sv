module ntt46_p520_ntt46_fact_terminal_crt_recombine32_r512 #(
  parameter int unsigned LANES = 16,
  parameter int unsigned BATCH_W = 4,
  parameter bit INPUT_PIPELINE = 1'b1,
  parameter bit RESET_DATA_ARRAYS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                clear,
  input  logic                                in_valid,
  input  logic [BATCH_W-1:0]                  in_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     plus_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     plus_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     minus_untwisted_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     minus_untwisted_y1 [0:LANES-1],
  output logic                                out_valid,
  output logic [BATCH_W-1:0]                  out_batch,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     low_y0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     high_y0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     low_y1 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     high_y1 [0:LANES-1]
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;

  generate
    if (INPUT_PIPELINE) begin : g_input_pipe
      mrec_res_t plus_y0_q [0:LANES-1];
      mrec_res_t plus_y1_q [0:LANES-1];
      mrec_res_t minus_y0_q [0:LANES-1];
      mrec_res_t minus_y1_q [0:LANES-1];
      logic valid_q;
      logic [BATCH_W-1:0] batch_q;

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          valid_q <= 1'b0;
          batch_q <= '0;
          out_valid <= 1'b0;
          out_batch <= '0;
          if (RESET_DATA_ARRAYS) begin
            for (int lane = 0; lane < LANES; lane++) begin
              plus_y0_q[lane] <= '0;
              plus_y1_q[lane] <= '0;
              minus_y0_q[lane] <= '0;
              minus_y1_q[lane] <= '0;
              low_y0[lane] <= '0;
              high_y0[lane] <= '0;
              low_y1[lane] <= '0;
              high_y1[lane] <= '0;
            end
          end
        end else begin
          valid_q <= in_valid;
          batch_q <= in_batch;
          for (int lane = 0; lane < LANES; lane++) begin
            plus_y0_q[lane] <= plus_y0[lane];
            plus_y1_q[lane] <= plus_y1[lane];
            minus_y0_q[lane] <= minus_untwisted_y0[lane];
            minus_y1_q[lane] <= minus_untwisted_y1[lane];
          end

          out_valid <= valid_q;
          out_batch <= batch_q;
          if (valid_q) begin
            for (int lane = 0; lane < LANES; lane++) begin
              low_y0[lane] <= mod_half(mod_add(plus_y0_q[lane], minus_y0_q[lane]));
              high_y0[lane] <= mod_half(mod_sub(plus_y0_q[lane], minus_y0_q[lane]));
              low_y1[lane] <= mod_half(mod_add(plus_y1_q[lane], minus_y1_q[lane]));
              high_y1[lane] <= mod_half(mod_sub(plus_y1_q[lane], minus_y1_q[lane]));
            end
          end
        end
      end
    end else begin : g_direct_input
      always_ff @(posedge clk) begin
        if (rst || clear) begin
          out_valid <= 1'b0;
          out_batch <= '0;
          if (RESET_DATA_ARRAYS) begin
            for (int lane = 0; lane < LANES; lane++) begin
              low_y0[lane] <= '0;
              high_y0[lane] <= '0;
              low_y1[lane] <= '0;
              high_y1[lane] <= '0;
            end
          end
        end else begin
          out_valid <= in_valid;
          out_batch <= in_batch;
          if (in_valid) begin
            for (int lane = 0; lane < LANES; lane++) begin
              low_y0[lane] <= mod_half(mod_add(plus_y0[lane], minus_untwisted_y0[lane]));
              high_y0[lane] <= mod_half(mod_sub(plus_y0[lane], minus_untwisted_y0[lane]));
              low_y1[lane] <= mod_half(mod_add(plus_y1[lane], minus_untwisted_y1[lane]));
              high_y1[lane] <= mod_half(mod_sub(plus_y1[lane], minus_untwisted_y1[lane]));
            end
          end
        end
      end
    end
  endgenerate

endmodule

