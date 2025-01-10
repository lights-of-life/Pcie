`timescale 1ns / 1ps
module pio_rx_engine #(
    parameter                           C_DATA_WIDTH = 128         ,
    parameter                           KEEP_WIDTH   = C_DATA_WIDTH / 31 
)(
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
    output reg                          m_axis_cq_tready           ,
    
    //bar0
    output reg         [   2:0]         bar0_req_tc                ,// Memory Read TC
    output reg         [   2:0]         bar0_req_attr              ,// Memory Read Attribute
    output reg         [  10:0]         bar0_req_len               ,// Memory Read Length
    output reg         [  15:0]         bar0_req_rid               ,// Memory Read Requestor ID { 8'b0 (Bus no),
                                                                        //                            3'b0 (Dev no),
                                                                        //                            5'b0 (Func no)}
    output reg         [   7:0]         bar0_req_tag               ,// Memory Read Tag
    output reg         [   7:0]         bar0_req_be                ,// Memory Read Byte Enables
    output reg         [  15:0]         bar0_req_addr              ,// Memory Read Address
    output reg         [   1:0]         bar0_req_at                ,// Address Translation
    
    output reg                          bar0_wr                    ,
    output reg         [  15:0]         bar0_wr_addr               ,
    output reg         [  31:0]         bar0_wr_data               ,

    output reg                          bar0_rd                    ,
    output reg         [  15:0]         bar0_rd_addr               ,
    input                               bar0_rd_valid              ,
    input              [  31:0]         bar0_rd_data               ,
   
    //bar1 
    output reg         [   2:0]         bar1_req_tc                ,// Memory Read TC
    output reg         [   2:0]         bar1_req_attr              ,// Memory Read Attribute
    output reg         [  10:0]         bar1_req_len               ,// Memory Read Length
    output reg         [  15:0]         bar1_req_rid               ,// Memory Read Requestor ID { 8'b0 (Bus no),
                                                                        //                            3'b0 (Dev no),
                                                                        //                            5'b0 (Func no)}
    output reg         [   7:0]         bar1_req_tag               ,// Memory Read Tag
    output reg         [   7:0]         bar1_req_be                ,// Memory Read Byte Enables
    output reg         [  15:0]         bar1_req_addr              ,// Memory Read Address
    output reg         [   1:0]         bar1_req_at                ,// Address Translation
    
    output reg                          bar1_wr                    ,
    output reg         [  15:0]         bar1_wr_addr               ,
    output reg         [  31:0]         bar1_wr_data               ,

    output reg                          bar1_rd                    ,
    output reg         [  15:0]         bar1_rd_addr               ,
    input                               bar1_rd_valid              ,
    input              [  31:0]         bar1_rd_data                
    );
    
localparam                              PIO_RX_MEM_RD_FMT_TYPE    = 4'b0000;// Memory Read
localparam                              PIO_RX_MEM_WR_FMT_TYPE    = 4'b0001;// Memory Write

localparam                              PIO_RX_RST_STATE          = 3'b000;
localparam                              PIO_RX_WAIT_STATE         = 3'b001;
localparam                              PIO_RX_DATA               = 3'b011;

// Local 
reg                    [   2:0]         state                      ;
reg                                     bar0_flag                  ;
reg                                     bar1_flag                  ;
reg                    [   3:0]         trn_type                   ;
wire                                    sop                        ;// Start of packet

assign sop = m_axis_cq_tuser[40];
    
always@(posedge pcie_clk) begin
    if (pcie_rst) begin
        m_axis_cq_tready <= 1'b0;
    
        bar0_req_tc      <= 3'b0;
        bar0_req_attr    <= 3'b0;
        bar0_req_len     <= 11'b0;
        bar0_req_rid     <= 16'b0;
        bar0_req_tag     <= 8'b0;
        bar0_req_be      <= 8'b0;
        bar0_req_addr    <= 16'b0;
        bar0_req_at      <= 2'b0;
        
        bar0_wr          <= 1'd0;
        bar0_wr_addr     <= 16'd0;
        bar0_wr_data     <= 31'd0;
        bar0_rd          <= 1'd0;
        bar0_rd_addr     <= 16'd0;
        
        bar1_req_tc      <= 3'b0;
        bar1_req_attr    <= 3'b0;
        bar1_req_len     <= 11'b0;
        bar1_req_rid     <= 16'b0;
        bar1_req_tag     <= 8'b0;
        bar1_req_be      <= 8'b0;
        bar1_req_addr    <= 16'b0;
        bar1_req_at      <= 2'b0;
        
        bar1_wr          <= 1'd0;
        bar1_wr_addr     <= 16'd0;
        bar1_wr_data     <= 31'd0;
        bar1_rd          <= 1'd0;
        bar1_rd_addr     <= 16'd0;
    
        state            <= PIO_RX_RST_STATE;
        trn_type         <= 4'b0;
        
        bar0_flag        <= 1'b0;
        bar1_flag        <= 1'b0;
    end
    else begin
        bar0_flag        <= 1'b0;
        bar1_flag        <= 1'b0;

        case (state)
        
            PIO_RX_RST_STATE : begin
        
            m_axis_cq_tready <= 1'b1;
        
            if (sop && m_axis_cq_tvalid)
            begin
        
                case (m_axis_cq_tdata[78:75])                       //Request Type
        
                PIO_RX_MEM_RD_FMT_TYPE : begin                      // Memory Read
                        
                    trn_type         <= m_axis_cq_tdata[78:75];     //Request Type
                    m_axis_cq_tready <= 1'b0;
                    state            <= PIO_RX_WAIT_STATE;
                    
                    if(m_axis_cq_tdata[114:112] == 3'b000)          //bar0
                    begin
                        bar0_req_len  <= m_axis_cq_tdata[74:64];
                        bar0_req_tc   <= m_axis_cq_tdata[123:121];
                        bar0_req_attr <= m_axis_cq_tdata[126:124];
                        bar0_req_rid  <= m_axis_cq_tdata[95:80];
                        bar0_req_tag  <= m_axis_cq_tdata[103:96];
                        bar0_req_be   <= m_axis_cq_tuser[7:0];
                        bar0_req_addr <= {m_axis_cq_tdata[15:2], 2'b00};
                        bar0_req_at   <= m_axis_cq_tdata[1:0];
                        
                        bar0_flag     <= 1'b1;
                        bar0_rd       <= 1'd1;
                        bar0_rd_addr  <= {m_axis_cq_tdata[15:2], 2'b00};
                    end
                    else if(m_axis_cq_tdata[114:112] == 3'b001)     //bar1
                    begin
                        bar1_req_len  <= m_axis_cq_tdata[74:64];
                        bar1_req_tc   <= m_axis_cq_tdata[123:121];
                        bar1_req_attr <= m_axis_cq_tdata[126:124];
                        bar1_req_rid  <= m_axis_cq_tdata[95:80];
                        bar1_req_tag  <= m_axis_cq_tdata[103:96];
                        bar1_req_be   <= m_axis_cq_tuser[7:0];
                        bar1_req_addr <= {m_axis_cq_tdata[15:2], 2'b00};
                        bar1_req_at   <= m_axis_cq_tdata[1:0];
                        bar1_flag     <= 1'b1;
                        bar1_rd       <= 1'd1;
                        bar1_rd_addr  <= {m_axis_cq_tdata[15:2], 2'b00};
                    end
        
                end                                                 // PIO_RX_MEM_RD_FMT_TYPE
        
        
                PIO_RX_MEM_WR_FMT_TYPE : begin                      // Memory Write
        
                    trn_type         <= m_axis_cq_tdata[78:75];     //Request Type
                    state            <= PIO_RX_DATA;
                    
                    if(m_axis_cq_tdata[114:112] == 3'b000)          //bar0
                    begin
                        bar0_req_len  <= m_axis_cq_tdata[74:64];
                        bar0_req_tc   <= m_axis_cq_tdata[123:121];
                        bar0_req_attr <= m_axis_cq_tdata[126:124];
                        bar0_req_rid  <= m_axis_cq_tdata[95:80];
                        bar0_req_tag  <= m_axis_cq_tdata[103:96];
                        bar0_req_be   <= m_axis_cq_tuser[7:0];
                        bar0_req_addr <= {m_axis_cq_tdata[15:2], 2'b00};
                        bar0_req_at   <= m_axis_cq_tdata[1:0];
                        
                        bar0_flag     <= 1'b1;
                        bar0_wr_addr  <= {m_axis_cq_tdata[15:2], 2'b00};
                    end
                    else if(m_axis_cq_tdata[114:112] == 3'b001)     //bar1
                    begin
                        bar1_req_len  <= m_axis_cq_tdata[74:64];
                        bar1_req_tc   <= m_axis_cq_tdata[123:121];
                        bar1_req_attr <= m_axis_cq_tdata[126:124];
                        bar1_req_rid  <= m_axis_cq_tdata[95:80];
                        bar1_req_tag  <= m_axis_cq_tdata[103:96];
                        bar1_req_be   <= m_axis_cq_tuser[7:0];
                        bar1_req_addr <= {m_axis_cq_tdata[15:2], 2'b00};
                        bar1_req_at   <= m_axis_cq_tdata[1:0];
                        
                        bar1_flag     <= 1'b1;
                        bar1_wr_addr  <= {m_axis_cq_tdata[15:2], 2'b00};
                    end
    
                end  
                   
                default : begin                                     // other TLPs
        
                    state        <= PIO_RX_RST_STATE;
                end
        
                endcase                                             // Req_Type
            end                                                     // m_axis_cq_tvalid
            else
                state <= PIO_RX_RST_STATE;
        
            end                                                     // PIO_RX_RST_STATE
        
        
            PIO_RX_DATA : begin
        
            if (m_axis_cq_tvalid)
            begin
                if(bar0_flag) begin
                    bar0_wr          <= 1'd1;
                    bar0_wr_data     <= m_axis_cq_tdata[31:0];
                end
                else if(bar1_flag)begin
                    bar1_wr          <= 1'd1;
                    bar1_wr_data     <= m_axis_cq_tdata[31:0];
                end
                
                state            <= PIO_RX_WAIT_STATE;
                m_axis_cq_tready <= 1'b0;
            end
            else
                state        <= PIO_RX_DATA;
        
            end                                                     // PIO_RX_DATA
        
            PIO_RX_WAIT_STATE : begin
                bar0_wr          <= 1'd0;
                bar0_rd          <= 1'd0;
                bar1_wr          <= 1'd0;
                bar1_rd          <= 1'd0;
                bar0_flag        <= 1'b0;
                bar1_flag        <= 1'b0;
        
                //if ((trn_type == PIO_RX_MEM_WR_FMT_TYPE) && (!wr_busy))
                //begin
            
                    m_axis_cq_tready <= 1'b1;
                    state        <= PIO_RX_RST_STATE;
            
            end
            
            default : begin
            // default case stmt
            state        <= PIO_RX_RST_STATE;
            end                                                     // default
        
        endcase
    
    end                                                             // if reset_n

end                                                                 // always @ pcie_clk  
    

endmodule