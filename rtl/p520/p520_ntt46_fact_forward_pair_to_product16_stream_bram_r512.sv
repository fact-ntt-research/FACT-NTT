module ntt46_p520_ntt46_fact_forward_pair_to_product16_stream_bram_r512 #(
  parameter string RAM_STYLE = "block",
  parameter bit ENABLE_DEBUG_OUTPUTS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                clear,
  input  logic                                x_valid,
  input  logic                                x_radix2,
  input  logic [3:0]                          x_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y0 [0:15],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y1 [0:15],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y2 [0:15],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     x_y3 [0:15],
  input  logic                                h_valid,
  input  logic                                h_radix2,
  input  logic [3:0]                          h_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y0 [0:15],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y1 [0:15],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y2 [0:15],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     h_y3 [0:15],
  input  logic                                in_odd,
  input  logic                                in_clear_accum,
  output logic                                out_valid,
  output logic                                out_odd,
  output logic                                out_clear_accum,
  output logic [4:0]                          out_batch,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_x_data [0:15],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_h_data [0:15],
  output logic                                batch_mismatch,
  output logic                                radix2_seen,
  output logic [5:0]                          x_queued,
  output logic [5:0]                          h_queued
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;
  import ntt46_p520_ntt46_mrec_params_pkg::*;

  localparam int unsigned LANES = 16;
  localparam int unsigned BURSTS = 8;
  localparam int unsigned FULL_W = 64 * MREC_DATA_W;

  logic aligned_c;
  logic [BURSTS-1:0] ready_q;
  logic [2:0] rd_burst_q;
  logic [2:0] pending_burst_q;
  logic [2:0] current_burst_q;
  logic [1:0] sub_q;
  logic rd_pending_q;
  logic have_word_q;
  logic rd_fire_c;

  logic [FULL_W-1:0] x_wr_data;
  logic [FULL_W-1:0] h_wr_data;
  logic [FULL_W-1:0] x_rd_data;
  logic [FULL_W-1:0] h_rd_data;
  logic [FULL_W-1:0] x_word_q;
  logic [FULL_W-1:0] h_word_q;

  assign aligned_c = x_valid && h_valid && !x_radix2 && !h_radix2 && (x_batch == h_batch);
  assign rd_fire_c = (ready_q[rd_burst_q] && !rd_pending_q && (!have_word_q || (sub_q == 2'd3)));

  generate
    if (ENABLE_DEBUG_OUTPUTS) begin : g_debug_outputs
      logic [5:0] queued_c;

      assign batch_mismatch = x_valid && h_valid && (x_batch != h_batch);
      assign radix2_seen = (x_valid && x_radix2) || (h_valid && h_radix2);
      assign queued_c = {2'b00, ready_q[0]} + {2'b00, ready_q[1]} + {2'b00, ready_q[2]} + {2'b00, ready_q[3]} +
                        {2'b00, ready_q[4]} + {2'b00, ready_q[5]} + {2'b00, ready_q[6]} + {2'b00, ready_q[7]} +
                        (rd_pending_q ? 6'd1 : 6'd0) + (have_word_q ? (6'd4 - {4'd0, sub_q}) : 6'd0);
      assign x_queued = queued_c;
      assign h_queued = queued_c;
    end else begin : g_no_debug_outputs
      assign batch_mismatch = 1'b0;
      assign radix2_seen = 1'b0;
      assign x_queued = '0;
      assign h_queued = '0;
    end
  endgenerate

  function automatic mrec_res_t pick_full_word(
    input logic [FULL_W-1:0] word,
    input logic [1:0] sub,
    input int unsigned lane
  );
    int unsigned elem;
    begin
      elem = (int'(sub) * LANES) + lane;
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

  ntt46_p520_ntt46_zest_batch64_store_r512 #(
    .RAM_STYLE(RAM_STYLE)
  ) u_x_store (
    .clk(clk),
    .full_wr_en(aligned_c),
    .full_wr_idx(x_batch[2:0]),
    .full_wr_data(x_wr_data),
    .stream_wr_en(1'b0),
    .stream_wr_batch('0),
    .stream_y0(x_y0),
    .stream_y1(x_y1),
    .rd_en(rd_fire_c),
    .rd_idx(rd_burst_q),
    .rd_data(x_rd_data)
  );

  ntt46_p520_ntt46_zest_batch64_store_r512 #(
    .RAM_STYLE(RAM_STYLE)
  ) u_h_store (
    .clk(clk),
    .full_wr_en(aligned_c),
    .full_wr_idx(h_batch[2:0]),
    .full_wr_data(h_wr_data),
    .stream_wr_en(1'b0),
    .stream_wr_batch('0),
    .stream_y0(h_y0),
    .stream_y1(h_y1),
    .rd_en(rd_fire_c),
    .rd_idx(rd_burst_q),
    .rd_data(h_rd_data)
  );

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      ready_q <= '0;
      rd_burst_q <= '0;
      pending_burst_q <= '0;
      current_burst_q <= '0;
      sub_q <= '0;
      rd_pending_q <= 1'b0;
      have_word_q <= 1'b0;
      x_word_q <= '0;
      h_word_q <= '0;
      out_valid <= 1'b0;
      out_odd <= 1'b0;
      out_clear_accum <= 1'b0;
      out_batch <= '0;
      for (int lane = 0; lane < LANES; lane++) begin
        out_x_data[lane] <= '0;
        out_h_data[lane] <= '0;
      end
    end else begin
      out_valid <= 1'b0;
      out_odd <= 1'b0;
      out_clear_accum <= 1'b0;
      out_batch <= '0;
      for (int lane = 0; lane < LANES; lane++) begin
        out_x_data[lane] <= '0;
        out_h_data[lane] <= '0;
      end

      if (aligned_c) begin
        ready_q[x_batch[2:0]] <= 1'b1;
      end

      if (rd_pending_q) begin
        rd_pending_q <= 1'b0;
        have_word_q <= 1'b1;
        current_burst_q <= pending_burst_q;
        x_word_q <= x_rd_data;
        h_word_q <= h_rd_data;
        sub_q <= 2'd1;
        out_valid <= 1'b1;
        out_odd <= in_odd;
        out_clear_accum <= in_clear_accum;
        out_batch <= {pending_burst_q, 2'b00};
        for (int lane = 0; lane < LANES; lane++) begin
          out_x_data[lane] <= pick_full_word(x_rd_data, 2'd0, lane);
          out_h_data[lane] <= pick_full_word(h_rd_data, 2'd0, lane);
        end
      end else if (have_word_q) begin
        out_valid <= 1'b1;
        out_odd <= in_odd;
        out_clear_accum <= in_clear_accum;
        out_batch <= {current_burst_q, 2'b00} + {3'b000, sub_q};
        for (int lane = 0; lane < LANES; lane++) begin
          out_x_data[lane] <= pick_full_word(x_word_q, sub_q, lane);
          out_h_data[lane] <= pick_full_word(h_word_q, sub_q, lane);
        end
        if (sub_q == 2'd3) begin
          have_word_q <= 1'b0;
          sub_q <= '0;
        end else begin
          sub_q <= sub_q + 2'd1;
        end
      end

      if (rd_fire_c) begin
        rd_pending_q <= 1'b1;
        pending_burst_q <= rd_burst_q;
        ready_q[rd_burst_q] <= 1'b0;
        rd_burst_q <= rd_burst_q + 3'd1;
      end
    end
  end

endmodule

