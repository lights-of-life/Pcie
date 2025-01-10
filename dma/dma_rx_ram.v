module dma_rx_ram(
    input                               clk                        ,//125M
    input                               rst                        ,//高有效

//local rx interface
    input                               dma_rx_valid               ,
    input              [128-1:0]        dma_rx_data                ,
    input              [4-1:0]          dma_rx_keep                ,
    input                               dma_rx_start               ,
    input                               dma_rx_end                 ,

    input              [   4:0]         dma_rx_tag                 ,
    input              [  11:0]         dma_rx_length              ,
    input              [  12:0]         dma_rx_byte_count          ,

//read_ram
    input                               ram_rd_en                  ,
    input              [13-1:0]         ram_rd_addr                ,
    output             [128-1:0]        ram_rd_data                ,

//tag refresh
    output reg                          tag_rc_done   ='b0         ,
    output reg         [5-1:0]          tag_rc_number ='b0         ,
    output wire        [  10:0]         tag_rc_length            
);


// 寄存一拍
reg                     d_dma_rx_valid     = 'b0   ;
reg    [127:0]          d_dma_rx_data      = 'b0   ;
reg    [  3:0]          d_dma_rx_keep      = 'b0   ;
reg                     d_dma_rx_start     = 'b0   ;
reg                     d_dma_rx_end       = 'b0   ;

// 锁存配置信息
reg    [  4:0]          d_dma_rx_tag       = 'b0   ;
reg    [ 11:0]          d_dma_rx_length    = 'b0   ;
reg    [ 12:0]          d_dma_rx_byte_count= 'b0   ;

reg    [  3:0]          ram_wr_en                  ;
reg    [ 12:0]          ram_wr_addr   [3:0]        ;
reg    [ 51:0]          ram_start_addr[31:0]      ;
reg    [ 31:0]          ram_wr_data   [3:0]        ;
wire   [ 31:0]          d_ram_rd_data [3:0]        ;
reg    [  1:0]          next_start_pos     = 'b0   ;

reg    [ 10:0]          d_tag_rc_length  [31:0]    ;

// 寄存一拍输入接口
always@(posedge clk)
begin
    if(dma_rx_start)
        begin
            d_dma_rx_tag       <= dma_rx_tag;
            d_dma_rx_length    <= dma_rx_length;
            d_dma_rx_byte_count<= dma_rx_byte_count;
        end
    else;
end

// STEP1.数据缓存写入RAM中

// 确定该TAG下一次的数据起始位置
always @(posedge clk )
begin
    if(rst)
        next_start_pos <= 0;
    else if(tag_rc_done) 
        next_start_pos <= 0;
    else if(dma_rx_valid) 
        case (dma_rx_keep)
            4'b0001:  next_start_pos  <= next_start_pos + 1 ; 
            4'b0011:  next_start_pos  <= next_start_pos + 2 ; 
            4'b0111:  next_start_pos  <= next_start_pos + 3 ; 
            4'b1111:  next_start_pos  <= next_start_pos + 0 ; 
            default: ;
        endcase 
end

// 调整数据位置
always @(posedge clk )
begin
    if(rst)
        begin 
            d_dma_rx_data  <= 'b0 ;
            d_dma_rx_keep  <= 'b0 ;
            d_dma_rx_valid <= 'b0 ;
            d_dma_rx_end   <= 'b0 ;
        end 
    else if(dma_rx_valid)
        begin
            d_dma_rx_valid <= 1'b1;
            d_dma_rx_end   <= dma_rx_end;
            case (next_start_pos)
              0: begin d_dma_rx_data  <= dma_rx_data                             ; d_dma_rx_keep  <= dma_rx_keep                        ; end
              1: begin d_dma_rx_data  <= {dma_rx_data[95:0],dma_rx_data[127:96]} ; d_dma_rx_keep  <= {dma_rx_keep[2:0],dma_rx_keep[3  ]}; end
              2: begin d_dma_rx_data  <= {dma_rx_data[63:0],dma_rx_data[127:64]} ; d_dma_rx_keep  <= {dma_rx_keep[1:0],dma_rx_keep[3:2]}; end
              3: begin d_dma_rx_data  <= {dma_rx_data[31:0],dma_rx_data[127:32]} ; d_dma_rx_keep  <= {dma_rx_keep[0  ],dma_rx_keep[3:1]}; end
              default:d_dma_rx_keep <= d_dma_rx_keep ;
            endcase             
        end
    else  
        begin 
            d_dma_rx_data  <= 'b0 ;
            d_dma_rx_keep  <= 'b0 ;
            d_dma_rx_valid <= 'b0 ;
            d_dma_rx_end   <= 'b0 ;
        end 
