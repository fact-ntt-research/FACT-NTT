module ntt46_zest_radix24_step16 #(
  parameter int DEPTH = 48,
  parameter int ADDR_W = $clog2(DEPTH),
  parameter int unsigned LANES = 16,
  parameter string FWD_MEM_FILE = "",
  parameter string INV_MEM_FILE = "",
  parameter bit J_USE_DSP = 1'b0,
  parameter bit J_LUT_FAST3 = 1'b0,
  parameter bit USE_UNIFIED_LANE = 1'b0,
  parameter bit MUL_EXTRA_STAGE = 1'b1,
  parameter bit J_PRE_STAGE = 1'b0,
  parameter bit INVERSE_J_PRE_STAGE = 1'b0,
  parameter bit COSET_J_PRE_STAGE = 1'b0,
  parameter bit USE_TIGHT_MUL = 1'b0,
  parameter bit J_USE_TIGHT_MUL = USE_TIGHT_MUL,
  parameter bit TWIDDLE_PRE_STAGE = 1'b0,
  parameter bit TWIDDLE_PREFETCH_STAGE = 1'b0,
  parameter bit INVERSE_TWIDDLE_ONLY = 1'b0,
  parameter bit ENABLE_PRODUCT4_MODE = 1'b1,
  parameter bit RESET_DATA_ARRAYS = 1'b1
) (
  input  logic                                clk,
  input  logic                                rst,
  input  logic                                in_valid,
  input  logic                                inverse,
  input  logic                                coset_untwist,
  input  logic                                radix2_mode,
  input  logic                                product_mode,
  input  logic                                product4_mode,
  input  logic [ADDR_W-1:0]                   twiddle_addr,
  input  logic                                twiddle_prefetch_valid,
  input  logic [ADDR_W-1:0]                   twiddle_prefetch_addr,
  input  ntt46_mrec_arith_pkg::mrec_res_t     x0_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x1_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x2_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     x3_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     product_w0_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     product_w1_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     product_w2_in [0:LANES-1],
  input  ntt46_mrec_arith_pkg::mrec_res_t     product_w3_in [0:LANES-1],
  output logic                                out_valid,
  output logic                                fwd_out_valid,
  output logic                                inv_out_valid,
  output ntt46_mrec_arith_pkg::mrec_res_t     y0_out [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     y1_out [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     y2_out [0:LANES-1],
  output ntt46_mrec_arith_pkg::mrec_res_t     y3_out [0:LANES-1]
);

  import ntt46_mrec_arith_pkg::*;
  import ntt46_mrec_params_pkg::*;

  logic      valid_q;
  logic      inverse_q;
  logic      coset_untwist_q;
  logic      radix2_mode_q;
  logic      product_mode_q;
  logic      product4_mode_eff_c;
  logic      product4_mode_q;
  mrec_res_t x0_q [0:LANES-1];
  mrec_res_t x1_q [0:LANES-1];
  mrec_res_t x2_q [0:LANES-1];
  mrec_res_t x3_q [0:LANES-1];
  mrec_res_t product_w0_q [0:LANES-1];
  mrec_res_t product_w1_q [0:LANES-1];
  mrec_res_t product_w2_q [0:LANES-1];
  mrec_res_t product_w3_q [0:LANES-1];

  mrec_res_t fwd_w1 [0:LANES-1];
  mrec_res_t fwd_w2 [0:LANES-1];
  mrec_res_t fwd_w3 [0:LANES-1];
  mrec_res_t inv_w1 [0:LANES-1];
  mrec_res_t inv_w2 [0:LANES-1];
  mrec_res_t inv_w3 [0:LANES-1];
  mrec_res_t pref_fwd_w1_q [0:LANES-1];
  mrec_res_t pref_fwd_w2_q [0:LANES-1];
  mrec_res_t pref_fwd_w3_q [0:LANES-1];
  mrec_res_t pref_inv_w1_q [0:LANES-1];
  mrec_res_t pref_inv_w2_q [0:LANES-1];
  mrec_res_t pref_inv_w3_q [0:LANES-1];
  mrec_res_t sel_w1 [0:LANES-1];
  mrec_res_t sel_w2 [0:LANES-1];
  mrec_res_t sel_w3 [0:LANES-1];
  mrec_res_t use_fwd_w1 [0:LANES-1];
  mrec_res_t use_fwd_w2 [0:LANES-1];
  mrec_res_t use_fwd_w3 [0:LANES-1];
  mrec_res_t use_inv_w1 [0:LANES-1];
  mrec_res_t use_inv_w2 [0:LANES-1];
  mrec_res_t use_inv_w3 [0:LANES-1];
  logic twiddle_rd_en_c;
  logic [ADDR_W-1:0] twiddle_rd_addr_c;
  logic lane_valid_c;
  logic lane_inverse_c;
  logic lane_coset_untwist_c;
  logic lane_radix2_mode_c;
  logic lane_product_mode_c;
  logic lane_product4_mode_c;
  mrec_res_t base_x0 [0:LANES-1];
  mrec_res_t base_x1 [0:LANES-1];
  mrec_res_t base_x2 [0:LANES-1];
  mrec_res_t base_x3 [0:LANES-1];
  mrec_res_t lane_x0 [0:LANES-1];
  mrec_res_t lane_x1 [0:LANES-1];
  mrec_res_t lane_x2 [0:LANES-1];
  mrec_res_t lane_x3 [0:LANES-1];
  mrec_res_t lane_w1 [0:LANES-1];
  mrec_res_t lane_w2 [0:LANES-1];
  mrec_res_t lane_w3 [0:LANES-1];
  mrec_res_t lane_product_w0 [0:LANES-1];
  mrec_res_t pre_x0_q [0:LANES-1];
  mrec_res_t pre_x1_q [0:LANES-1];
  mrec_res_t pre_x2_q [0:LANES-1];
  mrec_res_t pre_x3_q [0:LANES-1];
  mrec_res_t pre_w1_q [0:LANES-1];
  mrec_res_t pre_w2_q [0:LANES-1];
  mrec_res_t pre_w3_q [0:LANES-1];
  mrec_res_t pre_product_w0_q [0:LANES-1];
  mrec_res_t j_root_c;
  mrec_res_t lane_j_root_c;
  logic pre_valid_q;
  logic pre_inverse_q;
  logic pre_coset_untwist_q;
  logic pre_radix2_mode_q;
  logic pre_product_mode_q;
  logic pre_product4_mode_q;
  logic current_needs_pre_c;
  logic lane_use_pre_c;
  logic lane_out_valid;
  logic lane_fwd_out_valid;
  logic lane_inv_out_valid;

  assign out_valid = lane_out_valid;
  assign fwd_out_valid = lane_fwd_out_valid;
  assign inv_out_valid = lane_inv_out_valid;
  assign twiddle_rd_en_c = TWIDDLE_PREFETCH_STAGE ? twiddle_prefetch_valid : in_valid;
  assign twiddle_rd_addr_c = TWIDDLE_PREFETCH_STAGE ? twiddle_prefetch_addr : twiddle_addr;

  generate
    if (INVERSE_TWIDDLE_ONLY) begin : g_no_fwd_twiddle
      for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
        assign fwd_w1[lane] = '0;
        assign fwd_w2[lane] = '0;
        assign fwd_w3[lane] = '0;
      end
    end else begin : g_fwd_twiddle
      ntt46_zest_radix24_twiddle16_rom #(
        .DEPTH(DEPTH),
        .ADDR_W(ADDR_W),
        .LANES(LANES),
        .MEM_FILE(FWD_MEM_FILE)
      ) u_tw_fwd (
        .clk(clk),
        .rd_en(twiddle_rd_en_c),
        .rd_addr(twiddle_rd_addr_c),
        .w1_out(fwd_w1),
        .w2_out(fwd_w2),
        .w3_out(fwd_w3)
      );
    end
  endgenerate

  ntt46_zest_radix24_twiddle16_rom #(
    .DEPTH(DEPTH),
    .ADDR_W(ADDR_W),
    .LANES(LANES),
    .MEM_FILE(INV_MEM_FILE)
  ) u_tw_inv (
    .clk(clk),
    .rd_en(twiddle_rd_en_c),
    .rd_addr(twiddle_rd_addr_c),
    .w1_out(inv_w1),
    .w2_out(inv_w2),
    .w3_out(inv_w3)
  );

  always_comb begin
    for (int lane = 0; lane < LANES; lane++) begin
      use_fwd_w1[lane] = TWIDDLE_PREFETCH_STAGE ? pref_fwd_w1_q[lane] : fwd_w1[lane];
      use_fwd_w2[lane] = TWIDDLE_PREFETCH_STAGE ? pref_fwd_w2_q[lane] : fwd_w2[lane];
      use_fwd_w3[lane] = TWIDDLE_PREFETCH_STAGE ? pref_fwd_w3_q[lane] : fwd_w3[lane];
      use_inv_w1[lane] = TWIDDLE_PREFETCH_STAGE ? pref_inv_w1_q[lane] : inv_w1[lane];
      use_inv_w2[lane] = TWIDDLE_PREFETCH_STAGE ? pref_inv_w2_q[lane] : inv_w2[lane];
      use_inv_w3[lane] = TWIDDLE_PREFETCH_STAGE ? pref_inv_w3_q[lane] : inv_w3[lane];
      sel_w1[lane] = (product_mode_q || product4_mode_q) ? product_w1_q[lane] :
                     (inverse_q || INVERSE_TWIDDLE_ONLY) ? use_inv_w1[lane] : use_fwd_w1[lane];
      sel_w2[lane] = product4_mode_q ? product_w2_q[lane] :
                     product_mode_q ? '0 :
                     (inverse_q || INVERSE_TWIDDLE_ONLY) ? use_inv_w2[lane] : use_fwd_w2[lane];
      sel_w3[lane] = product4_mode_q ? product_w3_q[lane] :
                     product_mode_q ? '0 :
                     (inverse_q || INVERSE_TWIDDLE_ONLY) ? use_inv_w3[lane] : use_fwd_w3[lane];
      base_x0[lane] = x0_q[lane];
      base_x1[lane] = product_mode_q ? '0 : x1_q[lane];
      base_x2[lane] = product_mode_q ? '0 : x2_q[lane];
      base_x3[lane] = product_mode_q ? '0 : x3_q[lane];
      if (lane_use_pre_c) begin
        lane_x0[lane] = pre_x0_q[lane];
        lane_x1[lane] = pre_x1_q[lane];
        lane_x2[lane] = pre_x2_q[lane];
        lane_x3[lane] = pre_x3_q[lane];
        lane_product_w0[lane] = pre_product_w0_q[lane];
        lane_w1[lane] = pre_w1_q[lane];
        lane_w2[lane] = pre_w2_q[lane];
        lane_w3[lane] = pre_w3_q[lane];
      end else begin
        lane_x0[lane] = base_x0[lane];
        lane_x1[lane] = base_x1[lane];
        lane_x2[lane] = base_x2[lane];
        lane_x3[lane] = base_x3[lane];
        lane_product_w0[lane] = product_w0_q[lane];
        lane_w1[lane] = sel_w1[lane];
        lane_w2[lane] = sel_w2[lane];
        lane_w3[lane] = sel_w3[lane];
      end
    end
  end

  assign j_root_c = inverse_q ? mrec_res_t'(MREC_J_INV) : mrec_res_t'(MREC_J);
  assign current_needs_pre_c = TWIDDLE_PRE_STAGE && valid_q;
  assign lane_use_pre_c = pre_valid_q;
  assign lane_valid_c = lane_use_pre_c || (valid_q && !TWIDDLE_PRE_STAGE);
  assign lane_inverse_c = (lane_product_mode_c || lane_product4_mode_c) ? 1'b0 :
                          lane_use_pre_c ? pre_inverse_q : inverse_q;
  assign lane_coset_untwist_c = lane_use_pre_c ? pre_coset_untwist_q : coset_untwist_q;
  assign lane_product_mode_c = lane_use_pre_c ? pre_product_mode_q : product_mode_q;
  assign lane_product4_mode_c = lane_use_pre_c ? pre_product4_mode_q : product4_mode_q;
  assign lane_radix2_mode_c = lane_product_mode_c ? 1'b1 :
                              lane_use_pre_c ? pre_radix2_mode_q : radix2_mode_q;
  assign lane_j_root_c = lane_inverse_c ? mrec_res_t'(MREC_J_INV) : mrec_res_t'(MREC_J);

  // Shared twiddle shift registers 鈥?all 16 lanes receive identical w1/w2/w3,
  // so we store one copy and broadcast instead of 16 independent copies.
  localparam int unsigned SHARED_SIDE_LAT = (J_USE_DSP && !MUL_EXTRA_STAGE) ? 3 : 4;
  mrec_res_t shared_w1_q [0:SHARED_SIDE_LAT-1];
  mrec_res_t shared_w2_q [0:SHARED_SIDE_LAT-1];
  mrec_res_t shared_w3_q [0:SHARED_SIDE_LAT-1];
  logic shared_load_c;
  assign shared_load_c = lane_valid_c || (pre_valid_q && !TWIDDLE_PRE_STAGE);

  // Early/late positions map to J_LAT-1 and SIDE_LAT-1 in the lane's side channel
  localparam int unsigned SHARED_EARLY_IDX = SHARED_SIDE_LAT - 1;  // J_LAT-1 with J_LAT=SHARED_SIDE_LAT
  localparam int unsigned SHARED_LATE_IDX  = SHARED_SIDE_LAT - 1;  // SIDE_LAT-1 with SIDE_LAT=SHARED_SIDE_LAT (no pre-stage)
  mrec_res_t shared_w1_early, shared_w2_early, shared_w3_early;
  mrec_res_t shared_w1_late,  shared_w2_late,  shared_w3_late;
  assign shared_w1_early = shared_w1_q[SHARED_EARLY_IDX];
  assign shared_w2_early = shared_w2_q[SHARED_EARLY_IDX];
  assign shared_w3_early = shared_w3_q[SHARED_EARLY_IDX];
  assign shared_w1_late  = shared_w1_q[SHARED_LATE_IDX];
  assign shared_w2_late  = shared_w2_q[SHARED_LATE_IDX];
  assign shared_w3_late  = shared_w3_q[SHARED_LATE_IDX];

  generate
    if (USE_UNIFIED_LANE) begin : g_unified_lane
      ntt46_zest_radix24_lane16_group_unified_probe #(
        .LANES(LANES),
        .J_USE_DSP(J_USE_DSP),
        .J_LUT_FAST3(J_LUT_FAST3),
        .MUL_EXTRA_STAGE(MUL_EXTRA_STAGE),
        .J_PRE_STAGE(J_PRE_STAGE),
        .INVERSE_J_PRE_STAGE(INVERSE_J_PRE_STAGE),
        .COSET_J_PRE_STAGE(COSET_J_PRE_STAGE),
        .USE_TIGHT_MUL(USE_TIGHT_MUL),
        .J_USE_TIGHT_MUL(J_USE_TIGHT_MUL),
        .ENABLE_PRODUCT4_MODE(ENABLE_PRODUCT4_MODE),
        .USE_SHARED_TWIDDLE(1'b0),
        .RESET_DATA_ARRAYS(RESET_DATA_ARRAYS)
      ) u_lane_group (
        .clk(clk),
        .rst(rst),
        .in_valid(lane_valid_c),
        .radix2_mode(lane_product_mode_c ? 1'b1 : lane_radix2_mode_c),
        .inverse(lane_product_mode_c ? 1'b0 : lane_inverse_c),
        .coset_untwist(lane_product_mode_c ? 1'b0 : lane_coset_untwist_c),
        .product4_mode(lane_product4_mode_c),
        .x0_in(lane_x0),
        .x1_in(lane_x1),
        .x2_in(lane_x2),
        .x3_in(lane_x3),
        .product_w0_in(lane_product_w0),
        .w1_in(lane_w1),
        .w2_in(lane_w2),
        .w3_in(lane_w3),
        .j_in(lane_j_root_c),
        .shared_w1_early(shared_w1_early),
        .shared_w2_early(shared_w2_early),
        .shared_w3_early(shared_w3_early),
        .shared_w1_late(shared_w1_late),
        .shared_w2_late(shared_w2_late),
        .shared_w3_late(shared_w3_late),
        .out_valid(lane_out_valid),
        .fwd_out_valid(lane_fwd_out_valid),
        .inv_out_valid(lane_inv_out_valid),
        .y0_out(y0_out),
        .y1_out(y1_out),
        .y2_out(y2_out),
        .y3_out(y3_out)
      );
    end else begin : g_legacy_lane
      ntt46_zest_radix24_lane16_group #(
        .J_USE_DSP(J_USE_DSP)
      ) u_lane_group (
        .clk(clk),
        .rst(rst),
        .in_valid(lane_valid_c),
        .radix2_mode(lane_product_mode_c ? 1'b1 : lane_radix2_mode_c),
        .inverse(lane_product_mode_c ? 1'b0 : lane_inverse_c),
        .x0_in(lane_x0),
        .x1_in(lane_x1),
        .x2_in(lane_x2),
        .x3_in(lane_x3),
        .w1_in(lane_w1),
        .w2_in(lane_w2),
        .w3_in(lane_w3),
        .j_in(lane_j_root_c),
        .out_valid(lane_out_valid),
        .y0_out(y0_out),
        .y1_out(y1_out),
        .y2_out(y2_out),
        .y3_out(y3_out)
      );
      assign lane_fwd_out_valid = lane_out_valid && !inverse_q;
      assign lane_inv_out_valid = lane_out_valid && inverse_q;
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst) begin
      valid_q <= 1'b0;
      inverse_q <= 1'b0;
      coset_untwist_q <= 1'b0;
      radix2_mode_q <= 1'b0;
      product_mode_q <= 1'b0;
      product4_mode_q <= 1'b0;
      pre_valid_q <= 1'b0;
      pre_inverse_q <= 1'b0;
      pre_coset_untwist_q <= 1'b0;
      pre_radix2_mode_q <= 1'b0;
      pre_product_mode_q <= 1'b0;
      pre_product4_mode_q <= 1'b0;
      if (RESET_DATA_ARRAYS) begin
        for (int lane = 0; lane < LANES; lane++) begin
          x0_q[lane] <= '0;
          x1_q[lane] <= '0;
          x2_q[lane] <= '0;
          x3_q[lane] <= '0;
          product_w0_q[lane] <= '0;
          product_w1_q[lane] <= '0;
          product_w2_q[lane] <= '0;
          product_w3_q[lane] <= '0;
          pre_x0_q[lane] <= '0;
          pre_x1_q[lane] <= '0;
          pre_x2_q[lane] <= '0;
          pre_x3_q[lane] <= '0;
          pre_product_w0_q[lane] <= '0;
          pre_w1_q[lane] <= '0;
          pre_w2_q[lane] <= '0;
          pre_w3_q[lane] <= '0;
          pref_fwd_w1_q[lane] <= '0;
          pref_fwd_w2_q[lane] <= '0;
          pref_fwd_w3_q[lane] <= '0;
          pref_inv_w1_q[lane] <= '0;
          pref_inv_w2_q[lane] <= '0;
          pref_inv_w3_q[lane] <= '0;
        end
        for (int idx = 0; idx < SHARED_SIDE_LAT; idx++) begin
          shared_w1_q[idx] <= '0;
          shared_w2_q[idx] <= '0;
          shared_w3_q[idx] <= '0;
        end
      end
    end else begin
      valid_q <= in_valid;
      pre_valid_q <= TWIDDLE_PRE_STAGE && valid_q;
      if (in_valid) begin
        inverse_q <= inverse;
        coset_untwist_q <= coset_untwist;
        radix2_mode_q <= radix2_mode;
        product_mode_q <= product_mode;
        product4_mode_q <= product4_mode_eff_c;
        for (int lane = 0; lane < LANES; lane++) begin
          x0_q[lane] <= x0_in[lane];
          x1_q[lane] <= x1_in[lane];
          x2_q[lane] <= x2_in[lane];
          x3_q[lane] <= x3_in[lane];
          product_w0_q[lane] <= product_w0_in[lane];
          product_w1_q[lane] <= product_w1_in[lane];
          product_w2_q[lane] <= product_w2_in[lane];
          product_w3_q[lane] <= product_w3_in[lane];
        end
      end
      if (TWIDDLE_PRE_STAGE && valid_q) begin
        pre_inverse_q <= inverse_q;
        pre_coset_untwist_q <= coset_untwist_q;
        pre_radix2_mode_q <= radix2_mode_q;
        pre_product_mode_q <= product_mode_q;
        pre_product4_mode_q <= product4_mode_q;
        for (int lane = 0; lane < LANES; lane++) begin
          pre_x0_q[lane] <= base_x0[lane];
          pre_x1_q[lane] <= base_x1[lane];
          pre_x2_q[lane] <= base_x2[lane];
          pre_x3_q[lane] <= base_x3[lane];
          pre_product_w0_q[lane] <= product_w0_q[lane];
          pre_w1_q[lane] <= sel_w1[lane];
          pre_w2_q[lane] <= sel_w2[lane];
          pre_w3_q[lane] <= sel_w3[lane];
        end
      end
      if (TWIDDLE_PREFETCH_STAGE && in_valid) begin
        for (int lane = 0; lane < LANES; lane++) begin
          pref_fwd_w1_q[lane] <= fwd_w1[lane];
          pref_fwd_w2_q[lane] <= fwd_w2[lane];
          pref_fwd_w3_q[lane] <= fwd_w3[lane];
          pref_inv_w1_q[lane] <= inv_w1[lane];
          pref_inv_w2_q[lane] <= inv_w2[lane];
          pref_inv_w3_q[lane] <= inv_w3[lane];
        end
      end
      // Shared twiddle shift registers 鈥?one copy for all 16 lanes
      shared_w1_q[0] <= shared_load_c ? sel_w1[0] : '0;
      shared_w2_q[0] <= shared_load_c ? sel_w2[0] : '0;
      shared_w3_q[0] <= shared_load_c ? sel_w3[0] : '0;
      for (int idx = 1; idx < SHARED_SIDE_LAT; idx++) begin
        shared_w1_q[idx] <= shared_w1_q[idx-1];
        shared_w2_q[idx] <= shared_w2_q[idx-1];
        shared_w3_q[idx] <= shared_w3_q[idx-1];
      end
    end
  end

  assign product4_mode_eff_c = ENABLE_PRODUCT4_MODE && product4_mode;

endmodule
