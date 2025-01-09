`default_nettype none
`timescale 1ns/100ps
//////////////////////////////////////////////////////////////////////////////////
// Copyright(c)All rights reserved
// 
// Author       : 
// Project Name : 
// Module Name  : 
// Target Device: 
// Tool Version : vivado2021.2
//
// Description  : 
//
// Revision History
// Version    Date          Author       Description
// -------------------------------------------------------------------------------
// 
//////////////////////////////////////////////////////////////////////////////////
                                                               
module dma_top
(
    input  wire                    clk              ,
    input  wire                    rst              ,

    // 基本配置项------------------------------------
    input  wire [  2:0]            cfg_max_read_req ,                                                                   
    input  wire [  2:0]            cfg_max_payload  ,                                                                   

    input  wire                    dma_rd_start     ,
    input  wire [ 31:0]            dma_rd_addr      ,
    input  wire [ 31:0]            dma_rd_len       ,

    input  wire                    dma_wr_start     ,
    input  wire [ 31:0]            dma_wr_addr      ,
    input  wire [ 31:0]            dma_wr_len       ,
    
    output wire                    dma_user_tx_start, 
    output wire                    dma_user_tx_done , 

    // 用户数据接口----------------------------------
    output wire                    m_user_rx_valid  ,
    output wire [127:0]            m_user_rx_data   ,
    output wire [ 15:0]            m_user_rx_keep   ,
    output wire                    m_user_rx_last   ,
    input  wire                    m_user_rx_ready  ,

    input  wire                    s_user_tx_valid  ,
    input  wire [127:0]            s_user_tx_data   ,
    input  wire [ 15:0]            s_user_tx_keep   ,
    input  wire                    s_user_tx_last   ,
    output wire                    s_user_tx_ready  ,

   // PCIE IP数据接口----------------------------------
    input  wire [127:0]            m_axis_rc_tdata  ,
    input  wire [ 74:0]            m_axis_rc_tuser  ,
    input  wire                    m_axis_rc_tlast  ,
    input  wire [  3:0]            m_axis_rc_tkeep  ,
    input  wire                    m_axis_rc_tvalid ,
    output wire                    m_axis_rc_tready ,

    output wire [127:0]            s_axis_rq_tdata  ,
    output wire [ 59:0]            s_axis_rq_tuser  ,
    output wire                    s_axis_rq_tlast  ,
    output wire [  3:0]            s_axis_rq_tkeep  ,
    output wire                    s_axis_rq_tvalid ,
    input  wire                    s_axis_rq_tready ,    
    
    // PCIE 中断 --------------------------------------
    output wire                    dma_rd_intr_req  , 
    input  wire                    dma_rd_intr_ack  , 

    output wire                    dma_wr_intr_req  , 
    input  wire                    dma_wr_intr_ack  
    


);
// dma_rx -> dma_rx_ram
wire          dma_rx_valid     ;
wire  [127:0] dma_rx_data      ;
wire  [  3:0] dma_rx_keep      ;
wire          dma_rx_start     ;
wire          dma_rx_end       ;

wire  [  7:0] dma_rx_tag       ;
wire  [ 11:0] dma_rx_length    ;
wire  [ 12:0] dma_rx_byte_count;

// dma_rx_ram <-> dma_rx_process
wire          ram_rd_en        ; 
wire  [ 12:0] ram_rd_addr      ; 
wire  [127:0] ram_rd_data      ; 

// dma_rx_ram -> tag_manage
wire          tag_rc_vld       ;
wire  [  4:0] tag_rc_number    ;
wire  [ 10:0] tag_rc_len       ;

// dma_rx_process <-> tag_manage
wire         tag_rx_req        ;
wire         tag_rx_ack        ;
wire         tag_rx_last       ;
wire [  4:0] tag_rx_number     ;
wire [ 10:0] tag_rx_len        ;
wire         tag_rx_done       ;

