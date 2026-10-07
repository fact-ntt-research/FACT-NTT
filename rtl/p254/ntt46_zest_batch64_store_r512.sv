module ntt46_zest_batch64_store_r512 #(
  parameter string RAM_STYLE = "block"
) (
  input  logic                                      clk,
  input  logic                                      full_wr_en,
  input  logic [2:0]                                full_wr_idx,
  input  logic [(64*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] full_wr_data,
  input  logic                                      stream_wr_en,
  input  logic [3:0]                                stream_wr_batch,
  input  ntt46_mrec_arith_pkg::mrec_res_t           stream_y0 [0:15],
  input  ntt46_mrec_arith_pkg::mrec_res_t           stream_y1 [0:15],
  input  logic                                      rd_en,
  input  logic [2:0]                                rd_idx,
  output logic [(64*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] rd_data
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  localparam int BANKS = 16;
  localparam int WORD_W = 4 * MREC_DATA_W;

  logic [3:0] wr_en_c [0:BANKS-1];
  logic [2:0] wr_addr_c [0:BANKS-1];
  mrec_res_t  wr_data_c [0:BANKS-1][0:3];
  logic [2:0] rd_addr_c [0:BANKS-1];
  logic [WORD_W-1:0] rd_word [0:BANKS-1];

  ntt46_zest_slot16_store_sameaddr #(
    .DEPTH(8),
    .ADDR_W(3),
    .RAM_STYLE(RAM_STYLE)
  ) u_store (
    .clk(clk),
    .wr_en(wr_en_c),
    .wr_addr(wr_addr_c),
    .wr_data(wr_data_c),
    .rd_en(rd_en),
    .rd_addr(rd_addr_c),
    .rd_word(rd_word)
  );

  always_comb begin
    for (int bank = 0; bank < BANKS; bank++) begin
      wr_en_c[bank] = '0;
      wr_addr_c[bank] = full_wr_idx;
      rd_addr_c[bank] = rd_idx;
      for (int slot = 0; slot < 4; slot++) begin
        int elem;
        elem = bank * 4 + slot;
        wr_data_c[bank][slot] = full_wr_data[(elem * MREC_DATA_W) +: MREC_DATA_W];
        rd_data[(elem * MREC_DATA_W) +: MREC_DATA_W] =
          rd_word[bank][(slot * MREC_DATA_W) +: MREC_DATA_W];
      end
    end

    if (full_wr_en) begin
      for (int bank = 0; bank < BANKS; bank++) begin
        wr_en_c[bank] = 4'b1111;
        wr_addr_c[bank] = full_wr_idx;
      end
    end else if (stream_wr_en) begin
      int base_pos;
      int pos0;
      int pos1;
      int bank0;
      int bank1;
      int slot0;
      int slot1;
      base_pos = stream_wr_batch[0] ? 16 : 0;
      for (int lane = 0; lane < 16; lane++) begin
        pos0 = base_pos + lane;
        pos1 = 32 + base_pos + lane;
        bank0 = pos0 >> 2;
        bank1 = pos1 >> 2;
        slot0 = pos0 & 3;
        slot1 = pos1 & 3;
        wr_en_c[bank0][slot0] = 1'b1;
        wr_en_c[bank1][slot1] = 1'b1;
        wr_addr_c[bank0] = stream_wr_batch[3:1];
        wr_addr_c[bank1] = stream_wr_batch[3:1];
        wr_data_c[bank0][slot0] = stream_y0[lane];
        wr_data_c[bank1][slot1] = stream_y1[lane];
      end
    end
  end

endmodule
