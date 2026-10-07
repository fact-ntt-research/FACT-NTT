module ntt46_direct_spatial_parpipe_baseline #(
  parameter int unsigned NX = 512,
  parameter int unsigned PAR = 16,
  parameter int unsigned DATA_W = 18,
  parameter int unsigned ACC_W = 32,
  parameter int unsigned CIN_MAX = 2,
  parameter bit DEBUG = 1'b0
) (
  input  logic                                  clk,
  input  logic                                  rst,

  input  logic                                  load_en,
  input  logic                                  load_is_h,
  input  logic [(CIN_MAX <= 2 ? 1 : $clog2(CIN_MAX))-1:0] load_ch,
  input  logic [$clog2(NX)-1:0]                 load_idx,
  input  logic signed [DATA_W-1:0]              load_data,

  input  logic                                  start,
  input  logic [2:0]                            cfg_cin,
  input  logic [$clog2(NX+1)-1:0]               cfg_nh,

  output logic                                  busy,
  output logic                                  done,
  output logic [31:0]                           compute_cycles,
  output logic                                  out_valid,
  output logic [$clog2(2*NX)-1:0]               out_idx,
  output logic signed [ACC_W-1:0]               out_data
);

  localparam int unsigned N = 2 * NX;
  localparam int unsigned CHUNKS = (NX + PAR - 1) / PAR;
  localparam int unsigned OUT_W = $clog2(N);
  localparam int unsigned IX_W = $clog2(NX + 1);
  localparam int unsigned CHUNK_W = $clog2(CHUNKS + 1);

  typedef enum logic [0:0] {
    S_IDLE,
    S_RUN
  } state_t;

  state_t state_q;
  logic [OUT_W-1:0] out_idx_q;
  logic [CHUNK_W-1:0] chunk_q;
  logic [2:0] cin_q;
  logic [IX_W-1:0] nh_q;

  logic rd_valid_q;
  logic [PAR-1:0] rd_lane_valid_q;
  logic signed [DATA_W-1:0] x_rd_q [0:3][0:PAR-1];
  logic signed [DATA_W-1:0] h_rd_q [0:3][0:PAR-1];

  logic mul_valid_q;
  logic [PAR-1:0] mul_lane_valid_q;
  logic signed [(2*DATA_W)-1:0] prod_q [0:3][0:PAR-1];

  logic sum_valid_q;
  logic signed [ACC_W-1:0] lane_sum_q;
  logic signed [ACC_W-1:0] lane_sum_c;
  logic signed [ACC_W-1:0] acc_q;

  logic issue_valid_c [0:PAR-1];
  logic [$clog2(NX)-1:0] issue_i_addr_c [0:PAR-1];
  logic [$clog2(NX)-1:0] issue_j_addr_c [0:PAR-1];

  assign busy = (state_q != S_IDLE);

  always_comb begin
    for (int lane = 0; lane < PAR; lane++) begin
      int i_idx;
      int j_idx;
      issue_valid_c[lane] = 1'b0;
      issue_i_addr_c[lane] = '0;
      issue_j_addr_c[lane] = '0;
      if (chunk_q < CHUNK_W'(CHUNKS)) begin
        i_idx = int'(chunk_q) * int'(PAR) + lane;
        j_idx = int'(out_idx_q) - i_idx;
        if ((i_idx < int'(NX)) && (j_idx >= 0) && (j_idx < int'(nh_q))) begin
          issue_valid_c[lane] = 1'b1;
          issue_i_addr_c[lane] = i_idx[$clog2(NX)-1:0];
          issue_j_addr_c[lane] = j_idx[$clog2(NX)-1:0];
        end
      end
    end

    lane_sum_c = '0;
    for (int lane = 0; lane < PAR; lane++) begin
      if (mul_lane_valid_q[lane]) begin
        for (int ch = 0; ch < CIN_MAX; ch++) begin
          if (ch < int'(cin_q)) begin
            lane_sum_c += ACC_W'(prod_q[ch][lane]);
          end
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      out_idx_q <= '0;
      chunk_q <= '0;
      cin_q <= 3'd1;
      nh_q <= '0;
      rd_valid_q <= 1'b0;
      rd_lane_valid_q <= '0;
      mul_valid_q <= 1'b0;
      mul_lane_valid_q <= '0;
      sum_valid_q <= 1'b0;
      acc_q <= '0;
      done <= 1'b0;
      compute_cycles <= '0;
      out_valid <= 1'b0;
      out_idx <= '0;
      out_data <= '0;
      for (int ch = 0; ch < CIN_MAX; ch++) begin
        for (int lane = 0; lane < PAR; lane++) begin
          prod_q[ch][lane] <= '0;
        end
      end
      lane_sum_q <= '0;
    end else begin
      done <= 1'b0;
      out_valid <= 1'b0;

      if (state_q == S_RUN) begin
        compute_cycles <= compute_cycles + 32'd1;

        if (DEBUG && (out_idx_q == '0) && (compute_cycles < 32'd24)) begin
          $display("PARPIPE_DBG cyc=%0d chunk=%0d rd=%0b mul=%0b sum=%0b rdv0=%0b mulv0=%0b x0=%0d h0=%0d p0=%0d pair0=%0d lanesum=%0d acc=%0d",
                   compute_cycles, chunk_q, rd_valid_q, mul_valid_q, sum_valid_q,
                   rd_lane_valid_q[0], mul_lane_valid_q[0], x_rd_q[0][0], h_rd_q[0][0], prod_q[0][0],
                   lane_sum_q, lane_sum_c, acc_q);
        end

        mul_valid_q <= rd_valid_q;
        mul_lane_valid_q <= rd_lane_valid_q;
        for (int ch = 0; ch < CIN_MAX; ch++) begin
          for (int lane = 0; lane < PAR; lane++) begin
            prod_q[ch][lane] <= x_rd_q[ch][lane] * h_rd_q[ch][lane];
          end
        end

        sum_valid_q <= mul_valid_q;
        lane_sum_q <= lane_sum_c;

        if (sum_valid_q) begin
          acc_q <= acc_q + lane_sum_q;
        end

        if (chunk_q < CHUNK_W'(CHUNKS)) begin
          rd_valid_q <= 1'b1;
          for (int lane = 0; lane < PAR; lane++) begin
            rd_lane_valid_q[lane] <= issue_valid_c[lane];
          end
          chunk_q <= chunk_q + {{(CHUNK_W-1){1'b0}}, 1'b1};
        end else begin
          rd_valid_q <= 1'b0;
          rd_lane_valid_q <= '0;
        end

        if ((chunk_q == CHUNK_W'(CHUNKS)) && !rd_valid_q && !mul_valid_q && !sum_valid_q) begin
          out_valid <= 1'b1;
          out_idx <= out_idx_q;
          out_data <= acc_q;
          acc_q <= '0;
          chunk_q <= '0;
          if (out_idx_q == OUT_W'(N - 1)) begin
            state_q <= S_IDLE;
            done <= 1'b1;
          end else begin
            out_idx_q <= out_idx_q + {{(OUT_W-1){1'b0}}, 1'b1};
          end
        end
      end

      if ((state_q == S_IDLE) && start) begin
        state_q <= S_RUN;
        out_idx_q <= '0;
        chunk_q <= '0;
        cin_q <= cfg_cin;
        nh_q <= cfg_nh;
        rd_valid_q <= 1'b0;
        rd_lane_valid_q <= '0;
        mul_valid_q <= 1'b0;
        mul_lane_valid_q <= '0;
        sum_valid_q <= 1'b0;
        acc_q <= '0;
        compute_cycles <= '0;
      end
    end
  end

  for (genvar lane_g = 0; lane_g < PAR; lane_g++) begin : g_lane_mem
    (* ram_style = "block" *) logic signed [DATA_W-1:0] x0_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] x1_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] x2_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] x3_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] h0_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] h1_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] h2_mem [0:NX-1];
    (* ram_style = "block" *) logic signed [DATA_W-1:0] h3_mem [0:NX-1];

    always_ff @(posedge clk) begin
      if (rst) begin
        for (int ch = 0; ch < CIN_MAX; ch++) begin
          x_rd_q[ch][lane_g] <= '0;
          h_rd_q[ch][lane_g] <= '0;
        end
      end else begin
        if ((state_q == S_IDLE) && load_en) begin
          if (load_is_h) begin
            unique case (load_ch)
              0: h0_mem[load_idx] <= load_data;
              1: h1_mem[load_idx] <= load_data;
              2: h2_mem[load_idx] <= load_data;
              default: h3_mem[load_idx] <= load_data;
            endcase
          end else begin
            unique case (load_ch)
              0: x0_mem[load_idx] <= load_data;
              1: x1_mem[load_idx] <= load_data;
              2: x2_mem[load_idx] <= load_data;
              default: x3_mem[load_idx] <= load_data;
            endcase
          end
        end

        if (state_q == S_RUN) begin
          if (issue_valid_c[lane_g]) begin
            x_rd_q[0][lane_g] <= x0_mem[issue_i_addr_c[lane_g]];
            h_rd_q[0][lane_g] <= h0_mem[issue_j_addr_c[lane_g]];
            x_rd_q[1][lane_g] <= x1_mem[issue_i_addr_c[lane_g]];
            h_rd_q[1][lane_g] <= h1_mem[issue_j_addr_c[lane_g]];
            if (CIN_MAX > 2) begin
              x_rd_q[2][lane_g] <= x2_mem[issue_i_addr_c[lane_g]];
              h_rd_q[2][lane_g] <= h2_mem[issue_j_addr_c[lane_g]];
              x_rd_q[3][lane_g] <= x3_mem[issue_i_addr_c[lane_g]];
              h_rd_q[3][lane_g] <= h3_mem[issue_j_addr_c[lane_g]];
            end
          end else begin
            for (int ch = 0; ch < CIN_MAX; ch++) begin
              x_rd_q[ch][lane_g] <= '0;
              h_rd_q[ch][lane_g] <= '0;
            end
          end
        end
      end
    end
  end

endmodule
