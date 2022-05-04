`timescale 1ns / 1ps

module flanger
(
  input         clk,
  input         rst,

  input  [23:0] audio_in,
  input  [ 1:0] audio_in_vld,

  output [23:0] audio_out_0,
  output [23:0] audio_out_1,

  output [ 1:0] audio_out_vld,
  input  [ 1:0] audio_in_ack
);

// órajel osztó számláló 
reg [30:0] div_cntr;
always@ (posedge clk) begin
    div_cntr = div_cntr + 1;
end

// felhasznált órajelek 
// wire flanger_clk;

// Flange sebességét befolyásoló szintézis paraméter, minél nagyobb, annál lassabb
// 100 MHz / 2^24 - 1 ~= 6
// 100 MHz / 2^30 - 1 ~= 0.1
// flange speed = [0, 6]
// parameter flange_speed = 0;
// assign flanger_clk = div_cntr[23 + flange_speed];
// Ebből majd ki lehet találni hogy milyen gyors flange-t szeretnénk

// órajel felfutó élek
wire flanger_clk_rise;
assign flanger_clk_rise = div_cntr[23] == 23'hefffff;
 
// Signal letárolása regiszterben
// ezt fogjuk használni a végső flanginghez mint jelenlegi minta 
// Minden új valid minta jelre felveszi az inputot 
reg [23:0] current_audio_in; 
always@(posedge clk) begin
    if (audio_in_vld) begin
        current_audio_in <= audio_in;
    end
end

// regiszter, hogy aktuálisan melyik channel mintájával foglalkozunk 
// legutobb érkezett valid jelek indexét tárolja
reg channel;
always@(posedge clk) begin
    if(audio_in_vld[0]) begin
        channel <= 1'b0;
    end else if(audio_in_vld[1]) begin
        channel <= 1'b1;
    end
end

// history BRAM modul címe, betöltéshez!
// cirkulárisan indexeli a BRAM blokkokat, hogy mindig legyen egy 4096 mintából álló előzményünk
// minden másodi valid jelre inkrementáljuk, mert 2 RAM címzésére van szükség.
reg [11:0] history_base_addr;
always @ (posedge clk) begin
    if(audio_in_vld[0])begin
        history_base_addr <= history_base_addr + 1;
    end
end

// history BRAM modul címe, a késleltetett érték kiolvasásához!
// A késleltetéshez használt relatív címvonal
// értékét a késleltetési függvényt tároló BRAM modulból szerzi
wire [11:0] flange_addr;

// Flanger signal címregiszter 
// flanger clk-ra működik 
reg [4:0] signal_addr;
always@ (posedge clk) begin
    if (flanger_clk_rise) begin
        signal_addr <= signal_addr + 1; 
    end
end



// Flanger signal tárolására BRAM
blockram32 bram_signal(
    .clk(clk),
    .we(0),
    .en(1),
    .addr(signal_addr),
    .din(12'b0),
    .dout(flange_addr)
);


// cím multiplexer a BRAM modulok címeihez
// a valid jel esetén betöltés, míg egyébként a minták előzménye
wire [11:0] history_addr;
assign history_addr = (audio_in_vld) ? history_base_addr : history_base_addr - flange_addr; 

wire [23:0] dout_ch0;
wire [23:0] dout_ch1;

// BRAM a channelek mintáina tárolására
// 4096 mély, és 24 bit széles adatok tárolására való (A BRAM lehet, hogy 32 bit széles)
blockram4k bram_ch0(
    .clk(clk),
    .we(audio_in_vld[0]),
    .en(1),
    .addr(history_addr),
    .din(audio_in),
    .dout(dout_ch0)
);

blockram4k bram_ch1(
    .clk(clk),
    .we(audio_in_vld[1]),
    .en(1),
    .addr(history_addr),
    .din(audio_in),
    .dout(dout_ch1)
);

// BRAM kimeneti multplexer:
// az aktív channel alapján megmondja hogy melyik BRAM modul kimenete érvényes az adott ciklusban
wire [23:0] history_sample;
assign history_sample = (channel) ? dout_ch1 : dout_ch0;

// a jelenlegi és a késleltetett jel összege
// túlcsordulás esetén szaturáció -> ezért + 1 bit
wire [24:0] current_audio_out;
assign current_audio_out = current_audio_in + history_sample;
wire saturation;
assign saturation = current_audio_out[24];

// a kimenő jeleket eltároló regiszterek
reg [23:0] audio_out_0_reg;
reg [23:0] audio_out_1_reg;
always@(posedge clk)begin
    if(channel)begin
        if(saturation) begin
            audio_out_1_reg <= 24'hffffff;
        end else begin
            audio_out_1_reg <= current_audio_out;
        end
    end else begin
        if(saturation) begin
            audio_out_0_reg <= 24'hffffff;
        end else begin
            audio_out_0_reg <= current_audio_out;
        end
    end
end

assign audio_out_0 = audio_out_0_reg;
assign audio_out_1 = audio_out_1_reg;

endmodule
