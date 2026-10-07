package ntt46_p520_ntt46_mrec_params_pkg;

  localparam int unsigned MREC_P          = 19'd520193;
  localparam int unsigned MREC_BARRETT_K  = 19;
  localparam int unsigned MREC_MU         = 20'd528487;
  localparam int unsigned MREC_DATA_W     = 19;
  localparam int unsigned MREC_IO_W       = 19;
  localparam int unsigned MREC_LANES      = 32;
  localparam int unsigned MREC_MAX_ABS_IN = 10;
  localparam int unsigned MREC_MAX_CIN    = 4;
  localparam int unsigned MREC_PSEUDO_C   = 19'd4095;

  localparam int unsigned MREC_N_1024 = 1024;
  localparam int unsigned MREC_N_256  = 256;
  localparam int unsigned MREC_R_1024 = 256;
  localparam int unsigned MREC_R_256  = 128;
  localparam int unsigned MREC_ZEST_R_1024 = 512;
  localparam int unsigned MREC_ZEST_R_256  = 128;

  localparam int unsigned MREC_OMEGA_1024     = 19'd421701;
  localparam int unsigned MREC_OMEGA_INV_1024 = 19'd475157;
  localparam int unsigned MREC_OMEGA_512      = 19'd115000;
  localparam int unsigned MREC_OMEGA_INV_512  = 19'd8789;
  localparam int unsigned MREC_OMEGA_256      = 19'd133361;
  localparam int unsigned MREC_OMEGA_INV_256  = 19'd257957;
  localparam int unsigned MREC_OMEGA_128      = 19'd277844;
  localparam int unsigned MREC_OMEGA_INV_128  = 19'd285868;

  localparam int unsigned MREC_J      = 19'd196540;
  localparam int unsigned MREC_J_INV  = 19'd323653;
  localparam int unsigned MREC_INV2   = 19'd260097;
  localparam int unsigned MREC_INV4   = 19'd390145;
  localparam int unsigned MREC_NINV_1024 = 19'd519685;
  localparam int unsigned MREC_NINV_512  = 19'd519177;
  localparam int unsigned MREC_NINV_256  = 19'd518161;
  localparam int unsigned MREC_NINV_128  = 19'd516129;

  localparam int unsigned MREC_ALPHA_ID       = 19'd1;
  localparam int unsigned MREC_ALPHA_ID_INV   = 19'd1;
  localparam int unsigned MREC_ALPHA_M4_NEG1      = 19'd115000;
  localparam int unsigned MREC_ALPHA_M4_NEG1_INV  = 19'd8789;
  localparam int unsigned MREC_ALPHA_M4_POSJ      = 19'd421701;
  localparam int unsigned MREC_ALPHA_M4_POSJ_INV  = 19'd475157;
  localparam int unsigned MREC_ALPHA_M4_NEGJ      = 19'd98492;
  localparam int unsigned MREC_ALPHA_M4_NEGJ_INV  = 19'd45036;
  localparam int unsigned MREC_ALPHA_M2_NEG1      = 19'd133361;
  localparam int unsigned MREC_ALPHA_M2_NEG1_INV  = 19'd257957;

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

