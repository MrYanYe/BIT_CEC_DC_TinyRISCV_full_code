#include <stdint.h>
#include "../include/timer.h"
#include "../include/gpio.h"
#include "../include/utils.h"

static volatile uint32_t count;
int main()
{
    int sum = 0;//需设置初值，以防止仿真时硬件会非稳态

    #ifdef SIMULATION
 //条件编译指令，用于判断是否定义了SIMULATION宏，若定义了则编译下面的代码块，否则编译#else后的代码块  
        TIMER0_REG(TIMER0_VALUE) = 500;
        //timer.h文件中定义了TIMER0_VALUE及其所对应的地址，是TIMER0_BASE(基地址) + (0x08)
        //总线TIMER0_REG向该地址输入数据，该数据决定定时器多长时间被触发一次
        //在timer.v中定义了REG_VALUE及其所对应的地址，是5'h8，与TIMER0_VALUE及其所对应的地址相同
        //因此在timer.v中处理寄存器的写操作的always块里
        //当addr_i的最后四位等于5'h8，即TIMER0_BASE(基地址) + (0x08)，即REG_VALUE及其所对应的地址，即TIMER0_VALUE及其所对应的地址时
        //会将总线TIMER0_REG向该地址输入的数据赋值给timer.v中定义的寄存器timer_value
        //综上，通过timer.v、timer.h、main.c三个文件的先后定义，实现将软件中的参数值下传至硬件，从而可进一通过仿真对某一时刻值的变化情况进行观察
        //由此方法，对于TASK1，可在各文件中相应添加定义，以观察i和sum
        TIMER0_REG(TIMER0_I_VALUE) = 100;//设置累加器的预设值为100
        TIMER0_REG(TIMER0_CTRL) = 0x07;
        TIMER0_REG(TIMER0_SUM_CTRL) = 0x07; 
        //0x07二进制写作0000 0111
        //第0位是定时器使能位，为1时定时器开始计数；第1位是定时器中断使能位，为1时使能定时器中断；第2位是定时器中断挂起位，为1时表示定时器中断挂起
        //0x07表示让定时器开始计数并在定时器计数值达到预设值时触发中断，同时清零定时器中断挂起位避免重复触发中断

        while (1) 
        {
            if (count == 1) //定时器中断触发一次
            {
                TIMER0_REG(TIMER0_CTRL) = 0x00;//禁用定时器
                TIMER0_REG(TIMER0_SUM_CTRL) = 0x00;//禁用累加器
                count = 0; //重置count
                sum = TIMER0_REG(TIMER0_SUM);//读取累加结果
                if (sum == 5050)
                    set_test_pass();//添加对sum最终累加值的判断功能
                else
                    set_test_fail();
                break;
            }
        }
    #else
        TIMER0_REG(TIMER0_VALUE) = 500000;
        TIMER0_REG(TIMER0_CTRL) = 0x07; 
        GPIO_REG(GPIO_CTRL) |= 0x1; //设置GPIO控制寄存器，使能GPIO输出
        while (1)
        {
            if (count == 50) 
            {
                count = 0;
                GPIO_REG(GPIO_DATA) ^= 0x1;//切换GPIO数据寄存器的值
            }
        }
    #endif
    return 0;
}

void timer0_irq_handler()//该函数决定定时器被开启后所执行的功能
{
    TIMER0_REG(TIMER0_SUM_CTRL) |= (1 << 2); //清除累加器中断挂起位
    count++ ;//记录中断触发的次数
}