CON

SoundCOGNumber  = 4     
SystemBooted    = $7812 
 
' Chip A BC1   P12
' Chip A BDIR  P13
' Chip B BC1   P14
' Chip B BDIR  P15
'                    0....7
' A and B Data Bus P16..P23   
  
PUB start 
'' Start the SoundCOG  
  coginit(SoundCOGNumber,@SoundCOG,0)

DAT      
         org 0

SoundCOG

         mov       outa,#0             ' All outputs = 0
         mov       dira,C_PINS         ' Directions on pins (all outputs)

         ' Disable all sound  
         mov       address,#7
         mov       value,#%11_111_111
         call      #writeRegisterA
         call      #writeRegisterB 
                             
stall    rdbyte    coreTmp,C_BOOTED wz ' Wait for ...
  if_z   jmp       #stall              ' ... interpreter to boot

         mov       corePC,par          ' Program counter passed in          

' ----------------------------------------------------------------------------
' ----------------------------------------------------------------------------
' CORE of the parsing engine. This code includes the flow/data commands
' common to many languages. Customize this engine to include the
' functionality you want by adding the functions you need to the jump
' table and commenting out the others.                    
coreMain
         rdbyte    coreTmp,corePC      ' Read the next command
         add       corePC,#1           ' Next in script
         shl       coreTmp,#25 wc, nr  ' Upper bit set?
  if_nc  jmp       #dialect            ' No ... dialect command
         mov       coreCom,coreTmp     ' Get ...
         shr       coreCom,#2          ' ... command ...
         and       coreCom,#%000_11111 ' ... field    
         add       coreCom,#coreTable  ' Offset into list of jumps
         jmp       coreCom             ' Jump to the command 

coreGetByte
         rdbyte    coreLast,corePC     ' Read next byte ...
         add       corePC,#1           ' ... to coreLast
coreGetByte_ret                        '
         ret                           ' Done

coreGetRelative
         rdbyte    coreCom,corePC      ' Read next byte ...
         add       corePC,#1           ' ... to corePC
         and       coreTmp,#3          ' Add in ...
         shl       coreTmp,#8          ' ... lower 2 bits ...
         or        coreCom,coreTmp     ' ... from 1st byte
         shl       coreCom,#23 nr, wc  ' Sign extend ...
  if_c   or        coreCom,coreSX      ' ... if negative
coreGetRelative_ret                    '
         ret                           ' Done
         
coreGetDest
         rdbyte    coreCom,corePC      ' Read ...
         add       corePC,#1           ' ... 16 bit ...
         rdbyte    coreDest,corePC     ' ... dest ...
         add       corePC,#1           ' ... value
         shl       coreDest,#8         ' ...
         or        coreDest,coreCom    ' ...
coreGetDest_ret
         ret                           ' Done

coreGetSource
         rdbyte    coreCom,corePC      ' Read ...
         add       corePC,#1           ' ... 16 bit ...
         rdbyte    coreSource,corePC   ' ... source ...
         add       corePC,#1           ' ... value
         shl       coreSource,#8       ' ...
         or        coreSource,coreCom  ' ...
coreGetSource_ret                      '
         ret                           ' Done

corePC             long  0             ' Program counter
coreCarry          long  0             ' Carry value (1 or 0)
coreLast           long  0             ' Last result (used for ZERO check)
coreStackPointer   long  0             ' Index into stack
coreStack          long  0,0,0,0,0,0,0,0  ' Stack ... increase as needed
coreSyncLast       long  0             ' Last time value used in SYNC command
coreSX             long  %11111111_11111111_11111100_00000000 ' Sign extend
coreTmp            long  0             ' Temp used in command processing
coreCom            long  0             ' Command number
coreDest           long  0             ' Destination address
coreSource         long  0             ' Source address

