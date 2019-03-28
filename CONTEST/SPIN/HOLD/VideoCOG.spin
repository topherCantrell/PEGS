CON

' This include file is pasted into the top of every SPIN file

' ==================================================  
' Numeric constants
' ==================================================

DebugPin = $08_00_00_00

RandomSeedStart = $00_B4_F0_1A

DiskBoxNumber = 0
DiskCOGNumber = 3

SpriteBoxNumber = 2
SpriteCOGNumber = 5

SoundBoxNumber = 3
SoundCOGNumber = 4

VariableBoxNumber  = 1
VariableCOGNumber  = 1

VideoBoxNumber = 2
VideoCOGNumber = 2

NumSprites = 16

CursorTileA = 32             ' First tile to blink for text cursor
CursorTileB = 31             ' Second tile to blink for text cursor
CursorBlinkRate = $8000      ' Cursor blink rate (passes through readBuf before changing)

' VariableCOG command for get-variable
VariableGetCommand = %1_111_0001__00_000_111_00_10_10_00_0111_1011
' VariableCOG command for variable-set
VariableSetCommand = %1_111_0001__01_000_110_10_00_10_10_0000_1011
' VariableCOG command for reading next key
VariableGetKeyCommandA = %1_111_0001__00_000_110_00_10_10_11_0111_1011
VariableGetKeyCommandB = $0003_0000

MountCommand = %1_000__0000___0000_0000___00000000___00000000
LoadCluster  = %1_000__0000___0001_0011___00000000___00000000

' ==================================================
' Memory addresses
' ==================================================

SpriteTable = $0000

SorEvenMask  = $0100
SorOddMask   = $0140  
   
SorEvenImage = $0180
SorOddImage  = $01C0

ScreenMap  = $0200
TileMemory = $0880

Cluster0          = $8000 - 2048*2
Cluster1          = $8000 - 2048*3
Cluster2          = $8000 - 2048*4

GC1Data   = $7800
GC2Data   = $7808

NumberReserved    = $7810
SectorsPerCluster = $7811
DisplayBeamRowNumber = $7812
InputMode = $7813
CacheCopy         = $7818

KeyboardMemory     = $7E20

KeyStates = $7E2C

RetraceCounter = $7854

ScratchMemory = $7E70        ' A 16-byte scratch buffer used by "getNumber" function

MailboxMemory     = $7E80

      
PUB start 
  
  coginit(VideoCOGNumber,@VideoCOG,0)

DAT      
         org       0

VideoCOG    

stall    rdlong    tmp,boxComStat wz   ' On startup, wait for ...
   if_z  jmp       #stall              ' ... the start signal 

main     rdlong    tmp,boxComStat      ' Read the command
         shl       tmp,#1 nr, wc       ' If upper bit is clear ...
   if_nc jmp       #main               ' ... keep waiting for command  

         mov       com,tmp             ' Strip ...
         shr       com,#16             ' ... command ...
         and       com,#31             ' ... field ...
                   
         mov       i,tmp               ' Strip ... 
         shr       i,#21               ' ... i ...
         and       i,#1                ' ... field                

         add       com,#commandTable   ' Offset into list of jumps
         jmp       com                 ' Take the jump to the command

commandTable
  ' Room for 32 commands.
  ' Each command is passed i=varForm, tmp=complete command long
         jmp  #doRECT          ' 00000
         jmp  #doPRINT         ' 00001
         jmp  #doPRINTARR      ' 00010
         jmp  #doPRINTVAR      ' 00011
         jmp  #doSETCURSOR     ' 00100
         jmp   #final          ' 00101
         jmp   #final          ' 00110
         jmp   #final          ' 00111
         jmp  #doINITTILES     ' 01000
         jmp  #doSETTILE       ' 01001
         jmp  #doGETTILE       ' 01010         
         jmp  #doSETSPRITE     ' 01011
         jmp  #doGETSPRITE     ' 01100         

