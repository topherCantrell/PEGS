' -------------------------------------------------------------------------------
' LED Script Engine

CON
  
LEDControl   =  $7F6C
LEDBase      =  $7F6E
SystemBooted = $7812  ' System-booted flag. Non-zero when booted.
  
PUB start(cog, script) 
'' Start the LEDScriptEngine

  coginit(cog,@LEDScriptEngine,script)

DAT      
         org 0
         
LEDScriptEngine           

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

{
    mov       x,LEDTESTBASE
    wrbyte    x,BASE
    '
    mov       x,coreTmp
    mov       y,LEDTESTBASE    
    wrbyte    x,y
    add       y,#1
    shr       x,#8
    wrbyte    x,y
    '
    mov       x,#1
    wrbyte    x,CONTROL
    '
    sub       debcnt,#1 wz             
    tst if_z jmp #tst
}
         
         add       corePC,#1           ' Next in script  
         and       coreTmp,#$80 nr, wz ' Upper bit set
  if_z   jmp       #dialect            ' No ... dialect command
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
         and       coreCom,coreSXB nr, wz ' Sign extend ...         
  if_nz  or        coreCom,coreSX      ' ... if negative
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
coreSXB            long  %00000000_00000000_00000010_00000000
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
''  The N value is shifted left 17 here. Max value is
''  3FF<<17 =  7FE0000 / 80_000_000 = 1.6760832 sec
''    1<<17 =    20000 / 80_000_000 = 1.6384 msec
corePAUSE
         call      #coreGetRelative
         andn      coreCom,coreSX         
         shl       coreCom,#17         
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
         shl       coreCom,#17
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

cx  long  0
cy  long  0
x   long  0
y   long  0
xr  long  0
yr  long  0
yo  long  0
c   long  1
tx  long  0
ty  long  0
bp  long  0
drawPtr long  0

BASE      long   LEDBase
CONTROL   long   LEDControl
C_BOOTED  long   SystemBooted
               
dialect
         mov       coreCom,coreTmp     ' Original value            
         shr       coreCom,#3          ' Dialect command ...
         and       coreCom,#%0000_1111 ' ... field    
         add       coreCom,#dialTable  ' Offset into list of jumps
         jmp       coreCom             ' Jump to the command 

''
'' Dialect commands have the following 1st byte format:
'' 0_cccc_zz_v ...
''  v is 1 if command uses memory data or 0 if command
''  uses constant (immediate) data
''  zz is additional data bits available to the command
dialTable
         jmp      #cmdSetCanvas
         jmp      #cmdRenderCanvas
         jmp      #cmdColor
         jmp      #cmdPlotPoint
         jmp      #cmdMoveTo
         jmp      #cmdLineTo
''
'' SetCanvas address,clear
'' 0_cccc_vx_0__mmmmmmmm__mmmmmmmm
cmdSetCanvas        
         call      #coreGetDest        ' Get the address
         mov       drawPtr,coreDest    ' Set our draw pointer
         and       coreTmp,#2 wz,nr    ' If not clear ...
    if_z jmp       #coreMain           ' ... continue
         mov       coreSource,#0       ' Get clear ...
         and       coreTmp,#4 wz       ' ... value from ...
  if_nz  sub       coreSource,#1     ' ... command
         mov       coreTmp,#48         ' 48 longs (192 bytes)
cmdSetC1 wrlong    coreSource,coreDest ' Clear ...
         add       coreDest,#4         ' ... the draw ...
         djnz      coreTmp,#cmdSetC1   ' ... canvass            
         jmp       #coreMain           ' Done
''
'' RenderCanvas address
'' 0_cccc_00_0__mmmmmmmm__mmmmmmmm
cmdRenderCanvas 
         call      #coreGetDest        ' Get target canvas
         wrword    coreDest,BASE       ' Tell the LED driver where
         mov       coreDest,#1         ' Tell the LED driver ...
         wrword    coreDest,CONTROL    ' ... to refresh
         jmp       #coreMain           ' Done
