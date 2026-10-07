module ntt46_zero_pad_radix2_reference_engine #(
  parameter int unsigned N = 256,
  parameter int unsigned DATA_W = 19,
  parameter int unsigned P = 520193,
  parameter int unsigned ROOT = 133361,
  parameter int unsigned ROOT_INV = 257957,
  parameter int unsigned N_INV = 518161
) (
  input  logic                         clk,
  input  logic                         rst,
  input  logic                         load_en,
  input  logic [$clog2(N)-1:0]         load_addr,
  input  logic [DATA_W-1:0]            load_data,
  input  logic                         start,
  input  logic                         inverse,
  output logic                         busy,
  output logic                         done,
  output logic [31:0]                  compute_cycles,
  input  logic                         read_en,
  input  logic [$clog2(N)-1:0]         read_addr,
  output logic                         read_valid,
  output logic [DATA_W-1:0]            read_data
);

  localparam int unsigned LOG_N = $clog2(N);
  localparam int unsigned ADDR_W = LOG_N;
  localparam int unsigned HALF_N = N / 2;

  typedef enum logic [3:0] {
    S_IDLE,
    S_STAGE_ADDR,
    S_STAGE_READ,
    S_STAGE_MUL,
    S_STAGE_WAIT,
    S_STAGE_WRITE,
    S_SCALE_READ,
    S_SCALE_MUL,
    S_SCALE_WAIT,
    S_SCALE_WRITE
  } state_t;

  state_t state_q;
  logic inverse_q;
  logic [$clog2(LOG_N)-1:0] stage_q;
  logic [ADDR_W-1:0] butterfly_q;
  logic [ADDR_W-1:0] scale_addr_q;
  logic source_ping_q;
  logic result_ping_q;

  logic ping_a_we, ping_b_we, pong_a_we, pong_b_we;
  logic [ADDR_W-1:0] ping_a_addr, ping_b_addr, pong_a_addr, pong_b_addr;
  logic [DATA_W-1:0] ping_a_din, ping_b_din, pong_a_din, pong_b_din;
  logic [DATA_W-1:0] ping_a_dout, ping_b_dout, pong_a_dout, pong_b_dout;
  logic [DATA_W-1:0] source0, source1;
  logic [DATA_W-1:0] u_q;
  logic [DATA_W-1:0] twiddle_q;
  logic [DATA_W-1:0] product_q;
  logic [ADDR_W-1:0] twiddle_addr_q;
  logic [DATA_W-1:0] mul_a, mul_b, mul_product;
  logic mul_in_valid, mul_out_valid;
  logic [ADDR_W-1:0] read_addr0_c, read_addr1_c;
  logic [ADDR_W-1:0] write_addr0_c, write_addr1_c;

  (* rom_style = "distributed" *) logic [DATA_W-1:0] twiddle_fwd [0:HALF_N-1];
  (* rom_style = "distributed" *) logic [DATA_W-1:0] twiddle_inv [0:HALF_N-1];

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

  function automatic logic [DATA_W-1:0] modsub(
    input logic [DATA_W-1:0] a,
    input logic [DATA_W-1:0] b
  );
    begin
      if (a >= b) return a - b;
      return DATA_W'(a + P - b);
    end
  endfunction

  function automatic logic [DATA_W-1:0] modpow(
    input int unsigned base,
    input int unsigned exponent
  );
    logic [63:0] result;
    logic [63:0] factor;
    int unsigned exp_work;
    begin
      result = 1;
      factor = base % P;
      exp_work = exponent;
      while (exp_work != 0) begin
        if (exp_work[0]) result = (result * factor) % P;
        factor = (factor * factor) % P;
        exp_work = exp_work >> 1;
      end
      return result[DATA_W-1:0];
    end
  endfunction

  initial begin
    if ((N < 2) || ((N & (N - 1)) != 0)) $error("N must be a power of two");
    if (!((((1 << DATA_W) - P) == 4095) || (((1 << DATA_W) - P) == 7167))) begin
      $error("Unsupported modulus for the pseudo-Mersenne reference reducer");
    end
    for (int idx = 0; idx < HALF_N; idx++) begin
      twiddle_fwd[idx] = modpow(ROOT, idx);
      twiddle_inv[idx] = modpow(ROOT_INV, idx);
    end
  end

  assign busy = (state_q != S_IDLE);
  assign source0 = source_ping_q ? ping_a_dout : pong_a_dout;
  assign source1 = source_ping_q ? ping_b_dout : pong_b_dout;
  assign read_data = result_ping_q ? ping_a_dout : pong_a_dout;

  always_comb begin
    int unsigned span;
    int unsigned local_idx;
    span = 1 << stage_q;
    local_idx = butterfly_q & (span - 1);
    read_addr0_c = butterfly_q;
    read_addr1_c = butterfly_q + ADDR_W'(HALF_N);
    write_addr0_c = ADDR_W'((2 * butterfly_q) - local_idx);
    write_addr1_c = ADDR_W'((2 * butterfly_q) - local_idx + span);

    mul_in_valid = (state_q == S_STAGE_MUL) || (state_q == S_SCALE_MUL);
    mul_a = (state_q == S_SCALE_MUL)
          ? (result_ping_q ? ping_a_dout : pong_a_dout)
          : source1;
    mul_b = (state_q == S_SCALE_MUL) ? DATA_W'(N_INV) : twiddle_q;

    ping_a_we = 1'b0;
    ping_b_we = 1'b0;
    pong_a_we = 1'b0;
    pong_b_we = 1'b0;
    ping_a_addr = '0;
    ping_b_addr = '0;
    pong_a_addr = '0;
    pong_b_addr = '0;
    ping_a_din = '0;
    ping_b_din = '0;
    pong_a_din = '0;
    pong_b_din = '0;

    if (state_q == S_IDLE) begin
      ping_a_addr = load_en ? load_addr : read_addr;
      ping_a_we = load_en;
      ping_a_din = load_data;
      pong_a_addr = read_addr;
    end else if (state_q inside {S_STAGE_ADDR, S_STAGE_READ, S_STAGE_MUL, S_STAGE_WAIT}) begin
      if (source_ping_q) begin
        ping_a_addr = read_addr0_c;
        ping_b_addr = read_addr1_c;
      end else begin
        pong_a_addr = read_addr0_c;
        pong_b_addr = read_addr1_c;
      end
    end else if (state_q == S_STAGE_WRITE) begin
      if (source_ping_q) begin
        pong_a_addr = write_addr0_c;
        pong_b_addr = write_addr1_c;
        pong_a_we = 1'b1;
        pong_b_we = 1'b1;
        pong_a_din = modadd(u_q, product_q);
        pong_b_din = modsub(u_q, product_q);
      end else begin
        ping_a_addr = write_addr0_c;
        ping_b_addr = write_addr1_c;
        ping_a_we = 1'b1;
        ping_b_we = 1'b1;
        ping_a_din = modadd(u_q, product_q);
        ping_b_din = modsub(u_q, product_q);
      end
    end else begin
      if (result_ping_q) begin
        ping_a_addr = scale_addr_q;
        ping_b_addr = scale_addr_q;
        if (state_q == S_SCALE_WRITE) begin
          ping_b_we = 1'b1;
          ping_b_din = product_q;
        end
      end else begin
        pong_a_addr = scale_addr_q;
        pong_b_addr = scale_addr_q;
        if (state_q == S_SCALE_WRITE) begin
          pong_b_we = 1'b1;
          pong_b_din = product_q;
        end
      end
    end
  end

  ntt46_zero_pad_pseudo_modmul_pipe #(.DATA_W(DATA_W), .P(P)) u_mul (
    .clk(clk), .rst(rst), .in_valid(mul_in_valid), .a_in(mul_a), .b_in(mul_b),
    .out_valid(mul_out_valid), .p_out(mul_product)
  );

  ntt46_zero_pad_tdp_ram #(.DEPTH(N), .DATA_W(DATA_W)) u_ping (
    .clk(clk),
    .a_we(ping_a_we), .a_addr(ping_a_addr), .a_din(ping_a_din), .a_dout(ping_a_dout),
    .b_we(ping_b_we), .b_addr(ping_b_addr), .b_din(ping_b_din), .b_dout(ping_b_dout)
  );
  ntt46_zero_pad_tdp_ram #(.DEPTH(N), .DATA_W(DATA_W)) u_pong (
    .clk(clk),
    .a_we(pong_a_we), .a_addr(pong_a_addr), .a_din(pong_a_din), .a_dout(pong_a_dout),
    .b_we(pong_b_we), .b_addr(pong_b_addr), .b_din(pong_b_din), .b_dout(pong_b_dout)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      state_q <= S_IDLE;
      inverse_q <= 1'b0;
      stage_q <= '0;
      butterfly_q <= '0;
      scale_addr_q <= '0;
      source_ping_q <= 1'b1;
      result_ping_q <= 1'b1;
      u_q <= '0;
      twiddle_q <= '0;
      product_q <= '0;
      twiddle_addr_q <= '0;
      done <= 1'b0;
      compute_cycles <= '0;
      read_valid <= 1'b0;
    end else begin
      done <= 1'b0;
      read_valid <= (state_q == S_IDLE) && read_en && !load_en;
      if (state_q != S_IDLE) compute_cycles <= compute_cycles + 32'd1;

      unique case (state_q)
        S_IDLE: begin
          if (start) begin
            inverse_q <= inverse;
            stage_q <= '0;
            butterfly_q <= '0;
            source_ping_q <= 1'b1;
            compute_cycles <= '0;
            state_q <= S_STAGE_ADDR;
          end
        end
        S_STAGE_ADDR: begin
          int unsigned span;
          int unsigned local_idx;
          span = 1 << stage_q;
          local_idx = butterfly_q & (span - 1);
          twiddle_addr_q <= ADDR_W'(local_idx << (LOG_N - 1 - stage_q));
          state_q <= S_STAGE_READ;
        end
        S_STAGE_READ: begin
          twiddle_q <= inverse_q
                      ? twiddle_inv[twiddle_addr_q]
                      : twiddle_fwd[twiddle_addr_q];
          state_q <= S_STAGE_MUL;
        end
        S_STAGE_MUL: begin
          u_q <= source0;
          state_q <= S_STAGE_WAIT;
        end
        S_STAGE_WAIT: begin
          if (mul_out_valid) begin
            product_q <= mul_product;
            state_q <= S_STAGE_WRITE;
          end
        end
        S_STAGE_WRITE: begin
          if (butterfly_q == ADDR_W'(HALF_N - 1)) begin
            butterfly_q <= '0;
            if (stage_q == $clog2(LOG_N)'(LOG_N - 1)) begin
              result_ping_q <= !source_ping_q;
              if (inverse_q) begin
                scale_addr_q <= '0;
                state_q <= S_SCALE_READ;
              end else begin
                state_q <= S_IDLE;
                done <= 1'b1;
              end
            end else begin
              source_ping_q <= !source_ping_q;
              stage_q <= stage_q + 1'b1;
              state_q <= S_STAGE_ADDR;
            end
          end else begin
            butterfly_q <= butterfly_q + ADDR_W'(1);
            state_q <= S_STAGE_ADDR;
          end
        end
        S_SCALE_READ: state_q <= S_SCALE_MUL;
        S_SCALE_MUL: state_q <= S_SCALE_WAIT;
        S_SCALE_WAIT: begin
          if (mul_out_valid) begin
            product_q <= mul_product;
            state_q <= S_SCALE_WRITE;
          end
        end
        S_SCALE_WRITE: begin
          if (scale_addr_q == ADDR_W'(N - 1)) begin
            state_q <= S_IDLE;
            done <= 1'b1;
          end else begin
            scale_addr_q <= scale_addr_q + ADDR_W'(1);
            state_q <= S_SCALE_READ;
          end
        end
        default: state_q <= S_IDLE;
      endcase
    end
  end
endmodule

module ntt46_zero_pad_pseudo_modmul_pipe #(
  parameter int unsigned DATA_W = 19,
  parameter int unsigned P = 520193
) (
  input  logic                   clk,
  input  logic                   rst,
  input  logic                   in_valid,
  input  logic [DATA_W-1:0]      a_in,
  input  logic [DATA_W-1:0]      b_in,
  output logic                   out_valid,
  output logic [DATA_W-1:0]      p_out
);
  localparam int unsigned PSEUDO_C = (1 << DATA_W) - P;
  localparam logic [63:0] MASK = (64'd1 << DATA_W) - 1;
  logic v1, v2, v3, v4;
  logic [63:0] s1, s2, s3, s4;

  function automatic logic [63:0] fold_once(input logic [63:0] value);
    return (value & MASK) + ((value >> DATA_W) * PSEUDO_C);
  endfunction

  function automatic logic [DATA_W-1:0] normalize(input logic [63:0] value);
    begin
      // Four pseudo-Mersenne folds bound both supported moduli below 2P.
      if (value >= P) return DATA_W'(value - P);
      return value[DATA_W-1:0];
    end
  endfunction

  always_ff @(posedge clk) begin
    if (rst) begin
      v1 <= 1'b0;
      v2 <= 1'b0;
      v3 <= 1'b0;
      v4 <= 1'b0;
      out_valid <= 1'b0;
      s1 <= '0;
      s2 <= '0;
      s3 <= '0;
      s4 <= '0;
      p_out <= '0;
    end else begin
      v1 <= in_valid;
      v2 <= v1;
      v3 <= v2;
      v4 <= v3;
      out_valid <= v4;
      s1 <= a_in * b_in;
      s2 <= fold_once(s1);
      s3 <= fold_once(s2);
      s4 <= fold_once(s3);
      p_out <= normalize(fold_once(s4));
    end
  end
endmodule

module ntt46_zero_pad_tdp_ram #(
  parameter int unsigned DEPTH = 256,
  parameter int unsigned DATA_W = 19
) (
  input  logic                       clk,
  input  logic                       a_we,
  input  logic [$clog2(DEPTH)-1:0]   a_addr,
  input  logic [DATA_W-1:0]          a_din,
  output logic [DATA_W-1:0]          a_dout,
  input  logic                       b_we,
  input  logic [$clog2(DEPTH)-1:0]   b_addr,
  input  logic [DATA_W-1:0]          b_din,
  output logic [DATA_W-1:0]          b_dout
);
  (* ram_style = "block" *) logic [DATA_W-1:0] mem [0:DEPTH-1];
  always_ff @(posedge clk) begin
    if (a_we) mem[a_addr] <= a_din;
    a_dout <= mem[a_addr];
  end
  always_ff @(posedge clk) begin
    if (b_we) mem[b_addr] <= b_din;
    b_dout <= mem[b_addr];
  end
endmodule