coreTable
         jmp       #coreSETconst       ' 0
         jmp       #coreSETmem         ' 1
         jmp       #coreGOTO           ' 2
         jmp       #coreGOTOIFZERO     ' 3
         jmp       #coreGOTOIFNOTZERO  ' 4
         jmp       #coreGOTOIFCARRY    ' 5
         jmp       #coreGOTOIFNOTCARRY ' 6
         jmp       #coreCALL           ' 7
         jmp       #coreRETURN         ' 8
         jmp       #coreINC            ' 9
         jmp       #coreDEC            ' A
         jmp       #coreADDconst       ' B
         jmp       #coreADDmem         ' C
         jmp       #coreSUBconst       ' D    
         jmp       #coreSUBmem         ' E
         jmp       #coreANDconst       ' F
         jmp       #coreANDmem         ' 10
         jmp       #coreORconst        ' 11
         jmp       #coreORmem          ' 12
         jmp       #coreXORconst       ' 13
         jmp       #coreXORmem         ' 14
         jmp       #corePAUSE          ' 15
         jmp       #coreSYNC           ' 16
         'jmp       #coreMain           ' 17
         'jmp       #coreMain           ' 18
         'jmp       #coreMain           ' 19
         'jmp       #coreMain           ' 1A
         'jmp       #coreMain           ' 1B
         'jmp       #coreMain           ' 1C
         'jmp       #coreMain           ' 1D
         'jmp       #coreMain           ' 1E
         'jmp       #coreMain           ' 1F
  
''
'' SET dest,const
'' 1_ccccc_00__dddddddd_dddddddd__xxxxxxxx
coreSETconst
         call      #coreGetDest
         call      #coreGetByte
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' SET dest, source
'' 1_ccccc_00__dddddddd_dddddddd__ssssssss_ssssssss
coreSETmem
         call      #coreGetDest
         call      #coreGetSource
         rdbyte    coreLast,coreSource
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' GOTO rel
'' 1_ccccc_rr__rrrrrrrr
coreGOTO
         call      #coreGetRelative
         add       corePC,coreCom
         jmp       #coreMain
''
'' GOTO-IF-ZERO rel
'' 1_ccccc_rr__rrrrrrrr
coreGOTOIFZERO
         cmp       coreLast,#0 wz
  if_z   jmp       #coreGOTO
         jmp       #coreMain
''
'' GOTO-IF-ZERO rel
'' 1_ccccc_rr__rrrrrrrr
coreGOTOIFNOTZERO
         cmp       coreLast,#0 wz
  if_nz  jmp       #coreGOTO
         jmp       #coreMain
''
'' GOTO-IF-CARRY rel
'' 1_ccccc_rr__rrrrrrrr
coreGOTOIFCARRY
         cmp       coreCarry,#1 wz
  if_z   jmp       #coreGOTO
         jmp       #coreMain
''
'' GOTO-IF-CARRY rel
'' 1_ccccc_rr__rrrrrrrr
coreGOTOIFNOTCARRY
         cmp       coreCarry,#1 wz
  if_nz  jmp       #coreGOTO
         jmp       #coreMain
''
'' CALL rel
'' 1_ccccc_rr__rrrrrrrr
coreCALL
         mov       coreCom,coreStackPointer
         add       coreCom,#coreStack
         movd      coreCALL_i,coreCom
         add       coreStack,#1
coreCALL_i
         mov       0,corePC         
         jmp       #coreGOTO
''
'' RETURN
'' 1_ccccc_00
coreRETURN
         sub       coreStackPointer,#1
         mov       coreCom,coreStackPointer
         add       coreCom,#coreStack
         movs      coreRET_i,coreCom
         nop
coreRET_i
         mov       corePC,0
         jmp       #coreMain
