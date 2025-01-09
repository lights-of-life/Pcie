`default_nettype none
`timescale 1ns/100ps
                                                         
module tag_manage
(
    input  wire                       clk                        ,
    input  wire                       rst                        ,
     
    // dma_read_tlp
    input  wire                       tag_read_req               ,// tag号请求
    input  wire                       tag_read_last              ,// 本次TLP读包的最后一个tag
    output reg                        tag_read_ack    = 1'b0     ,// tag号请求
    output reg         [ 4:0]         tag_read_number = 5'b0     ,// 响应的tag号, 当前仅提供32个tag号

    // dma_rc接口 
    input  wire                       tag_rc_vld                 ,// 一个tag的数据包已缓存入RAM
    input  wire        [ 4:0]         tag_rc_number              ,// 本次tag号
    input  wire        [10:0]         tag_rc_len                 ,// 本次tag的数据包长度, dw为一个单位

    // dma_rx接口
    output reg                        tag_rx_req    = 1'b0      ,// 读取RAM中缓存的数据请求
    input  wire                       tag_rx_ack                ,// 响应
    output reg                        tag_rx_last   = 1'b0      ,// 本次TLP读包的最后一个tag
    output reg         [ 4:0]         tag_rx_number = 5'b0      ,// 本次请求的tag号,等同于RAM地址
    output reg         [10:0]         tag_rx_len    = 11'b0     ,// 本次请求的tag的数据包长度, dw为一个单位
    input  wire                       tag_rx_done                // 本次请求的数据包已全部获取完, 刷新tag号

);

                            
//----------------------------- SIGNAL ----------------------------------// 
reg [31:0] tag_used            ;
reg [31:0] tag_used_last       ; 
reg [4:0]  tag_used_point = 5'b0;  // 写指针 



reg [31:0] tag_read_vld  = 32'b0        ;
reg [10:0] tag_read_len  [31:0]         ;
reg [4:0]  tag_read_point = 5'b0;  // 写指针                 
                                            
reg        tag_rx_busy   = 1'b0      ;                  
                  
//----------------------------- USER LOGIC -----------------------------//                      
// step_1 数据请求tag号------------------------------------------------
always @(posedge clk)
begin 
    if(rst)
        begin
            tag_used      <= 1'b0;
            tag_used_last <= 1'b0;
        end 
    else if(tag_rx_done && tag_read_req && (&tag_used == 1'b0)  ) // 该tag号数据接收完成, 将该tag号回收
        begin
            tag_used     [tag_rx_number]   <= 1'b0 ;
            tag_used_last[tag_rx_number]   <= 1'b0 ;
            tag_used     [tag_read_number]  <= 1'b1 ;
            tag_used_last[tag_read_number]  <= tag_read_last;
        end 
    else if(tag_read_req && (&tag_used == 1'b0))// 该标记使用的tag号
        begin
            tag_used     [tag_read_number]  <= 1'b1 ;
            tag_used_last[tag_read_number]  <= tag_read_last;
        end 
    else if(tag_rx_done)// 将该tag号回收
        begin
            tag_used     [tag_rx_number]   <= 1'b0 ;
            tag_used_last[tag_rx_number]   <= 1'b0 ;
        end 
    else 
        begin
            tag_used      <= tag_used     ;
            tag_used_last <= tag_used_last;
        end 
end

// 写指针 ,分配tag号
always @(posedge clk)
begin 
    if(rst)
        begin
            tag_read_ack    <= 'b0;
            tag_used_point  <= 'b0;
            tag_read_number <= 'b0;
        end
    else if(tag_read_ack)
        begin
            tag_read_ack    <=  1'b0                ;
            tag_used_point  <= tag_used_point + 1'b1;
            tag_read_number <= tag_read_number      ;
        end
    else if(tag_read_req && (&tag_used == 1'b0))
        begin
            tag_read_ack    <=  1'b1                ;
            tag_used_point  <= tag_used_point       ;
            tag_read_number <= tag_used_point       ;
        end
    else 
        begin
            tag_read_ack    <= 1'b0            ;
            tag_used_point  <= tag_used_point  ;
            tag_read_number <= tag_read_number ;
        end
end

      
// step_2 dma_rc接收到数据, 标记可读的地址----------------------------------------------
always @(posedge clk)
begin 
    if(rst)
        begin
            tag_read_vld[tag_rc_number] <= 1'b0  ;
            tag_read_len[tag_rc_number] <= 11'b0 ;
        end 
    else if(tag_rc_vld & tag_rx_req & tag_rx_ack )
        begin
            tag_read_vld[tag_rc_number] <= 1'b1       ;
            tag_read_len[tag_rc_number] <= tag_rc_len;
            tag_read_vld[tag_rx_number] <= 1'b0  ;
            tag_read_len[tag_rx_number] <= 11'b0 ;
        end 
    else if(tag_rc_vld)
        begin
            tag_read_vld[tag_rc_number] <= 1'b1       ;
            tag_read_len[tag_rc_number] <= tag_rc_len;
        end 
    else if(tag_rx_req & tag_rx_ack)
        begin
            tag_read_vld[tag_rx_number] <= 1'b0  ;
            tag_read_len[tag_rx_number] <= 11'b0 ;
        end 
    else ;
end


// step_3 dma_rx 按序从ram取出数据----------------------------------

// 读指针递增, 到了31递增自动清零
always @(posedge clk)
begin 
    if(rst)
        tag_read_point <= 5'b0;
    else if(tag_rx_req & tag_rx_ack )
        tag_read_point <= tag_read_point + 1'b1 ;
    else 
        tag_read_point <= tag_read_point ;
end

// 发起读RAM数据请求
always @(posedge clk)
begin 
    if(rst)
        begin
            tag_rx_req    <= 1'b0 ;
            tag_rx_last   <= 1'b0 ;
            tag_rx_number <= 5'b0 ;
            tag_rx_len    <= 12'b0;
        end 
    else if(tag_rx_req & tag_rx_ack)
        begin
            tag_rx_req    <= 1'b0 ;
            tag_rx_last   <= tag_rx_last   ;
            tag_rx_number <= tag_rx_number ;
            tag_rx_len    <= tag_rx_len    ;
        end 
    else if(tag_read_vld[tag_read_point] && (tag_rx_busy == 1'b0))
        begin
            tag_rx_req    <= 1'b1 ;
            tag_rx_last   <= tag_used_last[tag_read_point] ;
            tag_rx_number <= tag_read_point ;
            tag_rx_len    <= tag_read_len[tag_read_point];
        end
    else ;
end

always @(posedge clk)
begin 
    if(rst)
        tag_rx_busy <= 0;
    else if(tag_rx_req & tag_rx_ack)
        tag_rx_busy <= 1'b1 ;
    else if(tag_rx_done)
        tag_rx_busy <= 1'b0 ;
end

endmodule
                           
`default_nettype wire