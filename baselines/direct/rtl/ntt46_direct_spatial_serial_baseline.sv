module ntt46_direct_spatial_serial_baseline #(
  parameter int unsigned NX = 512,
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
  localparam int unsigned OUT_W = $clog2(N);
  localparam int unsigned IX_W = $clog2(NX + 1);

  typedef enum logic [0:0] {
    S_IDLE,
    S_RUN
  } state_t;

  (* ram_style = "block" *) logic signed [DATA_W-1:0] x0_mem [0:NX-1];
  (* ram_style = "block" *) logic signed [DATA_W-1:0] x1_mem [0:NX-1];
  (* ram_style = "block" *) logic signed [DATA_W-1:0] h0_mem [0:NX-1];
  (* ram_style = "block" *) logic signed [DATA_W-1:0] h1_mem [0:NX-1];

  state_t state_q;
  logic [OUT_W-1:0] out_idx_q;
  logic [IX_W-1:0] issue_i_q;
  logic rd_valid_q;
  logic signed [DATA_W-1:0] x0_rd_q;
  logic signed [DATA_W-1:0] x1_rd_q;
  logic signed [DATA_W-1:0] h0_rd_q;
  logic signed [DATA_W-1:0] h1_rd_q;
  logic mul_valid_q;
  logic signed [(2*DATA_W)-1:0] prod0_q;
  logic signed [(2*DATA_W)-1:0] prod1_q;
  logic prod_valid_q;
  logic signed [ACC_W-1:0] prod_sum_q;
  logic signed [ACC_W-1:0] acc_q;

  logic issue_valid_c;
  logic [$clog2(NX)-1:0] issue_i_addr_c;
  logic [$clog2(NX)-1:0] issue_j_addr_c;
  logic signed [(2*DATA_W)-1:0] prod0_c;
  logic signed [(2*DATA_W)-1:0] prod1_c;
  logic signed [ACC_W-1:0] prod_sum_c;
  logic signed [ACC_W-1:0] acc_next_c;

  assign busy = (state_q != S_IDLE);

  always_comb begin
    int j_int;
    issue_valid_c = 1'b0;
    issue_i_addr_c = '0;
    issue_j_addr_c = '0;
    if (issue_i_q < IX_W'(NX)) begin
      j_int = int'(out_idx_q) - int'(issue_i_q);
      if ((j_int >= 0) && (j_int < int'(cfg_nh))) begin
        issue_valid_c = 1'b1;
        issue_i_addr_c = issue_i_q[$clog2(NX)-1:0];
        issue_j_addr_c = j_int[$clog2(NX)-1:0];
      end
    end

    prod0_c = x0_rd_q * h0_rd_q;
    prod1_c = x1_rd_q * h1_rd_q;
    prod_sum_c = '0;
    if (mul_valid_q) begin
      prod_sum_c = ACC_W'(prod0_q);
      if (cfg_cin == 2'd2) begin
        prod_sum_c += ACC_W'(prod1_q);
      end
    end
    acc_next_c = acc_q + (prod_valid_q ? prod_sum_q : '0);
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      out_idx_q <= '0;
      issue_i_q <= '0;
      rd_valid_q <= 1'b0;
      x0_rd_q <= '0;
      x1_rd_q <= '0;
      h0_rd_q <= '0;
      h1_rd_q <= '0;
      mul_valid_q <= 1'b0;
      prod0_q <= '0;
      prod1_q <= '0;
      prod_valid_q <= 1'b0;
      prod_sum_q <= '0;
      acc_q <= '0;
      done <= 1'b0;
      compute_cycles <= '0;
      out_valid <= 1'b0;
      out_idx <= '0;
      out_data <= '0;
    end else begin
      done <= 1'b0;
      out_valid <= 1'b0;

      if ((state_q == S_IDLE) && load_en) begin
        unique case ({load_is_h, load_ch})
          2'b00: x0_mem[load_idx] <= load_data;
          2'b01: x1_mem[load_idx] <= load_data;
          2'b10: h0_mem[load_idx] <= load_data;
          default: h1_mem[load_idx] <= load_data;
        endcase
      end

      if (state_q == S_RUN) begin
        compute_cycles <= compute_cycles + 32'd1;
        mul_valid_q <= rd_valid_q;
        prod0_q <= prod0_c;
        prod1_q <= prod1_c;
        prod_valid_q <= mul_valid_q;
        prod_sum_q <= prod_sum_c;
        if (issue_i_q < IX_W'(NX)) begin
          if (issue_valid_c) begin
            x0_rd_q <= x0_mem[issue_i_addr_c];
            h0_rd_q <= h0_mem[issue_j_addr_c];
            x1_rd_q <= x1_mem[issue_i_addr_c];
            h1_rd_q <= h1_mem[issue_j_addr_c];
          end else begin
            x0_rd_q <= '0;
            h0_rd_q <= '0;
            x1_rd_q <= '0;
            h1_rd_q <= '0;
          end
          rd_valid_q <= issue_valid_c;
          issue_i_q <= issue_i_q + {{(IX_W-1){1'b0}}, 1'b1};
          acc_q <= acc_next_c;
        end else if (rd_valid_q || mul_valid_q || prod_valid_q) begin
          rd_valid_q <= 1'b0;
          acc_q <= acc_next_c;
        end else begin
          out_valid <= 1'b1;
          out_idx <= out_idx_q;
          out_data <= acc_q;
          acc_q <= '0;
          issue_i_q <= '0;
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
        issue_i_q <= '0;
        rd_valid_q <= 1'b0;
        mul_valid_q <= 1'b0;
        prod0_q <= '0;
        prod1_q <= '0;
        prod_valid_q <= 1'b0;
        prod_sum_q <= '0;
        acc_q <= '0;
        compute_cycles <= '0;
      end
    end
  end

endmodule
