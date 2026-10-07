package ntt46_mrec_params_pkg;

  localparam int unsigned MREC_P          = 18'd254977;
  localparam int unsigned MREC_BARRETT_K  = 18;
  localparam int unsigned MREC_MU         = 19'd269512;
  localparam int unsigned MREC_DATA_W     = 18;
  localparam int unsigned MREC_IO_W       = 18;
  localparam int unsigned MREC_LANES      = 32;
  localparam int unsigned MREC_MAX_ABS_IN = 10;
  localparam int unsigned MREC_MAX_CIN    = 2;
  localparam int unsigned MREC_PSEUDO_C   = 18'd7167;

  localparam int unsigned MREC_N_1024 = 1024;
  localparam int unsigned MREC_N_256  = 256;
  localparam int unsigned MREC_R_1024 = 256;
  localparam int unsigned MREC_R_256  = 128;
  localparam int unsigned MREC_ZEST_R_1024 = 512;
  localparam int unsigned MREC_ZEST_R_256  = 128;

  localparam int unsigned MREC_OMEGA_1024     = 18'd236176;
  localparam int unsigned MREC_OMEGA_INV_1024 = 18'd228789;
  localparam int unsigned MREC_OMEGA_512      = 18'd79479;
  localparam int unsigned MREC_OMEGA_INV_512  = 18'd178191;
  localparam int unsigned MREC_OMEGA_256      = 18'd111243;
  localparam int unsigned MREC_OMEGA_INV_256  = 18'd1648;
  localparam int unsigned MREC_OMEGA_128      = 18'd206308;
  localparam int unsigned MREC_OMEGA_INV_128  = 18'd166134;

  localparam int unsigned MREC_J      = 18'd32884;
  localparam int unsigned MREC_J_INV  = 18'd222093;
  localparam int unsigned MREC_INV2   = 18'd127489;
  localparam int unsigned MREC_INV4   = 18'd191233;
  localparam int unsigned MREC_NINV_1024 = 18'd254728;
  localparam int unsigned MREC_NINV_512  = 18'd254479;
  localparam int unsigned MREC_NINV_256  = 18'd253981;
  localparam int unsigned MREC_NINV_128  = 18'd252985;

  localparam int unsigned MREC_ALPHA_ID       = 18'd1;
  localparam int unsigned MREC_ALPHA_ID_INV   = 18'd1;
  localparam int unsigned MREC_ALPHA_M4_NEG1      = 18'd79479;
  localparam int unsigned MREC_ALPHA_M4_NEG1_INV  = 18'd178191;
  localparam int unsigned MREC_ALPHA_M4_POSJ      = 18'd236176;
  localparam int unsigned MREC_ALPHA_M4_POSJ_INV  = 18'd228789;
  localparam int unsigned MREC_ALPHA_M4_NEGJ      = 18'd135518;
  localparam int unsigned MREC_ALPHA_M4_NEGJ_INV  = 18'd123146;
  localparam int unsigned MREC_ALPHA_M2_NEG1      = 18'd111243;
  localparam int unsigned MREC_ALPHA_M2_NEG1_INV  = 18'd1648;

  typedef enum logic {
    MREC_MODE_256  = 1'b0,
    MREC_MODE_1024 = 1'b1
  } mrec_n_mode_t;

  typedef enum logic [1:0] {
    MREC_BRANCH_POS1 = 2'd0,
    MREC_BRANCH_NEG1 = 2'd1,
    MREC_BRANCH_POSJ = 2'd2,
    MREC_BRANCH_NEGJ = 2'd3
  } mrec_branch_sel_t;

  typedef enum logic [1:0] {
    MREC_SLOT_BRANCH    = 2'd0,
    MREC_SLOT_INVERSE   = 2'd1,
    MREC_SLOT_RECON     = 2'd2,
    MREC_SLOT_IDLE      = 2'd3
  } mrec_slot_kind_t;

endpackage
