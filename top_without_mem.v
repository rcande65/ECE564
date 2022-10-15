module MyDesign(
       clk, 
       reset_b, 
       dut_run, 
       sram_dut_read_data, 
       wmem_dut_read_data,
       dut_busy,
       dut_sram_write_enable,
       dut_sram_write_address,
       dut_sram_write_data,
       dut_sram_read_address,
       dut_wmem_read_address
       );

input clk, reset_b, dut_run;
input [15:0] sram_dut_read_data, wmem_dut_read_data;

output dut_busy, dut_sram_write_enable;
output wire [11:0] dut_sram_write_address, dut_sram_read_address, dut_wmem_read_address;
output wire [15:0] dut_sram_write_data;


//internal connections
wire [1:0]input_address_size_sel, weight_data_sel, input_address_sel, input_data_sel, output_data_shift_sel, output_address_sel;
wire horizontal_data_shift_sel;
wire [11:0] input_address_size_reg; 
wire [15:0] weight_data_reg;

//weight sram address will always be 1
assign dut_wmem_read_address = 1;

//controller
controller_v2 U0 (
              reset_b,
              clk,
              dut_run,
              dut_busy,
              input_address_size_sel,
              weight_data_sel,
              horizontal_data_shift_sel,
              input_address_sel,
              output_address_sel,
              input_data_sel,
              output_data_shift_sel,
              input_address_size_reg,
              dut_sram_write_enable,
              sram_dut_read_data
              );

//datapath

//input sram address 
sram_address input_sram (clk, input_address_sel, dut_sram_read_address);

//output sram address
sram_address output_sram (clk, output_address_sel, dut_sram_write_address);

//size of input matrix
input_address_size U1 (clk, input_address_size_sel, sram_dut_read_data, input_address_size_reg);

//weight sram data
weight_data weight_sram (clk, weight_data_sel, wmem_dut_read_data, weight_data_reg);

//convolution
convolution U2 (clk, input_address_size_reg, input_data_sel, horizontal_data_shift_sel, output_data_shift_sel, sram_dut_read_data, wmem_dut_read_data, dut_sram_write_data);

endmodule

//datapath components

//module for producing address to send to SRAM (for both input and output)
module sram_address(clock, sram_address_sel, sram_address_reg);

input clock;
input [1:0] sram_address_sel;
output reg [11:0] sram_address_reg;

always@(posedge clock)
begin
   case(sram_address_sel)
      2'b00: //clear
            sram_address_reg <= 0;
      2'b01: //clear
            sram_address_reg <= 0;
      2'b10: //increment 
            sram_address_reg <= sram_address_reg + 1;
      2'b11: //hold
            sram_address_reg <= sram_address_reg;
   endcase
end 
endmodule

//module for getting the size of the data set to be convolved 
module input_address_size(clock, input_address_size_sel, input_sram_data, input_address_size_reg);

input clock;
input [1:0] input_address_size_sel;
input [15:0] input_sram_data;
output reg [11:0] input_address_size_reg;

always@(posedge clock)
begin
   case(input_address_size_sel)
      2'b00: //clear
            input_address_size_reg <= 0;
      2'b01: //clear
            input_address_size_reg <= 0;
      2'b10: //capture new value
            input_address_size_reg <= input_sram_data;
      2'b11: //hold
            input_address_size_reg <= input_address_size_reg;
   endcase
end
endmodule

//module for getting the weight SRAM data
module weight_data(clock, weight_data_sel, weight_sram_data, weight_data_reg);

input clock;
input [1:0] weight_data_sel;
input [15:0] weight_sram_data;
output reg [15:0] weight_data_reg;

always@(posedge clock)
begin
   case(weight_data_sel)
      2'b00: //clear
            weight_data_reg <= 0;
      2'b01: //clear
            weight_data_reg <= 0;
      2'b10: //capture new data
            weight_data_reg <= weight_sram_data;
      2'b11: //hold
            weight_data_reg <= weight_data_reg;
   endcase
end
endmodule

//convolution 
module convolution(clock, input_address_size_reg, input_data_sel, horizontal_data_shift_sel, output_data_shift_sel, input_data, weight_data, output_data);

