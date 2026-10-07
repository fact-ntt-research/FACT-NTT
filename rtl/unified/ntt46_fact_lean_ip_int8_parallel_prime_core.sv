module ntt46_fact_lean_ip_int8_parallel_prime_core #(
  parameter int unsigned R = 128,
  parameter int unsigned LANES = 8,
  parameter int unsigned COUT_MAX = 4,
  parameter bit INT8_OUTPUT_PIPELINE = 1'b0,
  parameter bit PRODUCT_STORE_DEPTH8 = 1'b1,
  parameter bit USE_PRODUCT32_STREAM = 1'b1,
  parameter bit PRODUCT32_USE_PACKED_FIFO = 1'b1,
  parameter bit PRODUCT32_RESET_DATA_ARRAYS = 1'b1,
  parameter bit PRODUCT32_INPUT_PIPELINE = 1'b0,
  parameter bit PRODUCT_READY_CLEAR_ON_ACCUM = 1'b1,
  parameter bit TRANSFORM_J_MUL_TIGHT = 1'b0,
  parameter bit TRANSFORM_TWIDDLE_PREFETCH_STAGE = 1'b1,
  parameter bit TERMINAL_INPUT_PIPELINE = 1'b1,
  parameter bit TERMINAL_RESET_DATA_ARRAYS = 1'b1,
  parameter bit RESET_WR_PIPE_DATA = 1'b1,
  parameter bit FACT_AREA_TRIM_CTRL = 1'b0,
  parameter bit USE_LOAD16 = 1'b1,
  parameter bit DIRECT_STAGE0_FROM_LOCAL = 1'b1,
  parameter int signed DIRECT_STAGE0_DRAIN_WAIT = -1,
  parameter int signed DIRECT_STAGE0_EVEN_WAIT = -1,
  parameter int signed DIRECT_STAGE0_TAIL_WAIT = -1,
  parameter int signed DIRECT_STAGE0_PRESTART_WAIT = -1
) (
  input  logic                            clk,
  input  logic                            rst,
  input  logic [8:0]                      cfg_nh,
  input  logic [2:0]                      cfg_cin_tile,
  input  logic [2:0]                      cfg_cout_tile,
  input  logic                            preload_valid,
  input  logic                            preload_is_h,
  input  logic [1:0]                      preload_cin,
  input  logic [1:0]                      preload_cout,
  input  logic [8:0]                      preload_idx,
  input  logic signed [18:0]              preload_data,
  input  logic                            start,
  output logic                            busy,
  output logic                            done,
  output logic                            cfg_error,
  output logic [3:0]                      error_code,
  output logic [31:0]                     wall_cycles,
  output logic [31:0]                     core_compute_cycles,
  output logic [31:0]                     preload_cycles_est,
  output logic [31:0]                     readout_cycles_est,
  input  logic                            y_read_en,
  input  logic [1:0]                      y_read_cout,
  input  logic [9:0]                      y_read_idx,
  output logic                            y_read_valid,
  output logic signed [31:0]              y_read_data
);

  localparam logic [3:0] ERR_NONE = 4'd0;
  localparam logic [3:0] ERR_NH   = 4'd1;
  localparam logic [3:0] ERR_CIN  = 4'd2;
  localparam logic [3:0] ERR_COUT = 4'd3;

  localparam longint unsigned P1 = 520193;
  localparam longint unsigned P2 = 254977;
  localparam logic [18:0] P1_19 = P1[18:0];
  localparam logic [18:0] P2_19 = P2[18:0];

  typedef enum logic [1:0] {
    S_IDLE,
    S_RUN,
    S_DONE
  } state_t;

  state_t state_q, state_d;

  logic p1_busy, p1_done, p1_cfg_error, p1_y_valid;
  logic [3:0] p1_error_code;
  logic [31:0] p1_wall_cycles, p1_core_cycles, p1_preload_est, p1_readout_est;
  logic signed [18:0] p1_y_data;

  logic p2_busy, p2_done, p2_cfg_error, p2_y_valid;
  logic [3:0] p2_error_code;
  logic [31:0] p2_wall_cycles, p2_core_cycles, p2_preload_est, p2_readout_est;
  logic signed [18:0] p2_y_data;

  logic p1_done_seen_q, p1_done_seen_d;
  logic p2_done_seen_q, p2_done_seen_d;
  logic cfg_error_q, cfg_error_d;
  logic [3:0] error_code_q, error_code_d;
  logic [31:0] wall_cycles_q, wall_cycles_d;
  logic [31:0] core_cycles_q, core_cycles_d;
  logic [31:0] preload_est_q, preload_est_d;
  logic [31:0] readout_est_q, readout_est_d;
  logic done_q, done_d;
  logic residue_pair_valid_c;
  logic [18:0] residue_p1_c, residue_p2_c;

  function automatic logic valid_124(input logic [2:0] v);
    return (v == 3'd1) || (v == 3'd2) || (v == 3'd4);
  endfunction

  function automatic logic local_cfg_error(input logic [8:0] nh, input logic [2:0] cin, input logic [2:0] cout);
    if ((nh == 9'd0) || (int'(nh) >= R)) return 1'b1;
    if (!valid_124(cin)) return 1'b1;
    if (!valid_124(cout)) return 1'b1;
    return 1'b0;
  endfunction

  function automatic logic [3:0] local_error_code(input logic [8:0] nh, input logic [2:0] cin, input logic [2:0] cout);
    if ((nh == 9'd0) || (int'(nh) >= R)) return ERR_NH;
    if (!valid_124(cin)) return ERR_CIN;
    if (!valid_124(cout)) return ERR_COUT;
    return ERR_NONE;
  endfunction

  function automatic logic [18:0] signed_to_residue(input logic signed [18:0] value, input logic [18:0] modulus);
    if (value < 0) return modulus + value[18:0];
    return value[18:0];
  endfunction

  ntt46_p520_ntt46_fact_lean_ip_int4_local_core #(
    .R(R),
    .LANES(LANES),
    .PRODUCT_STORE_DEPTH8(PRODUCT_STORE_DEPTH8),
    .USE_PRODUCT32_STREAM(USE_PRODUCT32_STREAM),
    .PRODUCT32_USE_PACKED_FIFO(PRODUCT32_USE_PACKED_FIFO),
    .PRODUCT32_RESET_DATA_ARRAYS(PRODUCT32_RESET_DATA_ARRAYS),
    .PRODUCT32_INPUT_PIPELINE(PRODUCT32_INPUT_PIPELINE),
    .PRODUCT_READY_CLEAR_ON_ACCUM(PRODUCT_READY_CLEAR_ON_ACCUM),
    .TRANSFORM_J_MUL_TIGHT(TRANSFORM_J_MUL_TIGHT),
    .TRANSFORM_TWIDDLE_PREFETCH_STAGE(TRANSFORM_TWIDDLE_PREFETCH_STAGE),
    .TERMINAL_INPUT_PIPELINE(TERMINAL_INPUT_PIPELINE),
    .TERMINAL_RESET_DATA_ARRAYS(TERMINAL_RESET_DATA_ARRAYS),
    .RESET_WR_PIPE_DATA(RESET_WR_PIPE_DATA),
    .FACT_AREA_TRIM_CTRL(FACT_AREA_TRIM_CTRL),
    .USE_LOAD16(USE_LOAD16),
    .DIRECT_STAGE0_FROM_LOCAL(DIRECT_STAGE0_FROM_LOCAL),
    .DIRECT_STAGE0_DRAIN_WAIT(DIRECT_STAGE0_DRAIN_WAIT),
    .DIRECT_STAGE0_EVEN_WAIT(DIRECT_STAGE0_EVEN_WAIT),
    .DIRECT_STAGE0_TAIL_WAIT(DIRECT_STAGE0_TAIL_WAIT),
    .DIRECT_STAGE0_PRESTART_WAIT(DIRECT_STAGE0_PRESTART_WAIT),
    .CIN_MAX(4),
    .COUT_MAX(COUT_MAX),
    .READOUT_PIPELINE(INT8_OUTPUT_PIPELINE)
  ) u_p1 (
    .clk(clk),
    .rst(rst),
    .cfg_nh(cfg_nh),
    .cfg_cin_tile(cfg_cin_tile),
    .cfg_cout_tile(cfg_cout_tile),
    .preload_valid(preload_valid),
    .preload_is_h(preload_is_h),
    .preload_cin(preload_cin),
    .preload_cout(preload_cout),
    .preload_idx(preload_idx),
    .preload_data(preload_data),
    .start(start && (state_q == S_IDLE) && !local_cfg_error(cfg_nh, cfg_cin_tile, cfg_cout_tile)),
    .busy(p1_busy),
    .done(p1_done),
    .cfg_error(p1_cfg_error),
    .error_code(p1_error_code),
    .wall_cycles(p1_wall_cycles),
    .core_compute_cycles(p1_core_cycles),
    .preload_cycles_est(p1_preload_est),
    .readout_cycles_est(p1_readout_est),
    .y_read_en(y_read_en),
    .y_read_cout(y_read_cout),
    .y_read_idx(y_read_idx),
    .y_read_valid(p1_y_valid),
    .y_read_data(p1_y_data)
  );

  ntt46_fact_lean_ip_int4_local_core #(
    .R(R),
    .LANES(LANES),
    .PRODUCT_STORE_DEPTH8(PRODUCT_STORE_DEPTH8),
    .USE_PRODUCT32_STREAM(USE_PRODUCT32_STREAM),
    .PRODUCT32_USE_PACKED_FIFO(PRODUCT32_USE_PACKED_FIFO),
    .PRODUCT32_RESET_DATA_ARRAYS(PRODUCT32_RESET_DATA_ARRAYS),
    .PRODUCT32_INPUT_PIPELINE(PRODUCT32_INPUT_PIPELINE),
    .PRODUCT_READY_CLEAR_ON_ACCUM(PRODUCT_READY_CLEAR_ON_ACCUM),
    .TRANSFORM_J_MUL_TIGHT(TRANSFORM_J_MUL_TIGHT),
    .TRANSFORM_TWIDDLE_PREFETCH_STAGE(TRANSFORM_TWIDDLE_PREFETCH_STAGE),
    .TERMINAL_INPUT_PIPELINE(TERMINAL_INPUT_PIPELINE),
    .TERMINAL_RESET_DATA_ARRAYS(TERMINAL_RESET_DATA_ARRAYS),
    .RESET_WR_PIPE_DATA(RESET_WR_PIPE_DATA),
    .FACT_AREA_TRIM_CTRL(FACT_AREA_TRIM_CTRL),
    .USE_LOAD16(USE_LOAD16),
    .DIRECT_STAGE0_FROM_LOCAL(DIRECT_STAGE0_FROM_LOCAL),
    .DIRECT_STAGE0_DRAIN_WAIT(DIRECT_STAGE0_DRAIN_WAIT),
    .DIRECT_STAGE0_EVEN_WAIT(DIRECT_STAGE0_EVEN_WAIT),
    .DIRECT_STAGE0_TAIL_WAIT(DIRECT_STAGE0_TAIL_WAIT),
    .DIRECT_STAGE0_PRESTART_WAIT(DIRECT_STAGE0_PRESTART_WAIT),
    .CIN_MAX(4),
    .COUT_MAX(COUT_MAX),
    .READOUT_PIPELINE(INT8_OUTPUT_PIPELINE)
  ) u_p2 (
    .clk(clk),
    .rst(rst),
    .cfg_nh(cfg_nh),
    .cfg_cin_tile(cfg_cin_tile),
    .cfg_cout_tile(cfg_cout_tile),
    .preload_valid(preload_valid),
    .preload_is_h(preload_is_h),
    .preload_cin(preload_cin),
    .preload_cout(preload_cout),
    .preload_idx(preload_idx),
    .preload_data(preload_data),
    .start(start && (state_q == S_IDLE) && !local_cfg_error(cfg_nh, cfg_cin_tile, cfg_cout_tile)),
    .busy(p2_busy),
    .done(p2_done),
    .cfg_error(p2_cfg_error),
    .error_code(p2_error_code),
    .wall_cycles(p2_wall_cycles),
    .core_compute_cycles(p2_core_cycles),
    .preload_cycles_est(p2_preload_est),
    .readout_cycles_est(p2_readout_est),
    .y_read_en(y_read_en),
    .y_read_cout(y_read_cout),
    .y_read_idx(y_read_idx),
    .y_read_valid(p2_y_valid),
    .y_read_data(p2_y_data)
  );

  assign residue_pair_valid_c = p1_y_valid && p2_y_valid;
  assign residue_p1_c = signed_to_residue(p1_y_data, P1_19);
  assign residue_p2_c = signed_to_residue(p2_y_data, P2_19);

  generate
    if (INT8_OUTPUT_PIPELINE) begin : g_output_pipeline
      logic residue_pair_valid_q;
      logic [18:0] residue_p1_q;
      logic [18:0] residue_p2_q;
      logic [1:0] y_read_cout_q;
      logic [9:0] y_read_idx_q;
      logic [1:0] crt_pipe_cout_unused;
      logic [9:0] crt_pipe_idx_unused;
      logic crt_pipe_busy_unused;

      always_ff @(posedge clk) begin
        if (rst) begin
          residue_pair_valid_q <= 1'b0;
          residue_p1_q <= '0;
          residue_p2_q <= '0;
          y_read_cout_q <= '0;
          y_read_idx_q <= '0;
        end else begin
          residue_pair_valid_q <= residue_pair_valid_c;
          if (residue_pair_valid_c) begin
            residue_p1_q <= residue_p1_c;
            residue_p2_q <= residue_p2_c;
            y_read_cout_q <= y_read_cout;
            y_read_idx_q <= y_read_idx;
          end
        end
      end

      ntt46_fact_ip_v1_crt2_reconstruct_pipe u_crt_pipe (
        .clk(clk),
        .rst(rst),
        .in_valid(residue_pair_valid_q),
        .residue_p1(residue_p1_q),
        .residue_p2(residue_p2_q),
        .in_cout(y_read_cout_q),
        .in_idx(y_read_idx_q),
        .out_valid(y_read_valid),
        .signed_value(y_read_data),
        .out_cout(crt_pipe_cout_unused),
        .out_idx(crt_pipe_idx_unused),
        .pipe_busy(crt_pipe_busy_unused)
      );
    end else begin : g_output_comb
      logic signed [31:0] crt_data_c;

      ntt46_fact_ip_v1_crt2_reconstruct u_crt (
        .residue_p1(residue_p1_c),
        .residue_p2(residue_p2_c),
        .signed_value(crt_data_c)
      );

      assign y_read_valid = residue_pair_valid_c;
      assign y_read_data = crt_data_c;
    end
  endgenerate

  always_comb begin
    state_d = state_q;
    p1_done_seen_d = p1_done_seen_q || p1_done;
    p2_done_seen_d = p2_done_seen_q || p2_done;
    cfg_error_d = cfg_error_q;
    error_code_d = error_code_q;
    wall_cycles_d = wall_cycles_q;
    core_cycles_d = core_cycles_q;
    preload_est_d = preload_est_q;
    readout_est_d = readout_est_q;
    done_d = 1'b0;

    unique case (state_q)
      S_IDLE: begin
        p1_done_seen_d = 1'b0;
        p2_done_seen_d = 1'b0;
        if (start) begin
          if (local_cfg_error(cfg_nh, cfg_cin_tile, cfg_cout_tile)) begin
            cfg_error_d = 1'b1;
            error_code_d = local_error_code(cfg_nh, cfg_cin_tile, cfg_cout_tile);
            wall_cycles_d = '0;
            core_cycles_d = '0;
            preload_est_d = '0;
            readout_est_d = '0;
            done_d = 1'b1;
            state_d = S_DONE;
          end else begin
            cfg_error_d = 1'b0;
            error_code_d = ERR_NONE;
            wall_cycles_d = '0;
            core_cycles_d = '0;
            preload_est_d = (32'(cfg_cin_tile) * R) +
                            (32'(cfg_cout_tile) * 32'(cfg_cin_tile) * R);
            readout_est_d = 32'(cfg_cout_tile) * (2 * R);
            state_d = S_RUN;
          end
        end
      end

      S_RUN: begin
        if (p1_done_seen_d && p2_done_seen_d) begin
          cfg_error_d = p1_cfg_error || p2_cfg_error;
          error_code_d = p1_cfg_error ? p1_error_code : (p2_cfg_error ? p2_error_code : ERR_NONE);
          wall_cycles_d = (p1_wall_cycles >= p2_wall_cycles) ? p1_wall_cycles : p2_wall_cycles;
          core_cycles_d = (p1_core_cycles >= p2_core_cycles) ? p1_core_cycles : p2_core_cycles;
          done_d = 1'b1;
          state_d = S_DONE;
        end
      end

      S_DONE: begin
        if (!start) state_d = S_IDLE;
      end

      default: state_d = S_IDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      p1_done_seen_q <= 1'b0;
      p2_done_seen_q <= 1'b0;
      cfg_error_q <= 1'b0;
      error_code_q <= ERR_NONE;
      wall_cycles_q <= '0;
      core_cycles_q <= '0;
      preload_est_q <= '0;
      readout_est_q <= '0;
      done_q <= 1'b0;
    end else begin
      state_q <= state_d;
      p1_done_seen_q <= p1_done_seen_d;
      p2_done_seen_q <= p2_done_seen_d;
      cfg_error_q <= cfg_error_d;
      error_code_q <= error_code_d;
      wall_cycles_q <= wall_cycles_d;
      core_cycles_q <= core_cycles_d;
      preload_est_q <= preload_est_d;
      readout_est_q <= readout_est_d;
      done_q <= done_d;
    end
  end

  assign busy = (state_q == S_RUN) || p1_busy || p2_busy;
  assign done = done_q;
  assign cfg_error = cfg_error_q;
  assign error_code = error_code_q;
  assign wall_cycles = wall_cycles_q;
  assign core_compute_cycles = core_cycles_q;
  assign preload_cycles_est = preload_est_q;
  assign readout_cycles_est = readout_est_q;

endmodule
