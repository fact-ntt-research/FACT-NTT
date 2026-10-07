module ntt46_zero_pad_radix2_residue_conv_core #(
  parameter int unsigned N = 256,
  parameter int unsigned INPUT_W = 8,
  parameter int unsigned DATA_W = 19,
  parameter int unsigned P = 520193,
  parameter int unsigned ROOT = 133361,
  parameter int unsigned ROOT_INV = 257957,
  parameter int unsigned N_INV = 518161,
  parameter int unsigned CIN_MAX = 4,
  parameter int unsigned COUT_MAX = 4
) (
  input  logic                         clk,
  input  logic                         rst,
  input  logic                         preload_valid,
  input  logic                         preload_is_h,
  input  logic [1:0]                   preload_cin,
  input  logic [1:0]                   preload_cout,
  input  logic [$clog2(N/2)-1:0]       preload_idx,
  input  logic signed [INPUT_W-1:0]    preload_data,
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
  output logic [DATA_W-1:0]            y_read_residue
);

  localparam int unsigned NX = N / 2;
  localparam int unsigned ADDR_W = $clog2(N);
  localparam int unsigned NX_ADDR_W = $clog2(NX);
  localparam int unsigned X_DEPTH = CIN_MAX * NX;
  localparam int unsigned H_DEPTH = COUT_MAX * CIN_MAX * NX;
  localparam int unsigned XS_DEPTH = CIN_MAX * N;
  localparam int unsigned Y_DEPTH = COUT_MAX * N;
  localparam int unsigned X_AW = $clog2(X_DEPTH);
  localparam int unsigned H_AW = $clog2(H_DEPTH);
  localparam int unsigned XS_AW = $clog2(XS_DEPTH);
  localparam int unsigned Y_AW = $clog2(Y_DEPTH);

  typedef enum logic [4:0] {
    S_IDLE,
    S_LOAD_X_REQ,
    S_LOAD_X_WRITE,
    S_START_X,
    S_WAIT_X,
    S_STORE_X_READ,
    S_STORE_X_WRITE,
    S_CLEAR_ACC,
    S_LOAD_H_REQ,
    S_LOAD_H_WRITE,
    S_START_H,
    S_WAIT_H,
    S_MAC_READ,
    S_MAC_MUL,
    S_MAC_WAIT,
    S_MAC_WRITE,
    S_LOAD_ACC_READ,
    S_LOAD_ACC_WRITE,
    S_START_INV,
    S_WAIT_INV,
    S_STORE_Y_READ,
    S_STORE_Y_WRITE
  } state_t;

  state_t state_q;
  logic [2:0] cin_q, cout_q;
  logic [NX_ADDR_W-1:0] nh_q;
  logic [1:0] active_cin_q, active_cout_q;
  logic [ADDR_W-1:0] index_q;

  logic engine_load_en, engine_start, engine_inverse, engine_read_en;
  logic [ADDR_W-1:0] engine_load_addr, engine_read_addr;
  logic [DATA_W-1:0] engine_load_data, engine_read_data;
  logic engine_busy, engine_done, engine_read_valid;
  logic [31:0] engine_cycles;

  logic x_we, h_we, xs_we, acc_we, y_we;
  logic [X_AW-1:0] x_addr;
  logic [H_AW-1:0] h_addr;
  logic [XS_AW-1:0] xs_addr;
  logic [ADDR_W-1:0] acc_addr;
  logic [Y_AW-1:0] y_addr;
  logic [INPUT_W-1:0] x_din, x_dout, h_din, h_dout;
  logic [DATA_W-1:0] xs_din, xs_dout, acc_din, acc_dout, y_din, y_dout;

  logic mac_in_valid, mac_out_valid;
  logic [DATA_W-1:0] mac_product, mac_product_q;

  function automatic logic valid_124(input logic [2:0] value);
    return (value == 3'd1) || (value == 3'd2) || (value == 3'd4);
  endfunction

  function automatic logic [DATA_W-1:0] signed_to_residue(
    input logic signed [INPUT_W-1:0] value
  );
    logic signed [DATA_W:0] wide_value;
    begin
      wide_value = value;
      if (wide_value < 0) return DATA_W'(P + wide_value);
      return DATA_W'(wide_value);
    end
  endfunction

  function automatic logic [DATA_W-1:0] modadd(
    input logic [DATA_W-1:0] a,
    input logic [DATA_W-1:0] b
  );
    logic [DATA_W:0] sum;
    begin
      sum = {1'b0, a} + {1'b0, b};
      if (sum >= P) sum = sum - P;
      return sum[DATA_W-1:0];
    end
  endfunction

  assign busy = (state_q != S_IDLE);
  assign mac_in_valid = (state_q == S_MAC_MUL);
  assign y_read_residue = y_dout;

  always_comb begin
    int unsigned flat_x;
    int unsigned flat_h;
    int unsigned flat_xs;
    int unsigned flat_y;
    flat_x = (active_cin_q * NX) + index_q;
    flat_h = (((active_cout_q * CIN_MAX) + active_cin_q) * NX) + index_q;
    flat_xs = (active_cin_q * N) + index_q;
    flat_y = (active_cout_q * N) + index_q;

    engine_load_en = 1'b0;
    engine_load_addr = index_q;
    engine_load_data = '0;
    engine_start = 1'b0;
    engine_inverse = 1'b0;
    engine_read_en = 1'b0;
    engine_read_addr = index_q;

    x_we = 1'b0;
    h_we = 1'b0;
    xs_we = 1'b0;
    acc_we = 1'b0;
    y_we = 1'b0;
    x_addr = X_AW'(flat_x);
    h_addr = H_AW'(flat_h);
    xs_addr = XS_AW'(flat_xs);
    acc_addr = index_q;
    y_addr = Y_AW'(flat_y);
    x_din = preload_data;
    h_din = preload_data;
    xs_din = engine_read_data;
    acc_din = '0;
    y_din = engine_read_data;

    if (state_q == S_IDLE) begin
      if (preload_valid && !preload_is_h) begin
        x_we = 1'b1;
        x_addr = X_AW'((preload_cin * NX) + preload_idx);
      end
      if (preload_valid && preload_is_h) begin
        h_we = 1'b1;
        h_addr = H_AW'((((preload_cout * CIN_MAX) + preload_cin) * NX) + preload_idx);
      end
      if (y_read_en) y_addr = Y_AW'((y_read_cout * N) + y_read_idx);
    end

    unique case (state_q)
      S_LOAD_X_REQ: x_addr = X_AW'(flat_x);
      S_LOAD_X_WRITE: begin
        engine_load_en = 1'b1;
        engine_load_data = (index_q < NX) ? signed_to_residue($signed(x_dout)) : '0;
      end
      S_START_X, S_START_H: engine_start = 1'b1;
      S_STORE_X_READ, S_STORE_Y_READ: engine_read_en = 1'b1;
      S_STORE_X_WRITE: begin
        xs_we = 1'b1;
        xs_din = engine_read_data;
      end
      S_CLEAR_ACC: begin
        acc_we = 1'b1;
        acc_din = '0;
      end
      S_LOAD_H_REQ: h_addr = H_AW'(flat_h);
      S_LOAD_H_WRITE: begin
        engine_load_en = 1'b1;
        engine_load_data = (index_q < nh_q) ? signed_to_residue($signed(h_dout)) : '0;
      end
      S_MAC_READ: begin
        engine_read_en = 1'b1;
        xs_addr = XS_AW'(flat_xs);
        acc_addr = index_q;
      end
      S_MAC_WRITE: begin
        acc_we = 1'b1;
        acc_din = modadd(acc_dout, mac_product_q);
      end
      S_LOAD_ACC_READ: acc_addr = index_q;
      S_LOAD_ACC_WRITE: begin
        engine_load_en = 1'b1;
        engine_load_data = acc_dout;
      end
      S_START_INV: begin
        engine_start = 1'b1;
        engine_inverse = 1'b1;
      end
      S_STORE_Y_WRITE: begin
        y_we = 1'b1;
        y_din = engine_read_data;
      end
      default: begin end
    endcase
  end

  ntt46_zero_pad_spram #(.DEPTH(X_DEPTH), .DATA_W(INPUT_W)) u_x_mem (
    .clk(clk), .we(x_we), .addr(x_addr), .din(x_din), .dout(x_dout)
  );
  ntt46_zero_pad_spram #(.DEPTH(H_DEPTH), .DATA_W(INPUT_W)) u_h_mem (
    .clk(clk), .we(h_we), .addr(h_addr), .din(h_din), .dout(h_dout)
  );
  ntt46_zero_pad_spram #(.DEPTH(XS_DEPTH), .DATA_W(DATA_W)) u_xs_mem (
    .clk(clk), .we(xs_we), .addr(xs_addr), .din(xs_din), .dout(xs_dout)
  );
  ntt46_zero_pad_spram #(.DEPTH(N), .DATA_W(DATA_W)) u_acc_mem (
    .clk(clk), .we(acc_we), .addr(acc_addr), .din(acc_din), .dout(acc_dout)
  );
  ntt46_zero_pad_spram #(.DEPTH(Y_DEPTH), .DATA_W(DATA_W)) u_y_mem (
    .clk(clk), .we(y_we), .addr(y_addr), .din(y_din), .dout(y_dout)
  );

  ntt46_zero_pad_radix2_reference_engine #(
    .N(N), .DATA_W(DATA_W), .P(P), .ROOT(ROOT), .ROOT_INV(ROOT_INV), .N_INV(N_INV)
  ) u_engine (
    .clk(clk), .rst(rst),
    .load_en(engine_load_en), .load_addr(engine_load_addr), .load_data(engine_load_data),
    .start(engine_start), .inverse(engine_inverse),
    .busy(engine_busy), .done(engine_done), .compute_cycles(engine_cycles),
    .read_en(engine_read_en), .read_addr(engine_read_addr),
    .read_valid(engine_read_valid), .read_data(engine_read_data)
  );

  ntt46_zero_pad_pseudo_modmul_pipe #(.DATA_W(DATA_W), .P(P)) u_mac_mul (
    .clk(clk), .rst(rst), .in_valid(mac_in_valid),
    .a_in(xs_dout), .b_in(engine_read_data),
    .out_valid(mac_out_valid), .p_out(mac_product)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      cin_q <= 3'd1;
      cout_q <= 3'd1;
      nh_q <= NX_ADDR_W'(1);
      active_cin_q <= '0;
      active_cout_q <= '0;
      index_q <= '0;
      mac_product_q <= '0;
      done <= 1'b0;
      cfg_error <= 1'b0;
      compute_cycles <= '0;
      y_read_valid <= 1'b0;
    end else begin
      done <= 1'b0;
      y_read_valid <= (state_q == S_IDLE) && y_read_en && !preload_valid;
      if (state_q != S_IDLE) compute_cycles <= compute_cycles + 32'd1;

      unique case (state_q)
        S_IDLE: begin
          if (start) begin
            cfg_error <= !valid_124(cfg_cin) || !valid_124(cfg_cout)
                         || (cfg_nh < 1) || (cfg_nh >= NX);
            compute_cycles <= '0;
            if (!valid_124(cfg_cin) || !valid_124(cfg_cout)
                || (cfg_nh < 1) || (cfg_nh >= NX)) begin
              done <= 1'b1;
            end else begin
              cin_q <= cfg_cin;
              cout_q <= cfg_cout;
              nh_q <= cfg_nh;
              active_cin_q <= '0;
              active_cout_q <= '0;
              index_q <= '0;
              state_q <= S_LOAD_X_REQ;
            end
          end
        end
        S_LOAD_X_REQ: state_q <= S_LOAD_X_WRITE;
        S_LOAD_X_WRITE: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            state_q <= S_START_X;
          end else begin
            index_q <= index_q + ADDR_W'(1);
            state_q <= S_LOAD_X_REQ;
          end
        end
        S_START_X: state_q <= S_WAIT_X;
        S_WAIT_X: if (engine_done) begin index_q <= '0; state_q <= S_STORE_X_READ; end
        S_STORE_X_READ: state_q <= S_STORE_X_WRITE;
        S_STORE_X_WRITE: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            if (({1'b0, active_cin_q} + 3'd1) < cin_q) begin
              active_cin_q <= active_cin_q + 2'd1;
              state_q <= S_LOAD_X_REQ;
            end else begin
              active_cin_q <= '0;
              state_q <= S_CLEAR_ACC;
            end
          end else begin
            index_q <= index_q + ADDR_W'(1);
            state_q <= S_STORE_X_READ;
          end
        end
        S_CLEAR_ACC: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            active_cin_q <= '0;
            state_q <= S_LOAD_H_REQ;
          end else index_q <= index_q + ADDR_W'(1);
        end
        S_LOAD_H_REQ: state_q <= S_LOAD_H_WRITE;
        S_LOAD_H_WRITE: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            state_q <= S_START_H;
          end else begin
            index_q <= index_q + ADDR_W'(1);
            state_q <= S_LOAD_H_REQ;
          end
        end
        S_START_H: state_q <= S_WAIT_H;
        S_WAIT_H: if (engine_done) begin index_q <= '0; state_q <= S_MAC_READ; end
        S_MAC_READ: state_q <= S_MAC_MUL;
        S_MAC_MUL: state_q <= S_MAC_WAIT;
        S_MAC_WAIT: if (mac_out_valid) begin mac_product_q <= mac_product; state_q <= S_MAC_WRITE; end
        S_MAC_WRITE: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            if (({1'b0, active_cin_q} + 3'd1) < cin_q) begin
              active_cin_q <= active_cin_q + 2'd1;
              state_q <= S_LOAD_H_REQ;
            end else begin
              active_cin_q <= '0;
              state_q <= S_LOAD_ACC_READ;
            end
          end else begin
            index_q <= index_q + ADDR_W'(1);
            state_q <= S_MAC_READ;
          end
        end
        S_LOAD_ACC_READ: state_q <= S_LOAD_ACC_WRITE;
        S_LOAD_ACC_WRITE: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            state_q <= S_START_INV;
          end else begin
            index_q <= index_q + ADDR_W'(1);
            state_q <= S_LOAD_ACC_READ;
          end
        end
        S_START_INV: state_q <= S_WAIT_INV;
        S_WAIT_INV: if (engine_done) begin index_q <= '0; state_q <= S_STORE_Y_READ; end
        S_STORE_Y_READ: state_q <= S_STORE_Y_WRITE;
        S_STORE_Y_WRITE: begin
          if (index_q == ADDR_W'(N - 1)) begin
            index_q <= '0;
            if (({1'b0, active_cout_q} + 3'd1) < cout_q) begin
              active_cout_q <= active_cout_q + 2'd1;
              active_cin_q <= '0;
              state_q <= S_CLEAR_ACC;
            end else begin
              state_q <= S_IDLE;
              done <= 1'b1;
            end
          end else begin
            index_q <= index_q + ADDR_W'(1);
            state_q <= S_STORE_Y_READ;
          end
        end
        default: state_q <= S_IDLE;
      endcase
    end
  end
endmodule

module ntt46_zero_pad_spram #(
  parameter int unsigned DEPTH = 256,
  parameter int unsigned DATA_W = 19
) (
  input  logic                         clk,
  input  logic                         we,
  input  logic [$clog2(DEPTH)-1:0]     addr,
  input  logic [DATA_W-1:0]            din,
  output logic [DATA_W-1:0]            dout
);
  (* ram_style = "block" *) logic [DATA_W-1:0] mem [0:DEPTH-1];
  always_ff @(posedge clk) begin
    if (we) mem[addr] <= din;
    dout <= mem[addr];
  end
endmodule
