`default_nettype none
`timescale 1ns/1ns
                                                
module dma_tx 
(
    input  wire                      clk                             ,
    input  wire                      rst                             ,
                                                
    input  wire         [ 127:0]     dma_rd_data                     ,
    input  wire         [  59:0]     dma_rd_user                     ,
    input  wire         [   3:0]     dma_rd_keep                     ,
    input  wire                      dma_rd_valid                    ,
    input  wire                      dma_rd_last                     ,
    output reg                       dma_rd_ready     = 1'b0         , 
    
    input  wire         [ 127:0]     dma_wr_data                     ,
    input  wire         [  59:0]     dma_wr_user                     ,
    input  wire         [   3:0]     dma_wr_keep                     ,
    input  wire                      dma_wr_valid                    ,
    input  wire                      dma_wr_last                     ,
    output reg                       dma_wr_ready     = 1'b0         ,

    output wire        [ 127:0]      s_axis_rq_tdata                 ,
    output wire        [  59:0]      s_axis_rq_tuser                 ,
    output wire                      s_axis_rq_tlast                 ,
    output wire        [   3:0]      s_axis_rq_tkeep                 ,
    output wire                      s_axis_rq_tvalid                ,
    input  wire                      s_axis_rq_tready        

                                        
);
  
//----------------------------- PARAMETER --------------------------------//
localparam S0_IDLE            = 4'b0000,             
           S1_TX_RDDATA       = 4'b0010,
           S2_TX_WRDATA       = 4'b0100,
           S3_DONE            = 4'b1000;
                            
//----------------------------- SIGNAL ----------------------------------// 
reg     [  3:0]    cstate              = S0_IDLE ;
reg     [  3:0]    nstate              = S0_IDLE ;

reg                rdata_fifo_wr_en    = 1'b0    ;
reg     [192:0]    rdata_fifo_din      = 193'b0  ;
wire               rdata_fifo_rd_en              ;
wire    [192:0]    rdata_fifo_dout               ;
wire               rdata_fifo_pfull              ;
wire               rdata_fifo_empty              ;

reg                wdata_fifo_wr_en    = 1'b0    ;
reg     [192:0]    wdata_fifo_din      = 193'b0  ;
wire               wdata_fifo_rd_en              ;
wire    [192:0]    wdata_fifo_dout               ;
wire               wdata_fifo_pfull              ;
wire               wdata_fifo_empty              ;

                  
                                
                  
                  
//----------------------------- USER LOGIC -----------------------------//  

// STEP1. 数据缓存FIFO
always @(posedge clk)
begin 
    rdata_fifo_wr_en <= dma_rd_valid;
    rdata_fifo_din   <= {dma_rd_last,dma_rd_user,dma_rd_keep,dma_rd_data};
    dma_rd_ready     <= ~rdata_fifo_pfull;

    wdata_fifo_wr_en <= dma_wr_valid;
    wdata_fifo_din   <= {dma_wr_last,dma_wr_user,dma_wr_keep,dma_wr_data};
    dma_wr_ready     <= ~wdata_fifo_pfull;
end

// STEP2. 数据输出
assign rdata_fifo_rd_en = (cstate == S1_TX_RDDATA) && ~rdata_fifo_empty && s_axis_rq_tready;
assign wdata_fifo_rd_en = (cstate == S2_TX_WRDATA) && ~wdata_fifo_empty && s_axis_rq_tready;

assign s_axis_rq_tvalid = (cstate == S1_TX_RDDATA  && ~rdata_fifo_empty) || (cstate == S2_TX_WRDATA && ~wdata_fifo_empty);
assign s_axis_rq_tdata  = (cstate == S1_TX_RDDATA)?rdata_fifo_dout[127:  0]:wdata_fifo_dout[127:  0];
assign s_axis_rq_tkeep  = (cstate == S1_TX_RDDATA)?rdata_fifo_dout[131:128]:wdata_fifo_dout[131:128];
assign s_axis_rq_tuser  = (cstate == S1_TX_RDDATA)?rdata_fifo_dout[191:132]:wdata_fifo_dout[191:132];
assign s_axis_rq_tlast  = (cstate == S1_TX_RDDATA)?rdata_fifo_dout[192    ]:wdata_fifo_dout[192    ];


// 状态机
always @(posedge clk)
begin 
    if(rst)
        cstate <= S0_IDLE;
    else  
        cstate <= nstate;
end

