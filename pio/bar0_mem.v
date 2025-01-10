timescale 1ns / 1ps
module bar0_mem(
    //system interface
    input                                           pcie_clk        ,   //125M
    input                                           pcie_rst        ,   //高有效
    
    //bar0 
    input                                           bar0_wr         ,
    input                   [15:0]                  bar0_wr_addr    ,
    input                   [31:0]                  bar0_wr_data    ,

    input                                           bar0_rd         ,
    input                   [15:0]                  bar0_rd_addr    ,
    output  reg                                     bar0_rd_valid   ,
    output  reg             [31:0]                  bar0_rd_data    ,
    
    //DMA
    output  reg                                     dma_wr_start    ,
    output  reg             [31:0]                  dma_wr_addr     ,
    output  reg             [31:0]                  dma_wr_len      ,
    
    output  reg                                     dma_rd_start    ,
    output  reg             [31:0]                  dma_rd_addr     ,
    output  reg             [31:0]                  dma_rd_len      
    );

//=====================================================//
//pio 写
always @(posedge pcie_clk)
begin
    if(pcie_rst)
        dma_wr_start <= 1'b0;
    else if(dma_wr_start)
        dma_wr_start <= 1'b0;
    else if(bar0_wr && bar0_wr_addr== 16'h0000)
        dma_wr_start <= 1'b1;
end

always @(posedge pcie_clk)
begin
    if(pcie_rst)
        dma_rd_start <= 1'b0;
    else if(dma_rd_start)
        dma_rd_start <= 1'b0;
    else if(bar0_wr && bar0_wr_addr== 16'h000C)
        dma_rd_start <= 1'b1;
end
    
always @(posedge pcie_clk)
begin
    if(pcie_rst) begin
        dma_wr_addr  <= 32'd0;
        dma_wr_len   <= 32'd0;
        dma_rd_addr  <= 32'd0;
        dma_rd_len   <= 32'd0;
    end
    else if(bar0_wr) begin
        case(bar0_wr_addr)
            16'h0004: dma_wr_addr  <= bar0_wr_data;
            16'h0008: dma_wr_len   <= bar0_wr_data;
            16'h0010: dma_rd_addr  <= bar0_wr_data;
            16'h0014: dma_rd_len   <= bar0_wr_data;
            default : ;
        endcase    
    end
end  

    
//=====================================================//
//pio 读
   
always @(posedge pcie_clk)
begin
    if(pcie_rst) begin    
        bar0_rd_valid <= 1'b0;   
        bar0_rd_data  <= 32'd0;
    end 
    else if(bar0_rd) begin
        bar0_rd_valid <= 1'b1;
        case(bar0_rd_addr)
            16'h0000: bar0_rd_data  <= {31'd0,dma_wr_start};
            16'h0004: bar0_rd_data  <= dma_wr_addr;
            16'h0008: bar0_rd_data  <= dma_wr_len;
            16'h000B: bar0_rd_data  <= {31'd0,dma_rd_start};
            16'h0010: bar0_rd_data  <= dma_rd_addr;
            16'h0014: bar0_rd_data  <= dma_rd_len;
            default : bar0_rd_data  <= bar0_rd_data;
        endcase
    end
    else begin
        bar0_rd_valid <= 1'b0;   
        bar0_rd_data  <= 32'd0;
    end
end  


  
endmodule