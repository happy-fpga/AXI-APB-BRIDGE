`timescale 1ns/1ps

module axi_apb_bridge_tb();
    // Parameters
    parameter CLK_PERIOD = 10;  // 100 MHz clock
    parameter AXI_DATA_WIDTH = 32;
    parameter AXI_ADDR_WIDTH = 32;
    parameter APB_ADDR_WIDTH = 32;
    parameter APB_DATA_WIDTH = 32;

    // Signals for AXI Interface
    reg                     axi_aclk;
    reg                     axi_aresetn;
    
    // AXI Write Address Channel
    reg [AXI_ADDR_WIDTH-1:0]    axi_awaddr;
    reg [2:0]               axi_awprot;
    reg                     axi_awvalid;
    wire                    axi_awready;
    
    // AXI Write Data Channel
    reg [AXI_DATA_WIDTH-1:0]    axi_wdata;
    reg [(AXI_DATA_WIDTH/8)-1:0] axi_wstrb;
    reg                     axi_wvalid;
    wire                    axi_wready;
    
    // AXI Write Response Channel
    wire [1:0]              axi_bresp;
    wire                    axi_bvalid;
    reg                     axi_bready;
    
    // AXI Read Address Channel
    reg [AXI_ADDR_WIDTH-1:0]    axi_araddr;
    reg [2:0]               axi_arprot;
    reg                     axi_arvalid;
    wire                    axi_arready;
    
    // AXI Read Data Channel
    wire [AXI_DATA_WIDTH-1:0]   axi_rdata;
    wire [1:0]              axi_rresp;
    wire                    axi_rvalid;
    reg                     axi_rready;
    
    // APB Master Interface
    wire [APB_ADDR_WIDTH-1:0]   apb_paddr;
    wire                    apb_pwrite;
    wire                    apb_psel;
    wire                    apb_penable;
    wire [APB_DATA_WIDTH-1:0]   apb_pwdata;
    reg [APB_DATA_WIDTH-1:0]    apb_prdata;
    reg                     apb_pready;
    reg                     apb_pslverr;

    // Instantiate Device Under Test (DUT)
    axi_apb_bridge #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
        .APB_DATA_WIDTH(APB_DATA_WIDTH)
    ) dut (
        .axi_aclk(axi_aclk),
        .axi_aresetn(axi_aresetn),
        
        .axi_awaddr(axi_awaddr),
        .axi_awprot(axi_awprot),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        
        .axi_araddr(axi_araddr),
        .axi_arprot(axi_arprot),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        
        .apb_paddr(apb_paddr),
        .apb_pwrite(apb_pwrite),
        .apb_psel(apb_psel),
        .apb_penable(apb_penable),
        .apb_pwdata(apb_pwdata),
        .apb_prdata(apb_prdata),
        .apb_pready(apb_pready),
        .apb_pslverr(apb_pslverr)
    );

    // Clock generation
    always begin
        #(CLK_PERIOD/2) axi_aclk = ~axi_aclk;
    end

    // Test sequence
    initial begin
        // Initialize all signals
        axi_aclk = 0;
        axi_aresetn = 0;
        axi_awaddr = 0;
        axi_awprot = 0;
        axi_awvalid = 0;
        axi_wdata = 0;
        axi_wstrb = 0;
        axi_wvalid = 0;
        axi_bready = 0;
        axi_araddr = 0;
        axi_arprot = 0;
        axi_arvalid = 0;
        axi_rready = 0;
        
        apb_prdata = 0;
        apb_pready = 0;
        apb_pslverr = 0;

        // Reset sequence
        #(CLK_PERIOD * 2);
        axi_aresetn = 1;

        // Test 1: Write Transaction
        @(posedge axi_aclk);
        // Write address phase
        axi_awaddr = 32'h1000_0000;
        axi_awvalid = 1;
        axi_awprot = 3'b000;
        axi_bready = 1;

        @(posedge axi_aclk);
        // Write data phase
        axi_wdata = 32'hDEAD_BEEF;
        axi_wstrb = 4'hF;  // Write all bytes
        axi_wvalid = 1;

        // Simulate APB ready
        @(posedge axi_aclk);
        apb_pready = 1;

        // Wait for write response
        repeat(2) @(posedge axi_aclk);
        
        // Reset write signals
        axi_awvalid = 0;
        axi_wvalid = 0;
        apb_pready = 0;

        // Test 2: Read Transaction
        @(posedge axi_aclk);
        // Read address phase
        axi_araddr = 32'h2000_0004;
        axi_arvalid = 1;
        axi_arprot = 3'b001;
        axi_rready = 1;

        @(posedge axi_aclk);
        // Simulate APB read data
        apb_prdata = 32'h1234_5678;
        apb_pready = 1;

        // Wait for read data
        repeat(2) @(posedge axi_aclk);

        // Test 3: Error Scenario
        @(posedge axi_aclk);
        axi_awaddr = 32'h3000_0000;
        axi_awvalid = 1;
        apb_pslverr = 1;  // Simulate slave error

        // End simulation
        #(CLK_PERIOD * 10);
        $finish;
    end

    // Waveform dumping for simulation
    initial begin
        $dumpfile("axi_apb_bridge_tb.vcd");
        $dumpvars(0, axi_apb_bridge_tb);
    end

    // Timeout mechanism
    initial begin
        #(CLK_PERIOD * 100);
        $display("ERROR: Simulation timeout");
        $finish;
    end

    // Assertions and checks
    always @(posedge axi_aclk) begin
        // Check write transaction
        if (axi_awvalid && axi_awready) begin
            $display("Write Address Transaction: ADDR = %h", axi_awaddr);
        end

        // Check read transaction
        if (axi_arvalid && axi_arready) begin
            $display("Read Address Transaction: ADDR = %h", axi_araddr);
        end

        // Check read data
        if (axi_rvalid && axi_rready) begin
            $display("Read Data Transaction: DATA = %h, RESP = %b", 
                     axi_rdata, axi_rresp);
        end
    end
endmodule