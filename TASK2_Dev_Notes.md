## TASK2_Dev_Notes


用VsCode对比新旧文件差异，在左侧文件栏，先右键一个文件，点“选择以进行比较”，然后选另外一个文件，右键，点“与已选项目进行比较”。


从实验报告参考二中：
仔细研究开发文档、参考答疑区的同届以及往届优秀技术贴之后，采用中断读取的方式以充分发挥硬件性能来进行加速。主要的思路为：修改中断条件，int_sig_o 信号是中断信号，在posedge 上升沿时阻塞赋值，使之前的 result 信号获得 sum 的值；同时增加一个 always 模块，完成 1 到 100的计数以及累加的过程，这一过程在达到条件所给出的累加边界后即可停止。在读写部分加入对应的 case，即可实现中断读取的功能。


首先来看他说的int_sig_o 
这个在timer.v里的assign语句是
```
assign int_sig_o = ((timer_ctrl[2] == 1'b1) && (timer_ctrl[1] == 1'b1))? `INT_ASSERT: `INT_DEASSERT;
```
什么意思，若timer_ctrl的第3位和第2位都为1，则int_sig_o被赋值为1，否则被赋值为0


那timer_ctrl是什么？它同样也在timer.v前面定义

    // [0]: timer enable
    // [1]: timer int enable
    // [2]: timer int pending, write 1 to clear it
    // addr offset: 0x00
    reg[31:0] timer_ctrl;

定义一个2位的控制寄存器timer_ctrl，用于存储定时器的控制信息，
//[0] 位是定时器使能位，为1时定时器开始计数
//[1] 位是定时器中断使能位，为1时定时器触发中断
//[2] 位是定时器中断挂起位，为1时表示定时器中断挂起，写1可以清除该位



---

**对于timer_ctrl <= {data_i[31:3], (timer_ctrl[2] & (~data_i[2])), data_i[1:0]};**

                        位拼接运算符，等同于
                        timer_ctrl <= {
                            data_i[31:3],        // 第3部分：bit31~bit3
                            (timer_ctrl[2] & (~data_i[2])),  // 第2部分：bit2
                            data_i[1:0]          // 第1部分：bit1~bit0
                        };

位段	功能定义	操作特性
bit31~bit3	保留位（Reserved）	无实际功能，写操作直接覆盖
bit2	定时器中断挂起位（IRQ_PENDING）	硬件置 1（溢出触发），软件清 0
bit1	定时器中断使能位（IRQ_EN）	写操作直接覆盖（1 = 使能中断）
bit0	定时器使能位（TIMER_EN）	写操作直接覆盖（1 = 使能定时器）


                        特殊位：bit2（中断挂起位）
                        这是整行代码的核心，逻辑为：timer_ctrl[2] & (~data_i[2])

                        中断挂起位（bit2）：实现 “硬件置 1、软件仅能写 1 清除” 的标准中断设计：
                        只有定时器溢出（硬件）能将 bit2 置 1（触发中断）；
                        软件处理完中断后，必须写 1 到 bit2 才能清除挂起位（写 0 无效）；
                        软件无法主动置 1 该位（避免误触发中断）。

                        这是嵌入式系统中中断处理的经典设计：中断挂起位（pending）是 “只读（软件）+ 写 1 清 0” 的特性，
                        确保中断只能由硬件触发，软件仅能确认（清除）中断，避免软件误操作引发异常中断。

---




由于已经有一个timer_ctrl控制总的定时器中断了，所以应该新设一个ctrl，也就是timer_sum_ctrl，沿用上面说的那一大堆那行代码

REG_SUM_CTRL: begin
    timer_sum_ctrl <= {data_i[31:3], (timer_sum_ctrl[2] & (~data_i[2])), data_i[1:0]};


然后跟Task1一样，在timer.v里要声明
    localparam REG_I = 5'hC;//用于标识对应timer_i寄存器的地址
    localparam REG_SUM = 5'h10;//用于标识对应timer_sum寄存器的地址
    localparam REG_SUM_CTRL = 5'h14;//用于标识对应timer_sum_ctrl寄存器的地址
    localparam REG_I_VALUE = 5'h18;//用于标识对应timer_i_value寄存器的地址
在0，4，8后面接着加，

#define TIMER0_I  (TIMER0_BASE + (0x0C))
#define TIMER0_SUM  (TIMER0_BASE + (0x10))
#define TIMER0_SUM_CTRL  (TIMER0_BASE + (0x14))
#define TIMER0_I_VALUE  (TIMER0_BASE + (0x18))

再通过TIMER0_REG赋值给对应地址的寄存器，比如

TIMER0_REG(TIMER0_I_VALUE) = 100;//设置累加器的预设值为100



TIMER0_I是变化的i，TIMER0_I_VALUE是预设的i要加到多少，比如要加到100。（timer.h）

那么timer.h和它main.c与FPGA对应起来的地方就是    

    localparam REG_I = 5'hC;//用于标识对应timer_i寄存器的地址
    localparam REG_SUM = 5'h10;//用于标识对应timer_sum寄存器的地址
    localparam REG_SUM_CTRL = 5'h14;//用于标识对应timer_sum_ctrl寄存器的地址
    localparam REG_I_VALUE = 5'h18;//用于标识对应timer_i_value寄存器的地址


case (addr_i[4:0])
                    REG_I: begin//在写操作中添加对应操作
                        timer_i <= data_i;
                    end
                    REG_SUM: begin
                        timer_sum <= data_i;
                    end
                    REG_SUM_CTRL: begin
                        timer_sum_ctrl <= {data_i[31:3], (timer_sum_ctrl[2] & (~data_i[2])), data_i[1:0]};//更新timer_sum_ctrl的低2位同时保留第2位的当前值，除非data_i[2]为1，此时第2位清零），避免直接写入操作会覆盖中断挂起位
                    end
                    REG_I_VALUE: begin
                        timer_i_value <= data_i;

这样就能读到我前面TIMER0_REG赋给那个地址的值是多少


然后进verilog里面算+1+1累加，最后得到一个sum result，还要CPU回读sum结果并校验。
这里首先要把sum result从FPGA传到总线，也就是data_o

                REG_COUNT: begin
                    data_o = timer_count;
                end
                REG_SUM: begin
                    data_o = timer_sum_result;
                end

这里REG_SUM就是最终累加结果对应的addr

在main.c里通过
sum = TIMER0_REG(TIMER0_SUM);
读取硬件模块内寄存器值，这样在main.c的软件端就可以校验结果是否为5050了

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

TIMER0_SUM对应的就是REG_SUM，只不过加上了0x20000000

---

timer_sum似乎只是要输出给CPU，CPU没给总线，所以  
REG_SUM: begin
                        timer_sum <= data_i;
似乎是多余的

//






