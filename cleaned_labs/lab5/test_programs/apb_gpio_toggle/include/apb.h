#ifndef APB_H
#define APB_H

#define BRAM_END_ADDR      0x00000FFC

#define APB_GPIO0_BASE     0x00040000
#define APB_GPIO0_OUT      (APB_GPIO0_BASE + 0x04)

#define TIMER_BASE         0x00040100
#define TIMER_COUNTER      (TIMER_BASE + 0x04)
#define TIMER_LIMIT        (TIMER_BASE + 0x08)
#define TIMER_CTRL         (TIMER_BASE + 0x0C)
#define TIMER_STATUS       (TIMER_BASE + 0x10)

#define TIMER_CTRL_RESET   0x00000001u
#define TIMER_CTRL_ENABLE  0x00000002u
#define TIMER_STATUS_RUNNING 0x00000001u
#define TIMER_STATUS_DONE     0x00000002u

#define REG32(addr) (*(volatile unsigned int *)(addr))

#endif