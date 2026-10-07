module ntt46_mrec_radix4_transpose_writer32_n1024 (
  input  logic                                 clk,
  input  logic                                 rst,
  input  logic                                 start,
  input  logic [2:0]                           stage_idx,
  input  logic [2:0]                           batch_idx,
  input  ntt46_mrec_arith_pkg::mrec_res_t      y0_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t      y1_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t      y2_in [0:31],
  input  ntt46_mrec_arith_pkg::mrec_res_t      y3_in [0:31],
  output logic                                 busy,
  output logic                                 done,
  output logic [3:0]                           wr_en [0:31],
  output logic [2:0]                           wr_addr [0:31],
  output ntt46_mrec_arith_pkg::mrec_res_t      wr_data [0:31][0:3]
);

  import ntt46_mrec_arith_pkg::*;

  logic busy_q;
  logic done_q;
  logic [2:0] stage_q;
  logic [2:0] batch_q;
  logic [3:0] phase_oh_q;
  logic [1:0] last_phase_q;
  mrec_res_t src_q [0:31][0:3];

  assign busy = busy_q;
  assign done = done_q;

  function automatic logic [1:0] phase_last_for_stage(input logic [2:0] stage);
    begin
      unique case (stage)
        3'd0: phase_last_for_stage = 2'd3;
        3'd1: phase_last_for_stage = 2'd1;
        default: phase_last_for_stage = 2'd0;
      endcase
    end
  endfunction

  generate
    for (genvar bank = 0; bank < 32; bank++) begin : g_bank
      localparam int unsigned BANK_I = bank;
      localparam int unsigned BANK_BIT4_I = (bank >> 4) & 1;
      localparam int unsigned S2_SRC_SLOT_I = (bank >> 2) & 3;
      localparam int unsigned S3_SRC_SLOT_I = bank & 3;
      localparam int unsigned S1_SRC_LANE_0_I = ((0 & 1) << 4) | (bank & 15);
      localparam int unsigned S1_SRC_LANE_1_I = ((1 & 1) << 4) | (bank & 15);
      localparam int unsigned S1_SRC_LANE_2_I = ((2 & 1) << 4) | (bank & 15);
      localparam int unsigned S1_SRC_LANE_3_I = ((3 & 1) << 4) | (bank & 15);
      localparam int unsigned S2_SRC_LANE_0_I = ((bank & 16) | (0 << 2) | (bank & 3));
      localparam int unsigned S2_SRC_LANE_1_I = ((bank & 16) | (1 << 2) | (bank & 3));
      localparam int unsigned S2_SRC_LANE_2_I = ((bank & 16) | (2 << 2) | (bank & 3));
      localparam int unsigned S2_SRC_LANE_3_I = ((bank & 16) | (3 << 2) | (bank & 3));
      localparam int unsigned S3_SRC_LANE_0_I = (((bank >> 2) << 2) | 0);
      localparam int unsigned S3_SRC_LANE_1_I = (((bank >> 2) << 2) | 1);
      localparam int unsigned S3_SRC_LANE_2_I = (((bank >> 2) << 2) | 2);
      localparam int unsigned S3_SRC_LANE_3_I = (((bank >> 2) << 2) | 3);

      always_comb begin
        wr_en[BANK_I] = '0;
        wr_addr[BANK_I] = '0;
        for (int slot = 0; slot < 4; slot++) begin
          wr_data[BANK_I][slot] = '0;
        end

        if (busy_q) begin
          unique case (stage_q)
            3'd0: begin
              wr_en[BANK_I] = (4'b0001 << batch_q[2:1]);
              if (phase_oh_q[0]) begin
                wr_addr[BANK_I] = {2'd0, batch_q[0]};
                wr_data[BANK_I][0] = src_q[BANK_I][0];
                wr_data[BANK_I][1] = src_q[BANK_I][0];
                wr_data[BANK_I][2] = src_q[BANK_I][0];
                wr_data[BANK_I][3] = src_q[BANK_I][0];
              end else if (phase_oh_q[1]) begin
                wr_addr[BANK_I] = {2'd1, batch_q[0]};
                wr_data[BANK_I][0] = src_q[BANK_I][1];
                wr_data[BANK_I][1] = src_q[BANK_I][1];
                wr_data[BANK_I][2] = src_q[BANK_I][1];
                wr_data[BANK_I][3] = src_q[BANK_I][1];
              end else if (phase_oh_q[2]) begin
                wr_addr[BANK_I] = {2'd2, batch_q[0]};
                wr_data[BANK_I][0] = src_q[BANK_I][2];
                wr_data[BANK_I][1] = src_q[BANK_I][2];
                wr_data[BANK_I][2] = src_q[BANK_I][2];
                wr_data[BANK_I][3] = src_q[BANK_I][2];
              end else if (phase_oh_q[3]) begin
                wr_addr[BANK_I] = {2'd3, batch_q[0]};
                wr_data[BANK_I][0] = src_q[BANK_I][3];
                wr_data[BANK_I][1] = src_q[BANK_I][3];
                wr_data[BANK_I][2] = src_q[BANK_I][3];
                wr_data[BANK_I][3] = src_q[BANK_I][3];
              end
            end

            3'd1: begin
              wr_en[BANK_I] = batch_q[0] ? 4'b1100 : 4'b0011;
              if (phase_oh_q[0]) begin
                wr_addr[BANK_I] = {batch_q[2:1], 1'b0};
                wr_data[BANK_I][0] = src_q[S1_SRC_LANE_0_I][BANK_BIT4_I];
                wr_data[BANK_I][1] = src_q[S1_SRC_LANE_1_I][BANK_BIT4_I];
                wr_data[BANK_I][2] = src_q[S1_SRC_LANE_2_I][BANK_BIT4_I];
                wr_data[BANK_I][3] = src_q[S1_SRC_LANE_3_I][BANK_BIT4_I];
              end else if (phase_oh_q[1]) begin
                wr_addr[BANK_I] = {batch_q[2:1], 1'b1};
                wr_data[BANK_I][0] = src_q[S1_SRC_LANE_0_I][2 + BANK_BIT4_I];
                wr_data[BANK_I][1] = src_q[S1_SRC_LANE_1_I][2 + BANK_BIT4_I];
                wr_data[BANK_I][2] = src_q[S1_SRC_LANE_2_I][2 + BANK_BIT4_I];
                wr_data[BANK_I][3] = src_q[S1_SRC_LANE_3_I][2 + BANK_BIT4_I];
              end
            end

            3'd2: begin
              wr_en[BANK_I] = 4'b1111;
              wr_addr[BANK_I] = batch_q;
              wr_data[BANK_I][0] = src_q[S2_SRC_LANE_0_I][S2_SRC_SLOT_I];
              wr_data[BANK_I][1] = src_q[S2_SRC_LANE_1_I][S2_SRC_SLOT_I];
              wr_data[BANK_I][2] = src_q[S2_SRC_LANE_2_I][S2_SRC_SLOT_I];
              wr_data[BANK_I][3] = src_q[S2_SRC_LANE_3_I][S2_SRC_SLOT_I];
            end

            default: begin
              wr_en[BANK_I] = 4'b1111;
              wr_addr[BANK_I] = batch_q;
              wr_data[BANK_I][0] = src_q[S3_SRC_LANE_0_I][S3_SRC_SLOT_I];
              wr_data[BANK_I][1] = src_q[S3_SRC_LANE_1_I][S3_SRC_SLOT_I];
              wr_data[BANK_I][2] = src_q[S3_SRC_LANE_2_I][S3_SRC_SLOT_I];
              wr_data[BANK_I][3] = src_q[S3_SRC_LANE_3_I][S3_SRC_SLOT_I];
            end
          endcase
        end
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst) begin
      busy_q <= 1'b0;
      done_q <= 1'b0;
      stage_q <= '0;
      batch_q <= '0;
      phase_oh_q <= 4'b0001;
      last_phase_q <= 2'd0;
      for (int lane = 0; lane < 32; lane++) begin
        for (int slot = 0; slot < 4; slot++) begin
          src_q[lane][slot] <= '0;
        end
      end
    end else begin
      done_q <= busy_q && phase_oh_q[last_phase_q];

      if (busy_q) begin
        if (phase_oh_q[last_phase_q]) begin
          busy_q <= 1'b0;
          phase_oh_q <= 4'b0001;
        end else begin
          phase_oh_q <= {phase_oh_q[2:0], 1'b0};
        end
      end

      if (start) begin
        busy_q <= 1'b1;
        stage_q <= stage_idx;
        batch_q <= batch_idx;
        phase_oh_q <= 4'b0001;
        last_phase_q <= phase_last_for_stage(stage_idx);
        for (int lane = 0; lane < 32; lane++) begin
          src_q[lane][0] <= y0_in[lane];
          src_q[lane][1] <= y1_in[lane];
          src_q[lane][2] <= y2_in[lane];
          src_q[lane][3] <= y3_in[lane];
        end
      end
    end
  end

endmodule
