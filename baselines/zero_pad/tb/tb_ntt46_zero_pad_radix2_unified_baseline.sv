module tb_ntt46_zero_pad_radix2_unified_baseline;
  parameter int unsigned DUT_N = 256;
  parameter int unsigned DUT_PRECISION = 4;
  parameter int unsigned DUT_CIN = 1;
  parameter int unsigned DUT_COUT = 1;
  localparam int unsigned NX = DUT_N / 2;
  localparam int signed MIN_VALUE = -(1 << (DUT_PRECISION - 1));
  localparam int signed MAX_VALUE = (1 << (DUT_PRECISION - 1)) - 1;

  logic clk = 1'b0;
  logic rst = 1'b1;
  logic preload_valid;
  logic preload_is_h;
  logic [1:0] preload_cin;
  logic [1:0] preload_cout;
  logic [$clog2(NX)-1:0] preload_idx;
  logic signed [7:0] preload_data;
  logic start;
  logic [$clog2(NX)-1:0] cfg_nh;
  logic [2:0] cfg_cin;
  logic [2:0] cfg_cout;
  logic busy;
  logic done;
  logic cfg_error;
  logic [31:0] compute_cycles;
  logic y_read_en;
  logic [1:0] y_read_cout;
  logic [$clog2(DUT_N)-1:0] y_read_idx;
  logic y_read_valid;
  logic signed [31:0] y_read_data;

  integer signed x [0:3][0:NX-1];
  integer signed h [0:3][0:3][0:NX-1];
  integer dump_fd;

  always #2 clk = ~clk;

  ntt46_zero_pad_radix2_unified_baseline #(
    .N(DUT_N),
    .PRECISION(DUT_PRECISION)
  ) dut (.*);

  task automatic preload_scalar(
    input bit is_h, input int cout, input int cin, input int idx, input int signed value
  );
    @(negedge clk);
    preload_valid = 1'b1;
    preload_is_h = is_h;
    preload_cout = cout[1:0];
    preload_cin = cin[1:0];
    preload_idx = idx;
    preload_data = value;
  endtask

  function automatic longint signed expected_value(input int cout, input int out_idx);
    longint signed sum;
    begin
      sum = 0;
      for (int cin = 0; cin < DUT_CIN; cin++) begin
        for (int xi = 0; xi < NX; xi++) begin
          int hi;
          hi = out_idx - xi;
          if ((hi >= 0) && (hi < int'(cfg_nh))) sum += x[cin][xi] * h[cout][cin][hi];
        end
      end
      return sum;
    end
  endfunction

  initial begin
    preload_valid = 1'b0;
    preload_is_h = 1'b0;
    preload_cin = '0;
    preload_cout = '0;
    preload_idx = '0;
    preload_data = '0;
    start = 1'b0;
    cfg_nh = $clog2(NX)'(NX - 1);
    cfg_cin = DUT_CIN;
    cfg_cout = DUT_COUT;
    y_read_en = 1'b0;
    y_read_cout = '0;
    y_read_idx = '0;

    repeat (5) @(negedge clk);
    rst = 1'b0;
    dump_fd = $fopen($sformatf("vectors_n%0d_int%0d_c%0do%0d.csv",
                              DUT_N, DUT_PRECISION, DUT_CIN, DUT_COUT), "w");
    if (dump_fd == 0) $fatal(1, "failed to open vector dump");
    $fwrite(dump_fd, "kind,cout,cin,index,value\n");

    for (int cin = 0; cin < DUT_CIN; cin++) begin
      for (int idx = 0; idx < NX; idx++) begin
        int signed value;
        value = ((idx * 13 + cin * 17 + 3) % (MAX_VALUE - MIN_VALUE + 1)) + MIN_VALUE;
        x[cin][idx] = value;
        $fwrite(dump_fd, "x,0,%0d,%0d,%0d\n", cin, idx, value);
        preload_scalar(1'b0, 0, cin, idx, value);
      end
    end
    for (int cout = 0; cout < DUT_COUT; cout++) begin
      for (int cin = 0; cin < DUT_CIN; cin++) begin
        for (int idx = 0; idx < int'(cfg_nh); idx++) begin
          int signed value;
          value = ((idx * 7 + cin * 11 + cout * 19 + 5) % (MAX_VALUE - MIN_VALUE + 1)) + MIN_VALUE;
          h[cout][cin][idx] = value;
          $fwrite(dump_fd, "h,%0d,%0d,%0d,%0d\n", cout, cin, idx, value);
          preload_scalar(1'b1, cout, cin, idx, value);
        end
      end
    end
    @(negedge clk);
    preload_valid = 1'b0;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
    wait (done);
    if (cfg_error) $fatal(1, "unexpected cfg_error");
    @(negedge clk);

    for (int cout = 0; cout < DUT_COUT; cout++) begin
      for (int idx = 0; idx < DUT_N; idx++) begin
        longint signed expected;
        expected = expected_value(cout, idx);
        @(negedge clk);
        y_read_en = 1'b1;
        y_read_cout = cout[1:0];
        y_read_idx = idx;
        @(negedge clk);
        if (!y_read_valid) $fatal(1, "missing valid cout=%0d idx=%0d", cout, idx);
        if (y_read_data !== expected[31:0]) begin
          $fatal(1, "mismatch precision=%0d cout=%0d idx=%0d got=%0d expected=%0d",
                 DUT_PRECISION, cout, idx, y_read_data, expected);
        end
        $fwrite(dump_fd, "y,%0d,0,%0d,%0d\n", cout, idx, $signed(y_read_data));
      end
    end
    y_read_en = 1'b0;
    $fclose(dump_fd);

    $display("tb_ntt46_zero_pad_radix2_unified_baseline PASS N=%0d precision=%0d Cin=%0d Cout=%0d cycles=%0d",
             DUT_N, DUT_PRECISION, DUT_CIN, DUT_COUT, compute_cycles);
    $finish;
  end

  initial begin
    repeat (4000000) @(posedge clk);
    $fatal(1, "timeout");
  end
endmodule
