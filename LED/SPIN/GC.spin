CON

GC1Pin = 8
GC2Pin = 9

InputMode = $7813

GC1Data   = $7800
GC2Data   = $7808

GC1Rumble = $7E6C
GC2Rumble = $7E6D

PUB start(cog)  
    
  coginit(cog,@entry,0)

DAT
 
                        org

' Entry
'
entry   

         rdbyte    x,inMode  wz        ' On startup, wait for ...
   if_z  jmp       #entry              ' ... the start signal  

         cmp       x,#1 wz
   if_z  jmp       #oneGC
         cmp       x,#2 wz
   if_z  jmp       #twoGC
     
' ---------------------------------------------------------------------
' CJ's Gamecube controller driver v1.2


'  Player 1: Pin 8
'  Player 2: Pin 9
  
oneGC 

         mov       pin, #GC1Pin
         mov       address, GC1store
         rdbyte    x,C_1Rumble wz
   if_z  mov       command,commandNoRumble
   if_nz mov       command,commandRumble
         call      #gcube

         mov       time, cnt
         add       time, speed
         waitcnt   time, #0        'wait for next update period
         jmp       #oneGC 

twoGC    mov       pin, #GC1Pin
         mov       address, GC1store
         rdbyte    x,C_1Rumble wz
   if_z  mov       command,commandNoRumble
   if_nz mov       command,commandRumble
         call      #gcube
  
         mov       pin, #GC2Pin
         mov       address, GC2store
         rdbyte    x,C_2Rumble wz
   if_z  mov       command,commandNoRumble
   if_nz mov       command,commandRumble
         call      #gcube

         mov       time, cnt
         add       time, speed
         waitcnt   time, #0        'wait for next update period
         jmp       #twoGC
          
gcube         mov gcpin, #1          'initialize pin mask
              shl gcpin, pin         
              
loop          mov data1, #0          'clear old data
              mov data2, #0
                         

              movs ctra, pin         'set Apins
              movs ctrb, pin
              
              movi ctra, #%01000_000              'counter a adds up high time
              movi ctrb, #%01100_000              'counter b adds up low time

              mov  frqa, #1
              mov  frqb, #1
              
              mov time, cnt          'setup for clean timing on transmit
              add time, uS

              mov reps, #25          'transmit bitcount    
gctrans       waitcnt time, uS          
              or dira, gcpin         'pull line low
              rol command, #1 wc     'read bit from command into c flag
              waitcnt time, uS2      'wait 1uS
        if_c  andn dira, gcpin       'if the bit is 1 then let the line go
              waitcnt time, uS       'wait 2uS
              andn dira, gcpin       'if not released already, release line
              djnz reps, #gctrans   'repeat for the rest of command word

first_bit     mov phsb, #0            'ready low count
              waitpne gcpin, gcpin    'wait for low
              mov phsa, #0            'ready high count
              waitpeq gcpin, gcpin    'wait for high
              mov lowtime, phsb       'capture low count
              mov phsb, #0            'reset low count
              waitpne gcpin, gcpin    'wait for low

              mov reps, #31           'receive bitcount
receive1      cmp lowtime, phsa  wc   'compare lowtime to hightime for bit that was just captured
              rcl data1, #1
              mov phsa, #0            'clear high count
              waitpeq gcpin, gcpin    'wait for high
              mov lowtime, phsb       'capture low count
              mov phsb, #0            'reset low count
              waitpne gcpin, gcpin    'wait for low
              djnz reps, #receive1    'repeat for remainder of long
              cmp lowtime, phsa  wc
              rcl data1, #1        
              
              mov reps, #32           'receive bitcount
receive2      cmp lowtime, phsa  wc   'compare lowtime to hightime for bit that was just captured     
              rcl data2, #1                                            
              mov phsa, #0            'clear high count                                               
              waitpeq gcpin, gcpin    'wait for high                                                  
              mov lowtime, phsb       'capture low count                                              
              mov phsb, #0            'reset low count                                                
              waitpne gcpin, gcpin    'wait for low                                                   
              djnz reps, #receive2    'repeat for remainder of long
              cmp lowtime, phsa  wc
              rcl data2, #1                          

put_data      mov pin,address
              wrlong data1, pin       'globalize datasets
              add pin,#4
              wrlong data2, pin

gcube_ret
     ret     

pin           long 0
address       long 0

gc1store      long  GC1Data
gc2store      long  GC2Data
C_1rumble     long  GC1Rumble
C_2rumble     long  GC2Rumble
                                              
commandRumble   long %0100_0000_0000_0011_0000_0001_1_000_0000     'command for standard controller
commandNoRumble long %0100_0000_0000_0011_0000_0000_1_000_0000     'command for standard controller

command       long 0
gcpin         long 0
uS            long     $04_C4_B4_00 / 1_000_000
uS2           long 2 * $04_C4_B4_00 / 1_000_000           
time          long 0
reps          long 0
data1         long 0
data2         long 0
speed         long     $04_C4_B4_00 / 200
lowtime       long 0
inMode long InputMode
x                       long     0

  fit