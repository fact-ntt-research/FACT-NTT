module ntt46_fact_lean_res_bank #(
  parameter int unsigned DEPTH = 128,
  parameter int unsigned ADDR_W = $clog2(DEPTH)
) (
  input  logic                            clk,
  input  logic                            wr_en,
  input  logic [ADDR_W-1:0]               wr_addr,
  input  ntt46_mrec_arith_pkg::mrec_res_t wr_data,
  input  logic [ADDR_W-1:0]               rd_addr,
  output ntt46_mrec_arith_pkg::mrec_res_t rd_data
);

  (* ram_style = "distributed" *) ntt46_mrec_arith_pkg::mrec_res_t mem [0:DEPTH-1];

  always_ff @(posedge clk) begin
    if (wr_en) mem[wr_addr] <= wr_data;
  end

  assign rd_data = mem[rd_addr];

endmodule