// dma_tx_read -> dma_tx
wire [127:0] dma_rd_data       ;
wire [ 59:0] dma_rd_user       ;
wire [  3:0] dma_rd_keep       ;
wire         dma_rd_valid      ;
wire         dma_rd_last       ;
wire         dma_rd_ready      ;

// dma_tx_write -> dma_tx
wire [127:0] dma_wr_data       ;
wire [ 59:0] dma_wr_user       ;
wire [  3:0] dma_wr_keep       ;
wire         dma_wr_valid      ;
wire         dma_wr_last       ;
wire         dma_wr_ready      ;

// 反压信号
wire         cpld_buffer_req   ;                                      
wire         cpld_buffer_ack   ;  

// dma_tx_read <-> tag_manage
wire         tag_read_req      ;
wire         tag_read_last     ;
wire         tag_read_ack      ;
wire [4:0]   tag_read_number   ;




dma_rx  u_dma_rx (
    .clk                               (clk                       ),// input          
    .rst                               (rst                       ),// input          

    // PCIE_IP IN
    .m_axis_rc_tdata                   (m_axis_rc_tdata           ),// input  [127:0]
    .m_axis_rc_tuser                   (m_axis_rc_tuser           ),// input  [ 74:0] 
    .m_axis_rc_tlast                   (m_axis_rc_tlast           ),// input           
    .m_axis_rc_tkeep                   (m_axis_rc_tkeep           ),// input  [  3:0]  
    .m_axis_rc_tvalid                  (m_axis_rc_tvalid          ),// input           
    .m_axis_rc_tready                  (m_axis_rc_tready          ),// output           

    // dma_rx -> dma_rx_ram
    .dma_rx_valid                      (dma_rx_valid              ),// output          
    .dma_rx_data                       (dma_rx_data               ),// output [127:0]
    .dma_rx_keep                       (dma_rx_keep               ),// output [  3:0]  
    .dma_rx_start                      (dma_rx_start              ),// output          
    .dma_rx_end                        (dma_rx_end                ),// output          

    .dma_rx_tag                        (dma_rx_tag                ),// output [  7:0] 
    .dma_rx_length                     (dma_rx_length             ),// output [ 11:0] 
    .dma_rx_byte_count                 (dma_rx_byte_count         ) // output [ 12:0] 
);


dma_rx_ram  u_dma_rx_ram (
    .clk                               (clk                       ),// input 
    .rst                               (rst                       ),// input 

    // dma_rx -> dma_rx_ram
    .dma_rx_valid                      (dma_rx_valid              ),// input
    .dma_rx_data                       (dma_rx_data               ),// input  [127:0]
    .dma_rx_keep                       (dma_rx_keep               ),// input  [  3:0]
    .dma_rx_start                      (dma_rx_start              ),// input
    .dma_rx_end                        (dma_rx_end                ),// input

    .dma_rx_tag                        (dma_rx_tag                ),// input  [  4:0]
    .dma_rx_length                     (dma_rx_length             ),// input  [ 11:0]
    .dma_rx_byte_count                 (dma_rx_byte_count         ),// input  [ 12:0]

    // dma_rx_ram <-> dma_rx_process
    .ram_rd_en                         (ram_rd_en                 ),// input
    .ram_rd_addr                       (ram_rd_addr               ),// input  [ 12:0]
    .ram_rd_data                       (ram_rd_data               ),// output [127:0]

    // dma_rx_ram -> tag_manage
    .tag_rc_done                       (tag_rc_vld                ),// output
    .tag_rc_number                     (tag_rc_number             ),// output [  4:0]
    .tag_rc_length                     (tag_rc_len                ) // output [ 10:0]
  );