''
'' INC dest
'' 1_ccccc_00_dddddddd_dddddddd
coreINC
         call      #coreGetDest
         rdbyte    coreLast,coreDest
         add       coreLast,#1
         and       coreLast,#255
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' DEC dest
'' 1_ccccc_00_dddddddd_dddddddd
coreDEC
         call      #coreGetDest
         rdbyte    coreLast,coreDest
         sub       coreLast,#1
         and       coreLast,#255
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' ADD dest,const
'' 1_ccccc_00__dddddddd_dddddddd__xxxxxxxx
coreADDconst
         call      #coreGetDest
         call      #coreGetByte
coreADD1 rdbyte    coreCom,coreDest
         add       coreLast,coreCom
         cmp       coreLast,#255
  if_a   mov       coreCarry,#1
  if_be  mov       coreCarry,#0
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' ADD dest, source
'' 1_ccccc_00__dddddddd_dddddddd__ssssssss_ssssssss
coreADDmem
         call      #coreGetDest
         call      #coreGetSource
         rdbyte    coreCom,coreSource
         jmp       #coreADD1
''
'' SUB dest,const
'' 1_ccccc_00__dddddddd_dddddddd__xxxxxxxx
coreSUBconst
         call      #coreGetDest
         call      #coreGetByte
         mov       coreCom,coreLast
coreSUB1 rdbyte    coreLast,coreDest
         sub       coreLast,coreCom wc
  if_c   mov       coreCarry,#1
  if_nc  mov       coreCarry,#0
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' ADD dest, source
'' 1_ccccc_00__dddddddd_dddddddd__ssssssss_ssssssss
coreSUBmem
         call      #coreGetDest
         call      #coreGetSource
         rdbyte    coreCom,coreSource
         jmp       #coreSUB1        
''
'' AND dest,const
'' 1_ccccc_00__dddddddd_dddddddd__xxxxxxxx
coreANDconst
         call      #coreGetDest
         call      #coreGetByte
coreAND1 rdbyte    coreCom,coreDest
         and       coreLast,coreCom
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' AND dest, source
'' 1_ccccc_00__dddddddd_dddddddd__ssssssss_ssssssss
coreANDmem
         call      #coreGetDest
         call      #coreGetSource
         rdbyte    coreCom,coreSource
         jmp       #coreAND1
''
'' OR dest,const
'' 1_ccccc_00__dddddddd_dddddddd__xxxxxxxx
coreORconst
         call      #coreGetDest
         call      #coreGetByte
coreOR1  rdbyte    coreCom,coreDest
         or        coreLast,coreCom
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' OR dest, source
'' 1_ccccc_00__dddddddd_dddddddd__ssssssss_ssssssss
coreORmem
         call      #coreGetDest
         call      #coreGetSource
         rdbyte    coreCom,coreSource
         jmp       #coreOR1
''
'' XOR dest,const
'' 1_ccccc_00__dddddddd_dddddddd__xxxxxxxx
coreXORconst
         call      #coreGetDest
         call      #coreGetByte
coreXOR1 rdbyte    coreCom,coreDest
         xor       coreLast,coreCom
         wrbyte    coreLast,coreDest
         jmp       #coreMain
''
'' XOR dest, source
'' 1_ccccc_00__dddddddd_dddddddd__ssssssss_ssssssss
coreXORmem
         call      #coreGetDest
         call      #coreGetSource
         rdbyte    coreCom,coreSource
         jmp       #coreXOR1
''
'' PAUSE n
'' 1_ccccc_nn__nnnnnnnn
corePAUSE
         call      #coreGetRelative
         andn      coreCom,coreSX
         shl       coreCom,#4
         add       coreCom,cnt
         waitcnt   coreCom,coreCom
         jmp       #coreMain
''
'' SYNC n
'' 1_ccccc_nn__nnnnnnnn
coreSYNC
         call      #coreGetRelative
         andn      coreCom,coreSX wz
  if_z   jmp       coreSYN1
         shl       coreCom,#4
         add       coreCom,coreSyncLast
         waitcnt   coreCom,#0
         mov       coreSyncLast,coreCom
         jmp       #coreMain  
