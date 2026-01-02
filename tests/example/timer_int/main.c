#include <stdint.h>

#include "../include/timer.h"
#include "../include/gpio.h"
#include "../include/utils.h"


static volatile uint32_t count;


int main()
{

    // Add at 202601012358
    // Reference simple/main.c

    int i;
    int sum = 0;

    // sum = 5050
    for (i = 0; i <= 100; i++)
    {        
        sum += i;
        // Connect to HARDWAER
        TIMER0_REG(TIMER0_I) = i;         // #define TIMER0_I  (TIMER0_BASE + (12))
        TIMER0_REG(TIMER0_SUM) = sum;

        // 这里TIMER0_I和TIMER0_SUM就是地址，在timer.h里面定义
        // 就是基于0x20000000加上一个偏移地址，
        // 然后TIMER0_REG也在timer.h里定义
        // #define TIMER0_REG(addr) (*((volatile uint32_t *)addr))
        // 当 CPU 执行该宏对应的指令时，会自动通过地址 / 数据 / 控制总线，把数据传输到定时器外设的寄存器中
        // 把C文件中的i和sum存进寄存器。
        //
        // 然后在rtl/perips/timer.h里，在case (addr_i[4:0])把最后5位的偏移地址取出来判断
        //
        // REG_I: begin
        //     timer_i <= data_i;
        // end
        //
        // REG_SUM: begin
        //     timer_sum <= data_i;
        // end
        //
        // 通过总线把上面的数据读到FPGA的reg timer_i,sum里
        // 这样sim之后就能看波形了
        


    }

    if (sum == 5050)
        set_test_pass();
    else
        set_test_fail();

    return 0;



    count = 0;

#ifdef SIMULATION
    TIMER0_REG(TIMER0_VALUE) = 500;     // 10us period
    TIMER0_REG(TIMER0_CTRL) = 0x07;     // enable interrupt and start timer

    while (1) {
        if (count == 2) {
            TIMER0_REG(TIMER0_CTRL) = 0x00;   // stop timer
            count = 0;
            // TODO: do something
            set_test_pass();
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

    count++;
}
