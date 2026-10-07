module ntt46_p520_ntt46_fact_forward64_to_product32_stream_r512 #(
  parameter int unsigned LANES = 16,
  parameter bit RESET_DATA_ARRAYS = 1'b1,
  parameter bit ZERO_INVALID_OUTPUTS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                clear,
  input  logic                                in_valid,
  input  logic                                in_radix2,
  input  logic [3:0]                          in_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y3 [0:LANES-1],
  output logic                                out_valid,
  output logic [5:0]                          out_batch0,
  output logic [5:0]                          out_batch1,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_data0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_data1 [0:LANES-1],
  output logic                                empty,
  output logic [4:0]                          queued
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;

  localparam int unsigned DEPTH = 16;

  mrec_res_t data0_q [0:DEPTH-1][0:LANES-1];
  mrec_res_t data1_q [0:DEPTH-1][0:LANES-1];
  logic [5:0] batch0_q [0:DEPTH-1];
  logic [5:0] batch1_q [0:DEPTH-1];
  logic [3:0] wr_ptr_q;
  logic [3:0] rd_ptr_q;
  logic [4:0] count_q;

  logic accept_c;
  logic pop_fifo_c;
  logic pop_input_c;
  logic [1:0] push_count_c;

  assign accept_c = in_valid && !in_radix2;
  assign pop_fifo_c = (count_q != 5'd0);
  assign pop_input_c = (count_q == 5'd0) && accept_c;
  assign push_count_c = accept_c ? (pop_input_c ? 2'd1 : 2'd2) : 2'd0;
  assign empty = (count_q == 5'd0) && !accept_c;
  assign queued = count_q;

  function automatic mrec_res_t pick_input(input int unsigned sub, input int unsigned lane);
    int unsigned elem;
    int unsigned src_lane;
    int unsigned src_slot;
    begin
      elem = (sub * LANES) + lane;
      src_lane = elem >> 2;
      src_slot = elem & 3;
      unique case (src_slot)
        0: pick_input = in_y0[src_lane];
        1: pick_input = in_y1[src_lane];
        2: pick_input = in_y2[src_lane];
        default: pick_input = in_y3[src_lane];
      endcase
    end
  endfunction

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q <= '0;
      out_valid <= 1'b0;
      out_batch0 <= '0;
      out_batch1 <= '0;
      if (RESET_DATA_ARRAYS) begin
        for (int idx = 0; idx < DEPTH; idx++) begin
          batch0_q[idx] <= '0;
          batch1_q[idx] <= '0;
          for (int lane = 0; lane < LANES; lane++) begin
            data0_q[idx][lane] <= '0;
            data1_q[idx][lane] <= '0;
          end
        end
      end
      for (int lane = 0; lane < LANES; lane++) begin
        out_data0[lane] <= '0;
        out_data1[lane] <= '0;
      end
    end else begin
      out_valid <= pop_fifo_c || pop_input_c;
      if (pop_fifo_c) begin
        out_batch0 <= batch0_q[rd_ptr_q];
        out_batch1 <= batch1_q[rd_ptr_q];
        for (int lane = 0; lane < LANES; lane++) begin
          out_data0[lane] <= data0_q[rd_ptr_q][lane];
          out_data1[lane] <= data1_q[rd_ptr_q][lane];
        end
      end else if (pop_input_c) begin
        out_batch0 <= {in_batch, 2'b00};
        out_batch1 <= {in_batch, 2'b00} + 6'd1;
        for (int lane = 0; lane < LANES; lane++) begin
          out_data0[lane] <= pick_input(0, lane);
          out_data1[lane] <= pick_input(1, lane);
        end
      end else if (ZERO_INVALID_OUTPUTS) begin
        out_batch0 <= '0;
        out_batch1 <= '0;
        for (int lane = 0; lane < LANES; lane++) begin
          out_data0[lane] <= '0;
          out_data1[lane] <= '0;
        end
      end

      if (accept_c) begin
        if (pop_input_c) begin
          batch0_q[wr_ptr_q] <= {in_batch, 2'b00} + 6'd2;
          batch1_q[wr_ptr_q] <= {in_batch, 2'b00} + 6'd3;
          for (int lane = 0; lane < LANES; lane++) begin
            data0_q[wr_ptr_q][lane] <= pick_input(2, lane);
            data1_q[wr_ptr_q][lane] <= pick_input(3, lane);
          end
        end else begin
          batch0_q[wr_ptr_q] <= {in_batch, 2'b00};
          batch1_q[wr_ptr_q] <= {in_batch, 2'b00} + 6'd1;
          batch0_q[wr_ptr_q + 4'd1] <= {in_batch, 2'b00} + 6'd2;
          batch1_q[wr_ptr_q + 4'd1] <= {in_batch, 2'b00} + 6'd3;
          for (int lane = 0; lane < LANES; lane++) begin
            data0_q[wr_ptr_q][lane] <= pick_input(0, lane);
            data1_q[wr_ptr_q][lane] <= pick_input(1, lane);
            data0_q[wr_ptr_q + 4'd1][lane] <= pick_input(2, lane);
            data1_q[wr_ptr_q + 4'd1][lane] <= pick_input(3, lane);
          end
        end
      end

      wr_ptr_q <= wr_ptr_q + {2'b00, push_count_c};
      if (pop_fifo_c) begin
        rd_ptr_q <= rd_ptr_q + 4'd1;
      end
      count_q <= count_q + {3'b000, push_count_c} - (pop_fifo_c ? 5'd1 : 5'd0);
    end
  end

endmodule

module ntt46_p520_ntt46_fact_forward64_to_product32_stream_packed_fifo_r512 #(
  parameter int unsigned LANES = 16,
  parameter bit INPUT_PIPELINE = 1'b0,
  parameter bit RESET_DATA_ARRAYS = 1'b1,
  parameter bit ZERO_INVALID_OUTPUTS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                clear,
  input  logic                                in_valid,
  input  logic                                in_radix2,
  input  logic [3:0]                          in_batch,
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y0 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y1 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y2 [0:LANES-1],
  input  ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     in_y3 [0:LANES-1],
  output logic                                out_valid,
  output logic [5:0]                          out_batch0,
  output logic [5:0]                          out_batch1,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_data0 [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t     out_data1 [0:LANES-1],
  output logic                                empty,
  output logic [4:0]                          queued
);

  import ntt46_p520_ntt46_mrec_arith_pkg::*;

  localparam int unsigned DEPTH = 16;
  localparam int unsigned RES_W = $bits(mrec_res_t);
  localparam int unsigned WORD_W = 4 * LANES * RES_W;

  typedef logic [WORD_W-1:0] word_t;

  (* ram_style = "distributed" *) word_t data_q [0:DEPTH-1];
  (* ram_style = "distributed" *) logic [3:0] batch_q [0:DEPTH-1];

  logic [3:0] wr_ptr_q;
  logic [3:0] rd_ptr_q;
  logic [4:0] count_q;
  logic phase_q;
  logic accept_c;
  logic pop_entry_c;
  logic [5:0] queued_w_c;
  word_t rd_word_c;
  logic [3:0] rd_batch_c;
  logic rd_valid_q;
  word_t rd_word_q;
  logic [3:0] rd_batch_q;
  logic rd_phase_q;
  word_t in_word_c;
  logic eff_valid;
  logic eff_radix2;
  logic [3:0] eff_batch;
  mrec_res_t eff_y0 [0:LANES-1];
  mrec_res_t eff_y1 [0:LANES-1];
  mrec_res_t eff_y2 [0:LANES-1];
  mrec_res_t eff_y3 [0:LANES-1];

  generate
    if (INPUT_PIPELINE) begin : g_input_pipe
      logic in_valid_q;
      logic in_radix2_q;
      logic [3:0] in_batch_q;
      mrec_res_t in_y0_q [0:LANES-1];
      mrec_res_t in_y1_q [0:LANES-1];
      mrec_res_t in_y2_q [0:LANES-1];
      mrec_res_t in_y3_q [0:LANES-1];

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          in_valid_q <= 1'b0;
          in_radix2_q <= 1'b0;
          in_batch_q <= '0;
          if (RESET_DATA_ARRAYS) begin
            for (int lane = 0; lane < LANES; lane++) begin
              in_y0_q[lane] <= '0;
              in_y1_q[lane] <= '0;
              in_y2_q[lane] <= '0;
              in_y3_q[lane] <= '0;
            end
          end
        end else begin
          in_valid_q <= in_valid;
          in_radix2_q <= in_radix2;
          in_batch_q <= in_batch;
          for (int lane = 0; lane < LANES; lane++) begin
            in_y0_q[lane] <= in_y0[lane];
            in_y1_q[lane] <= in_y1[lane];
            in_y2_q[lane] <= in_y2[lane];
            in_y3_q[lane] <= in_y3[lane];
          end
        end
      end

      assign eff_valid = in_valid_q;
      assign eff_radix2 = in_radix2_q;
      assign eff_batch = in_batch_q;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_eff_lane
        assign eff_y0[lane] = in_y0_q[lane];
        assign eff_y1[lane] = in_y1_q[lane];
        assign eff_y2[lane] = in_y2_q[lane];
        assign eff_y3[lane] = in_y3_q[lane];
      end
    end else begin : g_input_direct
      assign eff_valid = in_valid;
      assign eff_radix2 = in_radix2;
      assign eff_batch = in_batch;
      for (genvar lane = 0; lane < LANES; lane++) begin : g_eff_lane
        assign eff_y0[lane] = in_y0[lane];
        assign eff_y1[lane] = in_y1[lane];
        assign eff_y2[lane] = in_y2[lane];
        assign eff_y3[lane] = in_y3[lane];
      end
    end
  endgenerate

  assign accept_c = eff_valid && !eff_radix2;
  assign pop_entry_c = (count_q != 5'd0) && phase_q;
  assign empty = (count_q == 5'd0) && !rd_valid_q && !out_valid;
  assign queued_w_c = (((count_q == 5'd0) ? 6'd0 :
                        (({1'b0, count_q} << 1) - (phase_q ? 6'd1 : 6'd0))) +
                       (rd_valid_q ? 6'd1 : 6'd0) +
                       (out_valid ? 6'd1 : 6'd0));
  assign queued = queued_w_c[4:0];
  assign rd_word_c = data_q[rd_ptr_q];
  assign rd_batch_c = batch_q[rd_ptr_q];

  generate
    for (genvar elem = 0; elem < (4 * LANES); elem++) begin : g_pack_input
      localparam int unsigned SRC_LANE = elem >> 2;
      localparam int unsigned SRC_SLOT = elem & 3;
      if (SRC_SLOT == 0) begin : g_y0
        assign in_word_c[(elem * RES_W) +: RES_W] = eff_y0[SRC_LANE];
      end else if (SRC_SLOT == 1) begin : g_y1
        assign in_word_c[(elem * RES_W) +: RES_W] = eff_y1[SRC_LANE];
      end else if (SRC_SLOT == 2) begin : g_y2
        assign in_word_c[(elem * RES_W) +: RES_W] = eff_y2[SRC_LANE];
      end else begin : g_y3
        assign in_word_c[(elem * RES_W) +: RES_W] = eff_y3[SRC_LANE];
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q <= '0;
      phase_q <= 1'b0;
      rd_valid_q <= 1'b0;
      out_valid <= 1'b0;
      if (RESET_DATA_ARRAYS) begin
        rd_word_q <= '0;
        rd_batch_q <= '0;
        rd_phase_q <= 1'b0;
        out_batch0 <= '0;
        out_batch1 <= '0;
        for (int lane = 0; lane < LANES; lane++) begin
          out_data0[lane] <= '0;
          out_data1[lane] <= '0;
        end
      end
    end else begin
      out_valid <= rd_valid_q;
      if (rd_valid_q) begin
        out_batch0 <= {rd_batch_q, 2'b00} + (rd_phase_q ? 6'd2 : 6'd0);
        out_batch1 <= {rd_batch_q, 2'b00} + (rd_phase_q ? 6'd3 : 6'd1);
        if (rd_phase_q) begin
          for (int lane = 0; lane < LANES; lane++) begin
            out_data0[lane] <= mrec_res_t'(rd_word_q[((2 * LANES + lane) * RES_W) +: RES_W]);
            out_data1[lane] <= mrec_res_t'(rd_word_q[((3 * LANES + lane) * RES_W) +: RES_W]);
          end
        end else begin
          for (int lane = 0; lane < LANES; lane++) begin
            out_data0[lane] <= mrec_res_t'(rd_word_q[((0 * LANES + lane) * RES_W) +: RES_W]);
            out_data1[lane] <= mrec_res_t'(rd_word_q[((1 * LANES + lane) * RES_W) +: RES_W]);
          end
        end
      end else if (ZERO_INVALID_OUTPUTS) begin
        out_batch0 <= '0;
        out_batch1 <= '0;
        for (int lane = 0; lane < LANES; lane++) begin
          out_data0[lane] <= '0;
          out_data1[lane] <= '0;
        end
      end

      rd_valid_q <= (count_q != 5'd0) || ((count_q == 5'd0) && accept_c);
      if (count_q != 5'd0) begin
        rd_word_q <= rd_word_c;
        rd_batch_q <= rd_batch_c;
        rd_phase_q <= phase_q;
      end else if (accept_c) begin
        rd_batch_q <= eff_batch;
        rd_phase_q <= 1'b0;
        rd_word_q <= in_word_c;
      end

      if (accept_c) begin
        batch_q[wr_ptr_q] <= eff_batch;
        data_q[wr_ptr_q] <= in_word_c;
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

endmodule