always@(*)
begin
    case(cstate )
        S0_IDLE   :if(~rdata_fifo_empty                           )  nstate = S1_TX_RDDATA   ;
                   else if(~wdata_fifo_empty                      )  nstate = S2_TX_WRDATA   ;
                   else                                              nstate = S0_IDLE        ;
    
        S1_TX_RDDATA:if(rdata_fifo_rd_en && rdata_fifo_dout[192]  )  nstate = S3_DONE        ;
                     else                                            nstate = S1_TX_RDDATA   ;

        S2_TX_WRDATA:if(wdata_fifo_rd_en && wdata_fifo_dout[192]  )  nstate = S3_DONE        ;
                     else                                            nstate = S2_TX_WRDATA   ;

        S3_DONE:                                                     nstate = S0_IDLE        ;

        default:                                                     nstate = S0_IDLE        ;
    endcase
end

xpm_fifo_sync #(
    .DOUT_RESET_VALUE                  ("0"                       ),// String 
    .ECC_MODE                          ("no_ecc"                  ),// String 
    .FIFO_MEMORY_TYPE                  ("block"                   ),// String 
    .FIFO_READ_LATENCY                 (0                         ),// DECIMAL 
    .FIFO_WRITE_DEPTH                  (512                       ),// DECIMAL 
    .FULL_RESET_VALUE                  (0                         ),// DECIMAL 
    .PROG_EMPTY_THRESH                 (32                        ),// DECIMAL 
    .PROG_FULL_THRESH                  (500                       ),// DECIMAL 
    .RD_DATA_COUNT_WIDTH               ($clog2(512)               ),// DECIMAL 
    .READ_DATA_WIDTH                   (193                       ),// DECIMAL 
    .READ_MODE                         ("fwft"                    ),// String 
    .USE_ADV_FEATURES                  ("1F1F"                    ),// String 
    .WAKEUP_TIME                       (0                         ),// DECIMAL 
    .WRITE_DATA_WIDTH                  (193                       ),// DECIMAL 
    .WR_DATA_COUNT_WIDTH               ($clog2(512)               ) // DECIMAL 
) 
u_rdata_w193_d512_fifo ( 
    .rst                               (rst                       ),
    .wr_clk                            (clk                       ),
    .wr_en                             (rdata_fifo_wr_en          ),
    .din                               (rdata_fifo_din            ),
    .prog_full                         (rdata_fifo_pfull          ),
    .rd_en                             (rdata_fifo_rd_en          ),
    .dout                              (rdata_fifo_dout           ),
    .empty                             (rdata_fifo_empty          ),
    .sleep                             (1'b0                      ),
    .injectdbiterr                     (1'b0                      ),
    .injectsbiterr                     (1'b0                      ) 
);

xpm_fifo_sync #(
    .DOUT_RESET_VALUE                  ("0"                       ),// String 
    .ECC_MODE                          ("no_ecc"                  ),// String 
    .FIFO_MEMORY_TYPE                  ("block"                   ),// String 
    .FIFO_READ_LATENCY                 (0                         ),// DECIMAL 
    .FIFO_WRITE_DEPTH                  (512                       ),// DECIMAL 
    .FULL_RESET_VALUE                  (0                         ),// DECIMAL 
    .PROG_EMPTY_THRESH                 (32                        ),// DECIMAL 
    .PROG_FULL_THRESH                  (500                       ),// DECIMAL 
    .RD_DATA_COUNT_WIDTH               ($clog2(512)               ),// DECIMAL 
    .READ_DATA_WIDTH                   (193                       ),// DECIMAL 
    .READ_MODE                         ("fwft"                    ),// String 
    .USE_ADV_FEATURES                  ("1F1F"                    ),// String 
    .WAKEUP_TIME                       (0                         ),// DECIMAL 
    .WRITE_DATA_WIDTH                  (193                       ),// DECIMAL 
    .WR_DATA_COUNT_WIDTH               ($clog2(512)               ) // DECIMAL 
) 
u_wdata_w193_d512_fifo ( 
    .rst                               (rst                       ),
    .wr_clk                            (clk                       ),
    .wr_en                             (wdata_fifo_wr_en          ),
    .din                               (wdata_fifo_din            ),
    .prog_full                         (wdata_fifo_pfull          ),
    .rd_en                             (wdata_fifo_rd_en          ),
    .dout                              (wdata_fifo_dout           ),
    .empty                             (wdata_fifo_empty          ),
    .sleep                             (1'b0                      ),
    .injectdbiterr                     (1'b0                      ),
    .injectsbiterr                     (1'b0                      ) 
);


endmodule
                           
`default_nettype wire