end

// 数据写入RAM

genvar i;
integer j;
generate for(i=0;i<4;i=i+1)
begin : RAM_WR_DATA
    always @(posedge clk )
    begin
        if(rst ) 
            begin 
                ram_wr_addr[i]  <= 0;
                ram_wr_data[i]  <= 0;
                ram_wr_en  [i]  <= 0;
            end 
        else if(d_dma_rx_valid)
            begin 
                ram_wr_addr[i]                          <= (d_dma_rx_tag << 5) + ram_start_addr[d_dma_rx_tag][13*i +:13];

                ram_wr_data[i]                          <= d_dma_rx_data[(i+1)*32 - 1 :i*32 ] ;
                ram_wr_en  [i]                          <= d_dma_rx_keep[i]                   ;
            end 
        else if(tag_rc_done) 
            begin 
                ram_wr_addr[i]  <= 0;
                ram_wr_data[i]  <= 0;
                ram_wr_en  [i]  <= 0;
            end 
        else 
            begin 
                ram_wr_addr[i]  <= ram_wr_addr[i];
                ram_wr_data[i]  <= ram_wr_data[i];
                ram_wr_en  [i]  <= 0;
            end 
    end   
    
    always @(posedge clk )
    begin
        if(rst ) 
            for(j=0;j<32;j=j+1) begin
                ram_start_addr[j] <= 13'b0;
            end  
        else if(d_dma_rx_valid)
            ram_start_addr[d_dma_rx_tag][13*i +:13] <= ram_start_addr[d_dma_rx_tag][13*i +:13]+ d_dma_rx_keep[i] ;
        else if(tag_rc_done) 
            ram_start_addr[d_dma_rx_tag][13*i +:13] <= 13'b0;
        else;
    end

end
endgenerate


// STEP2.状态信息告知
integer rc_num;
initial begin
    for (rc_num = 0;rc_num < 32 ; rc_num = rc_num + 1 ) begin
        d_tag_rc_length[rc_num] = 0;
    end
end

assign tag_rc_length = d_tag_rc_length[dma_rx_tag];
always @(posedge clk )
begin
    if(rst)
        begin 
            tag_rc_done   <= 'b0;
            tag_rc_number <= 'b0;
            d_tag_rc_length[d_dma_rx_tag]  <= 'b0;
        end 
    else if(tag_rc_done) 
        begin 
            tag_rc_done   <= 1'b0;
            tag_rc_number <= 0;
            d_tag_rc_length[d_dma_rx_tag]  <= 0;
        end 
    else if(dma_rx_start) 
        begin 
            tag_rc_done   <= 1'b0;
            tag_rc_number <= 0;
            d_tag_rc_length[dma_rx_tag] <= d_tag_rc_length[dma_rx_tag] + dma_rx_length;
        end 
    else if(d_dma_rx_end &&  (d_dma_rx_length == (d_dma_rx_byte_count >> 2))) 
        begin 
            tag_rc_done   <= 1'b1;
            tag_rc_number <= d_dma_rx_tag   ;
        end 
    else ;
end


// STEP3.数据读取=====
assign ram_rd_data = {d_ram_rd_data[3],d_ram_rd_data[2],d_ram_rd_data[1],d_ram_rd_data[0]}; 
// 4个RAM
genvar ram_num;
generate for(ram_num=0;ram_num<4;ram_num=ram_num+1)
begin : FOUR_RAM
   ram_w32x8192 u_dma_data_ram_w32x8192(
        .clka     (clk                      ),//input  wire clka
        .clkb     (clk                      ),//input  wire clkb
        .wea      (1'b1                     ),//input  wire [0:0]wea
        .ena      (ram_wr_en   [ram_num]    ),//input  wire ena
        .addra    (ram_wr_addr [ram_num]    ),//input  wire [12:0]addra
        .dina     (ram_wr_data [ram_num]    ),//input  wire [31:0]dina
        .enb      (ram_rd_en                ),//input  wire enb
        .addrb    (ram_rd_addr              ),//input  wire [12:0]addrb
        .doutb    (d_ram_rd_data[ram_num]   ) //output wire [31:0]doutb
    );      
end
endgenerate


endmodule