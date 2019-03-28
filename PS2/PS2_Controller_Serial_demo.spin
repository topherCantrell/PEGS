{{
  Play Station 2 Controller driver demo v1.0

  Copyright 2007 Juan Carlos Orozco ACELAB LLC
  http://www.acelab.com
  Industrial Automation

  License: Distributed under the terms of the GNU General Public License v2

  Program to test PS2_Controller object
  Use a terminal with 19200N1 settings to see live data from Controller.

  Use the Sony Playstation Controller Cable (adapter) from LynxMotion
  http://www.lynxmotion.com/Product.aspx?productID=73&CategoryID=

  Connect DAT, CMD, SEL, CLK signals to four consecutive pins of the propeller
  DAT should be the lowest pin. Use this pin when calling Start(first_pin)
  DAT (Brown), CMD (Orange), SEL (Blue) and CLK (Black or White) 
  Use a 1K resistor from Propeller output to each controller pin.
  Use a 10K pullup to 5V for DAT pin. 

  Conect Power 5V (Yellow) and Gnd (Red covered with black)
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000                      

OBJ
  Num : "Simple_Numbers"
  'Serial: "Simple_Serial"
  text : "tv_text"
  PS2 : "PS2_Controller"

PUB Main
  'Serial.start(31, 30, 19200)  'Use the USB connection that is used to progam the Propeller.
  text.start(12)



  dirA[16] :=0
  dirA[17] :=1
  dirA[18] :=1
  dirA[19] :=1
  dirA[20] :=1

  outA[19] := inA[16]

  

  repeat
  

  PS2.Start(0, 1000) 'first_pin 0, Poll every 1ms
  Repeat
    Display

PUB Display
  waitcnt(clkfreq/4 + cnt)
  'Serial.str(Num.dec(Pulse_High_Ticks))
  'Serial.str(Num.dec(Pulse_Low_Ticks))
  'Serial.str(Num.dec(Delay_Ticks))
  text.str(Num.ihex(PS2.get_Data1,8))
  text.str(Num.ihex(PS2.get_Data2,8))
  text.str(Num.decf(PS2.get_RightX,4))
  text.str(Num.decf(PS2.get_RightY,4))
  text.str(Num.decf(PS2.get_LeftX,4))
  text.str(Num.decf(PS2.get_LeftY,4))
  text.str(string("      "))
  'Send carriage return so no new line is created and data is overwritten in the same line
  'Serial.tx(13) 