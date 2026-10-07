module ntt46_mrec_radix4_forward_core_n1024 #(
  parameter string TWIDDLE_FWD_MEM =
    "./rom/mrec_schedule/mrec_compact_radix4_twiddle_fwd_1024.mem"
) (
  input  logic                                 clk,
  input  logic                                 rst,
  input  logic                                 start,
  input  logic                                 batch_slot_load_en,
  input  logic [2:0]                           batch_slot_load_idx,
  input  logic [1:0]                           batch_slot_load_slot,
  input  logic [(32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] batch_slot_load_data,
  input  logic                                 batch_load_en,
  input  logic [2:0]                           batch_load_idx,
  input  logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] batch_load_data,
  output logic                                 final_batch_valid,
  output logic [2:0]                           final_batch_idx,
  output logic [(4*32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] final_batch_data,
  output logic                                 busy,
  output logic                                 done
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  localparam int WORD_W = 4 * MREC_DATA_W;
  localparam int TAG_DEPTH = 64;
  localparam int TAG_AW = 6;
  localparam int BATCHES = 8;
  localparam int LAST_STAGE = 4;

  logic busy_q;
  logic done_q;
  logic read_store1_q;
  logic write_store1_q;
  logic [2:0] stage_q;
  logic [3:0] batch_issue_q;
  logic [3:0] out_count_q;
  logic [1:0] gap_q;
  logic read_issue_c;
  logic final_stage_c;
  logic [1:0] issue_gap_c;

  logic read_valid_q;
  logic [2:0] read_stage_q;
  logic [2:0] read_batch_q;
  logic       read_final_q;
  logic [5:0] step_twiddle_addr;
  logic step_in_valid;
  logic step_out_valid;
  mrec_res_t step_x0 [0:31];
  mrec_res_t step_x1 [0:31];
  mrec_res_t step_x2 [0:31];
  mrec_res_t step_x3 [0:31];
  mrec_res_t step_y0 [0:31];
  mrec_res_t step_y1 [0:31];
  mrec_res_t step_y2 [0:31];
  mrec_res_t step_y3 [0:31];

  logic [6:0] tag_q [0:TAG_DEPTH-1];
  logic [TAG_AW-1:0] tag_wr_ptr_q;
  logic [TAG_AW-1:0] tag_rd_ptr_q;
  logic [2:0] out_stage_c;
  logic [2:0] out_batch_c;
  logic       out_final_c;

  logic writer_start;
  logic writer_done;
  logic [3:0] writer_wr_en [0:31];
  logic [2:0] writer_wr_addr [0:31];
  mrec_res_t writer_wr_data [0:31][0:3];

  logic [3:0] store0_wr_en [0:31];
  logic [2:0] store0_wr_addr [0:31];
  mrec_res_t store0_wr_data [0:31][0:3];
  logic store0_rd_en;
  logic [2:0] store0_rd_addr [0:31];
  logic [WORD_W-1:0] store0_rd_word [0:31];

  logic [3:0] store1_wr_en [0:31];
  logic [2:0] store1_wr_addr [0:31];
  mrec_res_t store1_wr_data [0:31][0:3];
  logic store1_rd_en;
  logic [2:0] store1_rd_addr [0:31];
  logic [WORD_W-1:0] store1_rd_word [0:31];

  logic final_wr_en;
  logic [2:0] final_wr_addr;
  mrec_res_t final_wr_data_words [0:31][0:3];

  assign busy = busy_q;
  assign done = done_q;
  assign final_stage_c = (stage_q == LAST_STAGE[2:0]);
  assign read_issue_c = busy_q && (batch_issue_q < BATCHES[3:0]) && (gap_q == 2'd0);
  assign step_in_valid = read_valid_q;
  assign step_twiddle_addr = (read_stage_q * 6'd8) + {3'd0, read_batch_q};
  assign {out_final_c, out_batch_c, out_stage_c} = tag_q[tag_rd_ptr_q];
  assign writer_start = step_out_valid && !out_final_c;
  assign final_wr_en = step_out_valid && out_final_c;
  assign final_wr_addr = out_batch_c;

  function automatic logic [1:0] phase_last_for_stage(input logic [2:0] stage);
    begin
      unique case (stage)
        3'd0: phase_last_for_stage = 2'd3;
        3'd1: phase_last_for_stage = 2'd1;
        default: phase_last_for_stage = 2'd0;
      endcase
    end
  endfunction

  always_comb begin
    issue_gap_c = final_stage_c ? 2'd0 : phase_last_for_stage(stage_q);
  end

  ntt46_mrec_radix4_slot32_store_sameaddr #(
    .DEPTH(8)
  ) u_store0 (
    .clk(clk),
    .wr_en(store0_wr_en),
    .wr_addr(store0_wr_addr),
    .wr_data(store0_wr_data),
    .rd_en(store0_rd_en),
    .rd_addr(store0_rd_addr),
    .rd_word(store0_rd_word)
  );

  ntt46_mrec_radix4_slot32_store_sameaddr #(
    .DEPTH(8)
  ) u_store1 (
    .clk(clk),
    .wr_en(store1_wr_en),
    .wr_addr(store1_wr_addr),
    .wr_data(store1_wr_data),
    .rd_en(store1_rd_en),
    .rd_addr(store1_rd_addr),
    .rd_word(store1_rd_word)
  );

  ntt46_mrec_radix4_step32_n1024 #(
    .TWIDDLE_FWD_MEM(TWIDDLE_FWD_MEM)
  ) u_step (
    .clk(clk),
    .rst(rst),
    .in_valid(step_in_valid),
    .stage0_active_mask(4'b1111),
    .twiddle_addr(step_twiddle_addr),
    .x0_in(step_x0),
    .x1_in(step_x1),
    .x2_in(step_x2),
    .x3_in(step_x3),
    .out_valid(step_out_valid),
    .y0_out(step_y0),
    .y1_out(step_y1),
    .y2_out(step_y2),
    .y3_out(step_y3)
  );

  ntt46_mrec_radix4_transpose_writer32_n1024 u_writer (
    .clk(clk),
    .rst(rst),
    .start(writer_start),
    .stage_idx(out_stage_c),
    .batch_idx(out_batch_c),
    .y0_in(step_y0),
    .y1_in(step_y1),
    .y2_in(step_y2),
    .y3_in(step_y3),
    .busy(),
    .done(writer_done),
    .wr_en(writer_wr_en),
    .wr_addr(writer_wr_addr),
    .wr_data(writer_wr_data)
  );

  always_comb begin
    for (int lane = 0; lane < 32; lane++) begin
      logic [WORD_W-1:0] sel_word;
      sel_word = read_store1_q ? store1_rd_word[lane] : store0_rd_word[lane];
      step_x0[lane] = sel_word[0 +: MREC_DATA_W];
      step_x1[lane] = sel_word[MREC_DATA_W +: MREC_DATA_W];
      step_x2[lane] = sel_word[(2 * MREC_DATA_W) +: MREC_DATA_W];
      step_x3[lane] = sel_word[(3 * MREC_DATA_W) +: MREC_DATA_W];
      final_wr_data_words[lane][0] = step_y0[lane];
      final_wr_data_words[lane][1] = step_y1[lane];
      final_wr_data_words[lane][2] = step_y2[lane];
      final_wr_data_words[lane][3] = step_y3[lane];
    end
  end

  always_comb begin
    store0_rd_en = 1'b0;
    store1_rd_en = 1'b0;
    for (int bank = 0; bank < 32; bank++) begin
      store0_wr_en[bank] = '0;
      store1_wr_en[bank] = '0;
      store0_wr_addr[bank] = '0;
      store1_wr_addr[bank] = '0;
      store0_rd_addr[bank] = '0;
      store1_rd_addr[bank] = '0;
      for (int slot = 0; slot < 4; slot++) begin
        store0_wr_data[bank][slot] = '0;
        store1_wr_data[bank][slot] = '0;
      end
    end

    if (read_issue_c) begin
      if (!read_store1_q) begin
        store0_rd_en = 1'b1;
        for (int bank = 0; bank < 32; bank++) begin
          store0_rd_addr[bank] = batch_issue_q[2:0];
        end
      end else begin
        store1_rd_en = 1'b1;
        for (int bank = 0; bank < 32; bank++) begin
          store1_rd_addr[bank] = batch_issue_q[2:0];
        end
      end
    end

    if (!busy_q && batch_slot_load_en) begin
      for (int bank = 0; bank < 32; bank++) begin
        store0_wr_en[bank][batch_slot_load_slot] = 1'b1;
        store0_wr_addr[bank] = batch_slot_load_idx;
        store0_wr_data[bank][batch_slot_load_slot] = batch_slot_load_data[(bank * MREC_DATA_W) +: MREC_DATA_W];
      end
    end

    if (!busy_q && batch_load_en) begin
      for (int bank = 0; bank < 32; bank++) begin
        store0_wr_en[bank] = 4'b1111;
        store0_wr_addr[bank] = batch_load_idx;
        for (int slot = 0; slot < 4; slot++) begin
          store0_wr_data[bank][slot] = batch_load_data[((slot * 32 + bank) * MREC_DATA_W) +: MREC_DATA_W];
        end
      end
    end

    if (busy_q && !final_stage_c) begin
      if (!write_store1_q) begin
        for (int bank = 0; bank < 32; bank++) begin
          store0_wr_en[bank] = writer_wr_en[bank];
          store0_wr_addr[bank] = writer_wr_addr[bank];
          for (int slot = 0; slot < 4; slot++) begin
            store0_wr_data[bank][slot] = writer_wr_data[bank][slot];
          end
        end
      end else begin
        for (int bank = 0; bank < 32; bank++) begin
          store1_wr_en[bank] = writer_wr_en[bank];
          store1_wr_addr[bank] = writer_wr_addr[bank];
          for (int slot = 0; slot < 4; slot++) begin
            store1_wr_data[bank][slot] = writer_wr_data[bank][slot];
          end
        end
      end
    end

    if (busy_q && final_wr_en) begin
      if (!write_store1_q) begin
        for (int bank = 0; bank < 32; bank++) begin
          store0_wr_en[bank] = 4'b1111;
          store0_wr_addr[bank] = final_wr_addr;
          for (int slot = 0; slot < 4; slot++) begin
            store0_wr_data[bank][slot] = final_wr_data_words[bank][slot];
          end
        end
      end else begin
        for (int bank = 0; bank < 32; bank++) begin
          store1_wr_en[bank] = 4'b1111;
          store1_wr_addr[bank] = final_wr_addr;
          for (int slot = 0; slot < 4; slot++) begin
            store1_wr_data[bank][slot] = final_wr_data_words[bank][slot];
          end
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      busy_q <= 1'b0;
      done_q <= 1'b0;
      final_batch_valid <= 1'b0;
      final_batch_idx <= '0;
      final_batch_data <= '0;
      read_store1_q <= 1'b0;
      write_store1_q <= 1'b1;
      stage_q <= '0;
      batch_issue_q <= '0;
      out_count_q <= '0;
      gap_q <= '0;
      read_valid_q <= 1'b0;
      read_stage_q <= '0;
      read_batch_q <= '0;
      read_final_q <= 1'b0;
      tag_wr_ptr_q <= '0;
      tag_rd_ptr_q <= '0;
      for (int idx = 0; idx < TAG_DEPTH; idx++) begin
        tag_q[idx] <= '0;
      end
    end else begin
      done_q <= 1'b0;
      final_batch_valid <= final_wr_en;
      if (final_wr_en) begin
        final_batch_idx <= final_wr_addr;
        for (int lane = 0; lane < 32; lane++) begin
          for (int slot = 0; slot < 4; slot++) begin
            final_batch_data[((slot * 32 + lane) * MREC_DATA_W) +: MREC_DATA_W] <= final_wr_data_words[lane][slot];
          end
        end
      end

      read_valid_q <= read_issue_c;
      if (read_issue_c) begin
        read_stage_q <= stage_q;
        read_batch_q <= batch_issue_q[2:0];
        read_final_q <= final_stage_c;
        batch_issue_q <= batch_issue_q + 4'd1;
        gap_q <= issue_gap_c;
      end else if (busy_q && (gap_q != 2'd0)) begin
        gap_q <= gap_q - 2'd1;
      end

      if (step_in_valid) begin
        tag_q[tag_wr_ptr_q] <= {read_final_q, read_batch_q, read_stage_q};
        tag_wr_ptr_q <= tag_wr_ptr_q + {{(TAG_AW-1){1'b0}}, 1'b1};
      end

      if (step_out_valid) begin
        tag_rd_ptr_q <= tag_rd_ptr_q + {{(TAG_AW-1){1'b0}}, 1'b1};
      end

      if (writer_done || final_wr_en) begin
        out_count_q <= out_count_q + 4'd1;
        if ((out_count_q + 4'd1) == BATCHES[3:0]) begin
          if (final_stage_c) begin
            busy_q <= 1'b0;
            done_q <= 1'b1;
          end else begin
            stage_q <= stage_q + 3'd1;
            read_store1_q <= !read_store1_q;
            write_store1_q <= !write_store1_q;
            batch_issue_q <= '0;
            out_count_q <= '0;
            gap_q <= '0;
            tag_wr_ptr_q <= '0;
            tag_rd_ptr_q <= '0;
          end
        end
      end

      if (start && !busy_q) begin
        busy_q <= 1'b1;
        done_q <= 1'b0;
        final_batch_valid <= 1'b0;
        read_store1_q <= 1'b0;
        write_store1_q <= 1'b1;
        stage_q <= 3'd0;
        batch_issue_q <= '0;
        out_count_q <= '0;
        gap_q <= '0;
        read_valid_q <= 1'b0;
        tag_wr_ptr_q <= '0;
        tag_rd_ptr_q <= '0;
      end
    end
  end

endmodule
