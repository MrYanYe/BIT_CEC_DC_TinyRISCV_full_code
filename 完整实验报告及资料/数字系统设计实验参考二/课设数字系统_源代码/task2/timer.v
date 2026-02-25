
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

    localparam REG_CTRL = 5'h0;
    localparam REG_COUNT = 5'h4;
    localparam REG_VALUE = 5'h8;

    //add by my
    localparam REG_SUM = 5'hc;
    localparam REG_I = 5'h10;
    localparam REG_SUM_CTRL = 5'h14;
    localparam REG_I_LIMIT = 5'h18;

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

    //add by my
    reg[31:0] timer_sum;
    reg[31:0] timer_i;
    reg[31:0] timer_sum_ctrl;
    reg[31:0] timer_i_limit;
    reg[31:0] timer_sum_final;


    assign int_sig_o = ((timer_sum_ctrl[2] == 1'b1) && (timer_sum_ctrl[1] == 1'b1))?
    `INT_ASSERT: `INT_DEASSERT;  //若timer_sum_ctrl的第三位和第二位都为1，则将int_sig_o设置为INT_ASSERT；否则，设置为INT_DEASSERT。

    // counter
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin  //若复位信号等于`RstEnable将 timer_i和timer_sum重置为`RstEnable
            timer_i <= `ZeroWord;
            timer_sum <= `ZeroWord;
        end else begin
            if (timer_ctrl[0] == 1'b1) begin  //若复位信号未激活且timer_sum_ctrl信号的最低位为1,则进行sum操作，timer_i加1，timer_sum增加timer_i的值。
                timer_i <= timer_i + 1'b1;
                timer_sum <= timer_sum + timer_i;
                if (timer_i >= timer_i_limit + 1'b1) begin  //若timer_i大于100，则将 timer_i和timer_sum重置为`RstEnable
                    timer_i <= `ZeroWord;
                    timer_sum <= `ZeroWord;
                end
            end else begin  //若timer_sum_ctrl[0]为0,将 timer_i和timer_sum重置为`RstEnable
                timer_i <= `ZeroWord;
                timer_sum <= `ZeroWord;
            end
        end
    end

    // write regs


    always @ (posedge clk) begin  

        if (rst == `RstEnable) begin   //检查复位信号rst是否等于RstEnable`。若是， 将timer_ctrl,timer_value,timer_sum_ctrl,timer_i_limit重置为0。
            timer_ctrl <= `ZeroWord;
            timer_value <= `ZeroWord;
            timer_sum_ctrl <= `ZeroWord;
            timer_i_limit <= `ZeroWord;

        end else begin
            if (we_i == `WriteEnable) begin  //检查写使能信号we_i是否等于WriteEnable`,根据地址信号addr_i[4:0]的值选择对应的寄存器数值进行更新。                  
                case (addr_i[4:0])
                    REG_CTRL: begin
                        timer_ctrl <= {data_i[31:3], (timer_ctrl[2] & (~data_i[2])), data_i[1:0]};
                    end
                    REG_VALUE: begin
                        timer_value <= data_i;
                    end

                    //sum求和
                    REG_I: begin
                        timer_i <= data_i;
                    end
                    REG_SUM: begin
                        timer_sum <= data_i;
                    end
                    REG_SUM_CTRL: begin
                        timer_sum_ctrl <= {data_i[31:3], (timer_sum_ctrl[2] & (~data_i[2])), data_i[1:0]};;

                    end
                    REG_I_VALUE: begin
                        timer_i_limit <= data_i;
                    end
                endcase
            end else begin
                if ((timer_ctrl[0] == 1'b1) && (timer_count >= timer_value)) begin  
                //根据timer_ctrl[0]和timer_count >= timer_value的条件判断，更新timer_ctrl[0]和timer_ctrl[2]的值。
                    timer_ctrl[0] <= 1'b0;
                    timer_ctrl[2] <= 1'b1;
                end
                else if((timer_sum_ctrl[0] == 1'b1) && (timer_i >= timer_i_limit)) begin
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
                REG_SUM: begin
                    data_o = timer_sum_final;
                end
            endcase
        end
    end
    
    //result_output

    always @ (posedge clk) begin  //当clk信号的上升沿（posedge）发生时进行下列操作
        if (rst == `RstEnable) begin
            timer_sum_final <= `ZeroWord;	//如果rst（复位信号）等于RstEnable将timer_sum_final复位
        end
        else begin
            if (timer_i == timer_i_limit + 1'b1) begin
                timer_sum_final <= timer_sum;	//如果timer_i == timer_i_value + 1，将timer_sum的值赋给timer_sum_final。
            end
            else begin
                timer_sum_final <= timer_sum_final;
            end
        end
    end

endmodule
