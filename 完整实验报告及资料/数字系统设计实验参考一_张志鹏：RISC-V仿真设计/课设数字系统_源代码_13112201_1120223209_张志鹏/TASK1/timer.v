`include "../core/defines.v"

module timer(
//定义一个32位计数器定时器模块timer
//timer模块服务于CPU，且主线是主从式的，读写操作都是由CPU发起的
    input wire clk,//时钟信号
    input wire rst,//复位信号
    input wire[31:0] data_i,//32位的数据输入端口，用于接收写入寄存器的数据
    input wire[31:0] addr_i,//32位的地址输入端口，用于指定要读写哪个寄存器
    input wire we_i,//写使能信号输入端口，用于指示当前是否进行写操作
    output reg[31:0] data_o,//32位的reg类型数据输出端口，用于输出读取寄存器的数据
    output wire int_sig_o//中断信号输出端口，用于指示定时器是否达到设定值并触发中断
    );

    localparam REG_CTRL = 5'h0;//对应timer_ctrl
    localparam REG_COUNT = 5'h4;//对应timer_count
    localparam REG_VALUE = 5'h8;//对应timer_value
    localparam REG_I = 5'hC;//对应timer_i
    localparam REG_SUM = 5'h10;//对应timer_sum
//设置地址是以4为单位递增且遵循16进制，则12对应c，16对应10，由于10多一位则位宽需改为5bit

    reg[31:0] timer_ctrl;
//定义一个2位的寄存器timer_ctrl，用于存储定时器的控制信息，即控制寄存器
//[0] 位是定时器使能位，为1时定时器开始计数
//[1] 位是定时器中断使能位，为1时定时器触发中断
//[2] 位是定时器中断挂起位，为1时表示定时器中断挂起，写1可以清除该位

    reg[31:0] timer_count;
//定义一个32位的寄存器timer_count，用于存储定时器的当前计数值，即定时器值寄存器

    reg[31:0] timer_value;
//定义一个32位的寄存器timer_value，用于存储定时器的最终预设值

    reg[31:0] timer_i;
    reg[31:0] timer_sum;
//添加sum和i两个32位的寄存器，32位是默认标准

    assign int_sig_o = ((timer_ctrl[2] == 1'b1) && (timer_ctrl[1] == 1'b1))? `INT_ASSERT: `INT_DEASSERT;
//使用assign语句对中断信号int_sig_o进行连续赋值
//当定时器中断挂起位timer_ctrl[2]为1且定时器中断使能位timer_ctrl[1]为1时，int_sig_o被赋值为 INT_ASSERT，表示中断信号被触发
//否则int_sig_o被赋值为INT_DEASSERT，表示中断信号未被触发

//以下的`RstEnable、`ZeroWord等值在"../core/defines.v"中定义

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            timer_count <= `ZeroWord;
        end else begin
            if (timer_ctrl[0] == 1'b1) begin
                timer_count <= timer_count + 1'b1;
                if (timer_count >= timer_value) begin
                    timer_count <= `ZeroWord;
                end
            end else begin
                timer_count <= `ZeroWord;
            end
        end
    end
//使用always块定义定时器的计数逻辑，该块在时钟信号clk的上升沿触发
//当复位信号rst为RstEnable时，将timer_count清零
//否则若定时器使能位timer_ctrl[0]为1，则定时器开始计数，timer_count每个时钟周期加1，且当timer_count 达到或超过timer_value时，将timer_count清零
//若定时器使能位timer_ctrl[0]为0，则timer_count仍保持为0

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            timer_ctrl <= `ZeroWord;
            timer_value <= `ZeroWord;
        end else begin
            if (we_i == `WriteEnable) begin
                case (addr_i[4:0])
                    REG_CTRL: begin
                        timer_ctrl <= {data_i[31:3], (timer_ctrl[2] & (~data_i[2])), data_i[1:0]};
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
                endcase
            end else begin
                if ((timer_ctrl[0] == 1'b1) && (timer_count >= timer_value)) begin
                    timer_ctrl[0] <= 1'b0;
                    timer_ctrl[2] <= 1'b1;
                end
            end
        end
    end
//使用always块处理寄存器的写操作，用于判断CPU通过总线传入的数据是要给到timer_ctrl还是timer_value
//若复位信号为RstEnable，则清空控制寄存器和定时器值寄存器
//否则，若写使能we_i为WriteEnable，则根据地址addr_i选择寄存器进行写操作，写入REG_CTRL时，更新控制寄存器，保留中断挂起标志；写入REG_VALUE时，更新定时器值寄存器
//若计数器达到设定值，则关闭定时器并设置中断挂起标志

    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = `ZeroWord;
        end else begin
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
                default: begin
                    data_o = `ZeroWord;
                end
            endcase
        end
    end
//使用always块处理寄存器的读操作，通过地址addr_i判断要读哪一个寄存器
//若复位信号为RstEnable，则输出数据为零
//读取REG_VALUE时，输出定时器值；读取REG_CTRL时，输出控制寄存器；读取REG_COUNT时，输出当前计数值；其他地址时，输出零
endmodule