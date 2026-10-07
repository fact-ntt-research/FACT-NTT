#ifndef FACT_NTT_REGS_H
#define FACT_NTT_REGS_H

#include <stdint.h>

#define FACT_REG_CTRL          UINT32_C(0x00)
#define FACT_REG_STATUS        UINT32_C(0x04)
#define FACT_REG_CFG_NH        UINT32_C(0x08)
#define FACT_REG_CFG_CIN       UINT32_C(0x0c)
#define FACT_REG_CFG_COUT      UINT32_C(0x10)
#define FACT_REG_WALL_CYCLES   UINT32_C(0x14)
#define FACT_REG_CORE_CYCLES   UINT32_C(0x18)
#define FACT_REG_PRELOAD_EST   UINT32_C(0x1c)
#define FACT_REG_READOUT_EST   UINT32_C(0x20)
#define FACT_REG_ERROR_CODE    UINT32_C(0x24)
#define FACT_REG_IP_ID         UINT32_C(0x28)
#define FACT_REG_BUILD_ID      UINT32_C(0x2c)
#define FACT_REG_CAP0          UINT32_C(0x30)
#define FACT_REG_CAP1          UINT32_C(0x34)
#define FACT_REG_CAP2          UINT32_C(0x38)
#define FACT_REG_PRIME0        UINT32_C(0x3c)
#define FACT_REG_PRIME1        UINT32_C(0x40)

#define FACT_CTRL_START        UINT32_C(0x01)
#define FACT_CTRL_CLEAR        UINT32_C(0x02)

#define FACT_STATUS_BUSY       UINT32_C(0x00000002)
#define FACT_STATUS_DONE       UINT32_C(0x00000004)
#define FACT_STATUS_CFG_ERROR  UINT32_C(0x00000008)
#define FACT_STATUS_CORE_ERROR UINT32_C(0x00000010)
#define FACT_STATUS_LOAD_ERROR UINT32_C(0x00000020)
#define FACT_STATUS_ERROR_MASK UINT32_C(0x00000038)
#define FACT_STATUS_LOAD_COUNT_MASK UINT32_C(0x000003c0)
#define FACT_STATUS_LOAD_COUNT_SHIFT 6u

#define FACT_IP_ID_VALUE       UINT32_C(0x46414354)

enum fact_error_code {
  FACT_ERROR_NONE = 0,
  FACT_ERROR_NH = 1,
  FACT_ERROR_CIN = 2,
  FACT_ERROR_COUT = 3,
  FACT_ERROR_PRELOAD = 4,
  FACT_ERROR_ENGINE = 5
};

static inline int fact_channel_count_valid(uint32_t value) {
  return value == 1u || value == 2u || value == 4u;
}

#endif