coreSYN1 mov       coreSyncLast,cnt
         jmp       #coreMain

' ----------------------------------------------------------------------------
' ----------------------------------------------------------------------------
' End of the common CORE of the engine. Specific dialect processing comes
' here.
' ----------------------------------------------------------------------------
' ----------------------------------------------------------------------------               
dialect  


{
cmdDelay
         and       tmp,C_7FFF          ' Mask off the delay value         
         shl       tmp,#9              ' Make it larger ... this is a fast counter
         mov       ctr,tmp             ' New counter value
         jmp       #main               ' Next command

cmdRegisterA 
' 0_000_rrrr_vvvvvvvv             
         mov       address,tmp         ' Get the ...
         shr       address,#8          ' ... register ...
         and       address,#15         ' ... address
         mov       value,tmp           ' Get the ...
         and       value,#255          ' ... value          
         call      #writeRegisterA     ' Write to chip A  
         jmp       #main               ' Next command

cmdRegisterB
' 0_111_rrrr_vvvvvvvv
         mov       address,tmp         ' Get the ...
         shr       address,#8          ' ... register ...
         and       address,#15         ' ... address
         mov       value,tmp           ' Get the ...
         and       value,#255          ' ... value
         call      #writeRegisterB     ' Write to chip B
         jmp       #main               ' Next command        

cmdNote
' 0_001_0c_vv_nnnnnnnn
         mov       com,tmp             ' Get the ...
         shr       com,#10             ' ... chip number
         
         mov       note,tmp            ' Get the ...
         and       note,#255           ' ... note number
         add       note,#noteTable     ' Offset into the table
         movs      cmdN1,note          ' Lookup ...
         nop                           ' ... the ...
cmdN1    mov       note,0              ' ... note value

         mov       address,tmp         ' Set address ...
         shr       address,#8          ' ... to FINE ...
         and       address,#3          ' ... register of ...
         shl       address,#1          ' ... target voice
                
         mov       value,note          ' Get ... 
         shr       value,#8            ' ... FINE value
         and       com,#1 nr, wz       ' Write to ...
  if_z   call      #writeRegisterA     ' ... Chip A ...
  if_nz  call      #writeRegisterB     ' ... or Chip B

         add       address,#1          ' Point to COARSE register
         mov       value,note          ' Get ...
         and       value,#255          ' ... COARSE value
         and       com,#1 nr, wz       ' Write to ...
  if_z   call      #writeRegisterA     ' ... Chip A ...
  if_nz  call      #writeRegisterB     ' ... or Chip B
                  
         jmp       #main               ' Next command 

cmdGoto
' 0_010_aaaaaaaaaaaa
         mov       ptr,tmp             ' Get the ...
         and       ptr,C_FFF           ' ... destination
         jmp       #main               ' Next command

cmdStop
' 0_011_000000000000
         mov       ptr,#0              ' Reset pointer
         jmp       #main               ' Next command     

cmdVarSet
' 0_100_rrrr_vvvvvvvv         ' Set variable R to V

         mov       com,tmp             ' Get the ...
         and       com,#$FF            ' ... value V
         shr       tmp,#8              ' Get the ...
         and       tmp,#$0F            ' ... register R
         add       tmp,musicVar        ' Offset to memory address
         wrbyte    com,tmp             ' Write the byte
         jmp       #main               ' Next command

cmdIncDec
' 0_101_00000000_rrrr         ' Increment R
' 0_101_00000001_rrrr         ' Decrement R
         mov       com,tmp             ' Get the ...
         and       tmp,#$0F            ' ... register R
         add       tmp,musicVar        ' Offset to memory address    
         rdbyte    last,tmp            ' Get the value
         and       com,#$10 wz         ' Check the operation bit
  if_z   jmp       #cmdInc             ' 0 means increment
         sub       last,#1             ' Decrement the value
         wrbyte    last,tmp            ' Write the new value
         jmp       #main               ' Next command
cmdInc   add       last,#1             ' Increment the value
         wrbyte    last,tmp            ' Write the new value
         jmp       #main               ' Next command

cmdConditional
' 0_110_oooooooooooo
         cmp       last,#0 wz          ' If last inc/dec was NOT zero ...
   if_nz jmp       #cmdGoto            ' ... do the goto
         jmp       #main               ' Otherwise next command
         
newScript 
         mov       oneway,tmp          ' Might be a oneway ... release later
         and       tmp,C_FFFF          ' Strip off script address
         mov       ptr,tmp             ' Set new address
         mov       ctr,#0              ' Script starts now
                
         mov       tmp,#1              ' Can't ...
         wrlong    tmp,boxDat1Ret      ' ... fail
         wrlong    tmp,boxComStat      ' Status = done
         and       oneway,C_ONEWAY wz  ' If this is a oneway command ...
  if_nz  mov       tmp,#SoundBoxNumber ' ... release the lock on ...
  if_nz  lockclr   tmp                 ' ... behalf of the caller
         jmp       #main               ' Top of script loop

         }
