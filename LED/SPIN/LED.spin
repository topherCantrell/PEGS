' -------------------------------------------------------------------------------
' LED Driver


CON
  
LEDControl =  $7F6C
LEDBase    =  $7F6E
  
PUB start(cog, pin, mem) 
'' Start the LED

  pin := pin << 8  
  mem := mem | pin
  
  ' par = PPPPPPPP_MMMMMMxx
  coginit(cog,@LEDDriver,mem)

DAT      
         org 0
LEDDriver

         mov       tmp,par             ' Get ...         
         and       tmp,#$FF            ' ... pointer
         mov       buffer,tmp          ' Will read from it later

         mov       tmp,par             ' Get ...
         shr       tmp,#8              ' ... pin ...
         mov       pinShift,tmp        ' ... shift

         mov       tmp,#0              ' Outputs are ...
         shl       tmp,pinShift        ' ... inverted
         mov       outa,tmp            ' CS=1, WR=1, DATA=X

         mov       tmp,#7              ' 3 pins ... CS, WR, DATA
         shl       tmp,pinShift        ' Configure our ...
         mov       dira,tmp            ' ... pins as outputs                                                                     

         ' Initalization command sequence
         mov       command,#$00
         call      #writeCommand         
         mov       command,#$2C
         call      #writeCommand
         mov       command,#$14
         call      #writeCommand
         mov       command,#$01
         call      #writeCommand
         mov       command,#$03
         call      #writeCommand

top      rdbyte    tmp,CONTROL wz      ' Wait for ...
         cmp       tmp,#100 wz         ' ... command ...
  if_z   jmp       #doCommand          ' ... or ...
         cmp       tmp,#1 wz           ' ... a refresh ...
  if_nz  jmp       #top                ' ... signal

         call      #initWrite          ' Reset address to top of display

         rdword    ptr,BASE            ' Base of the LED memory
         add       ptr,buffer          ' Add our offset into the memory
         
         mov       count,#48           ' Reading 48 bytes (48*8=384 pixels)
scan     rdbyte    command,ptr         '   8 Get next byte
         call      #writeTwoNibbles    ' 456 Write the two nibbles
         add       ptr,#1              '   4 Next in memory
         djnz      count,#scan         '   4 Do all bytes on the display

' Roughly 22656 clocks/scan (0.000_2832 sec)

         mov       tmp,#0              ' Set ...
         shl       tmp,pinShift        ' ... CS=1, WR=1, and ...
         mov       outa,tmp            ' ... DATA=X

ack      rdbyte    tmp,CONTROL         ' One ...
         add       tmp,#1              ' ... display ...
         wrbyte    tmp,CONTROL         ' ... is finished
         
         jmp       #top                ' Wait for the next refresh

doCommand
         rdbyte    command,buffer      ' Commands come from ...
         call      #writeCommand       ' ... first byte of buffer
         jmp       #ack                ' ACK the command
         
' -----------------------------------------------------
'  Reset the address to the beginning of the display. Leave CS asserted
'  for more spew 
'
initWrite
         mov       tmp,#%001              '
         shl       tmp,pinShift        ' CS=0 (enable) , WR=1 (should alredy be), DATA=X
         mov       outa,tmp            ' We leave CS=0 here
         
         mov       tmp,#1              ' Send ...
         call      #writeBit           ' ... 1
         mov       tmp,#0              ' Send ...
         call      #writeBit           ' ... 0
         mov       tmp,#1              ' Send ...
         call      #writeBit           ' .... 1

         mov       tmp,#0
         call      #writeBit           ' 7 bit address ...
         call      #writeBit           ' ... 0000000
         call      #writeBit
         call      #writeBit
         call      #writeBit
         call      #writeBit
         call      #writeBit
initWrite_ret
         ret    

' -----------------------------------------------------
'  Write 8 bits from command to next address on display
'
writeTwoNibbles         ' 452
         mov       tmp,command         '  4 Write ...
         call      #writeBit           ' 52 ... bit 0
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 1
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 2
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 3
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 4
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 5
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 6
         shr       tmp,#1              '  4 Write ...
         call      #writeBit           ' 52 ... bit 7
writeTwoNibbles_ret
         ret                           '  4 

' -----------------------------------------------------
'  Write a command value. CS is toggled.
'
writeCommand
         mov       tmp,#1              '
         shl       tmp,pinShift        '
         mov       outa,tmp            ' CS=0 (enable) , WR=1 (should alredy be), DATA=X
         mov       tmp,#1              '
         call      #writeBit           ' Send 1
         mov       tmp,#0              '
         call      #writeBit           ' Send 0
         call      #writeBit           ' Send 0

         mov       tmp,command
         shr       tmp,#7
         call      #writeBit

         mov       tmp,command
         shr       tmp,#6
         call      #writeBit

         mov       tmp,command
         shr       tmp,#5
         call      #writeBit

         mov       tmp,command
         shr       tmp,#4
         call      #writeBit

         mov       tmp,command
         shr       tmp,#3
         call      #writeBit

         mov       tmp,command
         shr       tmp,#2
         call      #writeBit

         mov       tmp,command
         shr       tmp,#1
         call      #writeBit

         mov       tmp,command         
         call      #writeBit

         mov       tmp,#1              ' Write the ...
         call      #writeBit           ' ... X bit (9 bit commands)

         mov       tmp,#0              ' Set CS=1 ...
         shl       tmp,pinShift        ' ... WR=1 ...
         mov       outa,tmp            ' ... DATA=X            

writeCommand_ret
         ret

' -----------------------------------------------------
'  Write a single bit toggling the WR. We assume CS is asserted
'  and we will leave it as such.
'
writeBit       ' 12*4 = 48

         mov       tmp2,tmp            ' 4 Invert ...
         and       tmp2,#1             ' 4 ... data ...
         xor       tmp2,#1             ' 4 ...
         shl       tmp2,#2             ' 4 Correct pin  for data
         or        tmp2,#%011          ' 4 CS=0 (still) and WR=0

         shl       tmp2,pinShift       ' 4 CS=0, WR=0, DATA=D
         mov       outa,tmp2           ' 4 Signal LED board

         shr       tmp2,pinShift       ' 4 Set ... 
         andn      tmp2,#%010          ' 4 CS=0, WR=1, DATA=D
         shl       tmp2,pinShift       ' 4 Signal ...
         mov       outa,tmp2           ' 4 ... LED board                  
writeBit_ret
         ret                           ' 4
   
com      long $0

command  long $0         

tmp      long $0
ptr      long $0
count    long $0
tmp2     long $0
buffer   long 0

pinShift long 3   

CONTROL  long LEDControl
BASE     long LEDBase
  
lastAddressUsed

    fit        ' Must fit under
    