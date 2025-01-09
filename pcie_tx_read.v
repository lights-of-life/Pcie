`default_nettype none 
`timescale 1ns/100ps
                                                          
module dma_tx_read (
    
    input  wire                         clk                        ,
    input  wire                         rst                        ,

    // 读指令 
    input  wire                         dma_rd_start               , // 读指令
    input  wire        [  31:0]         dma_rd_addr                , // 读起始地址
    input  wire        [  31:0]         dma_rd_len                 , // 长度单位:DW

    // 标签请求
    output reg                          tag_read_req     = 1'b0    ,
    output reg                          tag_read_last    = 1'b0    ,
    input  wire                         tag_read_ack               ,
    input  wire        [   5:0]         tag_read_number            ,

    // 基础配置
    input  wire        [   2:0]         cfg_max_read_req           ,// 0:128B,1:256B,2:512B,3:1024B

    // 反压信号
    output reg                          cpld_buffer_req  = 1'b0    ,
    input  wire                         cpld_buffer_ack            ,

    // dma读请求数据总线, 与pcie IP交互信号
    output reg         [ 127:0]         dma_rd_data      = 'b0     ,
    output reg         [  59:0]         dma_rd_user      = 'b0     ,
    output reg         [   3:0]         dma_rd_keep      = 'b0     ,
    output reg                          dma_rd_valid     = 'b0     ,
    output reg                          dma_rd_last      = 'b0     ,
    input  wire                         dma_rd_ready     

);

//----------------------------- PARAMETER -----------------------------// 
// 状态机
localparam  S0_IDLE        = 5'b00001,
            S1_CPLD_BUFFER = 5'b00010,
            S2_TAG_REQ     = 5'b00100,
            S3_READ_TX     = 5'b01000,
            S4_DONE        = 5'b10000;

//----------------------------- SIGNAL -----------------------------// 
reg      [   4:0]         cstate          = 5'b0     ;
reg      [   4:0]         nstate          = 5'b0     ;

reg      [  31:0]         d_dma_rd_addr   = 32'b0    ;
reg      [  31:0]         d_dma_rd_len    = 32'b0    ;

reg      [  31:0]         dma_remain_len  = 32'b0    ;
reg      [  10:0]         dword_count     = 11'b0    ;
reg      [  31:0]         dma_tlp_addr    = 32'b0    ;// 一个TLP地址代表  = 1 BYTE,
reg      [   5:0]         tag_read        =  6'b0    ;// 读请求使用的编号


//----------------------------- USER LOGIC -----------------------------// 

// latch addr/len
always @(posedge clk ) 
begin
  if(rst)
    begin
      d_dma_rd_addr <= 'b0;
      d_dma_rd_len  <= 'b0;
    end
  else if(dma_rd_start)
    begin
      d_dma_rd_addr <= dma_rd_addr;
      d_dma_rd_len  <= dma_rd_len ;
    end
  else;
end

// 拆分数据包
always @(posedge clk ) 
begin
  if(rst | dma_rd_start)
    begin
      dword_count     <= 0;
      dma_remain_len  <= dma_rd_len; 
    end  
  else if(cstate == S2_TAG_REQ && tag_read_ack)
    case (cfg_max_read_req)
      3'b000: // 128                                                      
        if(dma_remain_len >=  32)
          begin
            dword_count     <= 128 >> 2;
            dma_remain_len  <= dma_remain_len - (128 >> 2);
          end      
        else
          begin
            dword_count     <= dma_remain_len;
            dma_remain_len  <= 0;
          end 
      3'b001: // 256                                                      
        if(dma_remain_len >=  64)
          begin
            dword_count     <= 256 >> 2;
            dma_remain_len  <= dma_remain_len - (256 >> 2);
          end      
        else
          begin
            dword_count     <= dma_remain_len;
            dma_remain_len  <= 0;
          end 
      3'b010: // 512                                                      
        if(dma_remain_len >=  128)
          begin
            dword_count     <= 512 >> 2;
            dma_remain_len  <= dma_remain_len - (512 >> 2);
          end      
        else
          begin
            dword_count     <= dma_remain_len;
            dma_remain_len  <= 0;
          end 
      3'b011: // 1024                                                      
        if(dma_remain_len >=  256)
          begin
            dword_count     <= 1024 >> 2;
            dma_remain_len  <= dma_remain_len - (1024 >> 2);
          end      
        else
          begin
            dword_count     <= dma_remain_len;
            dma_remain_len  <= 0;
          end 
        default: ;
    endcase
  else
    begin
      dword_count     <= dword_count    ;
      dma_remain_len  <= dma_remain_len ;    
    end