dma_rx_data_process  u_dma_rx_data_process (
    .clk                               (clk                       ),// input
    .rst                               (rst                       ),// input

    .dma_rd_intr_req                   (dma_rd_intr_req           ),// output
    .dma_rd_intr_ack                   (dma_rd_intr_ack           ),// input 

    //FROM USER 
    .m_user_rx_valid                   (m_user_rx_valid           ),// output
    .m_user_rx_data                    (m_user_rx_data            ),// output [127:0]
    .m_user_rx_keep                    (m_user_rx_keep            ),// output [ 15:0]
    .m_user_rx_last                    (m_user_rx_last            ),// output
    .m_user_rx_ready                   (m_user_rx_ready           ),// input 

    // dma_rx_ram <-> dma_rx_process
    .ram_rd_en                         (ram_rd_en                 ),// output
    .ram_rd_addr                       (ram_rd_addr               ),// output [ 12:0]
    .ram_rd_data                       (ram_rd_data               ),// input  [127:0]

    // dma_rx_process <-> tag_manage
    .tag_rx_req                        (tag_rx_req                ),// input 
    .tag_rx_ack                        (tag_rx_ack                ),// output
    .tag_rx_last                       (tag_rx_last               ),// input 
    .tag_rx_number                     (tag_rx_number             ),// input  [  4:0]
    .tag_rx_length                     (tag_rx_len                ),// input  [ 10:0]
    .tag_rx_done                       (tag_rx_done               ) // output
  );


