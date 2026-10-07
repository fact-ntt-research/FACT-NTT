package ntt46_mrec_arith_pkg;

  import ntt46_mrec_params_pkg::*;

  typedef logic [MREC_DATA_W-1:0]      mrec_res_t;
  typedef logic signed [MREC_IO_W-1:0] mrec_io_t;
  typedef mrec_res_t                   mrec_vec32_t [0:MREC_LANES-1];

  localparam int unsigned MREC_PROD_W       = 2 * MREC_DATA_W;
  localparam int unsigned MREC_REDUCE_W     = 31;

  function automatic mrec_res_t mod_add(input mrec_res_t a, input mrec_res_t b);
    logic [MREC_DATA_W:0] sum_ext;
    sum_ext = {1'b0, a} + {1'b0, b};
    if (sum_ext >= MREC_P) begin
      sum_ext = sum_ext - MREC_P;
    end
    return mrec_res_t'(sum_ext[MREC_DATA_W-1:0]);
  endfunction

  function automatic mrec_res_t mod_sub(input mrec_res_t a, input mrec_res_t b);
    logic signed [MREC_DATA_W:0] diff_ext;
    diff_ext = $signed({1'b0, a}) - $signed({1'b0, b});
    if (diff_ext < 0) begin
      diff_ext = diff_ext + $signed(MREC_P);
    end
    return mrec_res_t'(diff_ext[MREC_DATA_W-1:0]);
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
    value_ext = value;
    p_ext = $signed(MREC_P);
    if (value_ext < 0) begin
      value_ext = value_ext + p_ext;
    end
    return mrec_res_t'(value_ext[MREC_DATA_W-1:0]);
  endfunction

  function automatic mrec_io_t residue_to_signed(input mrec_res_t value);
    logic signed [MREC_IO_W:0] centered;
    if (value > (MREC_P >> 1)) begin
      centered = $signed({1'b0, value}) - $signed(MREC_P);
    end else begin
      centered = $signed({1'b0, value});
    end
    return mrec_io_t'(centered[MREC_IO_W-1:0]);
  endfunction

  function automatic logic [MREC_REDUCE_W-1:0] pseudo_mul_c(input logic [MREC_DATA_W-1:0] hi);
    logic [MREC_REDUCE_W-1:0] hi_ext;
    begin
      hi_ext = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, hi};
      // For p = 254977, C = 2^18 - p = 7167 = 2^13 - 2^10 - 1.
      // Keep the reducer out of DSP48s by encoding the constant as shifts/subtracts.
      pseudo_mul_c = (hi_ext << 13) - (hi_ext << 10) - hi_ext;
    end
  endfunction

  function automatic logic [MREC_PROD_W-1:0] mul_const_j_raw(input mrec_res_t a);
    logic [MREC_PROD_W-1:0] a_ext;
    begin
      a_ext = {{(MREC_PROD_W-MREC_DATA_W){1'b0}}, a};
      // J = 32884 = 2^15 + 2^6 + 2^5 + 2^4 + 2^2.
      // Keep this fixed multiply out of DSP inference on the precombine/reconstruct path.
      mul_const_j_raw = (a_ext << 15) + (a_ext << 6) + (a_ext << 5) + (a_ext << 4) + (a_ext << 2);
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
      pseudo_mersenne_fold_product = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);
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
      pseudo_mersenne_fold_reduced = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);
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
    logic [MREC_DATA_W-1:0] lo;
    logic [MREC_DATA_W-1:0] hi;
    begin
      // product < p^2 < 2^36. Repeated folding by x = lo + hi * (2^18 - p)
      // shrinks the value quickly:
      //   after 1st fold: < 2^31
      //   after 2nd fold: < 2^26
      //   after 3rd fold: < 2^21
      //   after 4th fold: < 297978 < 2*p
      // At that point one final conditional subtract is already sufficient to
      // bring the value below p, so a 5th fold is unnecessary.
      r = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, product[MREC_DATA_W-1:0]} +
          pseudo_mul_c(product[MREC_PROD_W-1:MREC_DATA_W]);

      lo = r[MREC_DATA_W-1:0];
      hi = mrec_res_t'(r[MREC_REDUCE_W-1:MREC_DATA_W]);
      r = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);

      lo = r[MREC_DATA_W-1:0];
      hi = mrec_res_t'(r[MREC_REDUCE_W-1:MREC_DATA_W]);
      r = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);

      lo = r[MREC_DATA_W-1:0];
      hi = mrec_res_t'(r[MREC_REDUCE_W-1:MREC_DATA_W]);
      r = {{(MREC_REDUCE_W-MREC_DATA_W){1'b0}}, lo} + pseudo_mul_c(hi);

      if (r >= MREC_P) begin
        r = r - MREC_P;
      end

      return mrec_res_t'(r[MREC_DATA_W-1:0]);
    end
  endfunction

  function automatic mrec_res_t mod_mul(input mrec_res_t a, input mrec_res_t b);
    logic [MREC_PROD_W-1:0] product;
    product = a * b;
    return pseudo_mersenne_reduce(product);
  endfunction

  function automatic mrec_res_t mod_mul_j(input mrec_res_t a);
    return pseudo_mersenne_reduce(mul_const_j_raw(a));
  endfunction

  function automatic mrec_res_t mod_half(input mrec_res_t a);
    logic [MREC_DATA_W:0] tmp;
    tmp = {1'b0, a};
    if (tmp[0]) begin
      tmp = tmp + MREC_P;
    end
    return mrec_res_t'(tmp >> 1);
  endfunction

  function automatic mrec_res_t mod_quarter(input mrec_res_t a);
    return mod_half(mod_half(a));
  endfunction

endpackage
