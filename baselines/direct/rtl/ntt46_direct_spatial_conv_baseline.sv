module ntt46_direct_spatial_conv_baseline #(
  parameter int unsigned NX = 512,
  parameter int unsigned PAR = 16,
  parameter int unsigned DATA_W = 18,
  parameter int unsigned ACC_W = 32
) (
  input  logic                                  clk,
  input  logic                                  rst,

  input  logic                                  load_en,
  input  logic                                  load_is_h,
  input  logic                                  load_ch,
  input  logic [$clog2(NX)-1:0]                 load_idx,
  input  logic signed [DATA_W-1:0]              load_data,

  input  logic                                  start,
  input  logic [1:0]                            cfg_cin,
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
  localparam int unsigned BASE_W = $clog2(CHUNKS + 1);

  typedef enum logic [0:0] {
    S_IDLE,
    S_RUN
  } state_t;

  state_t state_q;

  logic [OUT_W-1:0] out_idx_q;
  logic [BASE_W-1:0] chunk_q;
  logic signed [ACC_W-1:0] acc_q;
  logic signed [ACC_W-1:0] lane_sum_c;
  logic signed [ACC_W-1:0] acc_next_c;

  logic signed [DATA_W-1:0] x_mem [0:1][0:NX-1];
  logic signed [DATA_W-1:0] h_mem [0:1][0:NX-1];

  assign busy = (state_q != S_IDLE);

  always_comb begin
    lane_sum_c = '0;
    for (int lane = 0; lane < PAR; lane++) begin
      int i_idx;
      int j_idx;
      logic signed [(2*DATA_W)-1:0] prod0;
      logic signed [(2*DATA_W)-1:0] prod1;
      i_idx = int'(chunk_q) * int'(PAR) + lane;
      j_idx = int'(out_idx_q) - i_idx;
      prod0 = '0;
      prod1 = '0;
      if ((i_idx < int'(NX)) && (j_idx >= 0) && (j_idx < int'(cfg_nh))) begin
        prod0 = x_mem[0][i_idx] * h_mem[0][j_idx];
        lane_sum_c += ACC_W'(prod0);
        if (cfg_cin == 2'd2) begin
          prod1 = x_mem[1][i_idx] * h_mem[1][j_idx];
          lane_sum_c += ACC_W'(prod1);
        end
      end
    end
    acc_next_c = (chunk_q == '0) ? lane_sum_c : (acc_q + lane_sum_c);
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      out_idx_q <= '0;
      chunk_q <= '0;
      acc_q <= '0;
      done <= 1'b0;
      compute_cycles <= '0;
      out_valid <= 1'b0;
      out_idx <= '0;
      out_data <= '0;
      for (int ch = 0; ch < 2; ch++) begin
        for (int idx = 0; idx < NX; idx++) begin
          x_mem[ch][idx] <= '0;
          h_mem[ch][idx] <= '0;
        end
      end
    end else begin
      done <= 1'b0;
      out_valid <= 1'b0;

      if ((state_q == S_IDLE) && load_en) begin
        if (load_is_h) begin
          h_mem[load_ch][load_idx] <= load_data;
        end else begin
          x_mem[load_ch][load_idx] <= load_data;
        end
      end

      if (state_q == S_RUN) begin
        compute_cycles <= compute_cycles + 32'd1;
        if (chunk_q == BASE_W'(CHUNKS - 1)) begin
          out_valid <= 1'b1;
          out_idx <= out_idx_q;
          out_data <= acc_next_c;
          acc_q <= '0;
          chunk_q <= '0;
          if (out_idx_q == OUT_W'(N - 1)) begin
            state_q <= S_IDLE;
            done <= 1'b1;
          end else begin
            out_idx_q <= out_idx_q + {{(OUT_W-1){1'b0}}, 1'b1};
          end
        end else begin
          acc_q <= acc_next_c;
          chunk_q <= chunk_q + {{(BASE_W-1){1'b0}}, 1'b1};
        end
      end

      if ((state_q == S_IDLE) && start) begin
        state_q <= S_RUN;
        out_idx_q <= '0;
        chunk_q <= '0;
        acc_q <= '0;
        compute_cycles <= '0;
      end
    end
  end

endmodule
