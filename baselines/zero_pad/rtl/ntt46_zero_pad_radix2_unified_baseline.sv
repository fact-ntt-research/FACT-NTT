module ntt46_zero_pad_radix2_unified_baseline #(
  parameter int unsigned N = 256,
  parameter int unsigned PRECISION = 4
) (
  input  logic                         clk,
  input  logic                         rst,
  input  logic                         preload_valid,
  input  logic                         preload_is_h,
  input  logic [1:0]                   preload_cin,
  input  logic [1:0]                   preload_cout,
  input  logic [$clog2(N/2)-1:0]       preload_idx,
  input  logic signed [7:0]            preload_data,
  input  logic                         start,
  input  logic [$clog2(N/2)-1:0]       cfg_nh,
  input  logic [2:0]                   cfg_cin,
  input  logic [2:0]                   cfg_cout,
  output logic                         busy,
  output logic                         done,
  output logic                         cfg_error,
  output logic [31:0]                  compute_cycles,
  input  logic                         y_read_en,
  input  logic [1:0]                   y_read_cout,
  input  logic [$clog2(N)-1:0]         y_read_idx,
  output logic                         y_read_valid,
  output logic signed [31:0]           y_read_data
);

  localparam int unsigned P520 = 520193;
  localparam int unsigned P254 = 254977;
  localparam int unsigned ROOT520 = (N == 256) ? 133361 : ((N == 512) ? 115000 : 421701);
  localparam int unsigned ROOT520_INV = (N == 256) ? 257957 : ((N == 512) ? 8789 : 475157);
  localparam int unsigned NINV520 = (N == 256) ? 518161 : ((N == 512) ? 519177 : 519685);
  localparam int unsigned ROOT254 = (N == 256) ? 111243 : ((N == 512) ? 79479 : 236176);
  localparam int unsigned ROOT254_INV = (N == 256) ? 1648 : ((N == 512) ? 178191 : 228789);
  localparam int unsigned NINV254 = (N == 256) ? 253981 : ((N == 512) ? 254479 : 254728);

  initial begin
    if (!((N == 256) || (N == 512) || (N == 1024))) begin
      $error("N must be 256, 512, or 1024");
    end
    if (!((PRECISION == 4) || (PRECISION == 8))) begin
      $error("PRECISION must be 4 or 8");
    end
  end

  generate
    if (PRECISION == 4) begin : g_int4
      logic residue_valid;
      logic [18:0] residue;

      ntt46_zero_pad_radix2_residue_conv_core #(
        .N(N),
        .INPUT_W(4),
        .DATA_W(19),
        .P(P520),
        .ROOT(ROOT520),
        .ROOT_INV(ROOT520_INV),
        .N_INV(NINV520)
      ) u_p520 (
        .clk(clk),
        .rst(rst),
        .preload_valid(preload_valid),
        .preload_is_h(preload_is_h),
        .preload_cin(preload_cin),
        .preload_cout(preload_cout),
        .preload_idx(preload_idx),
        .preload_data(preload_data[3:0]),
        .start(start),
        .cfg_nh(cfg_nh),
        .cfg_cin(cfg_cin),
        .cfg_cout(cfg_cout),
        .busy(busy),
        .done(done),
        .cfg_error(cfg_error),
        .compute_cycles(compute_cycles),
        .y_read_en(y_read_en),
        .y_read_cout(y_read_cout),
        .y_read_idx(y_read_idx),
        .y_read_valid(residue_valid),
        .y_read_residue(residue)
      );

      always_comb begin
        y_read_valid = residue_valid;
        if (residue > (P520 / 2)) y_read_data = $signed({1'b0, residue}) - $signed(P520);
        else y_read_data = $signed({1'b0, residue});
      end
    end else begin : g_int8
      logic p520_busy, p520_done, p520_error, p520_valid;
      logic p254_busy, p254_done, p254_error, p254_valid;
      logic [31:0] p520_cycles, p254_cycles;
      logic [18:0] p520_residue;
      logic [17:0] p254_residue_raw;
      logic [18:0] p254_residue;

      ntt46_zero_pad_radix2_residue_conv_core #(
        .N(N), .INPUT_W(8), .DATA_W(19), .P(P520),
        .ROOT(ROOT520), .ROOT_INV(ROOT520_INV), .N_INV(NINV520)
      ) u_p520 (
        .clk(clk), .rst(rst),
        .preload_valid(preload_valid), .preload_is_h(preload_is_h),
        .preload_cin(preload_cin), .preload_cout(preload_cout),
        .preload_idx(preload_idx), .preload_data(preload_data),
        .start(start), .cfg_nh(cfg_nh), .cfg_cin(cfg_cin), .cfg_cout(cfg_cout),
        .busy(p520_busy), .done(p520_done), .cfg_error(p520_error),
        .compute_cycles(p520_cycles),
        .y_read_en(y_read_en), .y_read_cout(y_read_cout), .y_read_idx(y_read_idx),
        .y_read_valid(p520_valid), .y_read_residue(p520_residue)
      );

      ntt46_zero_pad_radix2_residue_conv_core #(
        .N(N), .INPUT_W(8), .DATA_W(18), .P(P254),
        .ROOT(ROOT254), .ROOT_INV(ROOT254_INV), .N_INV(NINV254)
      ) u_p254 (
        .clk(clk), .rst(rst),
        .preload_valid(preload_valid), .preload_is_h(preload_is_h),
        .preload_cin(preload_cin), .preload_cout(preload_cout),
        .preload_idx(preload_idx), .preload_data(preload_data),
        .start(start), .cfg_nh(cfg_nh), .cfg_cin(cfg_cin), .cfg_cout(cfg_cout),
        .busy(p254_busy), .done(p254_done), .cfg_error(p254_error),
        .compute_cycles(p254_cycles),
        .y_read_en(y_read_en), .y_read_cout(y_read_cout), .y_read_idx(y_read_idx),
        .y_read_valid(p254_valid), .y_read_residue(p254_residue_raw)
      );

      assign p254_residue = {1'b0, p254_residue_raw};

      ntt46_zero_pad_crt2_reconstruct u_crt (
        .residue_p1(p520_residue),
        .residue_p2(p254_residue),
        .signed_value(y_read_data)
      );

      always_comb begin
        busy = p520_busy || p254_busy;
        done = p520_done && p254_done;
        cfg_error = p520_error || p254_error;
        compute_cycles = (p520_cycles >= p254_cycles) ? p520_cycles : p254_cycles;
        y_read_valid = p520_valid && p254_valid;
      end
    end
  endgenerate

endmodule

module ntt46_zero_pad_crt2_reconstruct (
  input  logic [18:0] residue_p1,
  input  logic [18:0] residue_p2,
  output logic signed [31:0] signed_value
);
  localparam longint unsigned P1 = 520193;
  localparam longint unsigned P2 = 254977;
  localparam longint unsigned P1_INV_MOD_P2 = 181141;
  localparam longint unsigned PRODUCT = P1 * P2;
  localparam longint unsigned HALF_PRODUCT = PRODUCT >> 1;
  localparam int unsigned P2_W = 18;
  localparam int unsigned P2_C = (1 << P2_W) - P2;
  logic [18:0] r1_mod_p2;
  logic [18:0] delta;
  logic [17:0] t;
  logic [63:0] reconstructed;
  logic signed [63:0] centered;

  function automatic logic [17:0] reduce_p2(input logic [63:0] value);
    logic [63:0] folded;
    logic [63:0] mask;
    begin
      mask = (64'd1 << P2_W) - 1;
      folded = value;
      for (int fold = 0; fold < 5; fold++) begin
        folded = (folded & mask) + ((folded >> P2_W) * P2_C);
      end
      for (int correction = 0; correction < 4; correction++) begin
        if (folded >= P2) folded = folded - P2;
      end
      return folded[17:0];
    end
  endfunction

  always_comb begin
    if (residue_p1 >= (2 * P2)) r1_mod_p2 = residue_p1 - (2 * P2);
    else if (residue_p1 >= P2) r1_mod_p2 = residue_p1 - P2;
    else r1_mod_p2 = residue_p1;
    if (residue_p2 >= r1_mod_p2) delta = residue_p2 - r1_mod_p2;
    else delta = residue_p2 + P2 - r1_mod_p2;
    t = reduce_p2(delta * P1_INV_MOD_P2);
    reconstructed = residue_p1 + (P1 * t);
    if (reconstructed > HALF_PRODUCT) centered = $signed(reconstructed) - $signed(PRODUCT);
    else centered = $signed(reconstructed);
    signed_value = centered[31:0];
  end
endmodule
