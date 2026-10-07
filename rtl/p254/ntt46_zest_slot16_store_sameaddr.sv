module ntt46_zest_slot16_store_sameaddr #(
  parameter int DEPTH = 4,
  parameter int ADDR_W = $clog2(DEPTH),
  parameter int unsigned LANES = 16,
  parameter string RAM_STYLE = "block",
  parameter bit SPLIT_SLOTS = 1'b0,
  parameter bit USE_XPM = 1'b0
) (
  input  logic                                 clk,
  input  logic [3:0]                           wr_en [0:LANES-1],
  input  logic [ADDR_W-1:0]                    wr_addr [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t      wr_data [0:LANES-1][0:3],
  input  logic                                 rd_en,
  input  logic [ADDR_W-1:0]                    rd_addr [0:LANES-1],
  output logic [(4*ntt46_mrec_params_pkg::MREC_DATA_W)-1:0] rd_word [0:LANES-1]
);

  import ntt46_mrec_params_pkg::*;
  import ntt46_mrec_arith_pkg::*;

  localparam int WORD_W = 4 * MREC_DATA_W;

  generate
    if (USE_XPM && !SPLIT_SLOTS) begin : g_xpm_word_slots
      for (genvar bank = 0; bank < LANES; bank++) begin : g_bank
        logic [WORD_W-1:0] wr_word;
        logic [(WORD_W/9)-1:0] wr_byte_en;

        always_comb begin
          for (int slot = 0; slot < 4; slot++) begin
            wr_word[(slot * MREC_DATA_W) +: MREC_DATA_W] = wr_data[bank][slot];
            wr_byte_en[(slot * 2) +: 2] = {2{wr_en[bank][slot]}};
          end
        end

`ifdef SYNTHESIS
        xpm_memory_sdpram #(
          .MEMORY_SIZE(DEPTH * WORD_W),
          .MEMORY_PRIMITIVE("block"),
          .CLOCKING_MODE("common_clock"),
          .ECC_MODE("no_ecc"),
          .MEMORY_INIT_FILE("none"),
          .MEMORY_INIT_PARAM("0"),
          .USE_MEM_INIT(0),
          .WAKEUP_TIME("disable_sleep"),
          .AUTO_SLEEP_TIME(0),
          .MESSAGE_CONTROL(0),
          .USE_EMBEDDED_CONSTRAINT(0),
          .MEMORY_OPTIMIZATION("true"),
          .CASCADE_HEIGHT(0),
          .WRITE_DATA_WIDTH_A(WORD_W),
          .BYTE_WRITE_WIDTH_A(9),
          .ADDR_WIDTH_A(ADDR_W),
          .RST_MODE_A("SYNC"),
          .READ_DATA_WIDTH_B(WORD_W),
          .ADDR_WIDTH_B(ADDR_W),
          .READ_RESET_VALUE_B("0"),
          .READ_LATENCY_B(1),
          .WRITE_MODE_B("no_change"),
          .RST_MODE_B("SYNC")
        ) u_xpm (
          .sleep(1'b0),
          .clka(clk),
          .ena(|wr_en[bank]),
          .wea(wr_byte_en),
          .addra(wr_addr[bank]),
          .dina(wr_word),
          .injectsbiterra(1'b0),
          .injectdbiterra(1'b0),
          .clkb(clk),
          .rstb(1'b0),
          .enb(rd_en),
          .regceb(1'b1),
          .addrb(rd_addr[bank]),
          .doutb(rd_word[bank]),
          .sbiterrb(),
          .dbiterrb()
        );
`else
        logic [WORD_W-1:0] mem [0:DEPTH-1];
        integer init_idx;

        initial begin
          for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
            mem[init_idx] = '0;
          end
        end

        always_ff @(posedge clk) begin
          if (|wr_en[bank]) begin
            for (int slot = 0; slot < 4; slot++) begin
              if (wr_en[bank][slot]) begin
                mem[wr_addr[bank]][(slot * MREC_DATA_W) +: MREC_DATA_W] <= wr_data[bank][slot];
              end
            end
          end
          if (rd_en) begin
            rd_word[bank] <= mem[rd_addr[bank]];
          end
        end
`endif
      end
    end else if (SPLIT_SLOTS) begin : g_split_slots
      mrec_res_t rd_slot_q [0:LANES-1][0:3];

      always_comb begin
        for (int bank = 0; bank < LANES; bank++) begin
          for (int slot = 0; slot < 4; slot++) begin
            rd_word[bank][(slot * MREC_DATA_W) +: MREC_DATA_W] = rd_slot_q[bank][slot];
          end
        end
      end

      for (genvar bank = 0; bank < LANES; bank++) begin : g_bank
        for (genvar slot = 0; slot < 4; slot++) begin : g_slot
          if (RAM_STYLE == "distributed") begin : g_distributed
            (* ram_style = "distributed" *) mrec_res_t mem [0:DEPTH-1];
            integer init_idx;

            initial begin
              for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
                mem[init_idx] = '0;
              end
            end

            always_ff @(posedge clk) begin
              if (wr_en[bank][slot]) begin
                mem[wr_addr[bank]] <= wr_data[bank][slot];
              end
              if (rd_en) begin
                rd_slot_q[bank][slot] <= mem[rd_addr[bank]];
              end
            end
          end else begin : g_block
            (* ram_style = "block" *) mrec_res_t mem [0:DEPTH-1];
            integer init_idx;

            initial begin
              for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
                mem[init_idx] = '0;
              end
            end

            always_ff @(posedge clk) begin
              if (wr_en[bank][slot]) begin
                mem[wr_addr[bank]] <= wr_data[bank][slot];
              end
              if (rd_en) begin
                rd_slot_q[bank][slot] <= mem[rd_addr[bank]];
              end
            end
          end
        end
      end
    end else begin : g_word_slots
      for (genvar bank = 0; bank < LANES; bank++) begin : g_bank
        if (RAM_STYLE == "distributed") begin : g_distributed
          (* ram_style = "distributed" *) logic [WORD_W-1:0] mem [0:DEPTH-1];
          integer init_idx;

          initial begin
            for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
              mem[init_idx] = '0;
            end
          end

          always_ff @(posedge clk) begin
            if (|wr_en[bank]) begin
              for (int slot = 0; slot < 4; slot++) begin
                if (wr_en[bank][slot]) begin
                  mem[wr_addr[bank]][(slot * MREC_DATA_W) +: MREC_DATA_W] <= wr_data[bank][slot];
                end
              end
            end
            if (rd_en) begin
              rd_word[bank] <= mem[rd_addr[bank]];
            end
          end
        end else begin : g_block
          (* ram_style = "block" *) logic [WORD_W-1:0] mem [0:DEPTH-1];
          integer init_idx;

          initial begin
            for (init_idx = 0; init_idx < DEPTH; init_idx++) begin
              mem[init_idx] = '0;
            end
          end

          always_ff @(posedge clk) begin
            if (|wr_en[bank]) begin
              for (int slot = 0; slot < 4; slot++) begin
                if (wr_en[bank][slot]) begin
                  mem[wr_addr[bank]][(slot * MREC_DATA_W) +: MREC_DATA_W] <= wr_data[bank][slot];
                end
              end
            end
            if (rd_en) begin
              rd_word[bank] <= mem[rd_addr[bank]];
            end
          end
        end
      end
    end
  endgenerate

endmodule
