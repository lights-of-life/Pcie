module dma_rx(
//systeminterface
    input                               clk                     ,//125M
    input                               rst                     ,//高有效

//dmaRXEngine
//RequesterCompletionInterface
    input              [128-1:0]        m_axis_rc_tdata         ,
    input              [  74:0]         m_axis_rc_tuser         ,
    input                               m_axis_rc_tlast         ,
    input              [4-1:0]          m_axis_rc_tkeep         ,
    input                               m_axis_rc_tvalid        ,
    output reg                          m_axis_rc_tready ='b0   ,

//localrxinterface
    output reg                          dma_rx_valid     ='b0   ,
    output reg         [128-1:0]        dma_rx_data      ='b0   ,
    output reg         [4-1:0]          dma_rx_keep      ='b0   ,
    output reg                          dma_rx_start     ='b0   ,
    output reg                          dma_rx_end       ='b0   ,

    output reg         [   7:0]         dma_rx_tag       ='b0   ,
    output reg         [  11:0]         dma_rx_length    ='b0   ,
    output reg         [  12:0]         dma_rx_byte_count='b0  


);

localparam     S0_IDLE    = 4'b0001         ;
localparam     S1_RX_HEAD = 4'b0010         ;
localparam     S2_RX_DATA = 4'b0100         ;
localparam     S3_RX_DONE = 4'b1000         ;


reg      [   3:0]         cstate     = S0_IDLE         ;
reg      [   3:0]         nstate     = S0_IDLE         ;
reg      [128-1:0]        d_rc_tdata = 'b0             ;
reg      [4-1:0]          d_rc_tkeep = 'b0             ;
reg                       d_rc_tlast = 1'b0            ;


always@(posedge clk)
begin
if(rst)
    cstate<=S0_IDLE;
else
    cstate<=nstate;
end

always@(*)
    begin
    case(cstate)
        S0_IDLE   :if(m_axis_rc_tuser[32] && m_axis_rc_tvalid   )nstate = S1_RX_HEAD;
                   else                                          nstate = S0_IDLE;
        
        S1_RX_HEAD:if(m_axis_rc_tready      && m_axis_rc_tlast && m_axis_rc_tvalid  )nstate = S3_RX_DONE;
                   else if(m_axis_rc_tready && m_axis_rc_tvalid  )nstate = S2_RX_DATA;
                   else                                          nstate = S1_RX_HEAD;
        
        S2_RX_DATA:if(m_axis_rc_tready    && m_axis_rc_tlast  && m_axis_rc_tvalid   ) nstate = S3_RX_DONE;
                   else                                          nstate = S2_RX_DATA;
        
        S3_RX_DONE:                                              nstate = S0_IDLE;

        default:                                                 nstate = S0_IDLE;
    endcase
end

//锁存头基本信息
always@(posedge clk)
begin
    if(rst)
        begin
            dma_rx_tag       <= 'b0;
            dma_rx_length    <= 'b0;
            dma_rx_byte_count<= 'b0;
        end
    else if(cstate == S1_RX_HEAD && m_axis_rc_tready)
        begin
            dma_rx_tag       <= m_axis_rc_tdata[71:64];
            dma_rx_length    <= m_axis_rc_tdata[42:32];
            dma_rx_byte_count<= m_axis_rc_tdata[28:16];
        end
    else;
end


//反压信号
always@(posedge clk)
begin
    if(rst)
        m_axis_rc_tready <= 1'b0;
    else if(m_axis_rc_tready && m_axis_rc_tlast)
        m_axis_rc_tready <= 1'b0;
    else if(cstate == S1_RX_HEAD)
        m_axis_rc_tready <= 1'b1;
    else;

end

//数据寄存一拍
always@(posedge clk)
begin
    if(rst)
        begin
            d_rc_tdata <= 'b0;
            d_rc_tkeep <= 'b0;
            d_rc_tlast <= 'b0;
        end
    else if(m_axis_rc_tready && m_axis_rc_tvalid)
        begin
            d_rc_tdata <= m_axis_rc_tdata;
            d_rc_tkeep <= m_axis_rc_tkeep;
            d_rc_tlast <= m_axis_rc_tlast;
        end
    else if(d_rc_tlast)
        begin
            d_rc_tdata <= 'b0;
            d_rc_tkeep <= 'b0;
            d_rc_tlast <= 'b0;
        end
    else;
end

//起始/终止标志
always@(posedge clk)
begin
    dma_rx_start <= (cstate == S1_RX_HEAD && m_axis_rc_tready)?1'b1:1'b0;
    dma_rx_end   <= ((d_rc_tlast&&d_rc_tkeep == 4'hf)||(m_axis_rc_tready && m_axis_rc_tvalid && m_axis_rc_tlast && m_axis_rc_tkeep != 4'hf))?1'b1:1'b0;
end

//数据转发
always@(posedge clk)
begin
    if(rst)
        begin
            dma_rx_valid <= 'b0;
            dma_rx_data  <= 'b0;
            dma_rx_keep  <= 'b0;
        end
    else if((m_axis_rc_tuser[32] != 1'b1) && m_axis_rc_tready && m_axis_rc_tvalid)
        begin
            dma_rx_valid <= 1'b1;
            dma_rx_data  <= {m_axis_rc_tdata[95:0], d_rc_tdata[127:96]};
            dma_rx_keep  <= {m_axis_rc_tkeep[ 2:0], d_rc_tkeep[3]};
        end
    else if(d_rc_tlast && d_rc_tkeep == 4'hf)
        begin
            dma_rx_valid <= 1'b1;
            dma_rx_data  <= {96'b0,d_rc_tdata[127:96]};
            dma_rx_keep  <= 4'b0001;
        end
    else
        begin
            dma_rx_valid <= 1'b0;
            dma_rx_data  <= dma_rx_data;
            dma_rx_keep  <= dma_rx_keep;
        end
end



endmodule