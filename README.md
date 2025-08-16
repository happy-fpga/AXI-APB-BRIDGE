# AXI-APB-BRIDGE  
Here we have designed a 32 Bit AXI to APB bridge, writing its Verilog code creating a module to 
translate high-speed AXI transactions to low-speed APB operations. The design includes address 
decoding, data conversion, and control logic to manage communication between the two protocols. 
Verification is carried out using a testbench, which simulates AXI transactions and checks if the bridge 
correctly handles read/write operations and synchronization. Once verified, we have done RTL-to-GDS 
flow, including Synthesis, Floorplan, Placement, Clock Tree Synthesis (CTS), Routing, Parasitics STA 
and DRC LVS checks to generate a GDSII file. 
