module tb_ntt46_fact_lean_ip_unified_axi_lite_core #(
  parameter int unsigned DUT_PRECISION = 8,
  parameter int unsigned DUT_R = 128,
  parameter int unsigned DUT_LANES = 8,
  parameter int unsigned DUT_CIN = 4,
  parameter int unsigned DUT_COUT = 4,
  parameter int unsigned DUT_COUT_MAX = 4,
  parameter int unsigned DUT_NH = 127,
  parameter int unsigned DUT_PATTERN = 6,
  parameter int unsigned DUT_CHANNEL_BASE = 0,
  parameter logic [31:0] DUT_BUILD_ID = 32'h2026_0813,
  parameter int signed DUT_BOUND = 128,
  parameter bit DUT_TEST_ILLEGAL = 1'b1,
  parameter bit DUT_TEST_REPEAT_START = 1'b0,
  parameter bit DUT_TEST_BACK_TO_BACK = 1'b0,
  parameter bit DUT_TEST_REPRELOAD = 1'b0,
  parameter bit DUT_TEST_RESET_MID_TASK = 1'b0,
  parameter bit DUT_DUMP_CSV = 1'b0,
  parameter bit DUT_TRACE_TRANSFORMS = 1'b0,
  parameter int unsigned DUT_TIMEOUT_CYCLES = 800000
);

  localparam int N = 2 * DUT_R;
  localparam int POS_BOUND = DUT_BOUND - 1;

  localparam logic [7:0] REG_CTRL          = 8'h00;
  localparam logic [7:0] REG_STATUS        = 8'h04;
  localparam logic [7:0] REG_CFG_NH        = 8'h08;
  localparam logic [7:0] REG_CFG_CIN       = 8'h0c;
  localparam logic [7:0] REG_CFG_COUT      = 8'h10;
  localparam logic [7:0] REG_WALL_CYCLES   = 8'h14;
  localparam logic [7:0] REG_CORE_CYCLES   = 8'h18;
  localparam logic [7:0] REG_PRELOAD_EST   = 8'h1c;
  localparam logic [7:0] REG_READOUT_EST   = 8'h20;
  localparam logic [7:0] REG_ERROR_CODE    = 8'h24;
  localparam logic [7:0] REG_IP_ID         = 8'h28;
  localparam logic [7:0] REG_BUILD_ID      = 8'h2c;
  localparam logic [7:0] REG_CAP0          = 8'h30;
  localparam logic [7:0] REG_CAP1          = 8'h34;
  localparam logic [7:0] REG_CAP2          = 8'h38;
  localparam logic [7:0] REG_PRIME0        = 8'h3c;
  localparam logic [7:0] REG_PRIME1        = 8'h40;
  localparam logic [7:0] REG_P1_PACKETS    = 8'h44;
  localparam logic [7:0] REG_P2_PACKETS    = 8'h48;
  localparam logic [7:0] REG_Y_WRITES      = 8'h4c;

  logic clk = 1'b0;
  logic rst = 1'b1;
  always #2 clk = ~clk;

  logic [7:0] s_axi_awaddr;
  logic s_axi_awvalid;
  logic s_axi_awready;
  logic [31:0] s_axi_wdata;
  logic [3:0] s_axi_wstrb;
  logic s_axi_wvalid;
  logic s_axi_wready;
  logic [1:0] s_axi_bresp;
  logic s_axi_bvalid;
  logic s_axi_bready;
  logic [7:0] s_axi_araddr;
  logic s_axi_arvalid;
  logic s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [1:0] s_axi_rresp;
  logic s_axi_rvalid;
  logic s_axi_rready;

  logic preload_valid;
  logic preload_is_h;
  logic [1:0] preload_cin;
  logic [1:0] preload_cout;
  logic [8:0] preload_idx;
  logic signed [18:0] preload_data;
  logic preload_ready;
  logic y_read_en;
  logic [1:0] y_read_cout;
  logic [9:0] y_read_idx;
  logic y_read_valid;
  logic signed [31:0] y_read_data;
  logic y_read_ready;

  ntt46_fact_lean_ip_unified_axi_lite_core #(
    .PRECISION(DUT_PRECISION),
    .R(DUT_R),
    .LANES(DUT_LANES),
    .CIN_MAX(4),
    .COUT_MAX(DUT_COUT_MAX),
    .IP_BUILD_ID(DUT_BUILD_ID)
  ) u_dut (
    .clk(clk),
    .rst(rst),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .preload_valid(preload_valid),
    .preload_is_h(preload_is_h),
    .preload_cin(preload_cin),
    .preload_cout(preload_cout),
    .preload_idx(preload_idx),
    .preload_data(preload_data),
    .preload_ready(preload_ready),
    .y_read_en(y_read_en),
    .y_read_cout(y_read_cout),
    .y_read_idx(y_read_idx),
    .y_read_valid(y_read_valid),
    .y_read_data(y_read_data),
    .y_read_ready(y_read_ready)
  );

  generate
    if (DUT_PRECISION == 4) begin : g_trace_int4
      always @(posedge clk) begin
        if (DUT_TRACE_TRANSFORMS && u_dut.g_int4.u_precision_core.u_core.core_done)
          $display("TRACE_TRANSFORM p=p520 forward=%0d odd=%0d cycles=%0d state=%0d",
                   u_dut.g_int4.u_precision_core.u_core.core_run_forward,
                   u_dut.g_int4.u_precision_core.u_core.core_fwd_odd,
                   u_dut.g_int4.u_precision_core.u_core.core_cycles,
                   u_dut.g_int4.u_precision_core.u_core.state_q);
      end
    end else if (DUT_PRECISION == 8) begin : g_trace_int8
      always @(posedge clk) begin
        if (DUT_TRACE_TRANSFORMS && u_dut.g_int8.u_precision_core.u_core.u_p1.core_done)
          $display("TRACE_TRANSFORM p=p520 forward=%0d odd=%0d cycles=%0d state=%0d",
                   u_dut.g_int8.u_precision_core.u_core.u_p1.core_run_forward,
                   u_dut.g_int8.u_precision_core.u_core.u_p1.core_fwd_odd,
                   u_dut.g_int8.u_precision_core.u_core.u_p1.core_cycles,
                   u_dut.g_int8.u_precision_core.u_core.u_p1.state_q);
        if (DUT_TRACE_TRANSFORMS && u_dut.g_int8.u_precision_core.u_core.u_p2.core_done)
          $display("TRACE_TRANSFORM p=p254 forward=%0d odd=%0d cycles=%0d state=%0d",
                   u_dut.g_int8.u_precision_core.u_core.u_p2.core_run_forward,
                   u_dut.g_int8.u_precision_core.u_core.u_p2.core_fwd_odd,
                   u_dut.g_int8.u_precision_core.u_core.u_p2.core_cycles,
                   u_dut.g_int8.u_precision_core.u_core.u_p2.state_q);
      end
    end
  endgenerate

  int signed x_int[0:3][0:DUT_R-1];
  int signed h_int[0:3][0:3][0:DUT_R-1];
  int signed expected[0:3][0:N-1];
  integer dump_fd;

  function automatic int signed bounded_hash(input int idx, input int ch, input int co, input int salt);
    int unsigned v;
    begin
      v = (32'h4d595df4 ^ (idx*32'd1103515245) ^ (ch*32'd2654435761) ^
           ((co+1)*32'd1597334677) ^ (salt*32'd2246822519));
      v = (v ^ (v>>16)) * 32'd2246822519;
      v = (v ^ (v>>13)) * 32'd3266489917;
      v = v ^ (v>>16);
      return int'(v%(DUT_BOUND+POS_BOUND+1))-DUT_BOUND;
    end
  endfunction

  function automatic int signed sample_x(input int idx, input int ch, input int pid);
    unique case(pid)
      0: return ((idx*5+ch*3+7)%(DUT_BOUND+POS_BOUND+1))-DUT_BOUND;
      1: return POS_BOUND;
      2: return -DUT_BOUND;
      3: return ((idx+ch)&1) ? -DUT_BOUND : POS_BOUND;
      4: return (idx==(ch?17:0)) ? (ch+1) : 0;
      5: return ((idx>=DUT_R-8 || idx<3) ? (((idx+ch)&1)?-DUT_BOUND:POS_BOUND) : 0);
      7: begin
        unique case (ch)
          0: return (idx % 32) - 16;
          1: return ((idx / 16) & 1) ? 24 : -24;
          2: return ((idx * 3) % 49) - 24;
          default: return ((idx % 64) == 0) ? 31 : ((idx % 64) == 1) ? -31 : 0;
        endcase
      end
      default: return bounded_hash(idx,ch,0,17 + pid*193);
    endcase
  endfunction

  function automatic int signed sample_h(input int idx, input int ch, input int co, input int pid);
    unique case(pid)
      0: return ((idx*7+ch*11+co*13+5)%(DUT_BOUND+POS_BOUND+1))-DUT_BOUND;
      1: return POS_BOUND;
      2: return -DUT_BOUND;
      3: return (idx&1) ? POS_BOUND : -DUT_BOUND;
      4: return (idx==0) ? (ch+1+co) : 0;
      5: return ((idx<4 || idx>=DUT_R-8) ? (((idx+ch+co)&1)?POS_BOUND:-DUT_BOUND) : 0);
      7: begin
        unique case (co)
          0: return (idx < 5) ? ((idx == 2) ? 3 : ((idx == 1 || idx == 3) ? 2 : 1)) : 0;
          1: return (idx == 0) ? -(ch + 1) : (idx == 2) ? (ch + 1) : 0;
          2: return (idx < 7) ? ((ch < 2) ? 1 : -1) : 0;
          default: return (idx < 8) ? (((idx + ch) & 1) ? -1 : 1) : 0;
        endcase
      end
      default: return bounded_hash(idx,ch,co,91 + pid*389);
    endcase
  endfunction

  task automatic axi_write_strb(
    input logic [7:0] addr,
    input logic [31:0] data,
    input logic [3:0] strb
  );
    begin
      @(negedge clk);
      s_axi_awaddr = addr;
      s_axi_wdata = data;
      s_axi_wstrb = strb;
      s_axi_awvalid = 1'b1;
      s_axi_wvalid = 1'b1;
      do @(posedge clk); while (!(s_axi_awready && s_axi_wready));
      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid = 1'b0;
      do @(posedge clk); while (!s_axi_bvalid);
    end
  endtask

  task automatic axi_write(input logic [7:0] addr, input logic [31:0] data);
    begin
      axi_write_strb(addr, data, 4'hf);
    end
  endtask

  task automatic axi_read(input logic [7:0] addr, output logic [31:0] data);
    begin
      @(negedge clk);
      s_axi_araddr = addr;
      s_axi_arvalid = 1'b1;
      do @(posedge clk); while (!s_axi_arready);
      @(negedge clk);
      s_axi_arvalid = 1'b0;
      do @(posedge clk); while (!s_axi_rvalid);
      data = s_axi_rdata;
    end
  endtask

  task automatic check_axi_back_to_back_write;
    int aw_index;
    int w_index;
    int b_count;
    int guard;
    logic aw_handshake;
    logic w_handshake;
    logic [31:0] data;
    begin
      while (s_axi_bvalid) @(posedge clk);
      aw_index = 0;
      w_index = 0;
      b_count = 0;
      guard = 0;
      s_axi_bready = 1'b1;

      @(negedge clk);
      s_axi_awaddr = REG_CFG_CIN;
      s_axi_awvalid = 1'b1;
      s_axi_wdata = 32'd2;
      s_axi_wstrb = 4'hf;
      s_axi_wvalid = 1'b1;

      while ((b_count < 2) && (guard < 64)) begin
        @(posedge clk);
        aw_handshake = s_axi_awvalid && s_axi_awready;
        w_handshake = s_axi_wvalid && s_axi_wready;
        if (s_axi_bvalid && s_axi_bready) b_count++;
        @(negedge clk);
        if (aw_handshake) begin
          aw_index++;
          if (aw_index == 1) s_axi_awaddr = REG_CFG_COUT;
          else s_axi_awvalid = 1'b0;
        end
        if (w_handshake) begin
          w_index++;
          if (w_index == 1) s_axi_wdata = 32'd4;
          else s_axi_wvalid = 1'b0;
        end
        guard++;
      end

      s_axi_awvalid = 1'b0;
      s_axi_wvalid = 1'b0;
      if ((aw_index != 2) || (w_index != 2) || (b_count != 2)) begin
        $fatal(1, "AXI-Lite back-to-back writes lost a transaction aw=%0d w=%0d b=%0d",
               aw_index, w_index, b_count);
      end
      axi_read(REG_CFG_CIN, data);
      if (data[2:0] != 3'd2) $fatal(1, "Back-to-back CFG_CIN write failed: %08x", data);
      axi_read(REG_CFG_COUT, data);
      if (data[2:0] != 3'd4) $fatal(1, "Back-to-back CFG_COUT write failed: %08x", data);
      $display("axi_back_to_back_write PASS");
    end
  endtask

  task automatic check_axi_read_backpressure;
    logic [31:0] first_data;
    logic [31:0] second_data;
    begin
      while (s_axi_rvalid) @(posedge clk);
      s_axi_rready = 1'b0;

      @(negedge clk);
      s_axi_araddr = REG_IP_ID;
      s_axi_arvalid = 1'b1;
      do @(posedge clk); while (!s_axi_arready);
      @(negedge clk);
      s_axi_araddr = REG_BUILD_ID;

      // The first response must remain unchanged while RREADY is low, even
      // when the next address is already being presented by the master.
      @(posedge clk);
      @(negedge clk);
      if (!s_axi_rvalid) $fatal(1, "AXI-Lite first read response disappeared under backpressure");
      first_data = s_axi_rdata;
      if (first_data !== 32'h4641_4354) begin
        $fatal(1, "AXI-Lite stalled response was overwritten: %08x", first_data);
      end

      s_axi_rready = 1'b1;
      do @(posedge clk); while (!s_axi_arready);
      @(negedge clk);
      s_axi_arvalid = 1'b0;
      if (!s_axi_rvalid) begin
        do @(negedge clk); while (!s_axi_rvalid);
      end
      second_data = s_axi_rdata;
      if (second_data !== DUT_BUILD_ID) begin
        $fatal(1, "AXI-Lite second read response mismatch: %08x", second_data);
      end
      $display("axi_read_backpressure PASS");
    end
  endtask

  task automatic check_wstrb_semantics;
    logic [31:0] data;
    begin
      axi_write(REG_CFG_NH, 32'h0000_0155);
      axi_write_strb(REG_CFG_NH, 32'h0000_00aa, 4'b0001);
      axi_read(REG_CFG_NH, data);
      if (data[8:0] != 9'h1aa) $fatal(1, "INT8 WSTRB low-byte merge failed: %08x", data);

      axi_write_strb(REG_CFG_NH, 32'h0000_0000, 4'b0010);
      axi_read(REG_CFG_NH, data);
      if (data[8:0] != 9'h0aa) $fatal(1, "INT8 WSTRB high-byte merge failed: %08x", data);

      axi_write_strb(REG_CFG_NH, 32'hffff_ffff, 4'b0000);
      axi_read(REG_CFG_NH, data);
      if (data[8:0] != 9'h0aa) $fatal(1, "INT8 WSTRB zero write changed CFG_NH: %08x", data);

      axi_write_strb(REG_CTRL, 32'h0000_0001, 4'b0000);
      repeat (3) @(posedge clk);
      axi_read(REG_STATUS, data);
      if (data[1]) $fatal(1, "INT8 WSTRB zero write started core: %08x", data);
      $display("int8_axi_wstrb_semantics PASS");
    end
  endtask

  task automatic check_capability_regs;
    logic [31:0] data;
    logic [7:0] expected_flags;
    logic [7:0] expected_precision;
    begin
      if (DUT_PRECISION == 4) begin
        expected_flags = {4'd0, (DUT_COUT_MAX < 4), 2'd0, 1'b1};
        expected_precision = 8'd4;
      end else begin
        expected_flags = {4'd0, (DUT_COUT_MAX < 4), 2'd0, 1'b1};
        expected_precision = 8'd8;
      end
      axi_read(REG_IP_ID, data);
      if (data !== 32'h4641_4354) $fatal(1, "Bad INT8 IP_ID got=%08x", data);
      axi_read(REG_BUILD_ID, data);
      if (data !== DUT_BUILD_ID) $fatal(1, "Bad unified BUILD_ID got=%08x", data);
      axi_read(REG_CAP0, data);
      if (int'(data[15:0]) != N || int'(data[31:16]) != DUT_R) begin
        $fatal(1, "Bad INT8 CAP0 got=%08x expected R=%0d N=%0d", data, DUT_R, N);
      end
      axi_read(REG_CAP1, data);
      if (int'(data[7:0]) != DUT_PRECISION || int'(data[15:8]) != DUT_LANES ||
          int'(data[23:16]) != 4 || int'(data[31:24]) != DUT_COUT_MAX) begin
        $fatal(1, "Bad INT8 CAP1 got=%08x", data);
      end
      axi_read(REG_CAP2, data);
      if (data[7:0] != expected_precision || data[15:8] != 8'd1 || data[23:16] != expected_flags) begin
        $fatal(1, "Bad INT8 CAP2 got=%08x expected_precision=%0d expected_flags=%02x",
               data, expected_precision, expected_flags);
      end
      axi_read(REG_PRIME0, data);
      if (data != 32'd520193) $fatal(1, "Bad INT8 PRIME0 got=%0d", data);
      axi_read(REG_PRIME1, data);
      if (data != ((DUT_PRECISION == 4) ? 32'd0 : 32'd254977))
        $fatal(1, "Bad unified PRIME1 got=%0d", data);
      $display("unified_capability_regs PASS ip_id=FACT build_id=%08x R=%0d N=%0d L=%0d cout_max=%0d precision=%0d exact_linear=1",
               DUT_BUILD_ID, DUT_R, N, DUT_LANES, DUT_COUT_MAX,
               DUT_PRECISION);
    end
  endtask

  task automatic wait_done(output logic [31:0] status);
    int guard;
    begin
      guard = 0;
      do begin
        axi_read(REG_STATUS, status);
        guard++;
        if (guard > DUT_TIMEOUT_CYCLES) $fatal(1, "INT8 AXI timeout");
      end while (!status[2]);
    end
  endtask

  task automatic wait_busy_seen(output logic [31:0] status);
    int guard;
    begin
      guard = 0;
      do begin
        axi_read(REG_STATUS, status);
        guard++;
        if (guard > 1000) $fatal(1, "INT8 AXI wrapper did not assert busy/done after start");
      end while (!status[1] && !status[2]);
    end
  endtask

  task automatic expect_cfg_error(input logic [31:0] nh_v, input logic [31:0] cin_v,
                                  input logic [31:0] cout_v, input logic [3:0] expected_error);
    logic [31:0] status;
    begin
      axi_write(REG_CFG_NH, nh_v);
      axi_write(REG_CFG_CIN, cin_v);
      axi_write(REG_CFG_COUT, cout_v);
      axi_write(REG_CTRL, 32'd1);
      wait_done(status);
      if (!status[3]) $fatal(1, "Expected INT8 AXI cfg_error");
      axi_read(REG_ERROR_CODE, status);
      if (status[3:0] != expected_error) begin
        $fatal(1, "Expected error %0d got %0d", expected_error, status[3:0]);
      end
      axi_write(REG_CTRL, 32'd2);
      repeat (2) @(posedge clk);
    end
  endtask

  task automatic prepare_with_pattern(input int pattern_id);
    begin
      for (int ch = 0; ch < 4; ch++)
        for (int i = 0; i < DUT_R; i++)
          x_int[ch][i] = (ch < DUT_CIN) ? sample_x(i, ch + DUT_CHANNEL_BASE, pattern_id) : 0;

      for (int co = 0; co < 4; co++)
        for (int ch = 0; ch < 4; ch++)
          for (int i = 0; i < DUT_R; i++)
            h_int[co][ch][i] = ((co < DUT_COUT) && (ch < DUT_CIN) && (i < DUT_NH))
                                     ? sample_h(i, ch + DUT_CHANNEL_BASE, co, pattern_id) : 0;

      for (int co = 0; co < 4; co++) begin
        for (int i = 0; i < N; i++) expected[co][i] = 0;
        for (int ch = 0; ch < DUT_CIN; ch++)
          for (int i = 0; i < DUT_R; i++)
            for (int j = 0; j < DUT_NH; j++)
              expected[co][i+j] += x_int[ch][i] * h_int[co][ch][j];
      end
    end
  endtask

  task automatic prepare;
    prepare_with_pattern(DUT_PATTERN);
  endtask

  task automatic preload_x(input int ch);
    begin
      for (int i = 0; i < DUT_R; i++) begin
        @(negedge clk);
        while (!preload_ready) @(negedge clk);
        preload_valid = 1'b1;
        preload_is_h = 1'b0;
        preload_cin = ch[1:0];
        preload_cout = '0;
        preload_idx = i[8:0];
        preload_data = x_int[ch][i][18:0];
      end
      @(negedge clk);
      preload_valid = 1'b0;
    end
  endtask

  task automatic preload_h(input int co, input int ch);
    begin
      for (int i = 0; i < DUT_R; i++) begin
        @(negedge clk);
        while (!preload_ready) @(negedge clk);
        preload_valid = 1'b1;
        preload_is_h = 1'b1;
        preload_cin = ch[1:0];
        preload_cout = co[1:0];
        preload_idx = i[8:0];
        preload_data = h_int[co][ch][i][18:0];
      end
      @(negedge clk);
      preload_valid = 1'b0;
    end
  endtask

  task automatic check_native_request_boundaries;
    logic [31:0] data;
    begin
      y_read_cout = '0;
      y_read_idx = '0;
      y_read_en = 1'b1;
      repeat (3) @(posedge clk);
      if (y_read_ready || y_read_valid)
        $fatal(1, "Native read was accepted before a completed task");
      @(negedge clk);
      y_read_en = 1'b0;

      axi_write(REG_CFG_CIN, 32'd1);
      axi_write(REG_CFG_COUT, 32'd1);
      @(negedge clk);
      while (!preload_ready) @(negedge clk);
      preload_valid = 1'b1;
      preload_is_h = 1'b0;
      preload_cin = 2'd1;
      preload_cout = 2'd0;
      preload_idx = DUT_R[8:0];
      preload_data = '0;
      @(negedge clk);
      preload_valid = 1'b0;
      repeat (2) @(posedge clk);
      axi_read(REG_STATUS, data);
      if (!data[5]) $fatal(1, "Invalid native preload metadata did not set STATUS.preload_error");
      axi_read(REG_ERROR_CODE, data);
      if (data[3:0] != 4'd4) $fatal(1, "Invalid native preload returned error %0d, expected 4", data[3:0]);
      axi_write(REG_CTRL, 32'd2);

      @(negedge clk);
      while (!preload_ready) @(negedge clk);
      preload_valid = 1'b1;
      preload_idx = '0;
      preload_cin = '0;
      preload_data = (DUT_PRECISION == 4) ? 19'sd8 : 19'sd128;
      @(negedge clk);
      preload_valid = 1'b0;
      repeat (2) @(posedge clk);
      axi_read(REG_STATUS, data);
      if (!data[5]) $fatal(1, "Out-of-range native sample did not set STATUS.preload_error");
      axi_write(REG_CTRL, 32'd2);
      $display("native_request_boundaries PASS");
    end
  endtask

  task automatic read_and_check(input int co, input int idx);
    int wait_cycles;
    begin
      @(negedge clk);
      y_read_en = 1'b1;
      y_read_cout = co[1:0];
      y_read_idx = idx[9:0];
      @(negedge clk);
      y_read_en = 1'b0;
      for (wait_cycles = 0; (wait_cycles < 16) && !y_read_valid; wait_cycles++) begin
        @(negedge clk);
      end
      if (!y_read_valid) $fatal(1, "Missing INT8 AXI y_read_valid co=%0d idx=%0d", co, idx);
      if (y_read_data !== expected[co][idx]) begin
        $fatal(1, "INT8 AXI mismatch co=%0d i=%0d got=%0d exp=%0d", co, idx, y_read_data, expected[co][idx]);
      end
      if (dump_fd != 0) $fdisplay(dump_fd, "%0d,%0d,%0d", co, idx, $signed(y_read_data));
    end
  endtask

  task automatic run_valid_task(
    input bit do_preload,
    input bit inject_repeat_start,
    output logic [31:0] wall_cycles,
    output logic [31:0] core_cycles
  );
    logic [31:0] status;
    logic [31:0] preload_est;
    logic [31:0] readout_est;
    logic [31:0] packets;
    begin
      dump_fd = 0;
      axi_write(REG_CFG_NH, DUT_NH[31:0]);
      axi_write(REG_CFG_CIN, DUT_CIN[31:0]);
      axi_write(REG_CFG_COUT, DUT_COUT[31:0]);

      if (do_preload) begin
        for (int ch = 0; ch < DUT_CIN; ch++) preload_x(ch);
        for (int co = 0; co < DUT_COUT; co++)
          for (int ch = 0; ch < DUT_CIN; ch++) preload_h(co, ch);
      end

      axi_write(REG_CTRL, 32'd1);
      if (DUT_TEST_ILLEGAL) begin
        wait_busy_seen(status);
        if (preload_ready) $fatal(1, "Native preload_ready remained high while core was busy");
        axi_write(REG_CFG_CIN, 32'd2);
        axi_read(REG_CFG_CIN, packets);
        if (packets != DUT_CIN)
          $fatal(1, "Runtime configuration changed while busy got=%0d expected=%0d", packets, DUT_CIN);
      end
      if (inject_repeat_start) begin
        wait_busy_seen(status);
        if (!status[1]) $fatal(1, "INT8 repeat-start test reached done before busy status=%08x", status);
        axi_write(REG_CTRL, 32'd1);
      end

      wait_done(status);
      if (status[5:3] != 0) begin
        axi_read(REG_ERROR_CODE, status);
        $fatal(1, "Unexpected INT8 AXI error status=%08x code=%0d", status, status[3:0]);
      end

      if (DUT_TEST_ILLEGAL) begin
        if (DUT_COUT < 4) begin
          @(negedge clk);
          y_read_en = 1'b1;
          y_read_cout = DUT_COUT[1:0];
          y_read_idx = '0;
          repeat (3) @(posedge clk);
          if (y_read_ready || y_read_valid)
            $fatal(1, "Out-of-range native Cout read was accepted after completion");
          @(negedge clk);
          y_read_en = 1'b0;
        end
        if (N < 1024) begin
          @(negedge clk);
          y_read_en = 1'b1;
          y_read_cout = '0;
          y_read_idx = N[9:0];
          repeat (3) @(posedge clk);
          if (y_read_ready || y_read_valid)
            $fatal(1, "Out-of-range native index read was accepted after completion");
          @(negedge clk);
          y_read_en = 1'b0;
        end
      end

      if (DUT_DUMP_CSV) begin
        dump_fd = $fopen("fact_output.csv", "w");
        if (dump_fd == 0) $fatal(1, "Could not open fact_output.csv");
        $fdisplay(dump_fd,
                  "# R=%0d,N=%0d,LANES=%0d,CIN=%0d,COUT=%0d,NH=%0d,PATTERN=%0d,BOUND=%0d",
                  DUT_R, N, DUT_LANES, DUT_CIN, DUT_COUT, DUT_NH, DUT_PATTERN,
                  DUT_BOUND);
        $fdisplay(dump_fd, "cout,index,y");
      end

      for (int co = 0; co < DUT_COUT; co++)
        for (int i = 0; i < N; i++) read_and_check(co, i);
      if (dump_fd != 0) begin
        $fclose(dump_fd);
        dump_fd = 0;
      end

      axi_read(REG_WALL_CYCLES, wall_cycles);
      axi_read(REG_CORE_CYCLES, core_cycles);
      axi_read(REG_PRELOAD_EST, preload_est);
      axi_read(REG_READOUT_EST, readout_est);
      if ((wall_cycles == 0) || (core_cycles == 0)) $fatal(1, "Zero INT8 cycle counters wall=%0d core=%0d", wall_cycles, core_cycles);

      if (DUT_PRECISION == 8) begin
        axi_read(REG_P1_PACKETS, packets);
        if (packets != 0)
          $fatal(1, "Reserved P1_PACKETS register must read zero, got=%0d", packets);
        axi_read(REG_P2_PACKETS, packets);
        if (packets != 0)
          $fatal(1, "Reserved P2_PACKETS register must read zero, got=%0d", packets);
        axi_read(REG_Y_WRITES, packets);
        if (packets != 0)
          $fatal(1, "Reserved Y_WRITES register must read zero, got=%0d", packets);
      end

      $display("int8_valid_task PASS preload=%0d repeat_start=%0d wall_cycles=%0d core_compute_cycles=%0d preload_est=%0d readout_est=%0d",
               do_preload, inject_repeat_start, wall_cycles, core_cycles, preload_est, readout_est);
    end
  endtask

  task automatic run_reset_mid_task_smoke;
    logic [31:0] status;
    logic [31:0] wall_cycles;
    logic [31:0] core_cycles;
    begin
      axi_write(REG_CFG_NH, DUT_NH[31:0]);
      axi_write(REG_CFG_CIN, DUT_CIN[31:0]);
      axi_write(REG_CFG_COUT, DUT_COUT[31:0]);
      for (int ch = 0; ch < DUT_CIN; ch++) preload_x(ch);
      for (int co = 0; co < DUT_COUT; co++)
        for (int ch = 0; ch < DUT_CIN; ch++) preload_h(co, ch);

      axi_write(REG_CTRL, 32'd1);
      wait_busy_seen(status);
      if (!status[1]) $fatal(1, "INT8 reset-mid-task test reached done before busy status=%08x", status);

      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid = 1'b0;
      s_axi_arvalid = 1'b0;
      preload_valid = 1'b0;
      y_read_en = 1'b0;
      rst = 1'b1;
      repeat (6) @(posedge clk);
      rst = 1'b0;
      repeat (4) @(posedge clk);
      axi_read(REG_STATUS, status);
      if (status[1]) $fatal(1, "INT8 core remained busy after reset status=%08x", status);

      run_valid_task(1'b1, 1'b0, wall_cycles, core_cycles);
      $display("int8_reset_mid_task_smoke PASS recovered_wall=%0d recovered_core=%0d", wall_cycles, core_cycles);
    end
  endtask

  initial begin
    logic [31:0] status;
    logic [31:0] wall_cycles;
    logic [31:0] core_cycles;

    prepare();
    s_axi_awaddr = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = '0;
    s_axi_wstrb = '0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b1;
    s_axi_araddr = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b1;
    preload_valid = 1'b0;
    preload_is_h = 1'b0;
    preload_cin = '0;
    preload_cout = '0;
    preload_idx = '0;
    preload_data = '0;
    y_read_en = 1'b0;
    y_read_cout = '0;
    y_read_idx = '0;

    repeat (8) @(posedge clk);
    rst = 1'b0;
    repeat (3) @(posedge clk);

    check_capability_regs();
    check_wstrb_semantics();
    if (DUT_TEST_ILLEGAL) begin
      check_axi_back_to_back_write();
      check_axi_read_backpressure();
      check_native_request_boundaries();
    end

    if (DUT_TEST_ILLEGAL) begin
      expect_cfg_error(32'd0, 32'd1, 32'd1, 4'd1);
      expect_cfg_error(32'd1, 32'd3, 32'd1, 4'd2);
      expect_cfg_error(32'd1, 32'd1, 32'd3, 4'd3);
      if (DUT_COUT_MAX < 4) expect_cfg_error(32'd1, 32'd1, 32'd4, 4'd3);
    end

    run_valid_task(1'b1, DUT_TEST_REPEAT_START, wall_cycles, core_cycles);
    if (DUT_TEST_BACK_TO_BACK) run_valid_task(1'b0, 1'b0, wall_cycles, core_cycles);
    if (DUT_TEST_REPRELOAD) begin
      prepare_with_pattern(DUT_PATTERN + 17);
      run_valid_task(1'b1, 1'b0, wall_cycles, core_cycles);
      $display("changed_data_back_to_back PASS wall_cycles=%0d core_compute_cycles=%0d",
               wall_cycles, core_cycles);
    end
    if (DUT_TEST_RESET_MID_TASK) run_reset_mid_task_smoke();

    $display("tb_ntt46_fact_lean_ip_unified_axi_lite_core PASS R=%0d N=%0d L=%0d Cin=%0d Cout=%0d Nh=%0d bound=%0d wall_cycles=%0d core_compute_cycles=%0d preload_est=%0d readout_est=%0d",
             DUT_R, N, DUT_LANES, DUT_CIN, DUT_COUT, DUT_NH, DUT_BOUND,
             wall_cycles, core_cycles,
             (DUT_CIN * DUT_R) + (DUT_COUT * DUT_CIN * DUT_R),
             DUT_COUT * N);
    $finish;
  end

endmodule
