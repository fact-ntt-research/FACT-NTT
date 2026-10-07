module ntt46_fact_lean_ip_int8_axi_lite_core #(
  parameter int unsigned R = 512,
  parameter int unsigned LANES = 16,
  parameter int unsigned COUT_MAX = 4,
  parameter logic [31:0] IP_BUILD_ID = 32'h2026_0703
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

  localparam logic [15:0] CAP_N = 16'(2 * R);
  localparam logic [15:0] CAP_R = 16'(R);
  localparam logic [7:0]  CAP_LANES = 8'(LANES);
  localparam logic [7:0]  CAP_CIN_MAX = 8'd4;
  localparam logic [7:0]  CAP_COUT_MAX = 8'(COUT_MAX);
  localparam logic [7:0]  CAP_PRECISION_ID = 8'd8;
  localparam logic [7:0]  CAP_FLAGS = {4'd0, (COUT_MAX < 4), 2'd0, 1'b1};
  logic [8:0] cfg_nh_q;
  logic [2:0] cfg_cin_q, cfg_cout_q;
  logic start_pulse_q;
  logic start_pending_q;
  logic done_sticky_q;

  logic core_busy, core_done, core_cfg_error;
  logic core_status_error, core_preload_error;
  logic [3:0] core_preload_pending;
  logic [3:0] core_error_code;
  logic [31:0] wall_cycles, core_compute_cycles;
  logic [31:0] preload_cycles_est, readout_cycles_est;
  logic [31:0] core_p1_packets, core_p2_packets, core_y_writes;
  logic preload_error_sticky_q;
  logic [5:0] preload_pipe_q;
  logic preload_meta_valid_c, preload_data_valid_c, preload_accept_c;
  logic y_read_request_valid_c;
  logic task_active_c;

  logic aw_pending_q;
  logic w_pending_q;
  logic [7:0] awaddr_q;
  logic [31:0] wdata_q;
  logic [3:0] wstrb_q;
  logic write_fire_c, read_fire_c;
  logic [31:0] read_data_c;

  assign write_fire_c = aw_pending_q && w_pending_q && !s_axi_bvalid;
  assign read_fire_c = s_axi_arready && s_axi_arvalid;
  assign s_axi_awready = !rst && !aw_pending_q && !s_axi_bvalid;
  assign s_axi_wready = !rst && !w_pending_q && !s_axi_bvalid;
  assign s_axi_arready = !rst && !s_axi_rvalid;
  assign task_active_c = core_busy || start_pending_q || start_pulse_q;
  assign preload_ready = !rst && !task_active_c;
  assign preload_meta_valid_c = (preload_idx < R) &&
                                ({1'b0, preload_cin} < cfg_cin_q) &&
                                (!preload_is_h ||
                                 ({1'b0, preload_cout} < cfg_cout_q));
  assign preload_data_valid_c = ($signed(preload_data) >= -19'sd128) &&
                                ($signed(preload_data) <= 19'sd127);
  assign preload_accept_c = preload_valid && preload_ready &&
                            preload_meta_valid_c && preload_data_valid_c;
  assign y_read_request_valid_c = (y_read_cout < cfg_cout_q) &&
                                  (y_read_idx < (2 * R));
  assign y_read_ready = !rst && done_sticky_q && !task_active_c &&
                        y_read_request_valid_c;

  ntt46_fact_lean_ip_int8_parallel_prime_core #(
    .R(R),
    .LANES(LANES),
    .COUT_MAX(COUT_MAX),
    .INT8_OUTPUT_PIPELINE(1'b0),
    .PRODUCT32_INPUT_PIPELINE(1'b0)
  ) u_core (
    .clk(clk), .rst(rst),
    .cfg_nh(cfg_nh_q), .cfg_cin_tile(cfg_cin_q),
    .cfg_cout_tile(cfg_cout_q),
    .preload_valid(preload_accept_c), .preload_is_h(preload_is_h),
    .preload_cin(preload_cin), .preload_cout(preload_cout),
    .preload_idx(preload_idx), .preload_data(preload_data),
    .start(start_pulse_q), .busy(core_busy), .done(core_done),
    .cfg_error(core_cfg_error),
    .error_code(core_error_code), .wall_cycles(wall_cycles),
    .core_compute_cycles(core_compute_cycles),
    .preload_cycles_est(preload_cycles_est),
    .readout_cycles_est(readout_cycles_est),
    .y_read_en(y_read_en && y_read_ready), .y_read_cout(y_read_cout),
    .y_read_idx(y_read_idx), .y_read_valid(y_read_valid),
    .y_read_data(y_read_data)
  );

  assign core_status_error = 1'b0;
  assign core_preload_error = preload_valid && preload_ready &&
                              (!preload_meta_valid_c || !preload_data_valid_c);
  assign core_preload_pending = 4'($countones(preload_pipe_q));
  assign core_p1_packets = '0;
  assign core_p2_packets = '0;
  assign core_y_writes = '0;

  always_comb begin
    unique case (s_axi_araddr[7:0])
      REG_CTRL:        read_data_c = 32'd0;
      REG_STATUS:      read_data_c = {22'd0, core_preload_pending,
                                      preload_error_sticky_q, core_status_error,
                                      core_cfg_error, done_sticky_q,
                                      task_active_c, 1'b0};
      REG_CFG_NH:      read_data_c = {23'd0, cfg_nh_q};
      REG_CFG_CIN:     read_data_c = {29'd0, cfg_cin_q};
      REG_CFG_COUT:    read_data_c = {29'd0, cfg_cout_q};
      REG_WALL_CYCLES: read_data_c = wall_cycles;
      REG_CORE_CYCLES: read_data_c = core_compute_cycles;
      REG_PRELOAD_EST: read_data_c = preload_cycles_est;
      REG_READOUT_EST: read_data_c = readout_cycles_est;
      REG_ERROR_CODE:  read_data_c = {28'd0,
                                      (preload_error_sticky_q ? 4'd4 : core_error_code)};
      REG_IP_ID:       read_data_c = 32'h4641_4354; // "FACT"
      REG_BUILD_ID:    read_data_c = IP_BUILD_ID;
      REG_CAP0:        read_data_c = {CAP_R, CAP_N};
      REG_CAP1:        read_data_c = {CAP_COUT_MAX, CAP_CIN_MAX, CAP_LANES, 8'd8};
      REG_CAP2:        read_data_c = {8'd0, CAP_FLAGS, 8'd1, CAP_PRECISION_ID};
      REG_PRIME0:      read_data_c = 32'd520193;
      REG_PRIME1:      read_data_c = 32'd254977;
      REG_P1_PACKETS:  read_data_c = core_p1_packets;
      REG_P2_PACKETS:  read_data_c = core_p2_packets;
      REG_Y_WRITES:    read_data_c = core_y_writes;
      default:         read_data_c = 32'hbad0_0000;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      cfg_nh_q <= R - 1;
      cfg_cin_q <= 3'd1;
      cfg_cout_q <= 3'd1;
      start_pulse_q <= 1'b0;
      start_pending_q <= 1'b0;
      done_sticky_q <= 1'b0;
      preload_error_sticky_q <= 1'b0;
      preload_pipe_q <= '0;
      aw_pending_q <= 1'b0;
      w_pending_q <= 1'b0;
      awaddr_q <= '0;
      wdata_q <= '0;
      wstrb_q <= '0;
      s_axi_bvalid <= 1'b0;
      s_axi_bresp <= 2'b00;
      s_axi_rvalid <= 1'b0;
      s_axi_rresp <= 2'b00;
      s_axi_rdata <= 32'd0;
    end else begin
      start_pulse_q <= 1'b0;
      preload_pipe_q <= {preload_pipe_q[4:0], preload_accept_c};
      if (core_done) done_sticky_q <= 1'b1;
      if (core_preload_error) preload_error_sticky_q <= 1'b1;
      if (start_pending_q && (preload_pipe_q == '0) && !preload_accept_c) begin
        start_pending_q <= 1'b0;
        start_pulse_q <= 1'b1;
      end

      if (s_axi_awready && s_axi_awvalid) begin
        aw_pending_q <= 1'b1;
        awaddr_q <= s_axi_awaddr;
      end
      if (s_axi_wready && s_axi_wvalid) begin
        w_pending_q <= 1'b1;
        wdata_q <= s_axi_wdata;
        wstrb_q <= s_axi_wstrb;
      end

      if (write_fire_c) begin
        aw_pending_q <= 1'b0;
        w_pending_q <= 1'b0;
        s_axi_bvalid <= 1'b1;
        s_axi_bresp <= 2'b00;
        unique case (awaddr_q[7:0])
          REG_CTRL: begin
            if (wstrb_q[0] && wdata_q[1]) begin
              done_sticky_q <= 1'b0;
              preload_error_sticky_q <= 1'b0;
            end
            if (wstrb_q[0] && wdata_q[0] && !task_active_c) begin
              if ((preload_pipe_q != '0) || preload_accept_c)
                start_pending_q <= 1'b1;
              else
                start_pulse_q <= 1'b1;
              done_sticky_q <= 1'b0;
            end
          end
          REG_CFG_NH: begin
            if (!task_active_c) begin
              if (wstrb_q[0]) cfg_nh_q[7:0] <= wdata_q[7:0];
              if (wstrb_q[1]) cfg_nh_q[8] <= wdata_q[8];
            end
          end
          REG_CFG_CIN: begin
            if (wstrb_q[0] && !task_active_c) cfg_cin_q <= wdata_q[2:0];
          end
          REG_CFG_COUT: begin
            if (wstrb_q[0] && !task_active_c) cfg_cout_q <= wdata_q[2:0];
          end
          default: begin
          end
        endcase
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end

      if (read_fire_c) begin
        s_axi_rvalid <= 1'b1;
        s_axi_rresp <= 2'b00;
        s_axi_rdata <= read_data_c;
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end

`ifndef SYNTHESIS
  assert property (@(posedge clk) disable iff (rst)
    s_axi_bvalid && !s_axi_bready |=> s_axi_bvalid && $stable(s_axi_bresp))
    else $fatal(1, "AXI-Lite B response changed under backpressure");
  assert property (@(posedge clk) disable iff (rst)
    s_axi_rvalid && !s_axi_rready |=>
      s_axi_rvalid && $stable(s_axi_rresp) && $stable(s_axi_rdata))
    else $fatal(1, "AXI-Lite R response changed under backpressure");
  assert property (@(posedge clk) disable iff (rst)
    start_pulse_q |-> (preload_pipe_q == '0) && !preload_accept_c)
    else $fatal(1, "Core start overlapped an accepted preload pipeline entry");
  assert property (@(posedge clk) disable iff (rst)
    preload_accept_c |-> preload_ready && preload_meta_valid_c && preload_data_valid_c)
    else $fatal(1, "Invalid native preload was accepted");
  assert property (@(posedge clk) disable iff (rst)
    !(core_busy && core_done))
    else $fatal(1, "Core busy and done asserted together");
`endif

endmodule
