`include "../core/defines.v"

module timer(
//定义一个32位计数器定时器模块timer
//timer外设模块通过主线服务于CPU，且主线是主从式的，读写操作都是由CPU发起的
    input wire clk,//时钟信号
    input wire rst,//复位信号
    input wire[31:0] data_i,//32位的数据输入端口，用于接收写入寄存器的数据
    input wire[31:0] addr_i,//32位的地址输入端口，用于指定读写操作所指向的寄存器的地址
    input wire we_i,//写使能信号输入端口，用于指示当前是否进行写操作
    output reg[31:0] data_o,//32位的reg类型数据输出端口，用于输出对寄存器进行读操作的数据
    output wire int_sig_o//中断信号输出端口，用于在定时器达到设定值时触发中断
    );

    localparam REG_CTRL = 5'h0;//用于标识对应timer_ctrl寄存器的地址
    localparam REG_COUNT = 5'h4;//用于标识对应timer_count寄存器的地址
    localparam REG_VALUE = 5'h8;//用于标识对应timer_value寄存器的地址
    localparam REG_I = 5'hC;//用于标识对应timer_i寄存器的地址
    localparam REG_SUM = 5'h10;//用于标识对应timer_sum寄存器的地址
    localparam REG_SUM_CTRL = 5'h14;//用于标识对应timer_sum_ctrl寄存器的地址
    localparam REG_I_VALUE = 5'h18;//用于标识对应timer_i_value寄存器的地址
//设置地址是以4为单位递增且遵循16进制，则12对应c，16对应10，20对应14，24对应18

    reg[31:0] timer_ctrl;
//定义一个2位的控制寄存器timer_ctrl，用于存储定时器的控制信息
//[0] 位是定时器使能位，为1时定时器开始计数
//[1] 位是定时器中断使能位，为1时定时器触发中断
//[2] 位是定时器中断挂起位，为1时表示定时器中断挂起，写1可以清除该位
    reg[31:0] timer_count;//定义一个32位的寄存器timer_count，用于存储定时器的当前计数值，即定时器值寄存器
    reg[31:0] timer_value;//定义一个32位的寄存器timer_value，用于存储定时器的最终预设值
    reg[31:0] timer_i;//定义一个32位的寄存器timer_i，用于用于记录累加过程中的当前计数值
    reg[31:0] timer_sum;//定义一个32位的寄存器timer_sum，用于用于记录每个时钟周期后timer_i的累加和
    reg[31:0] timer_sum_ctrl;//定义一个32位的寄存器timer_sum_ctrl，同timer_ctrl
    reg[31:0] timer_i_value;//定义一个32位的寄存器timer_i_value，用于作为timer_i的预设值
    reg[31:0] timer_sum_result;//定义一个32位的寄存器timer_sum_result，用于用于存储定时器累加操作的最终值

    assign int_sig_o = ((timer_sum_ctrl[2] == 1'b1) && (timer_sum_ctrl[1] == 1'b1))? `INT_ASSERT: `INT_DEASSERT;
//使用assign语句对中断信号int_sig_o进行连续赋值
//若timer_sum_ctrl的第3位和第2位都为1则int_sig_o被赋值为1，否则被赋值为0

//以下的`RstEnable、`ZeroWord等值在"../core/defines.v"中定义

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin//若复位信号rst是使能状态则清零timer_sum、timer_i
            timer_i <= `ZeroWord;
            timer_sum <= `ZeroWord;
        end 
        else begin//若复位信号不是使能状态，则进入正常操作逻辑
            if (timer_sum_ctrl[0] == 1'b1) begin//判断timer_sum_ctrl寄存器的第0位即累加使能位是否为1
                timer_i <= timer_i + 1'b1;//借用时钟上升沿进行累加
                timer_sum <= timer_sum + timer_i;//借用时钟上升沿进行计数
                if (timer_i >= timer_i_value + 1'b1) begin//若timer_i的值达到timer_i_value则t会触发中断信号，清零timer_i和timer_sum，重新开始累加
                    timer_i <= `ZeroWord;
                    timer_sum <= `ZeroWord;
                end
            end 
            else begin
                timer_i <= `ZeroWord;
                timer_sum <= `ZeroWord;
            end
        end
    end
//使用always块定义定时器的计数逻辑，该块在时钟信号clk的上升沿触发

    always @ (posedge clk) begin//若复位信号rst是使能状态则清零timer_i_value、timer_sum_ctrl、timer_value、timer_ctrl
        if (rst == `RstEnable) begin
            timer_ctrl <= `ZeroWord;
            timer_value <= `ZeroWord;
            timer_sum_ctrl <= `ZeroWord;
            timer_i_value <= `ZeroWord;
        end else begin//若复位信号不是使能状态，则进入正常操作逻辑
            if (we_i == `WriteEnable) begin
                case (addr_i[4:0])//若写使能信号we_i是使能状态，则根据地址addr_i的低5位判断写入哪个寄存器
                    REG_CTRL: begin
                        timer_ctrl <= {data_i[31:3], (timer_ctrl[2] & (~data_i[2])), data_i[1:0]};//更新timer_ctrl的低2位同时保留第2位的当前值，除非data_i[2]为1，此时第2位清零），避免直接写入操作会覆盖中断挂起位
                    end
                    REG_VALUE: begin
                        timer_value <= data_i;
                    end
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
                    end
                endcase
            end 
            else begin//若写使能信号不是使能状态，进行自动更新操作
                if ((timer_ctrl[0] == 1'b1) && (timer_count >= timer_value)) begin//若timer_ctrl的第0位即定时器使能位为1且timer_count达到限定值timer_value
                    timer_ctrl[0] <= 1'b0;//关闭定时器使能位
                    timer_ctrl[2] <= 1'b1;//设置中断挂起位
                end
                else if((timer_sum_ctrl[0] == 1'b1) && (timer_i >= timer_i_value)) begin//若timer_sum_ctrl的第0位即定时器使能位为1且timer_count达到限定值timer_value
                    timer_sum_ctrl[0] <= 1'b0;//关闭累加使能位
                    timer_sum_ctrl[2] <= 1'b1;//设置中断挂起位
                end
            end
        end
    end
//使用always块处理寄存器的写操作，用于判断CPU通过总线传入的数据是要给到timer_ctrl还是timer_value

    always @ (*) begin
        if (rst == `RstEnable) begin//若复位信号rst是使能状态则清零输出端口data_o
            data_o = `ZeroWord;
        end else begin//若复位信号不是使能状态，则进入正常操作逻辑，根据地址addr_i的低4位判断写入哪个寄存器
            case (addr_i[3:0])
                REG_VALUE: begin
                    data_o = timer_value;
                end
                REG_CTRL: begin
                    data_o = timer_ctrl;
                end
                REG_COUNT: begin
                    data_o = timer_count;
                end
                REG_SUM: begin
                    data_o = timer_sum_result;
                end
                default: begin
                    data_o = `ZeroWord;
                end
            endcase
        end
    end
//使用always块处理寄存器的读操作，通过地址addr_i判断要读哪一个寄存器

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin//若复位信号rst是使能状态则清零timer_sum_result
            timer_sum_result <= `ZeroWord;
        end 
        else begin////若复位信号不是使能状态，则进入正常操作逻辑
            if (timer_i == timer_i_value + 1'b1) begin
                timer_sum_result <= timer_sum;//当timer_i达到timer_i_value时将timer_sum的值赋给timer_sum_result以便后续读取
            end
            else begin
                timer_sum_result <= timer_sum_result;//不满足条件时timer_sum_result值不改变
            end
        end
    end
//使用always块处理timer_sum_result寄存器的更新

endmodule