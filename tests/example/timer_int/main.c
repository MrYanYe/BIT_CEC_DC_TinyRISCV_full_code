#include <stdint.h>

#include "../include/timer.h"
#include "../include/gpio.h"
#include "../include/utils.h"


static volatile uint32_t count;


int main()
{
    count = 0;
    int sum_result;     
    sum_result = 0;     //设置初值为0，否则仿真时硬件会出现非稳态xxxxx

    int i_max = 10;

    int correct_sum_result = 0;
    int i_temp;
    for ( i_temp = 0 ; i_temp <= i_max ; i_temp++ )
    {
        correct_sum_result = correct_sum_result + i_temp;
    }   // Should be 5050

#ifdef SIMULATION
    TIMER0_REG(TIMER0_VALUE) = 500;     // 10us period
    TIMER0_REG(TIMER0_CTRL) = 0x07;     // enable interrupt and start timer

    TIMER0_REG(TIMER0_I_MAX) = i_max;     // 设置i增加到的最大值是100
    TIMER0_REG(TIMER0_SUM_CTRL) = 0x07;

    while (1) {
        if (count == 1) {
            TIMER0_REG(TIMER0_CTRL) = 0x00;   // stop timer
            TIMER0_REG(TIMER0_SUM_CTRL) = 0x00;
            count = 0;
            // TODO: do something

            sum_result = TIMER0_REG(TIMER0_SUM_RESULT);
            // 读取FPGA算完后传过来的5050
            if (sum_result == correct_sum_result)
                set_sum_test_pass();
            else
                set_sum_test_fail();


            break;
        }
    }
#else
    TIMER0_REG(TIMER0_VALUE) = 500000;  // 10ms period
    TIMER0_REG(TIMER0_CTRL) = 0x07;     // enable interrupt and start timer

    GPIO_REG(GPIO_CTRL) |= 0x1;  // set gpio0 output mode

    while (1) {
        // 500ms
        if (count == 50) {
            count = 0;
            GPIO_REG(GPIO_DATA) ^= 0x1; // toggle led
        }
    }
#endif

    return 0;
}

void timer0_irq_handler()
{
    TIMER0_REG(TIMER0_CTRL) |= (1 << 2) | (1 << 0);  // clear int pending and start timer
    TIMER0_REG(TIMER0_SUM_CTRL) |= (1 << 2) | (1 << 0);

    count++;
}
