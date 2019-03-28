DAT

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