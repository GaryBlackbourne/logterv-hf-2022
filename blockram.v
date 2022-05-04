`timescale 1ns / 1ps

// READ first blockram blockram 

module blockram4k #(parameter WIDTH=24) // lehet hogy 32 nagyságú
(
    input               clk, 
    input               we, 
    input               en,
    input  [11:0]       addr, 
    input  [WIDTH-1:0]  din,
    output [WIDTH-1:0]  dout
);

reg [WIDTH-1:0] memory[4095:0];
reg [WIDTH-1:0] dout_reg;

always @ (posedge clk) begin
    if (en) begin
        if (we) begin
            memory[addr] <= din;
        end
        dout_reg <= memory[addr];
    end
end

assign dout = dout_reg;

endmodule

module blockram32 #(parameter WIDTH=12) // lehet hogy 32 nagyságú a BRAM
(
    input               clk, 
    input               we, 
    input               en,
    input  [11:0]       addr, 
    input  [WIDTH-1:0]  din,
    output [WIDTH-1:0]  dout
);

reg [WIDTH-1:0] memory[4095:0];
reg [WIDTH-1:0] dout_reg;

always @ (posedge clk) begin
    if (en) begin
        if (we) begin
            memory[addr] <= din;
        end
        dout_reg <= memory[addr];
    end
end

assign dout = dout_reg;

endmodule
