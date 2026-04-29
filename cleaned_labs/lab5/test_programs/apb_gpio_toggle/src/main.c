#include "apb.h"

void main(void)
{
    unsigned int status;
    unsigned int gpio0_value;

    // GPIO INIT TEST
    // Write GPIO0 as 7 
    REG32(APB_GPIO0_BASE) = 0x07u;


    // TIMER TEST (commented out now. Uncomment after implementing the timer logic in apb_timer.sv)

    /* Run the timer once to 8, then restart it and run to 16. */
    REG32(TIMER_LIMIT) = 8u;
    REG32(TIMER_CTRL) = TIMER_CTRL_RESET;
    REG32(TIMER_CTRL) = TIMER_CTRL_ENABLE;

    do {
       status = REG32(TIMER_STATUS);
       (void)REG32(TIMER_COUNTER);
    } while ((status & TIMER_STATUS_DONE) == 0u);

    REG32(TIMER_LIMIT) = 16u;
    REG32(TIMER_CTRL) = TIMER_CTRL_RESET;
    REG32(TIMER_CTRL) = TIMER_CTRL_ENABLE;

    do {
       status = REG32(TIMER_STATUS);
       (void)REG32(TIMER_COUNTER);
    } while ((status & TIMER_STATUS_DONE) == 0u);

    
    // GPIO FINAL TEST: Toggle GPIO0 output based on the sampled input value at the end.
    /* Loop GPIO0 output back from the sampled input value at the end. */
    REG32(APB_GPIO0_OUT) = 0x5Au;
    gpio0_value = REG32(APB_GPIO0_BASE);
    REG32(APB_GPIO0_OUT) = gpio0_value;

    /* Tell the testbench the program reached the end of the sequence. */
    REG32(BRAM_END_ADDR) = 0xC0FFEEu;

    while (1) {
        /* wait for simulation end marker */
    }
}
