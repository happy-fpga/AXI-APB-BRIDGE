module axi_apb_bridge #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
)(
    // AXI Slave Interface
    input wire                          axi_aclk,
    input wire                          axi_aresetn,
    
    // AXI Write Address Channel
    input wire [AXI_ADDR_WIDTH-1:0]     axi_awaddr,
    input wire [2:0]                    axi_awprot,
    input wire                          axi_awvalid,
    output reg                          axi_awready,
    
    // AXI Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]     axi_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0] axi_wstrb,
    input wire                          axi_wvalid,
    output reg                          axi_wready,
    
    // AXI Write Response Channel
    output reg [1:0]                    axi_bresp,
    output reg                          axi_bvalid,
    input wire                          axi_bready,
    
    // AXI Read Address Channel
    input wire [AXI_ADDR_WIDTH-1:0]     axi_araddr,
    input wire [2:0]                    axi_arprot,
    input wire                          axi_arvalid,
    output reg                          axi_arready,
    
    // AXI Read Data Channel
    output reg [AXI_DATA_WIDTH-1:0]     axi_rdata,
    output reg [1:0]                    axi_rresp,
    output reg                          axi_rvalid,
    input wire                          axi_rready,
    
    // APB Master Interface
    output reg [APB_ADDR_WIDTH-1:0]     apb_paddr,
    output reg                          apb_pwrite,
    output reg                          apb_psel,
    output reg                          apb_penable,
    output reg [APB_DATA_WIDTH-1:0]     apb_pwdata,
    input wire [APB_DATA_WIDTH-1:0]     apb_prdata,
    input wire                          apb_pready,
    input wire                          apb_pslverr
);

    // State Encoding
    localparam IDLE        = 3'b000;
    localparam WRITE_ADDR  = 3'b001;
    localparam WRITE_DATA  = 3'b010;
    localparam WRITE_RESP  = 3'b011;
    localparam READ_ADDR   = 3'b100;
    localparam READ_DATA   = 3'b101;

    // Registers for the state machine
    reg [2:0] current_state, next_state;
    reg [AXI_ADDR_WIDTH-1:0] captured_addr;
    reg [AXI_DATA_WIDTH-1:0] captured_wdata;
    reg [(AXI_DATA_WIDTH/8)-1:0] captured_wstrb;

    // Clock Enable signal (always enabled)
    // This signal doesn't disable clocking but is used for specific control logic
    reg clk_enable;

    // Sequential logic for state transition
    always @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = current_state; // Default assignment
        case (current_state)
            IDLE: begin
                if (axi_awvalid) next_state = WRITE_ADDR;
                else if (axi_arvalid) next_state = READ_ADDR;
            end
            WRITE_ADDR: begin
                if (axi_wvalid) next_state = WRITE_DATA;
            end
            WRITE_DATA: begin
                if (apb_pready) next_state = WRITE_RESP;
            end
            WRITE_RESP: begin
                if (axi_bready) next_state = IDLE;
            end
            READ_ADDR: begin
                if (apb_pready) next_state = READ_DATA;
            end
            READ_DATA: begin
                if (axi_rready) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and control path logic
    always @(posedge axi_aclk or negedge axi_aresetn) begin
        if (!axi_aresetn) begin
            // Reset all outputs and internal registers
            axi_awready <= 1'b0;
            axi_wready <= 1'b0;
            axi_arready <= 1'b0;
            axi_bvalid <= 1'b0;
            axi_rvalid <= 1'b0;
            captured_addr <= 0;
            captured_wdata <= 0;
            captured_wstrb <= 0;
            apb_paddr <= 0;
            apb_pwdata <= 0;
            apb_pwrite <= 0;
            apb_psel <= 0;
            apb_penable <= 0;
            clk_enable <= 1'b0;
        end else begin
            // Default assignments for signals
            axi_awready <= 1'b0;
            axi_wready <= 1'b0;
            axi_arready <= 1'b0;
            apb_psel <= 1'b0;
            apb_penable <= 1'b0;
            clk_enable <= 1'b1; // Clock always enabled for sequential logic

            case (current_state)
                IDLE: begin
                    if (axi_awvalid) begin
                        axi_awready <= 1'b1;
                        captured_addr <= axi_awaddr;
                    end else if (axi_arvalid) begin
                        axi_arready <= 1'b1;
                        captured_addr <= axi_araddr;
                    end
                end
                WRITE_ADDR: begin
                    if (axi_wvalid) begin
                        axi_wready <= 1'b1;
                        captured_wdata <= axi_wdata;
                        captured_wstrb <= axi_wstrb;
                    end
                end
                WRITE_DATA: begin
                    apb_psel <= 1'b1;
                    apb_pwrite <= 1'b1;
                    apb_paddr <= captured_addr;
                    apb_pwdata <= captured_wdata;
                    if (apb_pready) begin
                        apb_penable <= 1'b1;
                        axi_bresp <= apb_pslverr ? 2'b10 : 2'b00;
                        axi_bvalid <= 1'b1;
                    end
                end
                WRITE_RESP: begin
                    if (axi_bready) begin
                        axi_bvalid <= 1'b0;
                    end
                end
                READ_ADDR: begin
                    apb_psel <= 1'b1;
                    apb_pwrite <= 1'b0;
                    apb_paddr <= captured_addr;
                    if (apb_pready) begin
                        apb_penable <= 1'b1;
                        axi_rresp <= apb_pslverr ? 2'b10 : 2'b00;
                        axi_rvalid <= 1'b1;
                        axi_rdata <= apb_prdata;
                    end
                end
                READ_DATA: begin
                    if (axi_rready) begin
                        axi_rvalid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule