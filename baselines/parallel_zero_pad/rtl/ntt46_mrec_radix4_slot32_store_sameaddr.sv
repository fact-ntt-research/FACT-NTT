module ntt46_mrec_radix4_slot32_store_sameaddr #(
  parameter int DEPTH = 2,
  parameter int ADDR_W = $clog2(DEPTH)
) (
  input  logic                                 clk,
  input  logic [3:0]                           wr_en [0:31],
  input  logic [ADDR_W-1:0]                    wr_addr [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t      wr_data [0:31][0:3],
  input  logic                                 rd_en,
  input  logic [ADDR_W-1:0]                    rd_addr [0:31],
  output logic [(4*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] rd_word [0:31]
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  localparam int WORD_W = 4 * MREC_DATA_W;

  genvar bank;
  generate
    for (bank = 0; bank < 32; bank++) begin : g_bank
      (* ram_style = "block" *) logic [WORD_W-1:0] mem [0:DEPTH-1];
      integer init_idx;

      initial begin
        for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
          mem[init_idx] = '0;
        end
      end

      always_ff @(posedge clk) begin
        if (|wr_en[bank]) begin
          for (int wr_slot = 0; wr_slot < 4; wr_slot++) begin
            if (wr_en[bank][wr_slot]) begin
              mem[wr_addr[bank]][(wr_slot * MREC_DATA_W) +: MREC_DATA_W] <= wr_data[bank][wr_slot];
            end
          end
        end
        if (rd_en) begin
          rd_word[bank] <= mem[rd_addr[bank]];
        end
      end
    end
  endgenerate

endmodule
