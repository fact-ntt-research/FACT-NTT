module ntt46_p520_ntt46_fact_forward_pair_to_product32_stream_r512 #(
  parameter int unsigned LANES = 16,
  parameter bit RESET_DATA_ARRAYS = 1'b1,
  parameter bit USE_PACKED_FIFO = 1'b0,
  parameter bit INPUT_PIPELINE = 1'b0,
  parameter bit ZERO_INVALID_OUTPUTS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                clear,
  input  logic                                x_valid,
  input  logic                                x_radix2,
  input  logic [3:0]                          x_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y3 [0:LANES-1],
  input  logic                                h_valid,
  input  logic                                h_radix2,
  input  logic [3:0]                          h_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y3 [0:LANES-1],
  input  logic                                in_odd,
  input  logic                                in_clear_accum,
  output logic                                out_valid,
  output logic                                out_odd,
  output logic                                out_clear_accum,
  output logic [5:0]                          out_batch0,
  output logic [5:0]                          out_batch1,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_x_data0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_x_data1 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_h_data0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_h_data1 [0:LANES-1],
  output logic                                batch_mismatch,
  output logic                                radix2_seen,
  output logic [4:0]                          x_queued,
  output logic [4:0]                          h_queued
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;

  logic x_stream_valid;
  logic h_stream_valid;
  logic [5:0] x_stream_batch0;
  logic [5:0] x_stream_batch1;
  logic [5:0] h_stream_batch0;
  logic [5:0] h_stream_batch1;
  mrec_res_t x_stream_data0 [0:LANES-1];
  mrec_res_t x_stream_data1 [0:LANES-1];
  mrec_res_t h_stream_data0 [0:LANES-1];
  mrec_res_t h_stream_data1 [0:LANES-1];
  logic x_empty;
  logic h_empty;

  generate
    if (USE_PACKED_FIFO) begin : g_packed_fifo
      ntt46_p520_ntt46_fact_forward64_to_product32_stream_packed_fifo_r512 #(
        .LANES(LANES),
        .INPUT_PIPELINE(INPUT_PIPELINE),
        .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS),
        .ZERO_INVALID_OUTPUTS(ZERO_INVALID_OUTPUTS)
      ) u_x_stream (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .in_valid(x_valid),
        .in_radix2(x_radix2),
        .in_batch(x_batch),
        .in_y0(x_y0),
        .in_y1(x_y1),
        .in_y2(x_y2),
        .in_y3(x_y3),
        .out_valid(x_stream_valid),
        .out_batch0(x_stream_batch0),
        .out_batch1(x_stream_batch1),
        .out_data0(x_stream_data0),
        .out_data1(x_stream_data1),
        .empty(x_empty),
        .queued(x_queued)
      );

      ntt46_p520_ntt46_fact_forward64_to_product32_stream_packed_fifo_r512 #(
        .LANES(LANES),
        .INPUT_PIPELINE(INPUT_PIPELINE),
        .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS),
        .ZERO_INVALID_OUTPUTS(ZERO_INVALID_OUTPUTS)
      ) u_h_stream (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .in_valid(h_valid),
        .in_radix2(h_radix2),
        .in_batch(h_batch),
        .in_y0(h_y0),
        .in_y1(h_y1),
        .in_y2(h_y2),
        .in_y3(h_y3),
        .out_valid(h_stream_valid),
        .out_batch0(h_stream_batch0),
        .out_batch1(h_stream_batch1),
        .out_data0(h_stream_data0),
        .out_data1(h_stream_data1),
        .empty(h_empty),
        .queued(h_queued)
      );
    end else begin : g_reg_fifo
      ntt46_p520_ntt46_fact_forward64_to_product32_stream_r512 #(
        .LANES(LANES),
        .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS),
        .ZERO_INVALID_OUTPUTS(ZERO_INVALID_OUTPUTS)
      ) u_x_stream (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .in_valid(x_valid),
        .in_radix2(x_radix2),
        .in_batch(x_batch),
        .in_y0(x_y0),
        .in_y1(x_y1),
        .in_y2(x_y2),
        .in_y3(x_y3),
        .out_valid(x_stream_valid),
        .out_batch0(x_stream_batch0),
        .out_batch1(x_stream_batch1),
        .out_data0(x_stream_data0),
        .out_data1(x_stream_data1),
        .empty(x_empty),
        .queued(x_queued)
      );

      ntt46_p520_ntt46_fact_forward64_to_product32_stream_r512 #(
        .LANES(LANES),
        .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS),
        .ZERO_INVALID_OUTPUTS(ZERO_INVALID_OUTPUTS)
      ) u_h_stream (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .in_valid(h_valid),
        .in_radix2(h_radix2),
        .in_batch(h_batch),
        .in_y0(h_y0),
        .in_y1(h_y1),
        .in_y2(h_y2),
        .in_y3(h_y3),
        .out_valid(h_stream_valid),
        .out_batch0(h_stream_batch0),
        .out_batch1(h_stream_batch1),
        .out_data0(h_stream_data0),
        .out_data1(h_stream_data1),
        .empty(h_empty),
        .queued(h_queued)
      );
    end
  endgenerate

  assign out_valid = x_stream_valid && h_stream_valid &&
                     (x_stream_batch0 == h_stream_batch0) &&
                     (x_stream_batch1 == h_stream_batch1);

  generate
    if (USE_PACKED_FIFO && INPUT_PIPELINE) begin : g_meta_input_pipe
      localparam int unsigned META_DEPTH = 16;

      logic in_valid_q;
      logic in_radix2_q;
      logic in_odd_q;
      logic in_clear_accum_q;
      logic eff_valid;
      logic eff_radix2;
      logic eff_odd;
      logic eff_clear_accum;
      logic accept_c;
      logic pop_entry_c;
      logic [3:0] wr_ptr_q;
      logic [3:0] rd_ptr_q;
      logic [4:0] count_q;
      logic phase_q;
      logic rd_valid_q;
      logic rd_odd_q;
      logic rd_clear_accum_q;
      logic meta_odd_q [0:META_DEPTH-1];
      logic meta_clear_accum_q [0:META_DEPTH-1];

      assign eff_valid = in_valid_q;
      assign eff_radix2 = in_radix2_q;
      assign eff_odd = in_odd_q;
      assign eff_clear_accum = in_clear_accum_q;
      assign accept_c = eff_valid && !eff_radix2;
      assign pop_entry_c = (count_q != 5'd0) && phase_q;

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          in_valid_q <= 1'b0;
          in_radix2_q <= 1'b0;
          in_odd_q <= 1'b0;
          in_clear_accum_q <= 1'b0;
        end else begin
          in_valid_q <= x_valid;
          in_radix2_q <= x_radix2;
          in_odd_q <= in_odd;
          in_clear_accum_q <= in_clear_accum;
        end
      end

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          wr_ptr_q <= '0;
          rd_ptr_q <= '0;
          count_q <= '0;
          phase_q <= 1'b0;
          rd_valid_q <= 1'b0;
          rd_odd_q <= 1'b0;
          rd_clear_accum_q <= 1'b0;
          out_odd <= 1'b0;
          out_clear_accum <= 1'b0;
          for (int idx = 0; idx < META_DEPTH; idx++) begin
            meta_odd_q[idx] <= 1'b0;
            meta_clear_accum_q[idx] <= 1'b0;
          end
        end else begin
          out_odd <= rd_valid_q ? rd_odd_q : 1'b0;
          out_clear_accum <= rd_valid_q ? rd_clear_accum_q : 1'b0;

          rd_valid_q <= (count_q != 5'd0) || ((count_q == 5'd0) && accept_c);
          if (count_q != 5'd0) begin
            rd_odd_q <= meta_odd_q[rd_ptr_q];
            rd_clear_accum_q <= meta_clear_accum_q[rd_ptr_q];
          end else if (accept_c) begin
            rd_odd_q <= eff_odd;
            rd_clear_accum_q <= eff_clear_accum;
          end

          if (accept_c) begin
            meta_odd_q[wr_ptr_q] <= eff_odd;
            meta_clear_accum_q[wr_ptr_q] <= eff_clear_accum;
            wr_ptr_q <= wr_ptr_q + 4'd1;
          end

          if (count_q != 5'd0) begin
            phase_q <= ~phase_q;
          end else if (accept_c) begin
            phase_q <= 1'b1;
          end else begin
            phase_q <= 1'b0;
          end
          if (pop_entry_c) begin
            rd_ptr_q <= rd_ptr_q + 4'd1;
          end
          count_q <= count_q + (accept_c ? 5'd1 : 5'd0) - (pop_entry_c ? 5'd1 : 5'd0);
        end
      end
    end else begin : g_meta_direct
      assign out_odd = in_odd;
      assign out_clear_accum = in_clear_accum;
    end
  endgenerate

  assign out_batch0 = x_stream_batch0;
  assign out_batch1 = x_stream_batch1;
  assign batch_mismatch = (x_valid && h_valid && (x_batch != h_batch)) ||
                          (x_stream_valid && h_stream_valid &&
                           ((x_stream_batch0 != h_stream_batch0) ||
                            (x_stream_batch1 != h_stream_batch1)));
  assign radix2_seen = (x_valid && x_radix2) || (h_valid && h_radix2);

  for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
    assign out_x_data0[lane] = x_stream_data0[lane];
    assign out_x_data1[lane] = x_stream_data1[lane];
    assign out_h_data0[lane] = h_stream_data0[lane];
    assign out_h_data1[lane] = h_stream_data1[lane];
  end

endmodule

