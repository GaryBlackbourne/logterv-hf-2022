`timescale 1ns / 1ps

module codec_if
(
   input             clk, // 100MHz
   input             rst,

   // config pins
   output            codec_m0,
   output            codec_m1,
   output            codec_i2s,
   output            codec_mdiv1,
   output            codec_mdiv2,

   output            codec_rstn,  // 8 lrck periódust kell várni
   output            codec_mclk,  // master clk = clk/2 (szőrők és modulátorok órajele)
   output            codec_lrclk, // left right clk = clk/512 (melyik csatorna aktív)
   output            codec_sclk,  // serial clk = clk/8  (serial audio clk)

   output            codec_sdin,
   input             codec_sdout,

   output reg [ 1:0] aud_dout_vld,
   output     [23:0] aud_dout,

   input      [ 1:0] aud_din_vld,
   output reg [ 1:0] aud_din_ack,
   input      [23:0] aud_din0,
   input      [23:0] aud_din1
);

// Configuration pins
// stand-alone slave mode, left justified, 256x mclk
assign codec_m0      = 1'b1;
assign codec_m1      = 1'b1;
assign codec_i2s     = 1'b0;
assign codec_mdiv1   = 1'b1;
assign codec_mdiv2   = 1'b1;

// free-running counter, resettable
// - clock generation
// - reset generation & wait for at least 1045 sampling periods
reg [19:0] div_cntr;
always @ (posedge clk) begin
    if(rst) begin
        div_cntr <= 1'b0;
    end else begin
        div_cntr <= div_cntr + 1;
    end
end

assign codec_lrclk  = div_cntr[8];      // /512
assign codec_sclk   = div_cntr[2];      // /8
assign codec_mclk   = div_cntr[0];      // /2

wire sclk_fall;   //  adatkiadás
wire sclk_rise;   //  erre mintavételezzük a bemeneti adatot
assign sclk_fall    = (div_cntr[2:0] == 3'b111); // éldetektálás a számlálóból számolható
assign sclk_rise    = (div_cntr[2:0] == 3'b011);

// "virtual" bit counter, 5-bit part of div_cntr
// shift register valid jel generálásához kell
// 24 bites shift reg -> minimum 5 bit kell:
wire [4:0] bit_cntr;
assign bit_cntr = div_cntr[7:3];

// active low reset for the codec
// ~8 sampling periods long after system reset
// várakozunk megfelelő mennyiségű időt, reset esetén
reg rst_ff;
always @ (posedge clk) begin
    if(rst) begin
        rst_ff <= 1'b0;
    end else if(div_cntr[11:9] == 3'b111) begin // lrck periódusaiból 8at számolunk meg. EZ NEM TELJESEN 8
        rst_ff <= 1'b1;
    end
end


// assign codec reset to output port
assign codec_rstn = rst_ff;

// init done:
// wait at least 1045 sampling periods after codec reset is released,
// then set init done
reg init_done_ff;
always @ (posedge clk) begin
    if(rst) begin
        init_done_ff <= 1'b0;
    end else if(div_cntr[19:9] == 11'h81d) begin // 11'h81c = 1000 0001 1100 -> 1045 + 7 +1 a ráhagyás
        init_done_ff <= 1'b1;
    end
end


// input shift register
// sample input data when the generated sclk has a rising edge
reg  [23:0] shr_rx;
always @ (posedge clk) begin
    if(sclk_rise) begin
            shr_rx <= {shr_rx[22:0], codec_sdout};
    end
end


// ADC parallel data valid for channel 0
// should be 0 when init_done is 0
always @ (posedge clk) begin
    if(init_done_ff & sclk_rise & ~div_cntr[8] & (bit_cntr == 23)) begin
        aud_dout_vld[0] <= 1'b1;
    end else begin
        aud_dout_vld[0] <= 1'b0;
    end
end


// ADC parallel data valid for channel 1
// should be 0 when init_done is 0
always @ (posedge clk) begin
    if(init_done_ff & sclk_rise & div_cntr[8] & (bit_cntr == 23)) begin
        aud_dout_vld[1] <= 1'b1;
    end else begin
        aud_dout_vld[1] <= 1'b0;
    end
end


// ADC parallel data output: the receive shift register
assign aud_dout = shr_rx;



// transmit shift register, which should
// - load channel 0 or channel 1 parallel data
// - or shift when the generated sclk has a falling edge
reg  [23:0] shr_tx;
always @ (posedge clk) begin
    if (~init_done_ff)begin
        shr_tx <= 24'b0;
    end else if (sclk_fall & ~div_cntr[8] & bit_cntr == 31) begin
        if(aud_din_vld[0])begin
            shr_tx <= aud_din0;
        end else begin
            shr_tx <= 24'b0;
        end
    end else if(sclk_fall & div_cntr[8] & bit_cntr == 31) begin
        if(aud_din_vld[1])begin
            shr_tx <= aud_din0;
        end else begin
            shr_tx <= 24'b0;
        end
    end else if(sclk_fall) begin
        shr_tx <= {shr_tx[22:0], 1'b0};
    end
end

// serial input of the CODEC
assign codec_sdin = shr_tx[23];


// ACK output for channel 0 parallel data input
always @ (posedge clk) begin
    if(~div_cntr[8] & sclk_fall & aud_din_vld[1] & bit_cntr == 31) begin
        aud_din_ack[0] <= 1'b1;
    end else begin
        aud_din_ack[0] <= 1'b0;
    end
end


// ACK output for channel 1 parallel data input
always @ (posedge clk) begin
    if(div_cntr[8] & sclk_fall & aud_din_vld[0] & bit_cntr == 31) begin
        aud_din_ack[1] <= 1'b1;
    end else begin
        aud_din_ack[1] <= 1'b0;
    end
end

endmodule
