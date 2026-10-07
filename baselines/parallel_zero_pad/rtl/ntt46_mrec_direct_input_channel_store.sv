module ntt46_mrec_direct_input_channel_store #(
  parameter int WORDS = 8
) (
  input  logic                                               clk,
  input  logic                                               rst,
  input  logic                                               clear,
  input  logic                                               wr_scalar_en,
  input  logic                                               wr_block_idx,
  input  logic [$clog2(WORDS)-1:0]                           wr_word_idx,
  input  logic [4:0]                                         wr_lane_idx,
  input  logic [ntt46_mrec_params_pkg::MREC_DATA_W-1:0]      wr_scalar_data,
  input  logic [$clog2(WORDS)-1:0]                           rd_word_idx,
  output logic [(32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] rd_block0_word,
  output logic [(32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] rd_block1_word
);

  import ntt46_mrec_params_pkg::*;

  localparam int WORD_W = 32 * MREC_DATA_W;
  localparam int AW = $clog2(WORDS);

  (* ram_style = "distributed" *) logic [WORD_W-1:0] mem0_q [0:WORDS-1];
  (* ram_style = "distributed" *) logic [WORD_W-1:0] mem1_q [0:WORDS-1];
  logic [WORDS-1:0] valid0_q;
  logic [WORDS-1:0] valid1_q;

  logic [WORD_W-1:0] assemble_word_q;
  logic assemble_valid_q;
  logic assemble_block_q;
  logic [AW-1:0] assemble_word_idx_q;

  function automatic logic [WORD_W-1:0] merged_word(
    input logic [WORD_W-1:0] base_word,
    input logic [4:0] lane_idx,
    input logic [MREC_DATA_W-1:0] scalar_data
  );
    logic [WORD_W-1:0] tmp;
    begin
      tmp = base_word;
      for (int lane = 0; lane < MREC_LANES; lane++) begin
        if (lane_idx == lane[4:0]) begin
          tmp[(lane * MREC_DATA_W) +: MREC_DATA_W] = scalar_data;
        end
      end
      merged_word = tmp;
    end
  endfunction

  always_comb begin
    rd_block0_word = valid0_q[rd_word_idx] ? mem0_q[rd_word_idx] : '0;
    rd_block1_word = valid1_q[rd_word_idx] ? mem1_q[rd_word_idx] : '0;

    if (assemble_valid_q && (assemble_word_idx_q == rd_word_idx)) begin
      if (!assemble_block_q) begin
        rd_block0_word = assemble_word_q;
      end else begin
        rd_block1_word = assemble_word_q;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      valid0_q <= '0;
      valid1_q <= '0;
      assemble_word_q <= '0;
      assemble_valid_q <= 1'b0;
      assemble_block_q <= 1'b0;
      assemble_word_idx_q <= '0;
    end else if (wr_scalar_en) begin
      logic same_word;
      logic [WORD_W-1:0] next_word;

      same_word = assemble_valid_q &&
                  (assemble_block_q == wr_block_idx) &&
                  (assemble_word_idx_q == wr_word_idx);
      next_word = merged_word(same_word ? assemble_word_q : '0,
                              wr_lane_idx,
                              wr_scalar_data);

      assemble_word_q <= next_word;
      assemble_block_q <= wr_block_idx;
      assemble_word_idx_q <= wr_word_idx;
      assemble_valid_q <= (wr_lane_idx != 5'd31);

      if (wr_lane_idx == 5'd31) begin
        if (wr_block_idx) begin
          mem1_q[wr_word_idx] <= next_word;
          valid1_q[wr_word_idx] <= 1'b1;
        end else begin
          mem0_q[wr_word_idx] <= next_word;
          valid0_q[wr_word_idx] <= 1'b1;
        end
      end
    end
  end

endmodule
