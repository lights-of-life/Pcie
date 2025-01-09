`default_nettype none
module dma_rx_data_process(
    //systeminterface
    input  wire                         clk                      ,//125M
    input  wire                         rst                      ,//高有效

    //DMA读完成中断
    output reg                          dma_rd_intr_req = 0      ,
    input  wire                         dma_rd_intr_ack          ,
 
    //dmarxuserinterface 
    output reg                          m_user_rx_valid = 0      ,
    output wire        [ 127:0]         m_user_rx_data           ,
    output reg         [  15:0]         m_user_rx_keep           ,
    output reg                          m_user_rx_last           ,
    input  wire                         m_user_rx_ready          ,

    //reorder_quece
    output reg                          ram_rd_en       = 1'b0   ,
    output reg         [13-1:0]         ram_rd_addr     = 13'b0  ,
    input  wire        [128-1:0]        ram_rd_data              ,

    // dma_rx接口
    input  wire                         tag_rx_req               ,// 读取RAM中缓存的数据请求
    output reg                          tag_rx_ack      =  1'b0  ,// 响应
    input  wire                         tag_rx_last              ,// 本次TLP读包的最后一个tag
    input  wire        [ 4:0]           tag_rx_number            ,// 本次请求的tag号,等同于RAM地址
    input  wire        [10:0]           tag_rx_length            ,// 本次请求的tag的数据包长度, dw为一个单位
    output reg                          tag_rx_done     =  1'b0   // 本次请求的数据包已全部获取完, 刷新tag号


);

reg                     ram_rd_flag   =1'b0            ;
reg    [  13:0]         ram_rd_cnt    =14'b0           ;

reg                     d_tag_rx_last   = 'b0          ;
reg    [   4:0]         d_tag_rx_number = 'b0          ;
reg    [  10:0]         d_tag_rx_length = 'b0          ;
//读取ram中的数据---------------------------------
always @(posedge clk)
begin 
    if(rst)
        tag_rx_ack <= 0;
    else if(tag_rx_ack)
        tag_rx_ack <= 1'b0;
    else if(tag_rx_req && ~ram_rd_flag)
        tag_rx_ack <= 1'b1;
    else 
        tag_rx_ack <= 1'b0 ;
end

// 锁存当前tag的基本信息
always @(posedge clk)
begin 
    if(rst)
        begin
            d_tag_rx_last   <= 'b0;
            d_tag_rx_number <= 'b0;
            d_tag_rx_length <= 'b0;        
        end
    else if(tag_rx_ack)
        begin
            d_tag_rx_last   <= tag_rx_last  ;
            d_tag_rx_number <= tag_rx_number;
            d_tag_rx_length <= tag_rx_length;        
        end
    else ;
end



//读运行标志
always@(posedge clk)
begin
    if(rst)
        ram_rd_flag <= 1'b0;
    else if(tag_rx_ack)
        ram_rd_flag <= 1'b1;
    else if(ram_rd_en && ram_rd_cnt >= d_tag_rx_length)
        ram_rd_flag <= 1'b0;
    else;
end

//地址及读取使能
always@(posedge clk)
begin
    if(rst)
        begin
            ram_rd_en   <= 'b0;
            ram_rd_addr <= 'b0;
            ram_rd_cnt  <= 'b0;
        end
    else if(ram_rd_en && ram_rd_cnt >= d_tag_rx_length)
        begin
            ram_rd_en   <= 1'b0;
            ram_rd_addr <= 'b0;
            ram_rd_cnt  <= 'b0;
        end
    else if(ram_rd_flag & m_user_rx_ready)
        begin
            ram_rd_en   <= 1'b1;
            ram_rd_addr <= (d_tag_rx_number<<5) + (ram_rd_cnt>>2);//每个tag最多包含32个128BYTE
            ram_rd_cnt  <= ram_rd_cnt+4;
        end
    else
        begin
            ram_rd_en   <= 'b0;
            ram_rd_addr <= ram_rd_addr;
            ram_rd_cnt  <= ram_rd_cnt;
        end
end

//RAM数据返回
assign m_user_rx_data = ram_rd_data;
always@(posedge clk)
begin
    if(rst)
        m_user_rx_valid <= 0;
    else if(ram_rd_en)
        m_user_rx_valid <= 1'b1;
    else
        m_user_rx_valid <= 1'b0;
end
//此次DMA传输的最后一包数据
always@(posedge clk)
begin
    if(rst)
        begin
        m_user_rx_keep <= 'b0;
        m_user_rx_last <= 'b0;
        end
    else if(ram_rd_en && (ram_rd_cnt >= d_tag_rx_length) && d_tag_rx_last)
        begin
            m_user_rx_last<=1'b1;
            case(d_tag_rx_length[1:0])
                2'd0:   m_user_rx_keep <= 16'hffff;
                2'd1:   m_user_rx_keep <= 16'h000f;
                2'd2:   m_user_rx_keep <= 16'h00ff;
                2'd3:   m_user_rx_keep <= 16'h0fff;
                default:m_user_rx_keep <= 16'hffff;
            endcase
        end
    else
        begin
        m_user_rx_keep <= 16'hffff;
        m_user_rx_last <= 1'b0;
        end
end

//-------------------------------------------------//
//DMA读完成中断申请
always@(posedge clk)
begin
    if(rst)
        dma_rd_intr_req <= 1'b0;
    else if(dma_rd_intr_ack)
        dma_rd_intr_req <= 1'b0;
    else if(ram_rd_en && (ram_rd_cnt >= d_tag_rx_length) && d_tag_rx_last)
        dma_rd_intr_req <= 1'b1;
    else;
end

//该tag的数据获取完成
always@(posedge clk)
begin
    if(rst)
        tag_rx_done <= 1'b0;
    else if(ram_rd_en && ram_rd_cnt >= d_tag_rx_length)
        tag_rx_done <= 1'b1;
    else
        tag_rx_done <= 1'b0;
end

endmodule
`default_nettype wire