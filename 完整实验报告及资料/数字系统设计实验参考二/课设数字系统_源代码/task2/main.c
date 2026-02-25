#include <stdint.h>

#include "../include/timer.h"
#include "../include/gpio.h"
#include "../include/utils.h"


static volatile uint32_t count;


int main()
{
    int sum = 0;
    count = 0;
    
#ifdef SIMULATION

    TIMER0_REG(TIMER0_VALUE) = 500;     // 10us period
    TIMER0_REG(TIMER0_CTRL) = 0x07;     // enable interrupt and start timer
    TIMER0_REG(TIMER0_I_LIMIT) = 100;
    TIMER0_REG(TIMER0_SUM_CTRL) = 0x07; //START SUM

    // sum = 5050

    while (1) {
        if (count == 1) {
            TIMER0_REG(TIMER0_CTRL) = 0x00;   // stop timer
            TIMER0_REG(TIMER0_SUM_CTRL) = 0x00;

            count = 0;

            // TODO: do something

            sum = TIMER0_REG(TIMER0_SUM);

            if (sum == 5051)
                set_test_pass();
            else
                set_test_fail();

            break;

        }
    }
}
#endif

void timer0_irq_handler()
{
    TIMER0_REG(TIMER0_SUM_CTRL) |= (1 << 2);  // clear int pending and start timer

    count++;
}
