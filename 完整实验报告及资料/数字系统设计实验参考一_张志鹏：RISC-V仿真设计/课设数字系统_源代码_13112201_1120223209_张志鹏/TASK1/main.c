#include <stdint.h>
#include "../include/timer.h"
#include "../include/gpio.h"
#include "../include/utils.h"

static volatile uint32_t count;
int main()
{
    int i = 0;
    int sum = 0;//需设置初值，以防止仿真时硬件会非稳态

    // sum = 5050
    for (i = 0; i <= 100; i++)
    {
        sum += i;
        TIMER0_REG(TIMER0_I) = i;
        TIMER0_REG(TIMER0_SUM) = sum;

    }

    if (sum == 5050)
        set_test_pass();
    else
        set_test_fail();

    return 0;

    count = 0;
    #ifdef SIMULATION
        TIMER0_REG(TIMER0_VALUE) = 500;
        //timer.h文件中定义了TIMER0_VALUE及其所对应的地址，是TIMER0_BASE(基地址) + (0x08)
        //总线TIMER0_REG向该地址输入数据，该数据决定定时器多长时间被触发一次
        //在timer.v中定义了REG_VALUE及其所对应的地址，是5'h8，与TIMER0_VALUE及其所对应的地址相同
        //因此在timer.v中处理寄存器的写操作的always块里
        //当addr_i的最后四位等于5'h8，即TIMER0_BASE(基地址) + (0x08)，即REG_VALUE及其所对应的地址，即TIMER0_VALUE及其所对应的地址时
        //会将总线TIMER0_REG向该地址输入的数据赋值给timer.v中定义的寄存器timer_value
        //综上，通过timer.v、timer.h、main.c三个文件的先后定义，实现将软件中的参数值下传至硬件，从而可进一通过仿真对某一时刻值的变化情况进行观察
        //由此方法，对于TASK1，可在各文件中相应添加定义，以观察i和sum
        TIMER0_REG(TIMER0_CTRL) = 0x07;//设置控制寄存器以开启定时器启动计时

        while (1) 
        {
            if (count == 2) 
            {
                TIMER0_REG(TIMER0_CTRL) = 0x00;
                count = 0; 
                set_test_pass();
                break;
            }
        }
    #else
        TIMER0_REG(TIMER0_VALUE) = 500000;
        TIMER0_REG(TIMER0_CTRL) = 0x07; 
        GPIO_REG(GPIO_CTRL) |= 0x1; 
        while (1)
        {
            if (count == 50) 
            {
                count = 0;
                GPIO_REG(GPIO_DATA) ^= 0x1;
            }
        }
    #endif
    return 0;
}

void timer0_irq_handler()//该函数决定定时器被开启后所执行的功能
{
    TIMER0_REG(TIMER0_CTRL) |= (1 << 2) | (1 << 0);

    count++; 
}
