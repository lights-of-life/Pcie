`timescale 1ns / 1ps

module pio_tx_engine #(
    parameter                           C_DATA_WIDTH = 128         ,
    parameter                           KEEP_WIDTH   = C_DATA_WIDTH / 31 
)(
    //system interface
    input                               pcie_clk                   ,//125M
    input                               pcie_rst                   ,//高有效 
    
    //PIO TX Engine
    //AXI-S Completer Competion Interface
    output reg         [C_DATA_WIDTH-1:0]s_axis_cc_tdata            ,
    output reg         [KEEP_WIDTH-1:0] s_axis_cc_tkeep            ,
    output reg                          s_axis_cc_tlast            ,
    output reg                          s_axis_cc_tvalid           ,
    output reg         [  31:0]         s_axis_cc_tuser            ,
    input                               s_axis_cc_tready           ,
    
    //bar0
    input              [   2:0]         bar0_req_tc                ,// Memory Read TC
    input              [   2:0]         bar0_req_attr              ,// Memory Read Attribute
    input              [  10:0]         bar0_req_len               ,// Memory Read Length
    input              [  15:0]         bar0_req_rid               ,// Memory Read Requestor ID { 8'b0 (Bus no),
                                                                        //                            3'b0 (Dev no),
                                                                        //                            5'b0 (Func no)}
    input              [   7:0]         bar0_req_tag               ,// Memory Read Tag
    input              [   7:0]         bar0_req_be                ,// Memory Read Byte Enables
    input              [  15:0]         bar0_req_addr              ,// Memory Read Address
    input              [   1:0]         bar0_req_at                ,// Address Translation   

    input                               bar0_rd                    ,
    input              [  15:0]         bar0_rd_addr               ,
    input                               bar0_rd_valid              ,
    input              [  31:0]         bar0_rd_data               ,
   
    //bar1 
    input              [   2:0]         bar1_req_tc                ,// Memory Read TC
    input              [   2:0]         bar1_req_attr              ,// Memory Read Attribute
    input              [  10:0]         bar1_req_len               ,// Memory Read Length
    input              [  15:0]         bar1_req_rid               ,// Memory Read Requestor ID { 8'b0 (Bus no),
                                                                        //                            3'b0 (Dev no),
                                                                        //                            5'b0 (Func no)}
    input              [   7:0]         bar1_req_tag               ,// Memory Read Tag
    input              [   7:0]         bar1_req_be                ,// Memory Read Byte Enables
    input              [  15:0]         bar1_req_addr              ,// Memory Read Address
    input              [   1:0]         bar1_req_at                ,// Address Translation

    input                               bar1_rd                    ,
    input              [  15:0]         bar1_rd_addr               ,
    input                               bar1_rd_valid              ,
    input              [  31:0]         bar1_rd_data                
    
    );

    
    
localparam                              PIO_TX_RST_STATE                   = 3'b000;
localparam                              PIO_TX_COMPL_WD_bar0               = 3'b001;
localparam                              PIO_TX_COMPL_WD_bar1               = 3'b011;
localparam                              PIO_TX_WAIT_STATE                  = 3'b100;
    
reg                    [   2:0]         state                      ;
reg                    [  11:0]         bar0_byte_count_fbe        ;
reg                    [  11:0]         bar0_byte_count_lbe        ;
wire                   [  11:0]         bar0_byte_count            ;
reg                    [  06:0]         bar0_lower_addr            ;

reg                    [  11:0]         bar1_byte_count_fbe        ;
reg                    [  11:0]         bar1_byte_count_lbe        ;
wire                   [  11:0]         bar1_byte_count            ;
reg                    [  06:0]         bar1_lower_addr            ;

reg                                     bar0_rd_valid_flag         ;
reg                    [  31:0]         bar0_rd_data_reg           ;
reg                                     bar1_rd_valid_flag         ;
reg                    [  31:0]         bar1_rd_data_reg           ;


//=============================================================//
//bar0    
// Calculate byte count based on byte enable

always @ (bar0_req_be) begin
    casex (bar0_req_be[3:0])
    
        4'b1xx1 : bar0_byte_count_fbe = 12'h004;
        4'b01x1 : bar0_byte_count_fbe = 12'h003;
        4'b1x10 : bar0_byte_count_fbe = 12'h003;
        4'b0011 : bar0_byte_count_fbe = 12'h002;
        4'b0110 : bar0_byte_count_fbe = 12'h002;
        4'b1100 : bar0_byte_count_fbe = 12'h002;
        4'b0001 : bar0_byte_count_fbe = 12'h001;
        4'b0010 : bar0_byte_count_fbe = 12'h001;
        4'b0100 : bar0_byte_count_fbe = 12'h001;
        4'b1000 : bar0_byte_count_fbe = 12'h001;
        4'b0000 : bar0_byte_count_fbe = 12'h001;
        default : bar0_byte_count_fbe = 12'h000;
    endcase

    casex (bar0_req_be[7:4])
    
        4'b1xx1 : bar0_byte_count_lbe = 12'h004;
        4'b01x1 : bar0_byte_count_lbe = 12'h003;
        4'b1x10 : bar0_byte_count_lbe = 12'h003;
        4'b0011 : bar0_byte_count_lbe = 12'h002;
        4'b0110 : bar0_byte_count_lbe = 12'h002;
        4'b1100 : bar0_byte_count_lbe = 12'h002;
        4'b0001 : bar0_byte_count_lbe = 12'h001;
        4'b0010 : bar0_byte_count_lbe = 12'h001;
        4'b0100 : bar0_byte_count_lbe = 12'h001;
        4'b1000 : bar0_byte_count_lbe = 12'h001;
        4'b0000 : bar0_byte_count_lbe = 12'h000;
        default : bar0_byte_count_lbe = 12'h000;
    endcase

end


always @ (bar0_req_be or bar0_req_addr) begin

    casex (bar0_req_be[3:0])
        4'b0000 : bar0_lower_addr = {bar0_req_addr[6:2], 2'b00};
        4'bxxx1 : bar0_lower_addr = {bar0_req_addr[6:2], 2'b00};
        4'bxx10 : bar0_lower_addr = {bar0_req_addr[6:2], 2'b01};
        4'bx100 : bar0_lower_addr = {bar0_req_addr[6:2], 2'b10};
        4'b1000 : bar0_lower_addr = {bar0_req_addr[6:2], 2'b11};
        default : bar0_lower_addr = 7'h0;
    endcase

end

always @ ( posedge pcie_clk )
begin
    if(pcie_rst )
        bar0_rd_valid_flag <= 1'b0;
    else if(state == PIO_TX_COMPL_WD_bar0)
        bar0_rd_valid_flag <= 1'b0;
    else if(bar0_rd_valid)
        bar0_rd_valid_flag <= 1'b1;
end

always @ ( posedge pcie_clk )
begin
    if(pcie_rst )
        bar0_rd_data_reg <= 32'd0;
    else if(bar0_rd_valid)
        bar0_rd_data_reg <= bar0_rd_data;
end

//=============================================================//
//bar1    
// Calculate byte count based on byte enable

always @ (bar1_req_be) begin
    casex (bar1_req_be[3:0])
    
        4'b1xx1 : bar1_byte_count_fbe = 12'h004;
        4'b01x1 : bar1_byte_count_fbe = 12'h003;
        4'b1x10 : bar1_byte_count_fbe = 12'h003;
        4'b0011 : bar1_byte_count_fbe = 12'h002;
        4'b0110 : bar1_byte_count_fbe = 12'h002;
        4'b1100 : bar1_byte_count_fbe = 12'h002;
        4'b0001 : bar1_byte_count_fbe = 12'h001;
        4'b0010 : bar1_byte_count_fbe = 12'h001;
        4'b0100 : bar1_byte_count_fbe = 12'h001;
        4'b1000 : bar1_byte_count_fbe = 12'h001;
        4'b0000 : bar1_byte_count_fbe = 12'h001;
        default : bar1_byte_count_fbe = 12'h000;
    endcase

    casex (bar1_req_be[7:4])
    
        4'b1xx1 : bar1_byte_count_lbe = 12'h004;
        4'b01x1 : bar1_byte_count_lbe = 12'h003;
        4'b1x10 : bar1_byte_count_lbe = 12'h003;
        4'b0011 : bar1_byte_count_lbe = 12'h002;
        4'b0110 : bar1_byte_count_lbe = 12'h002;
        4'b1100 : bar1_byte_count_lbe = 12'h002;
        4'b0001 : bar1_byte_count_lbe = 12'h001;
        4'b0010 : bar1_byte_count_lbe = 12'h001;
        4'b0100 : bar1_byte_count_lbe = 12'h001;
        4'b1000 : bar1_byte_count_lbe = 12'h001;
        4'b0000 : bar1_byte_count_lbe = 12'h000;
        default : bar1_byte_count_lbe = 12'h000;
    endcase

end


always @ (bar1_req_be or bar1_req_addr) begin

    casex (bar1_req_be[3:0])
        4'b0000 : bar1_lower_addr = {bar1_req_addr[6:2], 2'b00};
        4'bxxx1 : bar1_lower_addr = {bar1_req_addr[6:2], 2'b00};
        4'bxx10 : bar1_lower_addr = {bar1_req_addr[6:2], 2'b01};
        4'bx100 : bar1_lower_addr = {bar1_req_addr[6:2], 2'b10};
        4'b1000 : bar1_lower_addr = {bar1_req_addr[6:2], 2'b11};
        default : bar1_lower_addr = 7'h0;
    endcase

end

always @ ( posedge pcie_clk )
begin
    if(pcie_rst )
        bar1_rd_valid_flag <= 1'b0;
    else if(state == PIO_TX_COMPL_WD_bar1)
        bar1_rd_valid_flag <= 1'b0;
    else if(bar1_rd_valid)
        bar1_rd_valid_flag <= 1'b1;
end

always @ ( posedge pcie_clk )
begin
    if(pcie_rst )
        bar1_rd_data_reg <= 32'd0;
    else if(bar1_rd_valid)
        bar1_rd_data_reg <= bar1_rd_data;
end

//=============================================================//

    
always @ ( posedge pcie_clk )
begin
    if(pcie_rst ) begin
        state             <= PIO_TX_RST_STATE;
        s_axis_cc_tdata   <= {C_DATA_WIDTH{1'b0}};
        s_axis_cc_tkeep   <= {KEEP_WIDTH{1'b0}};
        s_axis_cc_tlast   <= 1'b0;
        s_axis_cc_tvalid  <= 1'b0;
        s_axis_cc_tuser   <= 33'b0;
    end else begin                                                  // reset_else_block    
        case (state)
        
            PIO_TX_RST_STATE : begin                                // Reset_State                
                s_axis_cc_tdata         <= {C_DATA_WIDTH{1'b0}};
                s_axis_cc_tkeep         <= {KEEP_WIDTH{1'b1}};
                s_axis_cc_tlast         <= 1'b0;
                s_axis_cc_tvalid        <= 1'b0;
                s_axis_cc_tuser         <= 33'b0;
                
                if(bar0_rd_valid_flag)
                    state <= PIO_TX_COMPL_WD_bar0;
                else if (bar1_rd_valid_flag)
                    state <= PIO_TX_COMPL_WD_bar1;
                else
                    state <= PIO_TX_RST_STATE;

            end                                                     // PIO_TX_RST_STATE
          
            PIO_TX_COMPL_WD_bar0 : begin                            // Completion With Payload
                                        // Possible Scenario's Payload can be 1 DW or 2 DW
                                        // Alignment can be either of Dword aligned or address aligned
                s_axis_cc_tvalid  <= 1'b1;
                s_axis_cc_tkeep   <= 4'hF;
                s_axis_cc_tlast   <= 1'b1;
                s_axis_cc_tdata   <= {bar0_rd_data_reg,             // 32- bit read data
                                           1'b0,                    // Force ECRC
                                           1'b0, bar0_req_attr[1:0],// 3- bits
                                           bar0_req_tc,             // 3- bits
                                           1'b0,                    // Completer ID to control selection of Client
                                                                    // Supplied Bus number
                                           8'hAA,                   // Completer Bus number - Bus# selected if Compl ID = 1
                                           {5'b11111, 3'b000},      // Compl Dev / Func no - Dev# sel if Compl ID = 1. Function# = 0
                                           bar0_req_tag,            // Matching Request Tag
                                           bar0_req_rid,            // Requester ID - 16 bits
                                           1'b0,                    // Rsvd
                                           1'b0,                    // Posioned completion
                                           3'b000,                  // SuccessFull completion
                                           11'b1,                   // DWord Count 0 - IO Write completions
                                           2'b0,                    // Rsvd
                                           1'b0,                    // Locked Read Completion
                                           {1'b0, bar0_byte_count_fbe},// Byte Count
                                           6'b0,             
                                           bar0_req_at,             // Adress Type - 2 bits
                                           1'b0,                    // Rsvd
                                           bar0_lower_addr};        // Starting address of the mem byte - 7 bits
                s_axis_cc_tuser   <= {1'b0,31'b0};
                
                state             <= PIO_TX_WAIT_STATE;
            end                                                     // PIO_TX_COMPL_WD_bar0
            
            PIO_TX_COMPL_WD_bar1 : begin                            // Completion With Payload
                                        // Possible Scenario's Payload can be 1 DW or 2 DW
                                        // Alignment can be either of Dword aligned or address aligned
                s_axis_cc_tvalid  <= 1'b1;
                s_axis_cc_tkeep   <= 4'hF;
                s_axis_cc_tlast   <= 1'b1;
                s_axis_cc_tdata   <= {bar1_rd_data_reg,             // 31- bit read data
                                           1'b0,                    // Force ECRC
                                           1'b0, bar1_req_attr[1:0],// 3- bits
                                           bar1_req_tc,             // 3- bits
                                           1'b0,                    // Completer ID to control selection of Client
                                                                    // Supplied Bus number
                                           8'hAA,                   // Completer Bus number - Bus# selected if Compl ID = 1
                                           {5'b11111, 3'b000},      // Compl Dev / Func no - Dev# sel if Compl ID = 1. Function# = 0
                                           bar1_req_tag,            // Matching Request Tag
                                           bar1_req_rid,            // Requester ID - 16 bits
                                           1'b0,                    // Rsvd
                                           1'b0,                    // Posioned completion
                                           3'b000,                  // SuccessFull completion
                                           11'b1,                   // DWord Count 0 - IO Write completions
                                           2'b0,                    // Rsvd
                                           1'b0,                    // Locked Read Completion
                                           {1'b0, bar1_byte_count_fbe},// Byte Count
                                           6'b0,                    // Rsvd
                                           bar1_req_at,             // Adress Type - 2 bits
                                           1'b0,                    // Rsvd
                                           bar1_lower_addr};        // Starting address of the mem byte - 7 bits
                s_axis_cc_tuser   <= {1'b0,31'b0};
                
                state             <= PIO_TX_WAIT_STATE;
            end                                                     // PIO_TX_COMPL_WD_bar0

            PIO_TX_WAIT_STATE : begin
                if(s_axis_cc_tready) begin
                    state             <= PIO_TX_RST_STATE;
                    s_axis_cc_tdata   <= {C_DATA_WIDTH{1'b0}};
                    s_axis_cc_tkeep   <= {KEEP_WIDTH{1'b0}};
                    s_axis_cc_tlast   <= 1'b0;
                    s_axis_cc_tvalid  <= 1'b0;
                    s_axis_cc_tuser   <= 33'b0;
                end
            end
            
            default: state             <= PIO_TX_RST_STATE;
        endcase
    end
end
    
    

    
    
    
endmodule