' --------------------------------------------------------------------------------
' [01011] SETSPRITE slot, Long1, Long2, Long3, Long4
'   1_111_0bbb____00_0_01011__00000000_0000ssss
'     Long1
'     Long2
'     Long3
'     Long4
' [01011] SETSPRITE actionScript, Vn (Vn = slot, Long1, Long2, Long3, Long4)
'   1_bbb_0000____00_1_01011__00000000_vvvvvvvv
' 
doSETSPRITE   

         djnz      i,#setSpriteConsts  ' If i==0 use constants from command         
       
         and       tmp,#$FF            ' Get 1st variable
         call      #fetchVar           ' Lookup ...
         mov       p,data1             ' ... sprite slot
         
         call      #fetchVar           ' Pull the 4 Longs ...
         mov       x,data1             ' ... from 4 consecutive variables
         call      #fetchVar           '
         mov       y,data1             '
         call      #fetchVar           '
         mov       width,data1         '   
         call      #fetchVar           '   
         mov       data4,data1         '

         rdlong    i,boxDat1Ret        ' ActionScript is still a constant
         shl       i,#16               ' Very last in the memory footprint
         and       data4,C_FFFF        ' Mask off any existing script data in last long
         add       data4,i             ' The action-script comes in as a constant

         mov       tmp,p               ' Slot number to tmp
         mov       data1,x             ' Data needs to be in "dataN"
         mov       data2,y             '
         mov       data3,width         '         

         jmp       #setSpriteDat       ' Store the sprite data from "dataN" to sprite memory
         
setSpriteConsts 
         rdlong    data1,boxDat1Ret    ' 4 longs of data ...
         rdlong    data2,boxDat2       ' ... stored in ...
         rdlong    data3,boxDat3       ' ... mailbox command
         rdlong    data4,boxDat4       '         
         
setSpriteDat
         rdbyte    i,C_DBRN            ' If the value is 250 (and a short time after) ... 
         cmp       i,#250 wz,wc        ' ... then it is safe for us to ...
  if_nz  jmp       #setSpriteDat       ' ... access sprite data          
  
         and       tmp,#15             ' tmp now has destination ...
         shl       tmp,#4              ' ... memory location   
         
         wrlong    data1,tmp           ' Write 16 bytes to memory
         add       tmp,#4              '
         wrlong    data2,tmp           '
         add       tmp,#4              '
         wrlong    data3,tmp           '
         add       tmp,#4              '
         rdlong    x,boxOfs            ' Automatically offset actionscript ....
         shl       x,#16               ' ... to current ...
         add       data4,x             ' ... cluster
         wrlong    data4,tmp           '               
         
         jmp       #final              ' Done

' --------------------------------------------------------------------------------
' [01100] GETSPRITE Vn (Vn = slot, Long1, Long2, Long3, Long4)
'   1_010_0000____00_0_01100__00000000_vvvvvvvv
'      
doGETSPRITE 
                                     
         and       tmp,#255
         call      #fetchVar           ' Lookup index
         mov       t2,tmp              ' Next var into t2 (used by storeVar)
         mov       p,data1             ' Index into p
         and       p,#15               ' p now has destination ...         
         shl       p,#4                ' ... memory location

getSpriteDat
         rdbyte    i,C_DBRN            ' If the value is 250 (and a short time after) ... 
         cmp       i,#250 wz,wc        ' ... then it is safe for us to ...
  if_nz  jmp       #getSpriteDat       ' ... access sprite data         
         
         rdlong    tmp,p               ' Read 4 longs ... 
         call      #storeVar           ' ... and store to ...
         add       p,#4                ' ... consecutive variables
         rdlong    tmp,p               '
         call      #storeVar           '
         add       p,#4                '
         rdlong    tmp,p               '
         call      #storeVar           '
         add       p,#4                '
         rdlong    tmp,p               '
         call      #storeVar           '
                       
         jmp       #final              ' Done

' --------------------------------------------------------------------------------
' [00000] RECTANGLE x,y,width,height,tile
'   1_111_0bbb____00_0_0000__xxxxxxxx_yyyyyyyy
'   wwwwwwww_hhhhhhhh_tttttttt_tttttttt
' [00000] RECTANGLE Vn
'   0_bbb_0000____00_1_0000__00000000_vvvvvvvv '
doRECT
         djnz      i,#doRECTcn         ' If i==0 use constants from command

         and       tmp,#$FF            ' Get 1st variable
         call      #fetchVar           ' Lookup ...
         mov       x,data1             ' ... X
         call      #fetchVar           ' Lookup ...
         mov       y,data1             ' ... Y
         call      #fetchVar           ' Lookup ...
         mov       width,data1         ' ... width
         call      #fetchVar           ' Lookup ...
         mov       height,data1        ' ... height
         call      #fetchVar           ' Lookup ...
         mov       tmp,data1           ' ... tile number
         jmp       #doRECTE            ' Do the loop

doRECTcn mov       x,tmp               ' Get the ..
         shr       x,#8                ' ... X ...
         and       x,#$FF              ' ... field
         mov       y,tmp               ' Get the ...
         and       y,#$FF              ' ... Y field
         rdlong    tmp,boxDat1Ret      ' Get next long
         mov       width,tmp           ' Get the ...
         shr       width,#24           ' ... width ...
         and       width,#$FF          ' ... field
         mov       height,tmp          ' Get the ...
         shr       height,#16          ' ... height ...
         and       height,#$FF         ' ... field
         and       tmp,C_FFFF          ' Get the tile number

doRECTE  shl       y,#6                ' Y * 64
         shl       x,#1                ' X * 2
         add       x,y                 ' X now has pointer to ...
         add       x,C_SCRMEM          ' ... upper left tile entry
doRECT2  mov       ptr,x               ' A PTR across the row
         mov       com,width           ' A counter across the row
doRECT1  wrword    tmp,ptr             ' Write the tile
         add       ptr,#2              ' Next in row
         djnz      com,#doRECT1        ' Do all of this row
         add       x,#32*2             ' Move screen ptr down a row
         djnz      height,#doRECT2     ' Do all rows
                  
final    mov       tmp,#1              ' Return ...
         wrlong    tmp,boxComStat      ' ... status (Done)
         jmp       #main               ' Next command

' --------------------------------------------------------------------------------
' [00001] PRINT msg
'   1_bbb_0000____00_0_00001__mmmmmmmm_mmmmmmmm
'
doPRINT  and       tmp,C_FFFF          ' Get ...
         rdlong    x,boxOfs            ' ... pointer to string ...
         add       x,tmp               ' ... in x
         
doPRINT1 rdbyte    tmp,x wz            ' Read next byte in string
  if_z   jmp       #final              ' Done if 0            
         call      #prChar             ' Print character
         add       x,#1                ' Bump pointer
         jmp       #doPRINT1           ' Next character
         
' --------------------------------------------------------------------------------
' [00010] PRINT msg[Vn]
'   1_111_0bbb____00_0_00010__mmmmmmmm_mmmmmmmm
'   00000000_00000000_00000000_vvvvvvvv
'
doPRINTARR
         and       tmp,C_FFFF          ' Get ....         
         rdlong    x,boxOfs            ' ... pointer to array ...
         add       x,tmp               ' ... in com
         
         rdlong    tmp,boxDat1Ret      ' Get the variable number
         call      #fetchVar           ' Get the index number

         cmp       data1,#0 wz         ' We already have ...
    if_z jmp       #doPRINT1           ' ... index zero
    
doPRTA2  rdbyte    tmp,x               ' Skip ...
         add       x,#1                ' ... to ....
         cmp       tmp,#0 wz           ' ... next ...
   if_nz jmp       #doPRTA2            ' ... zero
         djnz      data1,#doPRTA2      ' Skip to requested index

         jmp       #doPRINT1           ' Print the string 

' --------------------------------------------------------------------------------
' [00011] PRINTVAR Vn
'   1_bbb_0000____00_0_00011__00000000_vvvvvvvv
'
doPRINTVAR
         
         and       tmp,#$FF            ' Get ...
         call      #fetchVar           ' ... variable
         mov       x,data1             ' ... value
                  
         mov       i,#0                ' Ignore leading 0s if i==0
         mov       t1,#NC_TAB          ' Crude table of decimal places     
prv5     movd      prv2,t1             ' Comparison index into table
         movs      prp1,t1             ' Subtraction index into table
prv4     mov       tmp,#0              ' Keep count of digits at this decimal "place"
prv2     cmp       0,x wz,wc           ' Compare the "place" to the remainder
    if_a jmp       #prv1               ' No more digits at this decimal "place"
         mov       i,#1                ' No more leading zeros
         add       tmp,#1              ' Count digits at this place
prp1     sub       x,0                 ' Subtract off one "place" worth
         jmp       #prv2               ' Go back and get all at this "place"
prv1     cmp       i,#0 wz             ' Is this a leading zero?
    if_z jmp       #prv3               ' Yes ... skip it
         add       tmp,#$30            ' No ... make it a number character ...
         call      #prChar             ' ... and print
prv3     add       t1,#1               ' Next "place" to the right
         cmp       t1,#t1 wz           ' Have we printed all decimal "places"?
  if_nz  jmp       #prv5               ' No ... keep processing
         add       x,#$30              ' Print the final ...
         mov       tmp,x               ' .... "place" value ...
         call      #prChar             ' ... even if zero            
         jmp       #final              ' Done
          
NC_TAB long 1_000_000_000              ' 4_294_967_295 Max 4-byte decimal value
       long   100_000_000
       long    10_000_000
       long     1_000_000
       long       100_000
       long        10_000
       long         1_000
       long           100
       long            10
' t1 MUST follow the NC_TAB. It's address indicates the end of the table.
t1     long        0  
 
' --------------------------------------------------------------------------------
' [00100] SETCURSOR x,y
'   1_bbb_0000____00_0_00100__xxxxxxxx_yyyyyyyy
' SETCURSOR Vn
'   1_bbb_0000____00_1_00100__00000000_vvvvvvvv
'
doSETCURSOR
         cmp       i,#0 wz             ' User variables?
    if_z jmp       #doSCUcn            ' No ... go parse constants

         and       tmp,#$FF            ' Get 1st variable
         call      #fetchVar           ' Lookup ...
         mov       x,data1             ' ... X
         call      #fetchVar           ' Lookup ...
         mov       y,data1             ' ... Y         
         jmp       #doSCUE             ' Set the cursor

doSCUcn  mov       x,tmp               ' Get the ..
         shr       x,#8                ' ... X ...
         and       x,#$FF              ' ... field
         mov       y,tmp               ' Get the ...
         and       y,#$FF              ' ... Y field

doSCUE   shl       y,#6                ' Y * 64
         shl       x,#1                ' X * 2
         add       x,y                 ' X now has  ...
         add       x,C_SCRMEM          ' ... cursor ...
         mov       textCursor,x        ' ... value
          
         jmp       #final              ' Done

' --------------------------------------------------------------------------------
' [01000] INITTILES ptr,start,count
'   1_111_0bbb____00_0_01000__pppppppp_pppppppp
'   ssssssss_ssssssss_cccccccc_cccccccc
'
doINITTILES
        
         rdlong    com,boxOfs          ' Cluster offset          
         and       tmp,C_FFFF          ' ... data pointer          
         add       tmp,com             ' Absolute address
         rdlong    y,boxDat1Ret        ' Get ...
         mov       x,y                 ' ... start (x) and ...
         and       y,C_FFFF            ' ... count (y)
         shr       x,#16               ' X points ...
         shl       x,#4                ' ... to ...
         add       x,C_TILEMEM         ' ... tile memory
         shl       y,#4                ' Number of bytes to move

doINI1   rdbyte    com,tmp             ' From data ...
         add       tmp,#1              ' ... bump data pointer ...
         wrbyte    com,x               ' ... to screen memory
         add       x,#1                ' Bump tile memory pointer
         djnz      y,#doINI1           ' Move all bytes            
        
         jmp       #final              ' Done

' --------------------------------------------------------------------------------
' [01001] SETTILE x,y,n
'   1_111_0bbb____00_0_01001__xxxxxxxx_yyyyyyyy
'   00000000_00000000_nnnnnnnn_nnnnnnnn
' [01001] SETTILE Vn
'   1_bbb_0000____00_1_01001__00000000_vvvvvvvv
'
doSETTILE
         cmp       i,#0 wz             ' User variables?
    if_z jmp       #doSTTcn            ' No ... go parse constants

         and       tmp,#$FF            ' Get 1st variable
         call      #fetchVar           ' Lookup ...
         mov       x,data1             ' ... X
         call      #fetchVar           ' Lookup ...
         mov       y,data1             ' ... Y
         call      #fetchVar           ' Lookup ...
         mov       width,data1         ' ... tile number
         jmp       #doSETCUE           ' Skip constants
         
doSTTcn  rdlong    width,boxDat1Ret    ' Second word ...
         and       width,C_FFFF        ' ... is tile number
         mov       x,tmp               ' Get ...
         mov       y,tmp               ' ... X ...
         and       y,#$FF              ' ... and ...
         shr       x,#8                ' ... ...
         and       x,#$FF              ' ... Y
         
doSETCUE shl       y,#6                ' *64 bytes per row
         shl       x,#1                ' *2 bytes per column
         add       y,x                 ' Y points ...
         add       y,C_SCRMEM          ' ... to map address        
                           
         wrword    width,y             ' Change the map
         jmp       #final              ' Done

' --------------------------------------------------------------------------------
' [01010] GETTILE x,y,Vn
'   1_111_0bbb____00_0_01010__xxxxxxxx_yyyyyyyy
'   00000000_00000000_00000000_vvvvvvvv 
' [01010] GETTILE Vn
'   1_bbb_0000____00_1_01010__00000000_vvvvvvvv
' 
doGETTILE
         cmp       i,#0 wz             ' User variables?
    if_z jmp       #doGTTcn            ' No ... go parse constants

         and       tmp,#$FF            ' Get 1st variable
         call      #fetchVar           ' Lookup ...
         mov       x,data1             ' ... X
         call      #fetchVar           ' Lookup ...
         mov       y,data1             ' ... Y         
         mov       t2,tmp              ' Variable number
         jmp       #doGETCUE           ' Skip constants
         
doGTTcn  rdlong    t2,boxDat1Ret       ' Second word ...
         mov       x,tmp               ' Get ...
         mov       y,tmp               ' ... X ...
         and       y,#$FF              ' ... and ...
         shr       x,#8                ' ... ...
         and       x,#$FF              ' ... Y
         
doGETCUE shl       y,#6                ' *64 bytes per row
         shl       x,#1                ' *2 bytes per column
         add       y,x                 ' Y points ...
         add       y,C_SCRMEM          ' ... to map address
         rdword    tmp,y               ' Read the map
         call      #storeVar           ' Store the variable
         jmp       #final              ' Done

' --------------------------------------------------------------------------------
' --------------------------------------------------------------------------------
         
