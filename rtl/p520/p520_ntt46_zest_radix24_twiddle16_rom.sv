module ntt46_p520_ntt46_zest_radix24_twiddle16_rom #(
  parameter int DEPTH = 8,
  parameter int ADDR_W = $clog2(DEPTH),
  parameter int unsigned LANES = 16,
  parameter string MEM_FILE = ""
) (
  input  logic                                 clk,
  input  logic                                 rd_en,
  input  logic [ADDR_W-1:0]                    rd_addr,
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t      w1_out [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t      w2_out [0:LANES-1],
  output ntt46_p520_ntt46_mrec_arith_pkg::mrec_res_t      w3_out [0:LANES-1]
);

  import ntt46_p520_ntt46_mrec_params_pkg::*;

  localparam int unsigned TW_PER_LANE = 3;
  localparam int unsigned WORD_W = LANES * TW_PER_LANE * MREC_DATA_W;

  (* rom_style = "block" *) logic [WORD_W-1:0] rom [0:DEPTH-1];
  logic [WORD_W-1:0] rd_word_q;
  integer init_idx;

  initial begin
    for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
      rom[init_idx] = '0;
    end
    if (MEM_FILE != "") begin
      $readmemh(MEM_FILE, rom);
    end
  end

  always_ff @(posedge clk) begin
    if (rd_en) begin
      rd_word_q <= rom[rd_addr];
    end
  end

  generate
    for (genvar lane = 0; lane < LANES; lane++) begin : g_unpack
      localparam int unsigned BASE = lane * TW_PER_LANE * MREC_DATA_W;
      assign w1_out[lane] = rd_word_q[BASE +: MREC_DATA_W];
      assign w2_out[lane] = rd_word_q[BASE + MREC_DATA_W +: MREC_DATA_W];
      assign w3_out[lane] = rd_word_q[BASE + (2 * MREC_DATA_W) +: MREC_DATA_W];
    end
  endgenerate

endmodule

