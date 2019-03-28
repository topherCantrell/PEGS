{{
  Play Station 2 Controller driver v1.0

  Copyright 2007 Juan Carlos Orozco ACELAB LLC
  http://www.acelab.com
  Industrial Automation

  License: Distributed under the terms of the GNU General Public License v2
  
  Use the Sony Playstation Controller Cable (adapter) from LynxMotion
  http://www.lynxmotion.com/Product.aspx?productID=73&CategoryID=

  Connect DAT, CMD, SEL, CLK signals to four consecutive pins of the propeller
  DAT should be the lowest pin. Use this pin when calling Start(first_pin)
  DAT (Brown), CMD (Orange), SEL (Blue) and CLK (Black or White)
  Use a 1K resistor from Propeller output to each controller pin.
  Use a 10K pullup to 5V for DAT pin. 

  Conect Power 5V (Yellow) and Gnd (Red covered with black)

  See PS2_Controller_Serial_demo for a use example of this object.
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  PULSE_HIGH_US = 50'5
  PULSE_LOW_US = 50'5
  DELAY_US = 100'20 'Delay between communication bytes

VAR
  'Communication between object and new cog. Each variable is ofseted 4 bytes from the address passed as PAR
  long first_pin
  long Pulse_High_Ticks
  long Pulse_Low_Ticks
  long Delay_Ticks
  long Delay_Requests_Ticks
  long PSX_Data1
  long PSX_Data2

  'Normal variables
  long Cog

PUB Start(firstpin, delay_requests_us) : ok




  

  ''Start cog to read the PS2 Controller in repeatedly.
  ''first_pin: is first pin (DAT) for the 4 consecutive pins of the controller
  ''DAT, CMD, SEL, CLK
  ''delay_requests_us: Delay between requests poll controller every Ex. 1000 -> 1ms.
  ''   
  ''TODO Multiple controllers using chipselect signals.
  first_pin := firstpin
  
  'Convert time delays to equivalent procesor clock ticks
  Pulse_High_Ticks := PULSE_HIGH_US * (clkfreq / 1000000)
  Pulse_Low_Ticks := PULSE_LOW_US * (clkfreq / 1000000)
  Delay_Ticks := DELAY_US * (clkfreq / 1000000)
  Delay_Requests_Ticks := delay_requests_us * (clkfreq / 1000000)

  'If cog already executing stop it first.
  Stop
  'Call cog
  'TODO If Cog stop cog, add Stop function
  Cog := cognew(@Wave, @first_pin)+1
  ok := Cog

PUB Stop
  ''Stop cog

  'TODO reset dira for output pins. (Free pins)
  if cog
    cogstop(cog~ - 1)

PUB get_Data1
  return PSX_Data1

PUB get_Data2
  return PSX_Data2

PUB get_RightX
  return PSX_Data2 & $000000FF  

PUB get_RightY
  return PSX_Data2 >> 8 & $000000FF 

PUB get_LeftX
  return PSX_Data2 >> 16 & $000000FF 

PUB get_LeftY
  return PSX_Data2 >> 24 & $000000FF
  
DAT
                        org     0
Wave
                        mov     t1, par                 ' Set all pin masks
                        rdlong  t2, t1
                        mov     dat_mask, #1
                        shl     dat_mask, t2

                        mov     cmd_mask, dat_mask
                        shl     cmd_mask, #1

                        mov     sel_mask, dat_mask
                        shl     sel_mask, #2

                        mov     clk_mask, dat_mask
                        shl     clk_mask, #3

                        mov     t1, PAR
                        add     t1, #4
                        rdlong  high_t, t1 'Pulse_High_Ticks

                        mov     t1, PAR
                        add     t1, #8   'Pulse_Low_Ticks
                        rdlong  low_t, t1

                        mov     t1, PAR
                        add     t1, #12   'Delay_Ticks
                        rdlong  delay_t, t1

                        mov     t1, PAR
                        add     t1, #16  'Delay_Requests_Ticks
                        rdlong  delay_rq_t, t1

                        mov     dira, cmd_mask
                        or      dira, sel_mask
                        or      dira, clk_mask

                        'Set clock to high
                        or      outa, clk_mask
                        or      outa, sel_mask



                          {    
                        ' Put controller in config mode
                        mov     cmd1,#$43
                        mov     cmd2,#$0
                        mov     cmd3,#$1
                        mov     cmd4,#$0
                        mov     cmd5,#$0
                        call    #PSSendAndReceive

                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t
                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t    
                        
                        ' Set analog mode
                        mov     cmd1,#$4F
                        mov     cmd2,#$0
                        mov     cmd3,#$FF
                        mov     cmd4,#$FF
                        mov     cmd5,#$3 
                        call    #PSSendAndReceive

                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t
                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t   
                        
                        ' Exit config mode
                        mov     cmd1,#$43
                        mov     cmd2,#$0
                        mov     cmd3,#$0
                        mov     cmd4,#$0
                        mov     cmd5,#$0
                        call    #PSSendAndReceive

                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t
                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t

                           }
                                

                        ' Polling mode from here out
                        mov     cmd1,#$42
                        mov     cmd2,#$0
                        mov     cmd3,#$0
                        mov     cmd4,#$0
                        mov     cmd5,#$0
                        'call    #PSSendAndReceive




                        
:loop

                        call    #PSSendAndReceive

                        'Write Captured PSX_Data1
                        mov     t1, PAR
                        add     t1, #20  'PSX_Data1
                        wrlong  data1, t1                  

                        'Write Captured PSX_Data2
                        mov     t1, PAR
                        add     t1, #24  'PSX_Data2
                        wrlong  data2, t1                  

                        jmp     #:loop

'
PSSendAndReceive
                        'Delay between each controller POLL.
                        ' Wait Long delay (Maybe 1 milisecond)
                        mov     Time, cnt
                        add     Time, delay_rq_t
                        waitcnt Time, high_t
                        
                        xor     outa, sel_mask

                        ' Wait 20 us delay
                        mov     Time, cnt
                        add     Time, delay_t
                        waitcnt Time, low_t
      
                        mov     tx_data, #1
                        call    #txrx
                        mov     tx_data, cmd1
                        call    #txrx
                        mov     tx_data, cmd2
                        call    #txrx
                        mov     tx_data, cmd3
                        call    #txrx
                        mov     tx_data, cmd4
                        call    #txrx
                        mov     data1, rx_data
                        
                        mov     tx_data, cmd5
                        call    #txrx
                        mov     tx_data, #0
                        call    #txrx
                        mov     tx_data, #0
                        call    #txrx
                        mov     tx_data, #0
                        call    #txrx
                        mov     data2, rx_data
                      
                        or      outa, sel_mask                        

PSSendAndReceive_ret
                        ret
txrx                    
                        mov     t1, #8

                        ' Wait 20 us delay
                        mov     Time, cnt
                        add     Time, delay_t
                        waitcnt Time, low_t


                        ' Comment out the Initial Delay
                        'mov     Time, cnt
                        'add     Time, Delay
:bit
                        test    tx_data, #1 wc
                        muxc    outa, cmd_mask          ' Write tx_data[0]
                        ror     tx_data, #1             ' Shift out tx_data[0]
                        ' Clock = 0 (Assumes clock = 1 before)
                        xor     outa, clk_mask
                        ' In case we wanted to override the first delay.
                        'mov     Time, cnt
                        'add     Time, low_t
                        waitcnt Time, high_t
                        or      outa, clk_mask
                        test    dat_mask, ina wc        ' Read CMD bit
                        mov     clk_posedge_cnt, cnt    ' Timestamp this rising edge                        
                        rcr     rx_data, #1             ' Shift into rx_data[31]
                        waitcnt Time, low_t
                        djnz    t1, #:bit               ' Next bit...
txrx_ret                ret
                                  

cmd1                    long    $42
cmd2                    long    $0
cmd3                    long    $0
cmd4                    long    $0
cmd5                    long    $0
                        
dat_mask                res     1
cmd_mask                res     1
sel_mask                res     1
clk_mask                res     1

Time                    res     1
t1                      res     1     'Temp variable
t2                      res     1     'Temp variable
low_t                   res     1
high_t                  res     1
delay_t                 res     1
delay_rq_t              res     1
clk_posedge_cnt         res     1
tx_data                 res     1
rx_data                 res     1
data1                   res     1
data2                   res     1


   