''
'' Color c 
'' 0_cccc_0n_0
'' 0_cccc_00_1__mmmmmmmm__mmmmmmmm
cmdColor
         mov       c,coreTmp           ' Value if ...
         shr       c,#1                ' ... constant is ...
         and       c,#1                ' ... specified
         and       coreTmp,#1 wz       ' Use constant if ...
  if_z   jmp       #coreMain           ' ... this is a constant command
         call      #coreGetDest        ' Get the memory address
         rdbyte    c,coreDest          ' Read color from memory
         jmp       #coreMain           ' Done
''
'' PlotPoint x,y (set internal CX and CY)
'' 0_cccc_00_0__xxxxxxxx__yyyyyyyy
'' 0_cccc_00_1__mmmmmmmm__mmmmmmmm          
cmdPlotPoint
         and       coreTmp,#1 wz       ' Handle ...
  if_z   jmp       #cmdPlotP1          ' ... immediate data
         call      #coreGetDest        ' Get the memory address
         rdbyte    cx,coreDest         ' Get the CX value
         add       coreDest,#1         ' Next memory
         rdbyte    cy,coreDest         ' Get the CY value
         jmp       #cmdPlotP2          ' Do the plot      
cmdPlotP1
         call      #coreGetByte        ' Read ...
         mov       cx,coreLast         ' ... immediate CX
         call      #coreGetByte        ' Read ...
         mov       cy,coreLast         ' ... immediate CY      
cmdPlotP2
         mov       tx,cx               ' The plot mangles ...
         mov       ty,cy               ' ... the incoming X,Y
         call      #PlotTxTy           ' Plot the point
         jmp       #coreMain           ' Done
''
'' MoveTo x,y
'' 0_cccc_00_0__xxxxxxxx__yyyyyyyy
'' 0_cccc_00_1__mmmmmmmm__mmmmmmmm
cmdMoveTo    
         and       coreTmp,#1 wz       ' Handle ...
  if_z   jmp       #cmdMoveT1          ' ... immediate data
         call      #coreGetDest        ' Get the memory address
         rdbyte    cx,coreDest         ' Get the CX value
         add       coreDest,#1         ' Next memory
         rdbyte    cy,coreDest         ' Get the CY value
         jmp       #coreMain           ' Done
cmdMoveT1
         call      #coreGetByte        ' Read ...
         mov       cx,coreLast         ' ... immediate CX
         call      #coreGetByte        ' Read ...
         mov       cy,coreLast         ' ... immediate CY
         jmp       #coreMain           ' Done
''
'' LineTo x,y      (From cx,cy using color)
'' 0_cccc_00_0__xxxxxxxx__yyyyyyyy
'' 0_cccc_00_1__mmmmmmmm__mmmmmmmm
cmdLineTo
         and       coreTmp,#1 wz       ' Handle ...
  if_z   jmp       #cmdLineT1          ' ... immediate data
         call      #coreGetDest        ' Get the memory address
         rdbyte    x,coreDest          ' Get the X value
         add       coreDest,#1         ' Next memory
         rdbyte    y,coreDest          ' Get the Y value
         jmp       #cmdLineT2          ' Do the plot      
cmdLineT1
         call      #coreGetByte        ' Read ...
         mov       x,coreLast          ' ... immediate X
         call      #coreGetByte        ' Read ...
         mov       y,coreLast          ' ... immediate Y      
cmdLineT2         
         call      #linepd         
         jmp       #coreMain   
'
' ClusterRender cluster,offset,clear
' 0_cccc_0X_0__CCCCCCCC__CCCCCCCC__oooooooo_oooooooo
' 0_cccc_0X_1__mmmmmmmm__mmmmmmmm
'
' ClusterHint cluster
' 0_cccc_0X_0__CCCCCCCC__CCCCCCCC
' 0_cccc_0X_1__mmmmmmmm__mmmmmmmm
'
' Rect width,height,fill
' 0_cccc_0f_0__wwwwwwww__hhhhhhhh
' 0_cccc_0f_1__mmmmmmmm__mmmmmmmm      

