`timescale 1ns/100ps

module dma_tx_write(
    input                               clk                          ,
    input                               rst                          ,

//写的配置信息
    input              [   2:0]         cfg_max_payload              ,//最大读写请求大小
    input                               dma_wr_start                 ,//通过PIO配置:写指令
    input              [  31:0]         dma_wr_addr                  ,//通过PIO配置:写起始地址
    input              [  31:0]         dma_wr_len                   ,//通过PIO配置:写长度,DW为一个单位

//debus_data
    input                               s_user_tx_valid              ,//debus数据转换后的字段
    input              [ 127:0]         s_user_tx_data               ,//debus数据转换后的字段
    input              [  15:0]         s_user_tx_keep               ,//debus数据转换后的字段
    input                               s_user_tx_last               ,//debus数据转换后的字段
    output reg                          s_user_tx_ready  = 1'b0      ,//debus数据转换后的字段

//与PCIEIP交互接口
    output reg                          dma_wr_last      = 1'b0      ,
    output reg         [ 127:0]         dma_wr_data      = 128'b0    ,
    output reg         [  59:0]         dma_wr_user      = 60'hff    ,
    output reg         [   3:0]         dma_wr_keep      = 4'b0      ,
    output reg                          dma_wr_valid     = 1'b0      ,
    input                               dma_wr_ready                 ,

//DMA写完成中断
    output reg                          dma_wr_intr_req  = 1'b0      ,
    input                               dma_wr_intr_ack              ,

//状态信息
    output reg                          dma_user_tx_start= 1'b0      ,
    output reg                          dma_user_tx_done = 1'b0    

);

//-------------------------------PARAMETER-------------------------------//
localparam      S0_IDLE       =   4'b0000,
                S1_TX_HEAD    =   4'b0010,
                S2_TX_DATA    =   4'b0100,
                S3_TX_DONE    =   4'b1000;
//-------------------------------SIGNAL-------------------------------//
reg                        fifo_wr_en        = 1'b0     ;
wire                       fifo_rd_en                   ;
reg       [ 127:0]         fifo_din          = 128'b0   ;
wire      [ 127:0]         fifo_dout                    ;
wire                       fifo_empty                   ;
wire                       fifo_pfull                   ;

reg       [   3:0]         cstate            = S0_IDLE  ;
reg       [   3:0]         nstate            = S0_IDLE  ;

reg       [  10:0]         dword_count       = 11'b0    ;
reg       [  63:0]         dma_tlp_addr      = 64'b0    ;
reg       [  31:0]         d_dma_wr_addr     = 32'b0    ;
reg       [  31:0]         d_dma_wr_len      = 32'b0    ;
reg       [  31:0]         dma_wr_len_remain = 32'b0    ;


reg       [  10:0]         dma_tx_cnt        = 11'b0    ;
reg       [  10:0]         d_dword_count     = 11'b0    ;

//-------------------------------USERLOGIC-------------------------------//
//==================================================================
//状态信息
//==================================================================
always@(posedge clk)
begin
    dma_user_tx_start <= ( cstate == S1_TX_HEAD )?1'b1:1'b0;
    dma_user_tx_done  <= ( cstate == S3_TX_DONE )?1'b1:1'b0;
end

//==================================================================
//中断
//==================================================================
always@(posedge clk)
begin
    if(rst)
        dma_wr_intr_req <= 1'b0;
    else if(dma_wr_intr_ack)
        dma_wr_intr_req <= 1'b0;
    else if(cstate == S3_TX_DONE)
        dma_wr_intr_req <= 1'b1;
    else;
end

//==================================================================
//STEP1初始数据锁存
//==================================================================

//debus数据缓存
always@(posedge clk)
begin
    fifo_wr_en      <= s_user_tx_valid;
    fifo_din        <= s_user_tx_data ;
    s_user_tx_ready <= ~fifo_pfull    ;
end

//配置数据缓存
always@(posedge clk)
begin
    if(dma_wr_start)
        begin
            d_dma_wr_addr <= dma_wr_addr;
            d_dma_wr_len  <= dma_wr_len;
        end
    else
        begin
            d_dma_wr_addr <= dma_wr_addr;
            d_dma_wr_len  <= dma_wr_len;
        end
end


always@(posedge clk)
begin
    if(rst)
        cstate <= S0_IDLE;
    else
        cstate <= nstate;
end

always@(*)
begin
    case(cstate)
        S0_IDLE   :if(dma_wr_start                                                           ) nstate = S1_TX_HEAD;
                   else                                                                        nstate = S0_IDLE   ;
    
        S1_TX_HEAD:if(dma_wr_ready                                                           ) nstate = S2_TX_DATA;
                   else                                                                        nstate = S1_TX_HEAD;

        S2_TX_DATA:if(fifo_rd_en && ((dma_tx_cnt + 4  ) >= d_dword_count) && dword_count != 0) nstate = S1_TX_HEAD;
                   else if(fifo_rd_en&&((dma_tx_cnt + 4)>= d_dword_count) && dword_count == 0) nstate = S3_TX_DONE;
                   else                                                                        nstate = S2_TX_DATA;

        S3_TX_DONE:                                                                            nstate = S0_IDLE   ;

        default:                                                                               nstate = S0_IDLE   ;
    endcase
end

//地址及包长度确定---------------------------------------
always@(posedge clk)
begin
    if(rst|dma_wr_start)
        case(cfg_max_payload)
            3'b000: if(dma_wr_len <= 32 ) dma_wr_len_remain <= 32'b0;
                    else                  dma_wr_len_remain <= dma_wr_len-32;    
            3'b001: if(dma_wr_len <= 64 ) dma_wr_len_remain <= 32'b0;
                    else                  dma_wr_len_remain <= dma_wr_len-64;    
            3'b010: if(dma_wr_len <= 128) dma_wr_len_remain <= 32'b0;
                    else                  dma_wr_len_remain <= dma_wr_len-128;    
            3'b011: if(dma_wr_len <= 256) dma_wr_len_remain <= 32'b0;
                    else                  dma_wr_len_remain <= dma_wr_len-256; 
            default:;   
        endcase
    else if(cstate == S1_TX_HEAD && dma_wr_ready)
        case(cfg_max_payload)
            3'b000: if(dma_wr_len_remain <= 32 ) dma_wr_len_remain <= 32'b0;
                    else                         dma_wr_len_remain <= dma_wr_len_remain - 32;    
            3'b001: if(dma_wr_len_remain <= 64 ) dma_wr_len_remain <= 32'b0;
                    else                         dma_wr_len_remain <= dma_wr_len_remain - 64;    
            3'b010: if(dma_wr_len_remain <= 128) dma_wr_len_remain <= 32'b0;
                    else                         dma_wr_len_remain <= dma_wr_len_remain - 128;    
            3'b011: if(dma_wr_len_remain <= 256) dma_wr_len_remain <= 32'b0;
                    else                         dma_wr_len_remain <= dma_wr_len_remain - 256; 
            default:;   
        endcase
    else
        dma_wr_len_remain <= dma_wr_len_remain;
end

always@(posedge clk)
begin
    if(rst|dma_wr_start)
        case(cfg_max_payload)
            3'b000: if(dma_wr_len <= 32 ) dword_count <= dma_wr_len;
                    else                  dword_count <= 32;    
            3'b001: if(dma_wr_len <= 64 ) dword_count <= dma_wr_len;
                    else                  dword_count <= 64;    
            3'b010: if(dma_wr_len <= 128) dword_count <= dma_wr_len;
                    else                  dword_count <= 128;    
            3'b011: if(dma_wr_len <= 256) dword_count <= dma_wr_len;
                    else                  dword_count <= 256; 
            default:;   
        endcase
    else if(cstate == S1_TX_HEAD && dma_wr_ready)
        case(cfg_max_payload)
            3'b000: if(dma_wr_len_remain <= 32 ) dword_count <= dma_wr_len_remain;
                    else                         dword_count <= 32;    
            3'b001: if(dma_wr_len_remain <= 64 ) dword_count <= dma_wr_len_remain;
                    else                         dword_count <= 64;    
            3'b010: if(dma_wr_len_remain <= 128) dword_count <= dma_wr_len_remain;
                    else                         dword_count <= 128;    
            3'b011: if(dma_wr_len_remain <= 256) dword_count <= dma_wr_len_remain;
                    else                         dword_count <= 256; 
            default:;   
        endcase
    else
        dword_count <= dword_count;
end

always@(posedge clk)
begin
    if(rst|dma_wr_start)
        dma_tlp_addr <= dma_wr_addr;
    else if(cstate == S1_TX_HEAD && dma_wr_ready)
        dma_tlp_addr <= dma_tlp_addr + (dword_count << 2 );  //以BYTE为单位
    else;
end

//==================================================================
//数据发送,PCIE IP接口信号
//==================================================================
assign fifo_rd_en = ( cstate == S2_TX_DATA) && dma_wr_ready && ~fifo_empty;
always@(posedge clk)
begin
    if(rst)
      begin
        dma_tx_cnt    <= 'b0;
        d_dword_count <= 'b0;
        dma_wr_last   <= 'b0;
        dma_wr_data   <= 'b0;
        dma_wr_user   <= 60'h000_0000_0000_00ff; //[3:0]:FIRST_BE[7:4]:LAST_BE
        dma_wr_keep   <= 'b0;
        dma_wr_valid  <= 'b0;
      end
    else if(cstate == S1_TX_HEAD && dma_wr_ready)
      begin
        dma_tx_cnt   <= 11'b0;
        dma_wr_keep  <= 4'hf;
        dma_wr_valid <= 1'b1;
        dma_wr_last  <= 1'b0;
        dma_wr_data  <= {
                            1'b0,                 //[127]        ForceECRC
                            3'd0,                 //[126:124]    Attr
                            3'd0,                 //[123:121]    TC
                            1'b0,                 //[120]        RequesterIDEnableEP:必须设置为1'b0
                            16'd0,                //[119:104]    CompleterID该字段仅适用于按ID进行路由的配置请求和报文
                            8'h00,                //[103:96]     Tag可由核分配管理
                            16'd0,                //[95:80]      RequesterID
                            1'b0,                 //[79]         PoisonedRequest用于对所发送的请求TLP进行毒化
                            4'b0001,              //             reqtype
                            dword_count,          //[74:64]      DwordCount报文有效载荷大小
                            dma_tlp_addr[63:2],   //[63:2]       Address
                            2'b00                 //[1:0 ]       AddressType仅适用于内存传输事务和原子操作
                            };
        d_dword_count <= dword_count;
        end
    else if(cstate == S2_TX_DATA && fifo_rd_en)
      begin
          dma_tx_cnt    <= dma_tx_cnt+4;
          d_dword_count <= d_dword_count;
      if((dma_tx_cnt + 4) > d_dword_count)   //最后一包数据
          begin
              dma_wr_keep  <= 4'hf >> (4 - d_dword_count[1:0]);
              dma_wr_valid <= 1'b1;
              dma_wr_last  <= 1'b1;
              dma_wr_data  <= fifo_dout;
          end
         else if((dma_tx_cnt + 4) == d_dword_count)   //最后一包数据
          begin
              dma_wr_keep  <= 4'hf ;
              dma_wr_valid <= 1'b1;
              dma_wr_last  <= 1'b1;
              dma_wr_data  <= fifo_dout;
          end
      else
          begin
              dma_wr_keep  <= 4'hf;
              dma_wr_valid <= 1'b1;
              dma_wr_last  <= 1'b0;
              dma_wr_data  <= fifo_dout;
          end
      end
    else
        begin
            dma_wr_keep  <= 4'h0;
            dma_wr_valid <= 1'b0;
            dma_wr_last  <= 1'b0;
            dma_wr_data  <= dma_wr_data;
        end
end

xpm_fifo_sync 
#( 
    .DOUT_RESET_VALUE    ("0"         ),// String 
    .ECC_MODE            ("no_ecc"    ),// String 
    .FIFO_MEMORY_TYPE    ("block"     ),// String 
    .FIFO_READ_LATENCY   (0           ),// DECIMAL
    .FIFO_WRITE_DEPTH    (512         ),// DECIMAL
    .FULL_RESET_VALUE    (0           ),// DECIMAL
    .PROG_EMPTY_THRESH   (32          ),// DECIMAL
    .PROG_FULL_THRESH    (500         ),// DECIMAL
    .RD_DATA_COUNT_WIDTH ($clog2(512) ),// DECIMAL
    .READ_DATA_WIDTH     (128         ),// DECIMAL
    .READ_MODE           ("fwft"      ),// String 
    .USE_ADV_FEATURES    ("1F1F"      ),// String 
    .WAKEUP_TIME         (0           ),// DECIMAL
    .WRITE_DATA_WIDTH    (128         ),// DECIMAL
    .WR_DATA_COUNT_WIDTH ($clog2(512) ) // DECIMAL 
) u_data_w128_d512_fifo ( 
    .rst                 (rst        ),
    .wr_clk              (clk        ),
    .wr_en               (fifo_wr_en ),
    .din                 (fifo_din   ),
    .prog_full           (fifo_pfull ),
    .rd_en               (fifo_rd_en ),
    .dout                (fifo_dout  ),
    .empty               (fifo_empty ),
    .sleep               (1'b0       ),
    .injectdbiterr       (1'b0       ),
    .injectsbiterr       (1'b0       ) 
); 
 
 endmodule