module ntt46_fact_ip_v1_crt2_reconstruct #(
  parameter longint unsigned P1 = 520193,
  parameter longint unsigned P2 = 254977,
  parameter longint unsigned P2_INV_MOD_P1 = 150637,
  parameter longint unsigned P1_INV_MOD_P2 = 181141
) (
  input  logic [18:0]        residue_p1,
  input  logic [18:0]        residue_p2,
  output logic signed [31:0] signed_value
);

  localparam longint unsigned PRODUCT = P1 * P2;
  localparam longint unsigned HALF_PRODUCT = PRODUCT >> 1;
  localparam logic [63:0] P1_U = P1[63:0];
  localparam logic [63:0] P2_U = P2[63:0];
  localparam logic [63:0] P2_INV_MOD_P1_U = P2_INV_MOD_P1[63:0];
  localparam logic [63:0] P1_INV_MOD_P2_U = P1_INV_MOD_P2[63:0];
  localparam logic [63:0] PRODUCT_U = PRODUCT[63:0];
  localparam logic [63:0] HALF_PRODUCT_U = HALF_PRODUCT[63:0];

  logic [63:0] term1_c;
  logic [63:0] term2_c;
  logic [63:0] sum_c;
  logic [63:0] mod_c;
  logic signed [63:0] signed_c;

  always_comb begin
    term1_c = {45'd0, residue_p1} * P2_U * P2_INV_MOD_P1_U;
    term2_c = {45'd0, residue_p2} * P1_U * P1_INV_MOD_P2_U;
    sum_c = term1_c + term2_c;
    mod_c = sum_c % PRODUCT_U;
    if (mod_c > HALF_PRODUCT_U) begin
      signed_c = $signed(mod_c) - $signed(PRODUCT_U);
    end else begin
      signed_c = $signed(mod_c);
    end
    signed_value = signed_c[31:0];
  end

endmodule

module ntt46_fact_ip_v1_crt2_reconstruct_pipe #(
  parameter longint unsigned P1 = 520193,
  parameter longint unsigned P2 = 254977,
  parameter longint unsigned P1_INV_MOD_P2 = 181141
) (
  input  logic               clk,
  input  logic               rst,
  input  logic               in_valid,
  input  logic [18:0]        residue_p1,
  input  logic [18:0]        residue_p2,
  input  logic [1:0]         in_cout,
  input  logic [9:0]         in_idx,
  output logic               out_valid,
  output logic signed [31:0] signed_value,
  output logic [1:0]         out_cout,
  output logic [9:0]         out_idx,
  output logic               pipe_busy
);

  import ntt46_mrec_params_pkg::*;
  import ntt46_mrec_arith_pkg::*;

  localparam longint unsigned PRODUCT = P1 * P2;
  localparam longint unsigned HALF_PRODUCT = PRODUCT >> 1;
  localparam logic [63:0] P1_U = P1[63:0];
  localparam logic [63:0] P2_U = P2[63:0];
  localparam logic [63:0] PRODUCT_U = PRODUCT[63:0];
  localparam logic [63:0] HALF_PRODUCT_U = HALF_PRODUCT[63:0];
  localparam logic [18:0] P1_19 = P1[18:0];
  localparam logic [18:0] P2_19 = P2[18:0];
  localparam logic [18:0] TWO_P2_19 = P2_19 + P2_19;
  localparam logic [MREC_DATA_W-1:0] P1_INV_MOD_P2_RES = P1_INV_MOD_P2[MREC_DATA_W-1:0];

  logic [18:0] r1_mod_p2_c;
  logic [18:0] delta_c;

  logic valid_s1, valid_s2, valid_s3, valid_s4;
  logic [18:0] r1_s1, r1_s2, r1_s3;
  logic [1:0] cout_s1, cout_s2, cout_s3, cout_s4;
  logic [9:0] idx_s1, idx_s2, idx_s3, idx_s4;

  (* use_dsp = "yes" *) logic [MREC_PROD_W-1:0] product_s1;
  logic [MREC_REDUCE_W-1:0] fold12_s2;
  logic [MREC_DATA_W-1:0] t_s3;
  (* use_dsp = "yes" *) logic [63:0] full_x_s4;
  logic [37:0] p1_times_t_c;
  logic signed [63:0] signed_s4_c;

  always_comb begin
    if (residue_p1 >= TWO_P2_19) begin
      r1_mod_p2_c = residue_p1 - TWO_P2_19;
    end else if (residue_p1 >= P2_19) begin
      r1_mod_p2_c = residue_p1 - P2_19;
    end else begin
      r1_mod_p2_c = residue_p1;
    end

    if (residue_p2 >= r1_mod_p2_c) begin
      delta_c = residue_p2 - r1_mod_p2_c;
    end else begin
      delta_c = residue_p2 + P2_19 - r1_mod_p2_c;
    end

    p1_times_t_c = P1_19 * {1'b0, t_s3};

    if (full_x_s4 > HALF_PRODUCT_U) begin
      signed_s4_c = $signed(full_x_s4) - $signed(PRODUCT_U);
    end else begin
      signed_s4_c = $signed(full_x_s4);
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      valid_s1 <= 1'b0;
      valid_s2 <= 1'b0;
      valid_s3 <= 1'b0;
      valid_s4 <= 1'b0;
      out_valid <= 1'b0;
      r1_s1 <= '0;
      r1_s2 <= '0;
      r1_s3 <= '0;
      cout_s1 <= '0;
      cout_s2 <= '0;
      cout_s3 <= '0;
      cout_s4 <= '0;
      idx_s1 <= '0;
      idx_s2 <= '0;
      idx_s3 <= '0;
      idx_s4 <= '0;
      product_s1 <= '0;
      fold12_s2 <= '0;
      t_s3 <= '0;
      full_x_s4 <= '0;
      signed_value <= '0;
      out_cout <= '0;
      out_idx <= '0;
    end else begin
      valid_s1 <= in_valid;
      valid_s2 <= valid_s1;
      valid_s3 <= valid_s2;
      valid_s4 <= valid_s3;
      out_valid <= valid_s4;

      r1_s1 <= residue_p1;
      r1_s2 <= r1_s1;
      r1_s3 <= r1_s2;

      cout_s1 <= in_cout;
      cout_s2 <= cout_s1;
      cout_s3 <= cout_s2;
      cout_s4 <= cout_s3;
      out_cout <= cout_s4;

      idx_s1 <= in_idx;
      idx_s2 <= idx_s1;
      idx_s3 <= idx_s2;
      idx_s4 <= idx_s3;
      out_idx <= idx_s4;

      product_s1 <= mrec_res_t'(delta_c[MREC_DATA_W-1:0]) * P1_INV_MOD_P2_RES;
      fold12_s2 <= pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_product(product_s1));
      t_s3 <= pseudo_mersenne_normalize(
        pseudo_mersenne_fold_reduced(pseudo_mersenne_fold_reduced(fold12_s2))
      );
      full_x_s4 <= {26'd0, p1_times_t_c} + {45'd0, r1_s3};
      signed_value <= signed_s4_c[31:0];
    end
  end

  assign pipe_busy = valid_s1 || valid_s2 || valid_s3 || valid_s4 || out_valid;

endmodule