' -----------------------------------------------------------------------------
' -----------------------------------------------------------------------------
PlotTxTy        
         cmp       ty,#16 wz, wc
   if_ae jmp       #cmdPlotL 
cmdPlotU
         cmp       tx,#24 wz, wc
   if_ae jmp       #cmdPlotUR
cmdPlotUL
         mov       coreTmp,#191        ' cn = 191
         jmp       #cmdPlotUdo         
cmdPlotUR
         mov       coreTmp,#143        ' cn = 143
         sub       tx,#24              ' tx = tx - 24
cmdPlotUdo
         mov       xr,tx               ' xr = tx * 2
         shl       xr,#1               '
         mov       yr,ty               ' yr = ty / 8
         shr       yr,#3               '
         mov       yo,ty               ' yo = ty % 8
         and       yo,#7               '
         mov       bp,#128             ' bp = 128 >> yo
         shr       bp,yo               '
         sub       coreTmp,xr          ' xr = cn - xr
         mov       xr,coreTmp          '
         sub       xr,yr               ' xr = xr - yr
         jmp       #cmdPlotDo         
cmdPlotL
         sub       ty,#16              ' ty = ty - 16 
         cmp       tx,#24 wz, wc
  if_ae  jmp       #cmdPlotLR
cmdPlotLL
         mov       coreTmp,#48         ' cn = 48
         jmp       #cmdPlotLdo         
cmdPlotLR
         sub       tx,#24              ' tx = tx - 24
         mov       coreTmp,#0          ' cn = 0
cmdPlotLdo
         mov       xr,tx               ' xr = tx * 2
         shl       xr,#1               '
         mov       yr,ty               ' yr = ty / 8
         shr       yr,#3               '
         mov       yo,ty               ' yo = ty % 8
         and       yo,#7               '
         mov       bp,#1               ' bp = 1 << yo
         shl       bp,yo               '
         add       xr,coreTmp          ' xr = cn + xr
         add       xr,yr               ' xr = xr + yr
cmdPlotDo
         add       xr,drawPtr          ' Point into our memory 
         rdbyte    coreTmp,xr          ' Get what's there
         cmp       c,#0 wz             ' Set the ...
  if_nz  or        coreTmp,bp          ' ... bit to 1 or 0 ...
  if_z   andn      coreTmp,bp          ' ... based on color
         wrbyte    coreTmp,xr          ' Write the value back
PlotTxTy_ret
         ret

' -----------------------------------------------------------------------------
' This line algorithm lifted from the propeller library Graphics.spin
' -----------------------------------------------------------------------------

sx    long 0
sy    long 0
count long 0
ratio long 0

' Plot line from cx,cy to x,y  (cx,cy ends up at x,y)
'
linepd                  cmps    x,cx           wc, wr  'get x difference
                        negc    sx,#1                   'set x direction

                        cmps    y,cy           wc, wr  'get y difference
                        negc    sy,#1                   'set y direction

                        abs     x,x                   'make differences absolute
                        abs     y,y

                        cmp     x,y           wc      'determine dominant axis
        if_nc           tjz     x,#:last               'if both differences 0, plot single pixel
        if_nc           mov     count,x                'set pixel count
        if_c            mov     count,y
                        mov     ratio,count             'set initial ratio
                        shr     ratio,#1
        if_c            jmp     #:yloop                 'x or y dominant?


:xloop                  mov     tx,cx
                        mov     ty,cy
                        call    #PlotTxTy                  'dominant x line
                        add     cx,sx
                        sub     ratio,y        wc
        if_c            add     ratio,x
        if_c            add     cy,sy
                        djnz    count,#:xloop

                        jmp     #:last                  'plot last pixel


:yloop                  mov     tx,cx
                        mov     ty,cy
                        call    #PlotTxTy                  'dominant y line
                        add     cy,sy
                        sub     ratio,x        wc
        if_c            add     ratio,y
        if_c            add     cx,sx
                        djnz    count,#:yloop

:last                   mov     tx,cx
                        mov     ty,cy
                        call    #PlotTxTy                  'plot last pixel

linepd_ret              ret

         fit
