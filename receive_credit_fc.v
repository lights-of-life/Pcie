`timescale 1ns / 1ps

module receive_credit_fc(
    //system interface
    input                               pcie_clk                   ,//125M
    input                               pcie_rst                   ,//高有效
    
    input              [   2:0]         cfg_max_read_req           ,//Max_Read_Request_Size 最大读取请求大小
    
    input                               tag_rc_done                ,//一个tag所有的完成报文接收完成
    //input                                           dma_rd_sent, //DMA读请求发送
    output reg                          cpld_buffer_ack            ,
    input                               cpld_buffer_req            ,
    
    //flow control interface
    input              [   7:0]         cfg_fc_cplh                ,
    input              [  11:0]         cfg_fc_cpld                ,
    
    output reg                          cpld_buffer_avall           

);


//-------------------------------------------------//
//信号声明
    parameter                           TOTAL_CPLH = 64            ;
    parameter                           TOTAL_CPLD = 15872         ;

reg                    [  12:0]         max_read_req=0             ;
reg                    [  11:0]         cpld_number=0              ;
reg                    [   7:0]         cplh_number=0              ;
reg                    [  15:0]         cpld=0                     ;
reg                    [  15:0]         cplh=0                     ;

reg                                     cpld_avail=0               ;
reg                                     cplh_avail=0               ;

wire                                    dma_rd_sent                ;
reg                    [   1:0]         cpld_buffer_req_dly=0      ;
reg                                     credit_valid=0             ;
//-------------------------------------------------//
//流量控制计算
always@(posedge pcie_clk)
begin
    if(pcie_rst)
        cpld_buffer_req_dly <= 'd0;
    else
        cpld_buffer_req_dly <= {cpld_buffer_req_dly[0],cpld_buffer_req};
end

assign dma_rd_sent = (cpld_buffer_req_dly == 2'b01);

always@(*)
begin
    max_read_req <= 13'd128<<cfg_max_read_req;
    cpld_number  <= max_read_req>>4;
    cplh_number  <= max_read_req>>({2'b11,1'b1});
    
    //cpld_avail   <= (cpld <= cfg_fc_cpld);
    //cplh_avail   <= (cplh <= cfg_fc_cplh);
    
    //cpld_buffer_avall <= ((cpld <= cfg_fc_cpld) || (cfg_fc_cpld == 0)) && ((cplh <= cfg_fc_cplh) || (cfg_fc_cpld == 0));
    cpld_buffer_avall <= ((cpld <= (15872>>4))) && ((cplh <= 64));
end

always@(posedge pcie_clk)
begin
    if(pcie_rst) begin
        cpld <= 'd0;
        cplh <= 'd0;
    end
    else if(dma_rd_sent)begin
        cpld <= cpld + cpld_number;
        cplh <= cplh + cplh_number;
    end
    else if(tag_rc_done)begin
        cpld <= cpld - cpld_number;
        cplh <= cplh - cplh_number;
    end
end

always@(posedge pcie_clk)
begin
    if(pcie_rst)
        credit_valid <= 1'b0;
    else if(cpld_buffer_ack)
        credit_valid <= 1'b0;
    else if(dma_rd_sent)
        credit_valid <= 1'b1;
end

always@(posedge pcie_clk)
begin
    if(pcie_rst)
        cpld_buffer_ack <= 1'b0;
    else if(cpld_buffer_ack)
        cpld_buffer_ack <= 1'b0;
    else if(credit_valid && (cpld <= (TOTAL_CPLD>>4)) && (cplh <= TOTAL_CPLH))
        cpld_buffer_ack <= 1'b1;
end


endmodule