' -------------------------------------------------------------
writeRegisterA
'
' BDIR=0, BC1=0, BUS = address
' BDIR=1, BC1=1, BUS = address (latch address)
' BDIR=0, BC1=0, BUS = address
'
' BDIR=0, BC1=0, BUS = data
' BDIR=1, BC1=0, BUS = data (write)
' BDIR=0, BC1=0, BUS = data      

         mov       hold,address
         shl       hold,#16
         
         mov       tmp,hold
         or        tmp,C_A_INAC
         mov       outa,tmp       ' addr + inactive             
         call      #delay

         mov       tmp,hold
         or        tmp,C_A_ADDR
         mov       outa,tmp       ' addr + latch           
         call      #delay

         mov       tmp,hold
         or        tmp,C_A_INAC
         mov       outa,tmp       ' addr + inactive              
         call      #delay

         mov       hold,value
         shl       hold,#16  
         
         mov       tmp,hold
         or        tmp,C_A_INAC
         mov       outa,tmp       ' data + inactive          
         call      #delay
 
         mov       tmp,hold
         or        tmp,C_A_WR
         mov       outa,tmp       ' data + write            
         call      #delay 

         mov       tmp,hold
         or        tmp,C_A_INAC   ' data + inactive
         mov       outa,tmp         
         call      #delay
                   
writeRegisterA_ret
         ret   

' -------------------------------------------------------------
writeRegisterB
'
' BDIR=0, BC1=0, BUS = address
' BDIR=1, BC1=1, BUS = address (latch address)
' BDIR=0, BC1=0, BUS = address
'
' BDIR=0, BC1=0, BUS = data
' BDIR=1, BC1=0, BUS = data (write)
' BDIR=0, BC1=0, BUS = data      

         mov       hold,address
         shl       hold,#16
         
         mov       tmp,hold
         or        tmp,C_B_INAC
         mov       outa,tmp       ' addr + inactive             
         call      #delay

         mov       tmp,hold
         or        tmp,C_B_ADDR
         mov       outa,tmp       ' addr + latch           
         call      #delay

         mov       tmp,hold
         or        tmp,C_B_INAC
         mov       outa,tmp       ' addr + inactive              
         call      #delay

         mov       hold,value
         shl       hold,#16  
         
         mov       tmp,hold
         or        tmp,C_B_INAC
         mov       outa,tmp       ' data + inactive          
         call      #delay
 
         mov       tmp,hold
         or        tmp,C_B_WR
         mov       outa,tmp       ' data + write            
         call      #delay 

         mov       tmp,hold
         or        tmp,C_B_INAC   ' data + inactive
         mov       outa,tmp         
         call      #delay
                   
writeRegisterB_ret
         ret

delay    mov       tt,DELFAC
tdel     djnz      tt,#tdel
delay_ret
         ret