' --------------------------------------------------------------------------------
' Print a character in tmp handling backspace, LF, and scrolling
'
prChar   cmp       tmp,#10 wz              ' Handle ...
    if_z jmp       #printCharLF            ' ... LF
         cmp       tmp,#8 wz               ' Handle ...
    if_z jmp       #printCharBS            ' ... backspace
         rdword    data1,textCursor        ' Preserve ...
         and       data1,C_F000            ' ... the ...
         and       tmp,C_FFF               ' ... existing ...
         or        tmp,data1               ' ... colorset
         wrword    tmp,textCursor          ' Write character to screen
         add       textCursor,#2           ' Bump the cursor
         cmp       textCursor,C_SCRNOV wz  ' Scroll the screen ...
    if_z call      #printCharSC            ' ... if needed
prChar_ret
         ret     
          
printCharLF                                
         mov       ofs,textCursor          ' Get relative ...
         sub       ofs,C_SCRMEM            ' ... screen pointer
         shr       ofs,#1                  ' Two bytes per entry
         and       ofs,#31                 ' ofs = X pos on row
         mov       com,#32                 ' Number of spaces ...
         sub       com,ofs                 ' ... to print to next row              
prLF1    wrword    tileA,textCursor        ' Write background
         add       textCursor,#2           ' Bump cursor
         cmp       textCursor,C_SCRNOV wz  ' Scroll ...
    if_z call      #printCharSC            ' ... if needed
         djnz      com,#prLF1              ' Move to next row
         jmp       #prChar_ret             ' Return
         
printCharBS
         cmp       textCursor,C_SCRMEM wz  ' Ignore if already ...
    if_z jmp       #prChar_ret             ' ... at top of screen
         sub       textCursor,#2           ' Back up one character
         wrword    tileA,textCursor        ' Erase what's there
         jmp       #prChar_ret             ' Return

' --------------------------------------------------------------------------------
' Scrolls the screen
'
printCharSC         
         mov       data1,C_SCRMEM      ' Destination
         mov       data2,C_SCRMEM
         add       data2,#32*2          ' Source
         mov       data3,C_SCRNSC      ' Longs to move 
doPRSC1  rdlong    data4,data2         ' Move ...
         add       data2,#4            ' ... characters ...
         wrlong    data4,data1         ' ... up ....
         add       data1,#4            ' ... one row
         djnz      data3,#doPRSC1      ' Do all characters
         mov       data3,#16           ' 32 characters (16 pairs) on bottom row
         mov       t3,tileA
         shl       t3,#16
         add       t3,tileA
doPRSC2  wrlong    t3,data1             ' Erase ...
         add       data1,#4            ' ... bottom ...
         djnz      data3,#doPRSC2      ' ... row
         sub       textCursor,#32*2    ' Reset cursor to 1st on bottom row
printCharSC_ret
         ret 

' ----------------------------------------------------------
' This function fetches the value of a given variable
'   tmp holds the variable number
' Returns
'   data1 returns the variable's value
'   tmp is automatically incremented for next fetch
'
fetchVar
         mov       box,#1
         mov       cStat,C_VARLK
         mov       data1,tmp
         call      #cogTalk
         add       tmp,#1
fetchVar_ret
         ret

'-----------------------------------------------------------
' This function stores a value in a given variable
'   t2 the variable
'   tmp the value
' Returns
'   t2 is automatically incremented for the next fetch
'
storeVar
         mov       cStat,C_VARST       ' Command to store variable
         mov       data1,t2            ' Destination ...         
         shl       data1,#24           ' ... variable
         mov       data2,tmp           ' Large value
         mov       box,#1              ' Variable COG
         call      #cogTalk            ' Store variable
         add       t2,#1  
storeVar_ret
         ret
         
' ----------------------------------------------------------
' This function sends a command to the requested cog
' and waits for the reply.
'   cStat        - command to send
'   data1-data5  - data words
'   ofs          - offset value
' Returns
'   cStat        - status
'   data1        - return value
'
cogTalk 
       mov         ptr,box             ' 32 bytes ...
       shl         ptr,#5              ' ... per box                   
       add         ptr,baseBox         ' Point to target box
       add         ptr,#4              ' Save command for last