end

always @(posedge clk )
begin
  if(rst)
    dma_tlp_addr <= 'd0; // 1 tlp_addr = 1 BYTE
  else if(dma_rd_start)     
    dma_tlp_addr <= dma_rd_addr;
  else if(cstate == S3_READ_TX && dma_rd_ready)
    dma_tlp_addr <= dma_tlp_addr + (dword_count << 2);
  else;
end


// 状态机-------------------------------------------------------------
always @(posedge clk) 
begin
    if (rst) 
      cstate <= S0_IDLE;
    else
      cstate <= nstate;
end   
     
always @(*) 
begin
  if(rst)
    nstate = S0_IDLE;
  else case (cstate)
    S0_IDLE       :if(dma_rd_start                 ) nstate = S1_CPLD_BUFFER;
                   else                              nstate = S0_IDLE       ;

    S1_CPLD_BUFFER:if(cpld_buffer_ack              ) nstate = S2_TAG_REQ;
                   else                              nstate = S1_CPLD_BUFFER;
   
    S2_TAG_REQ    :if(tag_read_req && tag_read_ack ) nstate = S3_READ_TX;
                   else                              nstate = S2_TAG_REQ;

    S3_READ_TX    :if(dma_rd_ready                 ) nstate = S4_DONE;
                   else                              nstate = S3_READ_TX;

    S4_DONE       :if(dma_remain_len != 0          ) nstate = S1_CPLD_BUFFER;
                   else                              nstate = S0_IDLE;
                   
    default       :                                  nstate = S0_IDLE;
  endcase
end


always @(posedge clk)
begin 
    if(rst)
        begin
            tag_read_req  <= 1'b0;        
            tag_read_last <= 1'b0;
        end
    else if(tag_read_ack)
        begin
            tag_read_req  <= 1'b0;        
            tag_read_last <= 1'b0;
        end
    else if(cstate == S2_TAG_REQ )
        begin
            tag_read_req  <= 1'b1;        
            tag_read_last <= (dma_remain_len <= 128)?1'b1:1'b0;
        end
    else;
end

always @(posedge clk)
begin 
    if(rst)
        cpld_buffer_req <= 1'b0;
    else if(cpld_buffer_ack)
        cpld_buffer_req <= 1'b0 ; 
    else if(cstate == S1_CPLD_BUFFER)
        cpld_buffer_req <= 1'b1 ;
    else 
        cpld_buffer_req <=  cpld_buffer_req;
end

always @(posedge clk)
begin 
    if(rst)
        tag_read <= 6'b0;
    else if(tag_read_ack)
        tag_read <= tag_read_number ;
    else 
        tag_read <=  tag_read;
end

always @(posedge clk ) 
begin
  if(rst)
    begin
      dma_rd_last  <= 'd0   ;
      dma_rd_data  <= 'd0   ;
      dma_rd_user  <= 60'hff;
      dma_rd_keep  <= 'd0   ;
      dma_rd_valid <= 'd0   ;
    end  
  else if(cstate == S3_READ_TX && dma_rd_ready)
    begin
      dma_rd_last <= 1'b1  ;
      dma_rd_keep <= 4'hf  ;
      dma_rd_user <= 60'hff;
      dma_rd_data <= {
                      1'b0              , // [127]        ForceECRC    
                      3'd0              , // [126:124]    Attr    
                      3'd0              , // [123:121]    TC    
                      1'd0              , // [120]        RequesterIDEnableEP:必须设置为1'b0    
                      tag_read          , // [119:104]    CompleterID该字段仅适用于按ID进行路由的配置请求和报文    
                      16'd0             , // [103:96]     Tag可由核分配管理    
                      1'd0              , // [95:80]      RequesterID    
                      4'd0              , // [79]         PoisonedRequest用于对所发送的请求TLP进行毒化    
                      dword_count       , //              reqtype    
                      32'd0             , // [74:64]      DwordCount报文有效载荷大小    
                      dma_tlp_addr[31:2], // [63:2]       Address    
                      2'b00               // [1:0 ]       AddressType仅适用于内存传输事务和原子操作   
                     };
      dma_rd_valid <= 1'b1;
    end    
  else
    begin
      dma_rd_last  <= 'd0   ;
      dma_rd_data  <= 'd0   ;
      dma_rd_user  <= 60'hff;
      dma_rd_keep  <= 'd0   ;
      dma_rd_valid <= 'd0   ;
    end  
end

endmodule
`default_nettype wire