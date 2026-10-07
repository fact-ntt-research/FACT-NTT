module ntt46_fact_forward_pair_to_product64_stream_bram_r512 #(
  parameter int unsigned LANES = 16,
  parameter int unsigned BURSTS = 8,
  parameter string RAM_STYLE = "block"
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                clear,
  input  logic                                drain_enable,
  input  logic                                x_valid,
  input  logic                                x_radix2,
  input  logic [3:0]                          x_batch,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x_y0 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x_y1 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x_y2 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x_y3 [0:LANES-1],
  input  logic                                h_valid,
  input  logic                                h_radix2,
  input  logic [3:0]                          h_batch,
  input  ntt46_mrec_arith_pkg::mrec_res_t     h_y0 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     h_y1 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     h_y2 [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     h_y3 [0:LANES-1],
  input  logic                                in_odd,
  input  logic                                in_clear_accum,
  output logic                                out_valid,
  output logic                                out_odd,
  output logic                                out_clear_accum,
  output logic [5:0]                          out_burst,
  output ntt46_mrec_arith_pkg::mrec_res_t     out_x_y0 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_x_y1 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_x_y2 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_x_y3 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_h_y0 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_h_y1 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_h_y2 [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     out_h_y3 [0:LANES-1],
  output logic                                batch_mismatch,
  output logic                                radix2_seen,
  output logic [5:0]                          queued
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  localparam int unsigned BURST_W = (BURSTS <= 1) ? 1 : $clog2(BURSTS);
  localparam int unsigned FULL_ELEMS = 4 * LANES;
  localparam int unsigned FULL_W = FULL_ELEMS * MREC_DATA_W;

  logic aligned_c;
  logic [BURSTS-1:0] ready_q;
  logic [BURST_W-1:0] rd_burst_q;
  logic [BURST_W-1:0] pending_burst_q;
  logic pending_odd_q;
  logic pending_clear_q;
  logic rd_pending_q;
  logic rd_fire_c;

  logic [FULL_W-1:0] x_wr_data;
  logic [FULL_W-1:0] h_wr_data;
  logic [FULL_W-1:0] x_rd_data_q;
  logic [FULL_W-1:0] h_rd_data_q;
  logic [5:0] queued_c;

  (* ram_style = RAM_STYLE *) logic [FULL_W-1:0] x_mem [0:BURSTS-1];
  (* ram_style = RAM_STYLE *) logic [FULL_W-1:0] h_mem [0:BURSTS-1];

  assign aligned_c = x_valid && h_valid && !x_radix2 && !h_radix2 && (x_batch == h_batch);
  assign batch_mismatch = x_valid && h_valid && (x_batch != h_batch);
  assign radix2_seen = (x_valid && x_radix2) || (h_valid && h_radix2);
  assign rd_fire_c = drain_enable && ready_q[rd_burst_q] && !rd_pending_q;
  always_comb begin
    queued_c = rd_pending_q ? 6'd1 : 6'd0;
    for (int idx = 0; idx < BURSTS; idx++) begin
      queued_c = queued_c + (ready_q[idx] ? 6'd1 : 6'd0);
    end
  end
  assign queued = queued_c;

  function automatic mrec_res_t pick_full_word(
    input logic [FULL_W-1:0] word,
    input int unsigned elem
  );
    begin
      pick_full_word = word[(elem * MREC_DATA_W) +: MREC_DATA_W];
    end
  endfunction

  always_comb begin
    for (int lane = 0; lane < LANES; lane++) begin
      int elem0;
      int elem1;
      int elem2;
      int elem3;
      elem0 = lane * 4;
      elem1 = elem0 + 1;
      elem2 = elem0 + 2;
      elem3 = elem0 + 3;
      x_wr_data[(elem0 * MREC_DATA_W) +: MREC_DATA_W] = x_y0[lane];
      x_wr_data[(elem1 * MREC_DATA_W) +: MREC_DATA_W] = x_y1[lane];
      x_wr_data[(elem2 * MREC_DATA_W) +: MREC_DATA_W] = x_y2[lane];
      x_wr_data[(elem3 * MREC_DATA_W) +: MREC_DATA_W] = x_y3[lane];
      h_wr_data[(elem0 * MREC_DATA_W) +: MREC_DATA_W] = h_y0[lane];
      h_wr_data[(elem1 * MREC_DATA_W) +: MREC_DATA_W] = h_y1[lane];
      h_wr_data[(elem2 * MREC_DATA_W) +: MREC_DATA_W] = h_y2[lane];
      h_wr_data[(elem3 * MREC_DATA_W) +: MREC_DATA_W] = h_y3[lane];
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      ready_q <= '0;
      rd_burst_q <= '0;
      pending_burst_q <= '0;
      pending_odd_q <= 1'b0;
      pending_clear_q <= 1'b0;
      rd_pending_q <= 1'b0;
      out_valid <= 1'b0;
      out_odd <= 1'b0;
      out_clear_accum <= 1'b0;
      out_burst <= '0;
      for (int lane = 0; lane < LANES; lane++) begin
        out_x_y0[lane] <= '0;
        out_x_y1[lane] <= '0;
        out_x_y2[lane] <= '0;
        out_x_y3[lane] <= '0;
        out_h_y0[lane] <= '0;
        out_h_y1[lane] <= '0;
        out_h_y2[lane] <= '0;
        out_h_y3[lane] <= '0;
      end
    end else begin
      out_valid <= 1'b0;
      out_odd <= 1'b0;
      out_clear_accum <= 1'b0;
      out_burst <= '0;
      for (int lane = 0; lane < LANES; lane++) begin
        out_x_y0[lane] <= '0;
        out_x_y1[lane] <= '0;
        out_x_y2[lane] <= '0;
        out_x_y3[lane] <= '0;
        out_h_y0[lane] <= '0;
        out_h_y1[lane] <= '0;
        out_h_y2[lane] <= '0;
        out_h_y3[lane] <= '0;
      end

      if (aligned_c) begin
        x_mem[x_batch[BURST_W-1:0]] <= x_wr_data;
        h_mem[h_batch[BURST_W-1:0]] <= h_wr_data;
        ready_q[x_batch[BURST_W-1:0]] <= 1'b1;
      end

      if (rd_pending_q) begin
        rd_pending_q <= 1'b0;
        out_valid <= 1'b1;
        out_odd <= pending_odd_q;
        out_clear_accum <= pending_clear_q;
        out_burst <= 6'(pending_burst_q);
        for (int lane = 0; lane < LANES; lane++) begin
          int elem0;
          int elem1;
          int elem2;
          int elem3;
          elem0 = lane * 4;
          elem1 = elem0 + 1;
          elem2 = elem0 + 2;
          elem3 = elem0 + 3;
          out_x_y0[lane] <= pick_full_word(x_rd_data_q, elem0);
          out_x_y1[lane] <= pick_full_word(x_rd_data_q, elem1);
          out_x_y2[lane] <= pick_full_word(x_rd_data_q, elem2);
          out_x_y3[lane] <= pick_full_word(x_rd_data_q, elem3);
          out_h_y0[lane] <= pick_full_word(h_rd_data_q, elem0);
          out_h_y1[lane] <= pick_full_word(h_rd_data_q, elem1);
          out_h_y2[lane] <= pick_full_word(h_rd_data_q, elem2);
          out_h_y3[lane] <= pick_full_word(h_rd_data_q, elem3);
        end
      end

      if (rd_fire_c) begin
        rd_pending_q <= 1'b1;
        pending_burst_q <= rd_burst_q;
        pending_odd_q <= in_odd;
        pending_clear_q <= in_clear_accum;
        x_rd_data_q <= x_mem[rd_burst_q];
        h_rd_data_q <= h_mem[rd_burst_q];
        ready_q[rd_burst_q] <= 1'b0;
        rd_burst_q <= (rd_burst_q == BURST_W'(BURSTS - 1)) ? '0 :
                      (rd_burst_q + {{(BURST_W-1){1'b0}}, 1'b1});
      end
    end
  end

endmodule
