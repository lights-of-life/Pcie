`timescale 1ns / 1ps
module pio_top #(
    parameter                           C_DATA_WIDTH = 128         ,
    parameter                           PARITY_WIDTH = C_DATA_WIDTH /8,
    parameter                           KEEP_WIDTH   = C_DATA_WIDTH /32 
)
(
    //system interface
    input                               pcie_clk                   ,//125M
    input                               pcie_rst                   ,//高有效    
    
    //PIO RX Engine
    //Completer Request Interface  
    input              [C_DATA_WIDTH-1:0]m_axis_cq_tdata            ,
    input                               m_axis_cq_tlast            ,
    input                               m_axis_cq_tvalid           ,
    input              [  84:0]         m_axis_cq_tuser            ,
    input              [KEEP_WIDTH-1:0] m_axis_cq_tkeep            ,
    output wire                         m_axis_cq_tready           ,
    
    //PIO TX Engine
    //AXI-S Completer Competion Interface
    output wire        [C_DATA_WIDTH-1:0]s_axis_cc_tdata            ,
    output wire        [KEEP_WIDTH-1:0] s_axis_cc_tkeep            ,
    output wire                         s_axis_cc_tlast            ,
    output wire                         s_axis_cc_tvalid           ,
    output wire        [  32:0]         s_axis_cc_tuser            ,
    input                               s_axis_cc_tready           ,
    
    //pio interface
    output                              bar1_wr                    ,
    output             [  15:0]         bar1_wr_addr               ,
    output             [  31:0]         bar1_wr_data               ,
    
    output                              bar1_rd                    ,
    output             [  15:0]         bar1_rd_addr               ,
    input                               bar1_rd_valid              ,
    input              [  31:0]         bar1_rd_data               ,

        
    //DMA control interface
    output                              dma_wr_start               ,
    output             [  31:0]         dma_wr_addr                ,
    output             [  31:0]         dma_wr_len                 ,

    output                              dma_rd_start               ,
    output             [  31:0]         dma_rd_addr                ,
    output             [  31:0]         dma_rd_len                  
);

wire                   [   2:0]         bar0_req_tc                ;
wire                   [   2:0]         bar0_req_attr              ;
wire                   [  10:0]         bar0_req_len               ;
wire                   [  15:0]         bar0_req_rid               ;

wire                   [   7:0]         bar0_req_tag               ;
wire                   [   7:0]         bar0_req_be                ;
wire                   [  15:0]         bar0_req_addr              ;
wire                   [   1:0]         bar0_req_at                ;

wire                   [   2:0]         bar1_req_tc                ;
wire                   [   2:0]         bar1_req_attr              ;
wire                   [  10:0]         bar1_req_len               ;
wire                   [  15:0]         bar1_req_rid               ;

wire                   [   7:0]         bar1_req_tag               ;
wire                   [   7:0]         bar1_req_be                ;
wire                   [  15:0]         bar1_req_addr              ;
wire                   [   1:0]         bar1_req_at                ;

wire                                    bar0_wr                    ;
wire                   [  15:0]         bar0_wr_addr               ;
wire                   [  31:0]         bar0_wr_data               ;

wire                                    bar0_rd                    ;
wire                   [  15:0]         bar0_rd_addr               ;
wire                                    bar0_rd_valid              ;
wire                   [  31:0]         bar0_rd_data               ;

    
pio_rx_engine u_pio_rx_engine(
    //system interface 
    .pcie_clk                          (pcie_clk                  ),  // input
    .pcie_rst                          (pcie_rst                  ),  // input

    //PIO RX Engine                  
    //Completer Request Interface    
    .m_axis_cq_tdata                   (m_axis_cq_tdata           ),  // input  [127:0]
    .m_axis_cq_tlast                   (m_axis_cq_tlast           ),  // input                   
    .m_axis_cq_tvalid                  (m_axis_cq_tvalid          ),  // input                   
    .m_axis_cq_tuser                   (m_axis_cq_tuser           ),  // input  [ 84:0]         
    .m_axis_cq_tkeep                   (m_axis_cq_tkeep           ),  // input  [  3:0] 
    .m_axis_cq_tready                  (m_axis_cq_tready          ),  // output                  

    //bar0                          
    .bar0_req_tc                       (bar0_req_tc               ),  // output [  2:0]
    .bar0_req_attr                     (bar0_req_attr             ),  // output [  2:0]
    .bar0_req_len                      (bar0_req_len              ),  // output [ 10:0]
    .bar0_req_rid                      (bar0_req_rid              ),  // output [ 15:0]

    .bar0_req_tag                      (bar0_req_tag              ),  // output [  7:0] 
    .bar0_req_be                       (bar0_req_be               ),  // output [  7:0] 
    .bar0_req_addr                     (bar0_req_addr             ),  // output [ 15:0] 
    .bar0_req_at                       (bar0_req_at               ),  // output [  1:0] 

    .bar0_wr                           (bar0_wr                   ),  // output        
    .bar0_wr_addr                      (bar0_wr_addr              ),  // output [ 15:0]
    .bar0_wr_data                      (bar0_wr_data              ),  // output [ 31:0]

    .bar0_rd                           (bar0_rd                   ),  // output        
    .bar0_rd_addr                      (bar0_rd_addr              ),  // output [ 15:0]
    .bar0_rd_valid                     (bar0_rd_valid             ),  // input         
    .bar0_rd_data                      (bar0_rd_data              ),  // input  [ 31:0]


    //bar1                          
    .bar1_req_tc                       (bar1_req_tc               ),  // output [  2:0]
    .bar1_req_attr                     (bar1_req_attr             ),  // output [  2:0]
    .bar1_req_len                      (bar1_req_len              ),  // output [ 10:0]
    .bar1_req_rid                      (bar1_req_rid              ),  // output [ 15:0]

    .bar1_req_tag                      (bar1_req_tag              ),  // output [  7:0]
    .bar1_req_be                       (bar1_req_be               ),  // output [  7:0]
    .bar1_req_addr                     (bar1_req_addr             ),  // output [ 15:0]
    .bar1_req_at                       (bar1_req_at               ),  // output [  1:0]
                                                                      
    .bar1_wr                           (bar1_wr                   ),  // output        
    .bar1_wr_addr                      (bar1_wr_addr              ),  // output [ 15:0]
    .bar1_wr_data                      (bar1_wr_data              ),  // output [ 31:0]
                                                                      
    .bar1_rd                           (bar1_rd                   ),  // output         
    .bar1_rd_addr                      (bar1_rd_addr              ),  // output [ 15:0] 
    .bar1_rd_valid                     (bar1_rd_valid             ),  // input          
    .bar1_rd_data                      (bar1_rd_data              )   // input  [ 31:0] 
);

bar0_mem u_bar0_mem(
    //system interface
    .pcie_clk                          (pcie_clk                  ),  // input
    .pcie_rst                          (pcie_rst                  ),  // input
                                                                      
    //bar0                                                            
    .bar0_wr                           (bar0_wr                   ),  // input                                
    .bar0_wr_addr                      (bar0_wr_addr              ),  // input  [ 15:0]       
    .bar0_wr_data                      (bar0_wr_data              ),  // input  [ 31:0]       
    .bar0_rd                           (bar0_rd                   ),  // input                
    .bar0_rd_addr                      (bar0_rd_addr              ),  // input  [ 15:0]       
    .bar0_rd_valid                     (bar0_rd_valid             ),  // output               
    .bar0_rd_data                      (bar0_rd_data              ),  // output [ 31:0]       
                                                                    
    //DMA                                                           
    .dma_wr_start                      (dma_wr_start              ),  // output        
    .dma_wr_addr                       (dma_wr_addr               ),  // output [ 31:0]
    .dma_wr_len                        (dma_wr_len                ),  // output [ 31:0]
                                                                    
    .dma_rd_start                      (dma_rd_start              ),  // output        
    .dma_rd_addr                       (dma_rd_addr               ),  // output [ 31:0]
    .dma_rd_len                        (dma_rd_len                )   // output [ 31:0]
);
    
pio_tx_engine u_pio_tx_engine(
    //system interface
    .pcie_clk                          (pcie_clk                  ),  // input 
    .pcie_rst                          (pcie_rst                  ),  // input 
    
    //PIO TX Engine
    //AXI-S Completer Competion Interface
    .s_axis_cc_tdata                   (s_axis_cc_tdata           ),  // output [127:0]
    .s_axis_cc_tkeep                   (s_axis_cc_tkeep           ),  // output [  3:0] 
    .s_axis_cc_tlast                   (s_axis_cc_tlast           ),  // output                  
    .s_axis_cc_tvalid                  (s_axis_cc_tvalid          ),  // output                  
    .s_axis_cc_tuser                   (s_axis_cc_tuser           ),  // output [ 31:0]         
    .s_axis_cc_tready                  (s_axis_cc_tready          ),  // input               
    
    //bar0                           
    .bar0_req_tc                       (bar0_req_tc               ),  // input  [  2:0] 
    .bar0_req_attr                     (bar0_req_attr             ),  // input  [  2:0] 
    .bar0_req_len                      (bar0_req_len              ),  // input  [ 10:0] 
    .bar0_req_rid                      (bar0_req_rid              ),  // input  [ 15:0] 

    .bar0_req_tag                      (bar0_req_tag              ),  // input  [  7:0]
    .bar0_req_be                       (bar0_req_be               ),  // input  [  7:0]
    .bar0_req_addr                     (bar0_req_addr             ),  // input  [ 15:0]
    .bar0_req_at                       (bar0_req_at               ),  // input  [  1:0]

    .bar0_rd                           (bar0_rd                   ),  // input          
    .bar0_rd_addr                      (bar0_rd_addr              ),  // input  [ 15:0] 
    .bar0_rd_valid                     (bar0_rd_valid             ),  // input          
    .bar0_rd_data                      (bar0_rd_data              ),  // input  [ 31:0] 

    //bar1                           
    .bar1_req_tc                       (bar1_req_tc               ),  // input  [  2:0] 
    .bar1_req_attr                     (bar1_req_attr             ),  // input  [  2:0] 
    .bar1_req_len                      (bar1_req_len              ),  // input  [ 10:0] 
    .bar1_req_rid                      (bar1_req_rid              ),  // input  [ 15:0] 

    .bar1_req_tag                      (bar1_req_tag              ),  // input  [  7:0]
    .bar1_req_be                       (bar1_req_be               ),  // input  [  7:0]
    .bar1_req_addr                     (bar1_req_addr             ),  // input  [ 15:0]
    .bar1_req_at                       (bar1_req_at               ),  // input  [  1:0]

    .bar1_rd                           (bar1_rd                   ),  // input         
    .bar1_rd_addr                      (bar1_rd_addr              ),  // input  [ 15:0]
    .bar1_rd_valid                     (bar1_rd_valid             ),  // input         
    .bar1_rd_data                      (bar1_rd_data              )   // input  [ 31:0]
    
);
    
    
    
endmodule    
    
                    