dma_tx  u_dma_tx (
    .clk                               (clk                       ),// input          
    .rst                               (rst                       ),// input          

    // dma_tx_read -> dma_tx
    .dma_rd_data                       (dma_rd_data               ),// input   [127:0]
    .dma_rd_user                       (dma_rd_user               ),// input   [ 59:0]
    .dma_rd_keep                       (dma_rd_keep               ),// input   [  3:0]
    .dma_rd_valid                      (dma_rd_valid              ),// input          
    .dma_rd_last                       (dma_rd_last               ),// input          
    .dma_rd_ready                      (dma_rd_ready              ),// output        

    // dma_tx_write -> dma_tx
    .dma_wr_data                       (dma_wr_data               ),// input   [127:0]
    .dma_wr_user                       (dma_wr_user               ),// input   [ 59:0]
    .dma_wr_keep                       (dma_wr_keep               ),// input   [  3:0]
    .dma_wr_valid                      (dma_wr_valid              ),// input          
    .dma_wr_last                       (dma_wr_last               ),// input          
    .dma_wr_ready                      (dma_wr_ready              ),// output      

    // TO PCIE_IP 
    .s_axis_rq_tdata                   (s_axis_rq_tdata           ),// output  [127:0]
    .s_axis_rq_tuser                   (s_axis_rq_tuser           ),// output  [ 59:0]
    .s_axis_rq_tlast                   (s_axis_rq_tlast           ),// output  [  3:0]
    .s_axis_rq_tkeep                   (s_axis_rq_tkeep           ),// output         
    .s_axis_rq_tvalid                  (s_axis_rq_tvalid          ),// output         
    .s_axis_rq_tready                  (s_axis_rq_tready          ) // input          
  );


  dma_tx_read  u_dma_tx_read (
    .clk                               (clk                       ),// input         
    .rst                               (rst                       ),// input    

    // from user
    .dma_rd_start                      (dma_rd_start              ),// input         
    .dma_rd_addr                       (dma_rd_addr               ),// input  [ 31:0]
    .dma_rd_len                        (dma_rd_len                ),// input  [ 31:0]
    
    // from PCIE_IP
    .cfg_max_read_req                  (cfg_max_read_req          ),// input  [  2:0]

    // 接收端的反压信号
    .cpld_buffer_req                   (cpld_buffer_req           ),// output        
    .cpld_buffer_ack                   (cpld_buffer_ack           ),// input  

    // dma_tx_read <-> tag_manage
    .tag_read_req                      (tag_read_req              ),// output        
    .tag_read_last                     (tag_read_last             ),// output        
    .tag_read_ack                      (tag_read_ack              ),// input         
    .tag_read_number                   ({1'b0,tag_read_number}    ),// input  [  5:0]

    // dma_tx_read -> dma_tx
    .dma_rd_data                       (dma_rd_data               ),// output [127:0]
    .dma_rd_user                       (dma_rd_user               ),// output [ 59:0]
    .dma_rd_keep                       (dma_rd_keep               ),// output [  3:0]
    .dma_rd_valid                      (dma_rd_valid              ),// output        
    .dma_rd_last                       (dma_rd_last               ),// output        
    .dma_rd_ready                      (dma_rd_ready              ) // input         
  );


dma_tx_write  u_dma_tx_write (
    .clk                               (clk                       ),// input         
    .rst                               (rst                       ),// input    

    // from PCIE_IP
    .cfg_max_payload                   (cfg_max_payload           ),// input  [  2:0]

    // from user
    .dma_wr_start                      (dma_wr_start              ),// input         
    .dma_wr_addr                       (dma_wr_addr               ),// input  [ 31:0]
    .dma_wr_len                        (dma_wr_len                ),// input  [ 31:0]

    .s_user_tx_valid                   (s_user_tx_valid           ),// input         
    .s_user_tx_data                    (s_user_tx_data            ),// input  [127:0]
    .s_user_tx_keep                    (s_user_tx_keep            ),// input  [ 15:0]
    .s_user_tx_last                    (s_user_tx_last            ),// input         
    .s_user_tx_ready                   (s_user_tx_ready           ),// output        

    // dma_tx_write -> dma_tx
    .dma_wr_last                       (dma_wr_last               ),// output        
    .dma_wr_data                       (dma_wr_data               ),// output [127:0]
    .dma_wr_user                       (dma_wr_user               ),// output [ 59:0]
    .dma_wr_keep                       (dma_wr_keep               ),// output [  3:0]
    .dma_wr_valid                      (dma_wr_valid              ),// output        
    .dma_wr_ready                      (dma_wr_ready              ),// input   

    // TO PCIE_IP
    .dma_wr_intr_req                   (dma_wr_intr_req           ),// output        
    .dma_wr_intr_ack                   (dma_wr_intr_ack           ),// input        

    // TO USER
    .dma_user_tx_start                 (dma_user_tx_start         ),// output        
    .dma_user_tx_done                  (dma_user_tx_done          ) // output        
  );


tag_manage  u_tag_manage (
    .clk                               (clk                       ),// input         
    .rst                               (rst                       ),// input   

    .tag_read_req                      (tag_read_req              ),// input         
    .tag_read_last                     (tag_read_last             ),// input         
    .tag_read_ack                      (tag_read_ack              ),// output        
    .tag_read_number                   (tag_read_number           ),// output [  4:0]

    .tag_rc_vld                        (tag_rc_vld                ),// input         
    .tag_rc_number                     (tag_rc_number             ),// input  [  4:0]
    .tag_rc_len                        (tag_rc_len                ),// input  [ 10:0]

    .tag_rx_req                        (tag_rx_req                ),// output        
    .tag_rx_ack                        (tag_rx_ack                ),// input         
    .tag_rx_last                       (tag_rx_last               ),// output        
    .tag_rx_number                     (tag_rx_number             ),// output [  4:0]
    .tag_rx_len                        (tag_rx_len                ),// output [ 10:0]
    .tag_rx_done                       (tag_rx_done               ) // input         
  );


  receive_credit_fc  u_receive_credit_fc (
    .pcie_clk                          (clk                       ),
    .pcie_rst                          (rst                       ),
    .cfg_max_read_req                  (cfg_max_read_req          ),
    .tag_rc_done                       (tag_rc_vld                ),
    .cpld_buffer_ack                   (cpld_buffer_ack           ),
    .cpld_buffer_req                   (cpld_buffer_req           ),
    .cfg_fc_cplh                       (                          ),
    .cfg_fc_cpld                       (                          ),
    .cpld_buffer_avall                 (                          ) 
  );

                             
endmodule
                           
`default_nettype wire