cogTalk1
       lockset     box wc              ' Get the lock ... 
 if_nc jmp         #cogTalk1           ' ... on the mailbox  
       wrlong      data1,ptr           ' Write the data
       add         ptr,#4
       wrlong      data2,ptr
       add         ptr,#4
       wrlong      data3,ptr
       add         ptr,#4
       wrlong      data4,ptr
       'add         ptr,#4
       'wrlong      data5,ptr
       'add         ptr,#4
       'wrlong      data6,ptr
       add         ptr,#4*3
       wrlong      ofs,ptr             ' Write the offset
       sub         ptr,#7*4            ' Back to command now
       wrlong      cStat,ptr           ' Write the command
cogTalk2
       rdlong      com,ptr             ' Wait for ...
       shl         com,#1 nr, wc       ' ... status bit to ...
 if_c  jmp         #cogTalk2           ' clear out
       add         ptr,#4              ' Read the ...
       rdlong      data1,ptr           ' ... return value
       lockclr     box                 ' Release our lock
cogTalk_ret
       ret

cursorBlink
        sub        curCnt,#1 wz
  if_nz jmp        #cursorBlink_ret
        mov        curCnt,curRate
        rdbyte     data1,textCursor
        cmp        data1,tileA wz
  if_z  wrbyte     tileB,textCursor
  if_nz wrbyte     tileA,textCursor
cursorBlink_ret
        ret     

' ----------------------------
' Mailbox parameters to send in COGTALK
box        long    0
cStat      long    0
data1      long    0
data2      long    0
data3      long    0
data4      long    0
'data5     long     0
'data6     long     0
ofs        long    0
' ----------------------------

baseBox    long    MailboxMemory  ' The base of all boxes   

tmp        long    0
com        long    0
i          long    0
val        long    0
ptr        long    0
count      long    0
x          long    0
y          long    0
width      long    0
height     long    0  
t2         long    0
t3         long    0
p          long    0

tileA      long    CursorTileA         ' Two tiles swapped to blink the ...
tileB      long    CursorTileB         ' ... text cursor when taking user input

curRate    long    CursorBlinkRate     ' Blink rate of the cursor
curCnt     long    CursorBlinkRate     ' Cursor blink counter
                   
textCursor long    ScreenMap        ' Current text cursor (pointer into tile-map memory)

C_8000     long    $8000
C_FFFF     long    $FFFF
C_FFF      long    $FFF
C_F000     long    $F000    
 
C_SCRNOV   long    32*26*2+ScreenMap    ' Screen map + 1 entry (overflow check)
C_SCRNSC   long    25*32/2                 ' Character pairs (longs) to scroll (screen minus one row)

' VariableCOG command for variable-lookup
C_VARLK    long    VariableGetCommand

' VariableCOG command for variable-set
C_VARST    long    VariableSetCommand

' VariableCOG command for reading next key
C_KEYLKA   long    VariableGetKeyCommandA
C_KEYLKB   long    VariableGetKeyCommandB

C_SCRMEM   long    ScreenMap          ' Where the tile map is stored
C_TILEMEM  long    TileMemory            ' Where

C_SCRATCH  long    ScratchMemory         ' 16 byte scratch area used by "getNumber" function                        
C_DBRN     long    DisplayBeamRowNumber  ' Filled in by the TV8x8 ... current row being drawn

' Our mailbox
boxComStat long    MailboxMemory + VideoBoxNumber*32
boxDat1Ret long    MailboxMemory + VideoBoxNumber*32 +4
boxDat2    long    MailboxMemory + VideoBoxNumber*32 +8
boxDat3    long    MailboxMemory + VideoBoxNumber*32 +12
boxDat4    long    MailboxMemory + VideoBoxNumber*32 +16
'boxDat5   long     MailboxMemory + VideoBoxNumber*32 +20
'boxDat6   long     MailboxMemory + VideoBoxNumber*32 +24
boxOfs     long    MailboxMemory + VideoBoxNumber*32 +28

    fit  ' Must fit under COG [$1F0] 