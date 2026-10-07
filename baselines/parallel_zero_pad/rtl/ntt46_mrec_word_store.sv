module ntt46_mrec_word_store #(
  parameter int WORDS = 8,
  parameter bit USE_VALID = 1'b1
) (
  input  logic                                               clk,
  input  logic                                               rst,
  input  logic                                               clear,
  input  logic                                               wr_en,
  input  logic [$clog2(WORDS)-1:0]                           wr_word_idx,
  input  logic [(32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] wr_word_data,
  input  logic [$clog2(WORDS)-1:0]                           rd_word_idx,
  output logic [(32*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] rd_word_data
);

  import ntt46_mrec_params_pkg::*;

  localparam int WORD_W = 32 * MREC_DATA_W;

  (* ram_style = "distributed" *) logic [MREC_DATA_W-1:0] mem_q [0:MREC_LANES-1][0:WORDS-1];
  generate
    if (USE_VALID) begin : g_valid
      logic [WORDS-1:0] valid_q;

      always_comb begin
        rd_word_data = '0;
        if (valid_q[rd_word_idx]) begin
          for (int lane = 0; lane < MREC_LANES; lane++) begin
            rd_word_data[(lane * MREC_DATA_W) +: MREC_DATA_W] = mem_q[lane][rd_word_idx];
          end
        end
      end

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          valid_q <= '0;
        end else if (wr_en) begin
          valid_q[wr_word_idx] <= 1'b1;
          for (int lane = 0; lane < MREC_LANES; lane++) begin
            mem_q[lane][wr_word_idx] <= wr_word_data[(lane * MREC_DATA_W) +: MREC_DATA_W];
          end
        end
      end
    end else begin : g_no_valid
      always_comb begin
        for (int lane = 0; lane < MREC_LANES; lane++) begin
          rd_word_data[(lane * MREC_DATA_W) +: MREC_DATA_W] = mem_q[lane][rd_word_idx];
        end
      end

      always_ff @(posedge clk) begin
        if (wr_en) begin
          for (int lane = 0; lane < MREC_LANES; lane++) begin
            mem_q[lane][wr_word_idx] <= wr_word_data[(lane * MREC_DATA_W) +: MREC_DATA_W];
          end
        end
      end
    end
  endgenerate

endmodule