input clock;
input [1:0] input_data_sel, output_data_shift_sel;
input horizontal_data_shift_sel;
input [15:0] input_data, weight_data; 
input [11:0] input_address_size_reg;
output reg [15:0] output_data;

//internal registers, wires, and variables
reg [15:0] bottom_reg, middle_reg, top_reg;
reg new_shift_bit_top, new_shift_bit_middle, new_shift_bit_bottom;
reg left_reg_top, left_reg_middle, left_reg_bottom;
reg center_reg_top, center_reg_middle, center_reg_bottom;
reg right_reg_top, right_reg_middle, right_reg_bottom;
reg [3:0] i;
reg [4:0] x;
wire [8:0] convolution_xnor;
integer j;
wire [3:0] sum_0; 
reg [3:0] sum_1;

//vertical shift register 
always@(posedge clock)
begin
   case(input_data_sel)
      2'b00: //clear
            begin
            bottom_reg <= 0;
            middle_reg <= 0;
            top_reg    <= 0;
            end
      2'b01: //clear
            begin
            bottom_reg <= 0;
            middle_reg <= 0;
            top_reg    <= 0;
            end
      2'b10: //shift
            begin
            bottom_reg <= input_data;
            middle_reg <= bottom_reg;
            top_reg    <= middle_reg;
            end
      2'b11: //hold
            begin
            bottom_reg <= bottom_reg;
            middle_reg <= middle_reg;
            top_reg    <= top_reg;
            end
   endcase 
end


always@(posedge clock)
begin
   if(horizontal_data_shift_sel && i != 16)
      begin   
      left_reg_top    <= top_reg[i];
      left_reg_middle <= middle_reg[i];
      left_reg_bottom <= bottom_reg[i];
      i <= i + 1;
      end
   else
      begin
      new_shift_bit_top    <= 0;
      new_shift_bit_middle <= 0;
      new_shift_bit_bottom <= 0;
      i <= 0;
      end

   center_reg_top    <= left_reg_top;
   center_reg_middle <= left_reg_middle;
   center_reg_bottom <= left_reg_bottom;

   right_reg_top    <= center_reg_top;
   right_reg_middle <= center_reg_middle;
   right_reg_bottom <= center_reg_bottom;
end

//convolution xnors
assign convolution_xnor[0] = ~(right_reg_top  ^ weight_data[0]);
assign convolution_xnor[1] = ~(center_reg_top ^ weight_data[1]);
assign convolution_xnor[2] = ~(left_reg_top   ^ weight_data[2]);

assign convolution_xnor[3] = ~(right_reg_middle  ^ weight_data[3]);
assign convolution_xnor[4] = ~(center_reg_middle ^ weight_data[4]); 
assign convolution_xnor[5] = ~(left_reg_middle   ^ weight_data[5]);

assign convolution_xnor[6] = ~(right_reg_bottom  ^ weight_data[6]);
assign convolution_xnor[7] = ~(center_reg_bottom ^ weight_data[7]);
assign convolution_xnor[8] = ~(left_reg_bottom   ^ weight_data[8]);

assign sum_0 = convolution_xnor[0] + convolution_xnor[1] + convolution_xnor[2] + convolution_xnor[3] + convolution_xnor[4] + convolution_xnor[5] + convolution_xnor[6] + convolution_xnor[7] + convolution_xnor[8]; 

always@(*)
begin
   if(sum_0 > 4)
      sum_1 <= 1;
   else 
      sum_1 <= 0;
end

//put result in output reg 
always@(posedge clock)
begin
   case(output_data_shift_sel)
      2'b00:
            begin 
	    output_data = 0;
            x = 0;
            end
      2'b01:
            begin
            output_data = 0;
            x = 0;
            end
      2'b10:
	    begin
            if(x < input_address_size_reg - 2)
               begin
               output_data[x] = sum_1;
               output_data = output_data;  
               x = x + 1;
               end
            else
               begin
               output_data = output_data;
               x = x + 1;
               end
            end
      2'b11:
            begin
            output_data = output_data;
            x = x;
            end 
   endcase
end

endmodule

