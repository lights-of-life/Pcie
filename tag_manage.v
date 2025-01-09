`default_nettype none
`timescale 1ns/100ps
                                                         
module tag_manage
(
    input  wire                       clk                        ,
    input  wire                       rst                        ,
     
    // dma_read_tlp
    input  wire                       tag_read_req               ,// tag������
    input  wire                       tag_read_last              ,// ����TLP���������һ��tag
    output reg                        tag_read_ack    = 1'b0     ,// tag������
    output reg         [ 4:0]         tag_read_number = 5'b0     ,// ��Ӧ��tag��, ��ǰ���ṩ32��tag��

    // dma_rc�ӿ� 
    input  wire                       tag_rc_vld                 ,// һ��tag�����ݰ��ѻ�����RAM
    input  wire        [ 4:0]         tag_rc_number              ,// ����tag��
    input  wire        [10:0]         tag_rc_len                 ,// ����tag�����ݰ�����, dwΪһ����λ

    // dma_rx�ӿ�
    output reg                        tag_rx_req    = 1'b0      ,// ��ȡRAM�л������������
    input  wire                       tag_rx_ack                ,// ��Ӧ
    output reg                        tag_rx_last   = 1'b0      ,// ����TLP���������һ��tag
    output reg         [ 4:0]         tag_rx_number = 5'b0      ,// ���������tag��,��ͬ��RAM��ַ
    output reg         [10:0]         tag_rx_len    = 11'b0     ,// ���������tag�����ݰ�����, dwΪһ����λ
    input  wire                       tag_rx_done                // ������������ݰ���ȫ����ȡ��, ˢ��tag��

);

                            
//----------------------------- SIGNAL ----------------------------------// 
reg [31:0] tag_used            ;
reg [31:0] tag_used_last       ; 
reg [4:0]  tag_used_point = 5'b0;  // дָ�� 



reg [31:0] tag_read_vld  = 32'b0        ;
reg [10:0] tag_read_len  [31:0]         ;
reg [4:0]  tag_read_point = 5'b0;  // дָ��                 
                                            
reg        tag_rx_busy   = 1'b0      ;                  
                  
//----------------------------- USER LOGIC -----------------------------//                      
// step_1 ��������tag��------------------------------------------------
always @(posedge clk)
begin 
    if(rst)
        begin
            tag_used      <= 1'b0;
            tag_used_last <= 1'b0;
        end 
    else if(tag_rx_done && tag_read_req && (&tag_used == 1'b0)  ) // ��tag�����ݽ������, ����tag�Ż���
        begin
            tag_used     [tag_rx_number]   <= 1'b0 ;
            tag_used_last[tag_rx_number]   <= 1'b0 ;
            tag_used     [tag_read_number]  <= 1'b1 ;
            tag_used_last[tag_read_number]  <= tag_read_last;
        end 
    else if(tag_read_req && (&tag_used == 1'b0))// �ñ��ʹ�õ�tag��
        begin
            tag_used     [tag_read_number]  <= 1'b1 ;
            tag_used_last[tag_read_number]  <= tag_read_last;
        end 
    else if(tag_rx_done)// ����tag�Ż���
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

// дָ�� ,����tag��
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

      
// step_2 dma_rc���յ�����, ��ǿɶ��ĵ�ַ----------------------------------------------
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


// step_3 dma_rx �����ramȡ������----------------------------------

// ��ָ�����, ����31�����Զ�����
always @(posedge clk)
begin 
    if(rst)
        tag_read_point <= 5'b0;
    else if(tag_rx_req & tag_rx_ack )
        tag_read_point <= tag_read_point + 1'b1 ;
    else 
        tag_read_point <= tag_read_point ;
end

// �����RAM��������
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