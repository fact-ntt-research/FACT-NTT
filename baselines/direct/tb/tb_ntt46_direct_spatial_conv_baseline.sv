module tb_ntt46_direct_spatial_conv_baseline;

  parameter int unsigned NX = 512;
  parameter int unsigned PAR = 16;
  parameter int unsigned DATA_W = 18;
  parameter int unsigned ACC_W = 32;
  parameter bit DUT_SERIAL = 1'b0;
  parameter bit DUT_PARPIPE = 1'b0;
  parameter bit DUT_DEBUG = 1'b0;
  parameter int unsigned DUT_CIN_MAX = 2;
  parameter bit DUT_SINGLE_CASE = 1'b0;
  parameter int unsigned DUT_SINGLE_PATTERN = 0;
  parameter int unsigned DUT_SINGLE_NH = 0;
  parameter int unsigned DUT_SINGLE_CIN = 1;

  localparam int unsigned N = 2 * NX;
  localparam int unsigned CHUNKS = (NX + PAR - 1) / PAR;
  localparam int unsigned MAX_RUN_CYCLES = (2 * NX) * CHUNKS * 3 + 100;
  localparam int signed TEST_MIN = -(1 << (DATA_W - 1));
  localparam int signed TEST_MAX = (1 << (DATA_W - 1)) - 1;
  localparam int unsigned TEST_RANGE = TEST_MAX - TEST_MIN + 1;

  logic clk = 1'b0;
  logic rst;
  always #2 clk = ~clk;

  logic load_en;
  logic load_is_h;
  logic [(DUT_CIN_MAX <= 2 ? 1 : $clog2(DUT_CIN_MAX))-1:0] load_ch;
  logic [$clog2(NX)-1:0] load_idx;
  logic signed [DATA_W-1:0] load_data;
  logic start;
  logic [2:0] cfg_cin;
  logic [$clog2(NX+1)-1:0] cfg_nh;
  logic busy;
  logic done;
  logic [31:0] compute_cycles;
  logic out_valid;
  logic [$clog2(N)-1:0] out_idx;
  logic signed [ACC_W-1:0] out_data;

  int nh_cases [0:8];
  int signed x_int [0:DUT_CIN_MAX-1][0:NX-1];
  int signed h_int [0:DUT_CIN_MAX-1][0:NX-1];
  int signed expected [0:N-1];
  longint signed got [0:N-1];
  bit seen [0:N-1];
  int pass_count;
  int last_cin1_cycles;
  int last_cin2_cycles;
  int last_cin4_cycles;

  generate
    if (DUT_PARPIPE) begin : g_parpipe
      ntt46_direct_spatial_parpipe_baseline #(
        .NX(NX),
        .PAR(PAR),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .CIN_MAX(DUT_CIN_MAX),
        .DEBUG(DUT_DEBUG)
      ) u_dut (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .load_is_h(load_is_h),
        .load_ch(load_ch),
        .load_idx(load_idx),
        .load_data(load_data),
        .start(start),
        .cfg_cin(cfg_cin),
        .cfg_nh(cfg_nh),
        .busy(busy),
        .done(done),
        .compute_cycles(compute_cycles),
        .out_valid(out_valid),
        .out_idx(out_idx),
        .out_data(out_data)
      );
    end else if (DUT_SERIAL) begin : g_serial
      ntt46_direct_spatial_serial_baseline #(
        .NX(NX),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
      ) u_dut (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .load_is_h(load_is_h),
        .load_ch(load_ch[0]),
        .load_idx(load_idx),
        .load_data(load_data),
        .start(start),
        .cfg_cin(cfg_cin[1:0]),
        .cfg_nh(cfg_nh),
        .busy(busy),
        .done(done),
        .compute_cycles(compute_cycles),
        .out_valid(out_valid),
        .out_idx(out_idx),
        .out_data(out_data)
      );
    end else begin : g_parallel
      ntt46_direct_spatial_conv_baseline #(
        .NX(NX),
        .PAR(PAR),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
      ) u_dut (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .load_is_h(load_is_h),
        .load_ch(load_ch[0]),
        .load_idx(load_idx),
        .load_data(load_data),
        .start(start),
        .cfg_cin(cfg_cin[1:0]),
        .cfg_nh(cfg_nh),
        .busy(busy),
        .done(done),
        .compute_cycles(compute_cycles),
        .out_valid(out_valid),
        .out_idx(out_idx),
        .out_data(out_data)
      );
    end
  endgenerate

  function automatic int signed bounded_hash(input int idx, input int ch, input int pid, input int salt);
    int v;
    begin
      v = (idx * 73 + ch * 41 + pid * 29 + salt * 17 + 11) % TEST_RANGE;
      bounded_hash = v + TEST_MIN;
    end
  endfunction

  function automatic int signed sample_x(input int idx, input int ch, input int pid);
    begin
      unique case (pid)
        1: sample_x = TEST_MAX;
        2: sample_x = TEST_MIN;
        3: sample_x = ((idx + ch) & 1) ? TEST_MIN : TEST_MAX;
        4: sample_x = (idx == (ch * 3)) ? TEST_MAX : 0;
        5: sample_x = ((idx < 3) || (idx > int'(NX) - 4)) ? bounded_hash(idx, ch, pid, 3) : 0;
        default: sample_x = bounded_hash(idx, ch, pid, 1);
      endcase
    end
  endfunction

  function automatic int signed sample_h(input int idx, input int ch, input int pid, input int nh);
    begin
      if (idx >= nh) begin
        sample_h = 0;
      end else begin
        unique case (pid)
          1: sample_h = TEST_MAX;
          2: sample_h = TEST_MIN;
          3: sample_h = ((idx + ch) & 1) ? TEST_MAX : TEST_MIN;
          4: sample_h = (idx == 0) ? TEST_MAX : 0;
          5: sample_h = ((idx < 3) || (idx > nh - 4)) ? bounded_hash(idx, ch, pid, 7) : 0;
          default: sample_h = bounded_hash(idx, ch, pid, 5);
        endcase
      end
    end
  endfunction

  task automatic init_nh_cases;
    begin
      nh_cases[0] = 1;
      nh_cases[1] = 2;
      nh_cases[2] = (NX / 4) - 1;
      nh_cases[3] = (NX / 4);
      nh_cases[4] = (NX / 4) + 1;
      nh_cases[5] = (NX / 2) - 1;
      nh_cases[6] = (NX / 2);
      nh_cases[7] = (NX / 2) + 1;
      nh_cases[8] = NX - 1;
    end
  endtask

  task automatic prepare_case(input int pid, input int nh, input int cin);
    begin
      for (int ch = 0; ch < DUT_CIN_MAX; ch++) begin
        for (int i = 0; i < NX; i++) begin
          x_int[ch][i] = sample_x(i, ch, pid);
          h_int[ch][i] = sample_h(i, ch, pid, nh);
        end
      end
      for (int k = 0; k < N; k++) begin
        expected[k] = 0;
        got[k] = '0;
        seen[k] = 1'b0;
      end
      for (int ch = 0; ch < cin; ch++) begin
        for (int i = 0; i < NX; i++) begin
          for (int j = 0; j < nh; j++) begin
            expected[i+j] += x_int[ch][i] * h_int[ch][j];
          end
        end
      end
    end
  endtask

  task automatic load_case(input int cin);
    begin
      for (int ch = 0; ch < DUT_CIN_MAX; ch++) begin
        for (int i = 0; i < NX; i++) begin
          @(negedge clk);
          load_en = 1'b1;
          load_is_h = 1'b0;
          load_ch = ch;
          load_idx = i[$clog2(NX)-1:0];
          load_data = DATA_W'(x_int[ch][i]);
          @(negedge clk);
          load_is_h = 1'b1;
          load_data = DATA_W'(h_int[ch][i]);
        end
      end
      @(negedge clk);
      load_en = 1'b0;
      load_is_h = 1'b0;
      load_ch = 1'b0;
      load_idx = '0;
      load_data = '0;
    end
  endtask

  task automatic run_case(input int pid, input int nh, input int cin);
    int guard;
    int max_guard;
    begin
      prepare_case(pid, nh, cin);
      @(negedge clk);
      rst = 1'b1;
      load_en = 1'b0;
      start = 1'b0;
      cfg_cin = cin[2:0];
      cfg_nh = nh[$clog2(NX+1)-1:0];
      repeat (8) @(posedge clk);
      @(negedge clk);
      rst = 1'b0;

      load_case(cin);

      @(negedge clk);
      start = 1'b1;
      @(negedge clk);
      start = 1'b0;

      max_guard = (2 * int'(NX)) * int'(CHUNKS) * 3 + 100;
      guard = 0;
      while ((done !== 1'b1) && (guard < max_guard)) begin
        @(posedge clk);
        guard++;
      end
      if (done !== 1'b1) begin
        $fatal(1, "DIRECT timeout NX=%0d PAR=%0d pid=%0d nh=%0d cin=%0d guard=%0d", NX, PAR, pid, nh, cin, guard);
      end
      repeat (2) @(posedge clk);

      if (cin == 1) last_cin1_cycles = compute_cycles;
      else if (cin == 2) last_cin2_cycles = compute_cycles;
      else if (cin == 4) last_cin4_cycles = compute_cycles;

      for (int k = 0; k < N; k++) begin
        if (!seen[k]) begin
          $fatal(1, "DIRECT missing output k=%0d", k);
        end
        if (got[k] !== expected[k]) begin
          $fatal(1, "DIRECT mismatch k=%0d got=%0d exp=%0d pid=%0d nh=%0d cin=%0d", k, got[k], expected[k], pid, nh, cin);
        end
      end
      pass_count++;
      $display("DIRECT PASS NX=%0d PAR=%0d pid=%0d nh=%0d cin=%0d cycles=%0d", NX, PAR, pid, nh, cin, compute_cycles);
    end
  endtask

  always_ff @(posedge clk) begin
    if (!rst && out_valid) begin
      if (out_idx >= N) begin
        $fatal(1, "DIRECT out_idx OOB %0d", out_idx);
      end
      got[out_idx] <= out_data;
      seen[out_idx] <= 1'b1;
    end
  end

  initial begin
    pass_count = 0;
    last_cin1_cycles = 0;
    last_cin2_cycles = 0;
    last_cin4_cycles = 0;
    rst = 1'b1;
    load_en = 1'b0;
    load_is_h = 1'b0;
    load_ch = 1'b0;
    load_idx = '0;
    load_data = '0;
    start = 1'b0;
    cfg_cin = 3'd1;
    cfg_nh = '0;
    init_nh_cases();

    if (DUT_SINGLE_CASE) begin
      int selected_nh;
      selected_nh = (DUT_SINGLE_NH == 0) ? (NX - 1) : int'(DUT_SINGLE_NH);
      if ((selected_nh < 1) || (selected_nh >= NX)) begin
        $fatal(1, "Invalid DUT_SINGLE_NH=%0d for NX=%0d", selected_nh, NX);
      end
      if ((DUT_SINGLE_CIN != 1) && (DUT_SINGLE_CIN != 2) &&
          !((DUT_SINGLE_CIN == 4) && (DUT_CIN_MAX >= 4))) begin
        $fatal(1, "Invalid DUT_SINGLE_CIN=%0d", DUT_SINGLE_CIN);
      end
      run_case(int'(DUT_SINGLE_PATTERN), selected_nh, int'(DUT_SINGLE_CIN));
    end else begin
      for (int pid = 0; pid < 7; pid++) begin
        for (int nidx = 0; nidx < 9; nidx++) begin
          run_case(pid, nh_cases[nidx], 1);
          run_case(pid, nh_cases[nidx], 2);
          if (DUT_CIN_MAX >= 4) run_case(pid, nh_cases[nidx], 4);
        end
      end
    end

      $display("tb_ntt46_direct_spatial_conv_baseline PASS NX=%0d N=%0d PAR=%0d serial=%0d parpipe=%0d cases=%0d single=%0d cin1=%0d cin2=%0d cin4=%0d",
               NX, N, PAR, DUT_SERIAL, DUT_PARPIPE, pass_count, DUT_SINGLE_CASE,
               last_cin1_cycles, last_cin2_cycles, last_cin4_cycles);
    $finish;
  end

endmodule
