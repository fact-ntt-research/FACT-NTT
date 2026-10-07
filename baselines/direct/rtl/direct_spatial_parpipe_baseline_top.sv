module direct_spatial_parpipe_baseline_top #(
  parameter int unsigned NX = 512,
  parameter int unsigned PAR = 4,
  parameter int unsigned DATA_W = 18,
  parameter int unsigned ACC_W = 32,
  parameter int unsigned CIN_MAX = 4
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

  ntt46_direct_spatial_parpipe_baseline #(
    .NX(NX),
    .PAR(PAR),
    .DATA_W(DATA_W),
    .ACC_W(ACC_W),
    .CIN_MAX(CIN_MAX)
  ) u_baseline (.*);

endmodule
