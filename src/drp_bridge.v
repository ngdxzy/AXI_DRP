`timescale 1ns/1ns

module drp_bridge #(
    parameter DRP_ADDR_WIDTH       = 10,                
    parameter DRP_DATA_WIDTH       = 16,
    parameter S_AXI_ADDR_WIDTH     = 32,               
    parameter S_AXI_DATA_WIDTH     = 32
)(

    //--------------  AXI Interface Signals         --------------
    input                             S_AXI_aclk,
    input                             S_AXI_aresetn,

    input  [S_AXI_ADDR_WIDTH-1:0]                   S_AXI_araddr,
    output reg                        S_AXI_arready,
    input                             S_AXI_arvalid,
    input  [2:0]                      S_AXI_arprot,

    input [S_AXI_ADDR_WIDTH-1:0]                    S_AXI_awaddr,
    output reg                        S_AXI_awready,
    input                             S_AXI_awvalid,
    input  [2:0]                      S_AXI_awprot,

    output  [1:0]                  S_AXI_bresp,  
    input                             S_AXI_bready,
    output reg                        S_AXI_bvalid,

    output reg [S_AXI_DATA_WIDTH-1:0] S_AXI_rdata,
    input                             S_AXI_rready,
    output reg                        S_AXI_rvalid,
    output  [1:0]                  S_AXI_rresp,

    input  [S_AXI_DATA_WIDTH-1:0]     S_AXI_wdata,
    output                         S_AXI_wready,
    input                             S_AXI_wvalid,
    input  [S_AXI_DATA_WIDTH/8-1:0]   S_AXI_wstrb,

    //-------------- Dynamic Reconfiguration Port (DRP) --------------
    output                                      DRP_clk,
    output  reg                                    DRP_en,
    output                                      DRP_we,
    output    [DRP_ADDR_WIDTH-1: 0]             DRP_addr,
    output   reg [DRP_DATA_WIDTH-1: 0]             DRP_di,
    input  [DRP_DATA_WIDTH-1: 0]                DRP_do,
    input                                       DRP_rdy
); // drp_bridge
        
    reg [DRP_ADDR_WIDTH-1:0] drp_addr_r;

    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(!S_AXI_aresetn) begin
            drp_addr_r <= {DRP_ADDR_WIDTH{1'b0}};
        end
        else begin
            case({(S_AXI_arvalid & (~S_AXI_arready)),(S_AXI_awvalid & (~S_AXI_awready))})
                2'b00: begin drp_addr_r <= drp_addr_r; end
                2'b01: begin drp_addr_r <= S_AXI_awaddr[DRP_ADDR_WIDTH + 1:2]; end
                2'b10: begin drp_addr_r <= S_AXI_araddr[DRP_ADDR_WIDTH + 1:2]; end
                2'b11: begin drp_addr_r <= drp_addr_r; end
            endcase
        end
    end
    assign DRP_addr = drp_addr_r;
    // Write/Read
    
    reg wr;
    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            wr <= 1'b0;
        end
        else begin
            case({(S_AXI_arvalid & (~S_AXI_arready)),(S_AXI_awvalid & (~S_AXI_awready))})
                2'b00: begin wr <= wr; end
                2'b01: begin wr <= 1'b1; end
                2'b10: begin wr <= 1'b0; end
                2'b11: begin wr <= wr; end
            endcase
        end
    end

    //AW Channel
    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            S_AXI_awready <= 1'b0;
        end
        else begin
            if(S_AXI_awvalid && (~S_AXI_awready) && S_AXI_wvalid) begin
                S_AXI_awready <= 1;
            end
            else begin
                S_AXI_awready <= 0;
            end
        end
    end

    //W Channel
    assign S_AXI_wready = wr?DRP_rdy:1'b0;

    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            DRP_di <= 'b0;
        end
        else begin
            if(S_AXI_wvalid && S_AXI_awvalid && (~S_AXI_awready)) begin
                DRP_di <= S_AXI_wdata[DRP_DATA_WIDTH-1:0];
            end
            else begin
                DRP_di <= DRP_di;
            end
        end
    end

    //wrsp channel
    assign S_AXI_bresp = 2'b00;
    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            S_AXI_bvalid <= 0;
        end
        else begin
            if(DRP_rdy && wr && (~S_AXI_bvalid)) begin
                S_AXI_bvalid <= 1'b1;
            end
            else begin
                if(S_AXI_bvalid && S_AXI_bready) begin
                    S_AXI_bvalid <= 1'b0;
                end
            end
        end
    end

    //AR channel

    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            S_AXI_arready <= 1'b0;
        end
        else begin
            if(S_AXI_arvalid && (~S_AXI_arready)) begin
                S_AXI_arready <= 1;
            end
            else begin
                S_AXI_arready <= 0;
            end
        end
    end

    //R Channel
    assign S_AXI_rresp = 2'b00;
    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            S_AXI_rdata <= 'b0;
            S_AXI_rvalid <= 1'b0;
        end
        else begin
            if((~wr) && DRP_rdy && (~S_AXI_rvalid)) begin
                S_AXI_rdata <= {'b0,DRP_do};
                S_AXI_rvalid <= 1'b1;
            end
            else if(S_AXI_rvalid && S_AXI_rready) begin
                S_AXI_rdata <= S_AXI_rdata;
                S_AXI_rvalid <= 1'b0;
            end
        end
    end
    //
    //en 

    always @ (posedge S_AXI_aclk or negedge S_AXI_aresetn) begin
        if(~S_AXI_aresetn) begin
            DRP_en <= 0;
        end
        else begin
            if(S_AXI_arvalid && (~S_AXI_arready)) begin
                DRP_en <= 1;
            end
            else if(S_AXI_awvalid && (~S_AXI_awready) && S_AXI_wvalid) begin               
                DRP_en <= 1;
            end
            else begin
                DRP_en <= 0;
            end
        end
    end
    assign DRP_we = wr;
    assign DRP_clk = S_AXI_aclk;
endmodule