//controller

module controller_v2(
reset,
clock,
go,
busy,
input_address_size_sel,
weight_data_sel,
horizontal_data_shift_sel,
input_address_sel,
output_address_sel,
input_data_sel,
output_data_shift_sel,
input_address_size_reg,
write_enable,
input_data
);
//inputs and outputs
input clock, reset, go;
input [11:0] input_address_size_reg; 
input [15:0] input_data;
output reg [1:0] input_address_size_sel, weight_data_sel, input_address_sel, input_data_sel, output_data_shift_sel, output_address_sel;
output reg horizontal_data_shift_sel, busy, write_enable;

//internals
//state vectors
reg [3:0] current_state, next_state;

//internal counters
reg [3:0] vertical_iterations, horizontal_iterations;

//parameters
parameter
   s0 = 0,
   s1 = 1,
   s2 = 2,
   s3 = 3,
   s4 = 4,
   s5 = 5,
   s6 = 6,
   s7 = 7,
   s8 = 8,
   s9 = 9,
   s10 = 10,
   s11 = 11,
   s12 = 12,
   s13 = 13;

//state machine
always@(posedge clock or negedge reset)
begin
   if(!reset)
      current_state = s0;
   else 
      current_state = next_state;
end

always@(posedge clock)
begin
   case(current_state)
      s0: //clear everything
         begin
         busy <= 1'b0;
         input_address_size_sel <= 2'b00;
         input_data_sel <= 2'b00;
         weight_data_sel <= 2'b00;
         input_address_sel <= 2'b00;
         output_address_sel <= 2'b00;
         output_data_shift_sel <= 2'b00;
         vertical_iterations <= 4'b0000;
         horizontal_iterations <= 4'b0000;
         horizontal_data_shift_sel <= 1'b0;
         write_enable <= 1'b0;
         if(go)
            next_state <= s1;
         else
            next_state <= s0;
         end 
      s1: //busy high and get size
         begin
         busy <= 1'b1;
         write_enable <= 1'b0;
         input_address_sel <= 2'b10;
         input_address_size_sel <= 2'b11;
         input_data_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b11;
         vertical_iterations <= 4'b0000;
         horizontal_iterations <= 4'b0000;
         horizontal_data_shift_sel <= 1'b0;
         next_state <= s2;
         end
      s2:
         begin
         write_enable <= 1'b0;
         busy <= 1'b1;
         input_address_sel <= 2'b10;
         input_address_size_sel <= 2'b10;
         input_data_sel <= 2'b00;
         weight_data_sel <= 2'b00;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b00;
         vertical_iterations <= 4'b0000;
         horizontal_iterations <= 4'b0000;
         horizontal_data_shift_sel <= 1'b0; 
         if(input_data == 16'hFF)
            next_state <= s0;
         else
            next_state <= s3;
         end
      s3:
         begin
         write_enable <= 1'b0;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b10;
         busy <= 1'b1;
         input_address_sel <= 2'b10;
         input_data_sel <= 2'b00;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b00;
         vertical_iterations <= 4'b0000;
         horizontal_iterations <= 4'b0000;
         horizontal_data_shift_sel <= 1'b0;
         next_state <= s4;
         end
      s4:
         begin
         write_enable <= 1'b0;
         input_data_sel <= 2'b10;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         input_address_sel <= 2'b10;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b00;
         vertical_iterations <= 4'b0000;
         horizontal_iterations <= 4'b0000;
         horizontal_data_shift_sel <= 1'b0;
         next_state <= s5;
         end
      s5:
         begin
         write_enable <= 1'b0;
         input_data_sel <= 2'b10;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         input_address_sel <= 2'b10;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b00;
         vertical_iterations <= 4'b0000;
         horizontal_iterations <= 4'b0000;
         horizontal_data_shift_sel <= 1'b0;
         next_state <= s6;
         end
      s6:
         begin
         write_enable <= 1'b0;
         horizontal_iterations <= input_address_size_reg - 1;
         input_address_sel <= 2'b11;
         vertical_iterations <= input_address_size_reg - 2;
         input_data_sel <= 2'b10;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b00;
         horizontal_data_shift_sel <= 1'b0;
         next_state <= s7;
         end
      s7:
         begin
         write_enable <= 1'b0;
         input_data_sel <= 2'b11;
         horizontal_data_shift_sel <= 1;
         horizontal_iterations <= horizontal_iterations - 1;
         output_address_sel <= 2'b11;
         vertical_iterations <= vertical_iterations;
         input_address_sel <= 2'b11;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         output_data_shift_sel <= 2'b11;
         next_state <= s8;
         end
      s8:
         begin
         write_enable <= 0;
         horizontal_iterations <= horizontal_iterations - 1;
         vertical_iterations <= vertical_iterations - 1;
         input_data_sel <= 2'b11;
         horizontal_data_shift_sel <= 1'b1;
         output_address_sel <= 2'b11;
         input_address_sel <= 2'b11;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         output_data_shift_sel <= 2'b11;
         next_state <= s9;
         end
      s9:
         begin
         next_state <= s10;
         write_enable <= 0;
         horizontal_iterations <= horizontal_iterations;
         vertical_iterations <= vertical_iterations;
         input_data_sel <= 2'b11;
         horizontal_data_shift_sel <= 1'b1;
         output_address_sel <= 2'b11;
         output_data_shift_sel <= 2'b11;
         input_address_sel <= 2'b11;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         end
      s10:
         begin
         write_enable <= 0;
         output_data_shift_sel <= 2'b10;
         horizontal_iterations <= horizontal_iterations - 1;
         vertical_iterations <= vertical_iterations;
         input_data_sel <= 2'b11;
         horizontal_data_shift_sel <= 1'b1;
         output_address_sel <= 2'b11;
         input_address_sel <= 2'b11;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         if(horizontal_iterations > 0)
            next_state <= s10;
         //else if(input_data == 16'hff)
           // next_state = s0;
         else 
            next_state <= s11;
         end
      s11:
         begin
         write_enable <= 1'b1;
         input_data_sel <= 2'b10;
         output_data_shift_sel <= 2'b00;
         input_address_sel <= 2'b10;
         horizontal_iterations <= horizontal_iterations;
         vertical_iterations <= vertical_iterations;
         horizontal_data_shift_sel <= 1'b1;
         output_address_sel <= 2'b11;
         input_address_size_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         next_state <= s12;
         end
      s12:
         begin
         input_address_sel <= 2'b11;
         input_data_sel <= 2'b11;
         write_enable <= 1'b0;
         horizontal_data_shift_sel <= 1'b0;
         input_address_size_sel <= 2'b11;
         horizontal_iterations <= horizontal_iterations;
         vertical_iterations <= vertical_iterations;
         output_data_shift_sel <= 2'b11;
         weight_data_sel <= 2'b11;
         busy <= 1'b1;
         if(vertical_iterations > 0) begin
            next_state <= s13;
            output_address_sel <= 2'b11;
            end
         else begin
            next_state <= s2;
            output_address_sel <= 2'b10;
            end
          end
      s13:
         begin
         write_enable <= 1'b0;
         output_address_sel <= 2'b10;
         input_address_sel <= 2'b11;
         input_data_sel <= 2'b11;
         input_address_size_sel <= 2'b11;
         horizontal_data_shift_sel <= 1'b0;
         horizontal_iterations <= horizontal_iterations;
         vertical_iterations <= vertical_iterations;
         weight_data_sel <= 2'b11;
         output_data_shift_sel <= 2'b11;
         busy <= 1'b1;
         if(input_data == 16'hff)
            next_state <= s0;
         else 
            next_state <= s7;
         end
      default:
         begin
         write_enable <= 0;
         output_address_sel <= 2'b00;
         input_address_sel <= 2'b00;
         input_data_sel <= 2'b00;
         input_address_size_sel <= 2'b00;
         horizontal_data_shift_sel <= 1'b0;
         horizontal_iterations <= 4'b0000;
         vertical_iterations <= 4'b0000;
         weight_data_sel <= 2'b00;
         output_data_shift_sel <= 2'b00;
         busy <= 1'b0;
         next_state <= s0;
         end
   endcase
end
endmodule