tt       long 0


DELFAC   long $8

'note     long $0


'ctr      long $0
address  long $0
value    long $0
hold     long $0
'oneway   long $0   

tmp long $0
             
C_PINS   long %0000_0000_11111111_11_11_000_000_000_000  '
C_B_ADDR long %0000_0000_00000000_11_00_000_000_000_000  ' BDIR=1 BC1=1
C_B_WR   long %0000_0000_00000000_10_00_000_000_000_000  ' BDIR=1 BC1=0
C_B_INAC long %0000_0000_00000000_00_00_000_000_000_000  ' BDIR=0 BC1=0
'
C_A_ADDR long %0000_0000_00000000_00_11_000_000_000_000  ' BDIR=1 BC1=1
C_A_WR   long %0000_0000_00000000_00_10_000_000_000_000  ' BDIR=1 BC1=0
C_A_INAC long %0000_0000_00000000_00_00_000_000_000_000  ' BDIR=0 BC1=0

C_BOOTED         long  SystemBooted
'C_ONEWAY         long  %01000000_00000000_00000000_00000000

'C_FFFF   long $FFFF
'C_FFFFFFFF long $FFFFFFFF
'C_FFF    long $FFF
'C_7FFF   long $7FFF
'C_8000   long $8000

'boxComStat long   MailboxMemory+SoundBoxNumber*32
'boxDat1Ret long   MailboxMemory+SoundBoxNumber*32+4
'musicVar   long   MusicVariables
'pc         long   0

' 96 notes defined (97 with 0=silence)
noteTable
'      FF_CC
 long $00_00
 '
 long $5D_0D   ' C      Octave 1
 long $9C_0C   ' C#
 long $E7_0B   ' D
 long $3C_0B   ' D#
 long $9B_0A   ' E
 long $02_0A   ' F
 long $73_09   ' F#
 long $EB_08   ' G
 long $6B_08   ' G#
 long $F2_07   ' A
 long $80_07   ' A#
 long $14_07   ' B
 '
 long $AE_06   ' Octave 2
 long $4E_06
 long $F4_05
 long $9E_05
 long $4D_05
 long $01_05
 long $B9_04
 long $75_04
 long $35_04
 long $F9_03
 long $C0_03
 long $8A_03
 '
 long $57_03   ' Octave 3
 long $27_03
 long $FA_02
 long $CF_02
 long $A7_02
 long $84_02
 long $5D_02
 long $3B_02
 long $1B_02
 long $FC_01
 long $E0_01
 long $C5_01
 '
 long $AC_01   ' Octave 4  (Middle C)
 long $94_01
 long $7D_01
 long $68_01
 long $53_01
 long $40_01
 long $2E_01
 long $1D_01
 long $0D_01
 long $FE_00   ' A440  (note 46 in this table -- 69 as MIDI note)
 long $F0_00
 long $E2_00
 '
 long $D6_00   ' Octave 5
 long $CA_00
 long $BE_00
 long $B4_00
 long $AA_00
 long $A0_00
 long $97_00
 long $8F_00
 long $87_00
 long $7F_00
 long $78_00
 long $71_00
 '
 long $6B_00   ' Octave 6
 long $65_00
 long $5F_00
 long $5A_00
 long $55_00
 long $50_00
 long $4C_00
 long $47_00
 long $43_00
 long $40_00
 long $3C_00
 long $39_00
 '
 long $35_00   ' Octave 7
 long $32_00
 long $30_00
 long $2D_00
 long $2A_00
 long $28_00
 long $26_00
 long $24_00
 long $22_00
 long $20_00
 long $1E_00
 long $1C_00
 '
 long $1B_00   ' Octave 8
 long $19_00
 long $18_00
 long $16_00
 long $15_00
 long $14_00
 long $13_00
 long $12_00
 long $11_00
 long $10_00
 long $0F_00
 long $0E_00



lastAddress
         fit