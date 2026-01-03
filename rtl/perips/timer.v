 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "../core/defines.v"


// 32 bits count up timer module
module timer(

    input wire clk,
    input wire rst,

    input wire[31:0] data_i,
    input wire[31:0] addr_i,
    input wire we_i,

    output reg[31:0] data_o,
    output wire int_sig_o

    );

    // 这里位数要改成5，要不然后面REG_I REG_SUM不够用了
    localparam REG_CTRL = 5'd0;
    localparam REG_COUNT = 5'd4;
    localparam REG_VALUE = 5'd8;

    localparam REG_I = 5'd12;
    localparam REG_SUM_RESULT = 5'd16;
    localparam REG_SUM_CTRL = 5'd20;
    localparam REG_I_MAX = 5'd24;

    // [0]: timer enable
    // [1]: timer int enable
    // [2]: timer int pending, write 1 to clear it
    // addr offset: 0x00
    reg[31:0] timer_ctrl;

    // timer current count, read only
    // addr offset: 0x04
    reg[31:0] timer_count;

    // timer expired value
    // addr offset: 0x08
    reg[31:0] timer_value;

    // Add by YanZY, 202601031223
    reg [31:0] timer_i = 0;             // 每次i的数值，变化的
    reg [31:0] timer_sum_temp = 0;      // 保存每次累加后的值，不断变化的
    reg [31:0] timer_sum_ctrl;
    reg [31:0] timer_i_max;
    reg [31:0] timer_sum_result;    // 最后累加后的结果，5050



    // assign int_sig_o = ((timer_ctrl[2] == 1'b1) && (timer_ctrl[1] == 1'b1))? `INT_ASSERT: `INT_DEASSERT;
    assign int_sig_o = ((timer_sum_ctrl[2] == 1'b1) && (timer_sum_ctrl[1] == 1'b1))? `INT_ASSERT: `INT_DEASSERT;
    // timer_ctrl 和 timer_sum_ctrl 在main.c中都被赋为0x07。TIMER0_REG(TIMER0_CTRL) = 0x07;

    // counter
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            timer_count <= `ZeroWord;
            timer_sum_temp <= `ZeroWord;
            timer_sum_result <= `ZeroWord;
            timer_i <= `ZeroWord;
        end else begin
            if (timer_sum_ctrl[0] == 1'b1) begin
                timer_i <= timer_i + 1'b1;
                timer_sum_temp <= timer_sum_temp + timer_i;
                // 硬件累加部分

                if (timer_i >= timer_i_max + 1'b1) begin
                    timer_i <= `ZeroWord;
                    timer_sum_temp <= `ZeroWord;
                end
            end else begin
                // timer_count <= `ZeroWord;
                // 

                timer_i <= `ZeroWord;
                timer_sum_temp <= `ZeroWord;
            end
            // if (timer_ctrl[0] == 1'b1) begin
            //     timer_count <= timer_count + 1'b1;
            //     if (timer_count >= timer_value) begin
            //         timer_count <= `ZeroWord;
            //     end
            // end else begin
            //     timer_count <= `ZeroWord;
            // end
        end
    end

    // write regs
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            timer_ctrl <= `ZeroWord;
            timer_value <= `ZeroWord;

            timer_sum_ctrl <= `ZeroWord;
            timer_i_max <= `ZeroWord;

        end else begin
            if (we_i == `WriteEnable) begin
                case (addr_i[4:0])
                    REG_CTRL: begin
                        timer_ctrl <= {data_i[31:3], (timer_ctrl[2] & (~data_i[2])), data_i[1:0]};                   

                        // 特殊位：bit2（中断挂起位）
                        // 这是整行代码的核心，逻辑为：timer_ctrl[2] & (~data_i[2])

                        // 这是嵌入式系统中中断处理的经典设计：中断挂起位（pending）是 “只读（软件）+ 写 1 清 0” 的特性，
                        // 确保中断只能由硬件触发，软件仅能确认（清除）中断，避免软件误操作引发异常中断。

                        // 更详细解释在TASK2_Dev_Notes.md


                    end
                    REG_VALUE: begin
                        timer_value <= data_i;
                    end

                    // REG_I: begin
                    //     timer_i <= data_i;
                    // end

                    // REG_SUM_RESULT: begin
                    //     timer_sum_temp <= data_i;
                    // end
                    REG_SUM_CTRL: begin
                        timer_sum_ctrl <= {data_i[31:3], (timer_sum_ctrl[2] & (~data_i[2])), data_i[1:0]};//更新timer_sum_ctrl的低2位同时保留第2位的当前值，除非data_i[2]为1，此时第2位清零），避免直接写入操作会覆盖中断挂起位
                    end
                    REG_I_MAX: begin
                        timer_i_max <= data_i;
                    end

                endcase
            end else begin
                if ((timer_ctrl[0] == 1'b1) && (timer_count >= timer_value)) begin
                    timer_ctrl[0] <= 1'b0;
                    timer_ctrl[2] <= 1'b1;
                end
                if ((timer_sum_ctrl[0] == 1'b1) && (timer_i >= timer_i_max)) begin
                    // 新增，与上面原版if的逻辑一致，判断i加到最大值则触发中断
                    timer_sum_ctrl[0] <= 1'b0;
                    timer_sum_ctrl[2] <= 1'b1;
                end
            end
        end
    end

    // read regs
    always @ (*) begin
        if (rst == `RstEnable) begin
            data_o = `ZeroWord;
        end else begin
            case (addr_i[4:0])
                REG_VALUE: begin
                    data_o = timer_value;
                end
                REG_CTRL: begin
                    data_o = timer_ctrl;
                end
                REG_COUNT: begin
                    data_o = timer_count;
                end
                REG_SUM_RESULT: begin
                    data_o = timer_sum_result;
                end
                default: begin
                    data_o = `ZeroWord;
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            timer_sum_result <= `ZeroWord;
        end 
        else begin
            if ( timer_i == timer_i_max + 1'b1 ) begin
                timer_sum_result <= timer_sum_temp;
            end
            else begin
                timer_sum_result <= timer_sum_result;
                // sum_temp还没加到100的时候，timer_sum_result保持不变
            end
        end
    end
    // 新增，对timer_sum_result更新，让其可以复位0，和获得最终timer_sum_temp的值

endmodule
