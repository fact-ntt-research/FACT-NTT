module ntt46_fact_lean_ip_unified_axi_lite_core #(
  parameter int unsigned PRECISION = 4,
  parameter int unsigned R = 512,
  parameter int unsigned LANES = 16,
  parameter int unsigned CIN_MAX = 4,
  parameter int unsigned COUT_MAX = 4,
  parameter logic [31:0] IP_BUILD_ID = 32'h2026_0813
) (
  input  logic                clk,
  input  logic                rst,

  input  logic [7:0]          s_axi_awaddr,
  input  logic                s_axi_awvalid,
  output logic                s_axi_awready,
  input  logic [31:0]         s_axi_wdata,
  input  logic [3:0]          s_axi_wstrb,
  input  logic                s_axi_wvalid,
  output logic                s_axi_wready,
  output logic [1:0]          s_axi_bresp,
  output logic                s_axi_bvalid,
  input  logic                s_axi_bready,
  input  logic [7:0]          s_axi_araddr,
  input  logic                s_axi_arvalid,
  output logic                s_axi_arready,
  output logic [31:0]         s_axi_rdata,
  output logic [1:0]          s_axi_rresp,
  output logic                s_axi_rvalid,
  input  logic                s_axi_rready,

  input  logic                preload_valid,
  input  logic                preload_is_h,
  input  logic [1:0]          preload_cin,
  input  logic [1:0]          preload_cout,
  input  logic [8:0]          preload_idx,
  input  logic signed [18:0]  preload_data,
  output logic                preload_ready,

  input  logic                y_read_en,
  input  logic [1:0]          y_read_cout,
  input  logic [9:0]          y_read_idx,
  output logic                y_read_valid,
  output logic signed [31:0]  y_read_data,
  output logic                y_read_ready
);

  localparam int unsigned NUM_PRIMES = (PRECISION == 4) ? 1 : 2;

  generate
    if (PRECISION == 4) begin : g_int4
      logic signed [18:0] int4_y_read_data;

      ntt46_p520_ntt46_fact_lean_ip_int4_axi_lite_core #(
        .R(R),
        .LANES(LANES),
        .DIRECT_STAGE0_FROM_LOCAL(1'b1),
        .FACT_AREA_TRIM_CTRL(1'b1),
        .CIN_MAX(CIN_MAX),
        .COUT_MAX(COUT_MAX),
        .IP_BUILD_ID(IP_BUILD_ID),
        .INPUT_WIDTH(4),
        .PRECISION_ID(4),
        .PRIME0(520193),
        .PRIME1(0)
      ) u_precision_core (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready), .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready), .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .preload_valid(preload_valid), .preload_is_h(preload_is_h),
        .preload_cin(preload_cin), .preload_cout(preload_cout),
        .preload_idx(preload_idx), .preload_data(preload_data),
        .preload_ready(preload_ready),
        .y_read_en(y_read_en), .y_read_cout(y_read_cout),
        .y_read_idx(y_read_idx), .y_read_valid(y_read_valid),
        .y_read_data(int4_y_read_data), .y_read_ready(y_read_ready)
      );

      assign y_read_data = {{13{int4_y_read_data[18]}}, int4_y_read_data};
    end else if (PRECISION == 8) begin : g_int8
      ntt46_fact_lean_ip_int8_axi_lite_core #(
        .R(R),
        .LANES(LANES),
        .COUT_MAX(COUT_MAX),
        .IP_BUILD_ID(IP_BUILD_ID)
      ) u_precision_core (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready), .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready), .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .preload_valid(preload_valid), .preload_is_h(preload_is_h),
        .preload_cin(preload_cin), .preload_cout(preload_cout),
        .preload_idx(preload_idx), .preload_data(preload_data),
        .preload_ready(preload_ready),
        .y_read_en(y_read_en), .y_read_cout(y_read_cout),
        .y_read_idx(y_read_idx), .y_read_valid(y_read_valid),
        .y_read_data(y_read_data), .y_read_ready(y_read_ready)
      );
    end else begin : g_invalid_precision
      assign s_axi_awready = 1'b0;
      assign s_axi_wready = 1'b0;
      assign s_axi_bresp = 2'b10;
      assign s_axi_bvalid = 1'b0;
      assign s_axi_arready = 1'b0;
      assign s_axi_rdata = '0;
      assign s_axi_rresp = 2'b10;
      assign s_axi_rvalid = 1'b0;
      assign y_read_valid = 1'b0;
      assign y_read_data = '0;
      assign preload_ready = 1'b0;
      assign y_read_ready = 1'b0;
    end
  endgenerate

  initial begin
    if ((PRECISION != 4) && (PRECISION != 8))
      $error("PRECISION must be 4 or 8");
    if ((R != 128) && (R != 256) && (R != 512))
      $error("R must be 128, 256, or 512");
    if (((R == 512) && (LANES != 16)) || ((R != 512) && (LANES != 8)))
      $error("LANES must be 8 for R=128/256 and 16 for R=512");
    if (CIN_MAX != 4)
      $error("The public FACT IP requires CIN_MAX=4");
    if (COUT_MAX != 4)
      $error("The public FACT IP requires COUT_MAX=4");
    if (NUM_PRIMES != ((PRECISION == 4) ? 1 : 2))
      $error("Internal precision-to-prime mapping is inconsistent");
  end

endmodule
