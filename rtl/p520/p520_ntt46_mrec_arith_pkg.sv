package ntt46_p520_ntt46_mrec_arith_pkg;

  import ntt46_p520_ntt46_mrec_params_pkg::*;

  typedef logic [MREC_DATA_W-1:0]      mrec_res_t;
  typedef logic signed [MREC_IO_W-1:0] mrec_io_t;
  typedef mrec_res_t                   mrec_vec32_t [0:MREC_LANES-1];

  localparam int unsigned MREC_PROD_W   = 2 * MREC_DATA_W;
  localparam int unsigned MREC_REDUCE_W = 31;

  function automatic mrec_res_t mod_add(input mrec_res_t a, input mrec_res_t b);
    logic [MREC_DATA_W:0] sum_ext;
    begin
      sum_ext = {1'b0, a} + {1'b0, b};
      if (sum_ext >= MREC_P) begin
        sum_ext = sum_ext - MREC_P;
      end
      return mrec_res_t'(sum_ext[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_res_t mod_sub(input mrec_res_t a, input mrec_res_t b);
    logic signed [MREC_DATA_W:0] diff_ext;
    begin
      diff_ext = $signed({1'b0, a}) - $signed({1'b0, b});
      if (diff_ext < 0) begin
        diff_ext = diff_ext + $signed(MREC_P);
      end
      return mrec_res_t'(diff_ext[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_res_t mod_neg(input mrec_res_t a);
    if (a == '0) begin
      return '0;
    end
    return mrec_res_t'(MREC_P - a);
  endfunction

  function automatic mrec_res_t signed_to_residue(input mrec_io_t value);
    logic signed [MREC_IO_W:0] value_ext;
    logic signed [MREC_IO_W:0] p_ext;
    begin
      value_ext = value;
      p_ext = $signed(MREC_P);
      if (value_ext < 0) begin
        value_ext = value_ext + p_ext;
      end
      return mrec_res_t'(value_ext[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_io_t residue_to_signed(input mrec_res_t value);
    logic signed [MREC_IO_W:0] centered;
    begin
      if (value > (MREC_P >> 1)) begin
        centered = $signed({1'b0, value}) - $signed(MREC_P);
      end else begin
        centered = $signed({1'b0, value});
      end
      return mrec_io_t'(centered[MREC_IO_W-1:0]);
    end
  endfunction

  function automatic logic [MREC_REDUCE_W-1:0] pseudo_mul_c(input logic [MREC_DATA_W-1:0] hi);
    logic [MREC_REDUCE_W-1:0] hi_ext;
    begin
      hi_ext = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, hi};
      // K = 520193 = 2^19 - 4095; C = 4095 = 2^12 - 1.
      pseudo_mul_c = (hi_ext << 12) - hi_ext;
    end
  endfunction

  function automatic logic [MREC_PROD_W-1:0] mul_const_j_raw(input mrec_res_t a);
    logic [MREC_PROD_W-1:0] a_ext;
    begin
      a_ext = {{(MREC_PROD_W-MREC_DATA_W){1'b0}}, a};
      return a_ext * MREC_J[MREC_DATA_W-1:0];
    end
  endfunction

  function automatic logic [MREC_REDUCE_W-1:0] pseudo_mersenne_fold_product(
    input logic [MREC_PROD_W-1:0] product
  );
    logic [MREC_DATA_W-1:0] lo;
    logic [MREC_DATA_W-1:0] hi;
    begin
      lo = product[MREC_DATA_W-1:0];
      hi = product[MREC_PROD_W-1:MREC_DATA_W];
      return {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);
    end
  endfunction

  function automatic logic [MREC_REDUCE_W-1:0] pseudo_mersenne_fold_reduced(
    input logic [MREC_REDUCE_W-1:0] value
  );
    logic [MREC_DATA_W-1:0] lo;
    logic [MREC_DATA_W-1:0] hi;
    begin
      lo = value[MREC_DATA_W-1:0];
      hi = mrec_res_t'(value[MREC_REDUCE_W-1:MREC_DATA_W]);
      return {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);
    end
  endfunction

  function automatic mrec_res_t pseudo_mersenne_normalize(
    input logic [MREC_REDUCE_W-1:0] value
  );
    logic [MREC_REDUCE_W-1:0] r;
    begin
      r = value;
      if (r >= MREC_P) begin
        r = r - MREC_P;
      end
      return mrec_res_t'(r[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_res_t pseudo_mersenne_normalize_neg(
    input logic [MREC_REDUCE_W-1:0] value
  );
    logic [MREC_REDUCE_W:0] value_ext;
    logic [MREC_REDUCE_W:0] p_ext;
    logic [MREC_REDUCE_W:0] diff_ext;
    begin
      value_ext = {1'b0, value};
      p_ext = {{(MREC_REDUCE_W+1-MREC_DATA_W){1'b0}}, mrec_res_t'(MREC_P)};
      if (value == '0) begin
        return '0;
      end
      if (value <= MREC_P) begin
        diff_ext = p_ext - value_ext;
      end else begin
        diff_ext = (p_ext << 1) - value_ext;
      end
      return mrec_res_t'(diff_ext[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_res_t pseudo_mersenne_reduce(input logic [MREC_PROD_W-1:0] product);
    logic [MREC_REDUCE_W-1:0] r;
    begin
      r = pseudo_mersenne_fold_product(product);
      r = pseudo_mersenne_fold_reduced(r);
      r = pseudo_mersenne_fold_reduced(r);
      if (r >= MREC_P) begin
        r = r - MREC_P;
      end
      return mrec_res_t'(r[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_res_t mod_mul(input mrec_res_t a, input mrec_res_t b);
    logic [MREC_PROD_W-1:0] product;
    begin
      product = a * b;
      return pseudo_mersenne_reduce(product);
    end
  endfunction

  function automatic mrec_res_t mod_mul_j(input mrec_res_t a);
    return pseudo_mersenne_reduce(mul_const_j_raw(a));
  endfunction

  function automatic mrec_res_t mod_half(input mrec_res_t a);
    logic [MREC_DATA_W:0] tmp;
    begin
      tmp = {1'b0, a};
      if (tmp[0]) begin
        tmp = tmp + MREC_P;
      end
      return mrec_res_t'(tmp >> 1);
    end
  endfunction

  function automatic mrec_res_t mod_quarter(input mrec_res_t a);
    return mod_half(mod_half(a));
  endfunction

endpackage

