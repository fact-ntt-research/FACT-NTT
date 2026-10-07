module tb_ntt46_zero_pad_p520_n1024_local_core #(
  parameter int unsigned DUT_CIN = 4,
  parameter int unsigned DUT_NH = 511,
  parameter int unsigned DUT_PATTERN = 6,
  parameter bit DUT_DUMP_CSV = 1'b0
);

  localparam int N = 1024;
  localparam int NX = 512;

  logic clk = 1'b0;
  logic rst = 1'b1;
  always #2 clk = ~clk;

  logic start;
  logic [8:0] cfg_nh;
  logic [2:0] cfg_cin;
  logic preload_valid;
  logic preload_is_h;
  logic [1:0] preload_cin;
  logic [8:0] preload_idx;
  logic signed [18:0] preload_data;
  logic y_read_en;
  logic [9:0] y_read_idx;
  logic y_read_valid;
  logic signed [31:0] y_read_data;
  logic busy;
  logic done;
  logic cfg_error;
  logic [15:0] compute_cycles;

  int signed x_int [0:3][0:NX-1];
  int signed h_int [0:3][0:NX-1];
  int signed expected [0:N-1];

  function automatic int signed sample_x(input int idx, input int ch, input int pattern);
    case (pattern)
      0: return ((idx * 5 + ch * 3 + 7) % 16) - 8;
      1: return 7;
      2: return -8;
      3: return ((idx + ch) & 1) ? -8 : 7;
      4: return (idx == (ch ? 17 : 0)) ? (ch + 1) : 0;
      5: return (idx >= NX-8 || idx < 3) ? (((idx+ch)&1) ? -8 : 7) : 0;
      default: return ((idx * 13 + ch * 29 + 5) % 16) - 8;
    endcase
  endfunction

  function automatic int signed sample_h(input int idx, input int ch, input int pattern);
    case (pattern)
      0: return ((idx * 7 + ch * 11 + 5) % 16) - 8;
      1: return 7;
      2: return -8;
      3: return (idx & 1) ? 7 : -8;
      4: return (idx == 0) ? (ch + 1) : 0;
      5: return (idx < 4 || idx >= NX-8) ? (((idx+ch)&1) ? 7 : -8) : 0;
      default: return ((idx * 19 + ch * 31 + 9) % 16) - 8;
    endcase
  endfunction

  ntt46_zero_pad_p520_n1024_local_core u_dut (.*);

  task automatic preload_sample(input bit is_h, input int ch, input int idx, input int signed value);
    begin
      @(negedge clk);
      preload_valid = 1'b1;
      preload_is_h = is_h;
      preload_cin = ch[1:0];
      preload_idx = idx[8:0];
      preload_data = value;
    end
  endtask

  task automatic read_and_check(input int idx, input int dump_fd);
    int wait_cycles;
    begin
      @(negedge clk);
      y_read_en = 1'b1;
      y_read_idx = idx[9:0];
      @(negedge clk);
      y_read_en = 1'b0;
      for (wait_cycles = 0; wait_cycles < 16 && !y_read_valid; wait_cycles++) @(negedge clk);
      if (!y_read_valid) $fatal(1, "zero-pad local missing y_read_valid index=%0d", idx);
      if (y_read_data !== expected[idx]) begin
        $fatal(1, "zero-pad local mismatch index=%0d got=%0d expected=%0d", idx, y_read_data, expected[idx]);
      end
      if (dump_fd != 0) $fdisplay(dump_fd, "%0d,%0d", idx, y_read_data);
    end
  endtask

  initial begin
    int timeout;
    int dump_fd;
    start = 1'b0;
    cfg_nh = DUT_NH[8:0];
    cfg_cin = DUT_CIN[2:0];
    preload_valid = 1'b0;
    preload_is_h = 1'b0;
    preload_cin = '0;
    preload_idx = '0;
    preload_data = '0;
    y_read_en = 1'b0;
    y_read_idx = '0;
    dump_fd = 0;

    if (!(DUT_CIN inside {1,2,4}) || DUT_NH < 1 || DUT_NH >= NX) $fatal(1, "invalid test configuration");
    for (int idx = 0; idx < N; idx++) expected[idx] = 0;
    for (int ch = 0; ch < DUT_CIN; ch++) begin
      for (int idx = 0; idx < NX; idx++) begin
        x_int[ch][idx] = sample_x(idx, ch, DUT_PATTERN);
        h_int[ch][idx] = (idx < DUT_NH) ? sample_h(idx, ch, DUT_PATTERN) : 0;
      end
      for (int i = 0; i < NX; i++)
        for (int j = 0; j < DUT_NH; j++) expected[i+j] += x_int[ch][i] * h_int[ch][j];
    end

    repeat (8) @(posedge clk);
    rst = 1'b0;
    repeat (2) @(posedge clk);
    for (int ch = 0; ch < DUT_CIN; ch++) begin
      for (int idx = 0; idx < NX; idx++) preload_sample(1'b0, ch, idx, x_int[ch][idx]);
      for (int idx = 0; idx < NX; idx++) preload_sample(1'b1, ch, idx, h_int[ch][idx]);
    end
    @(negedge clk);
    preload_valid = 1'b0;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    timeout = 0;
    while (!done && timeout < 10000) begin
      @(posedge clk);
      #1;
      timeout++;
    end
    if (!done || cfg_error) $fatal(1, "zero-pad local failed done=%0b cfg_error=%0b", done, cfg_error);

    if (DUT_DUMP_CSV) begin
      dump_fd = $fopen("zero_pad_p520_n1024_local_output.csv", "w");
      if (dump_fd == 0) $fatal(1, "could not open local output dump");
      $fdisplay(dump_fd, "# N=%0d,NX=%0d,NH=%0d,CIN=%0d,PATTERN=%0d,PRIME=520193", N, NX, DUT_NH, DUT_CIN, DUT_PATTERN);
      $fdisplay(dump_fd, "index,y");
    end
    for (int idx = 0; idx < N; idx++) read_and_check(idx, dump_fd);
    if (dump_fd != 0) $fclose(dump_fd);

    $display("tb_ntt46_zero_pad_p520_n1024_local_core PASS Cin=%0d Nh=%0d Pattern=%0d compute_cycles=%0d rows=1024",
             DUT_CIN, DUT_NH, DUT_PATTERN, compute_cycles);
    $finish;
  end

endmodule
