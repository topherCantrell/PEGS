CON

' This include file is pasted into the top of every SPIN file

' ==================================================  
' Numeric constants
' ==================================================

DebugPin = $08_00_00_00

RandomSeedStart = $00_B4_F0_1A

DiskBoxNumber = 0
DiskCOGNumber = 3

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
  
  coginit(SpriteCOGNumber,@SpriteDriver,0)

DAT      
         org 0

SpriteDriver

' The sprite driver writes to memory clearing out the overlay rows. We
' have to make sure the initial data has been moved from there before
' overwriting. We will wait for the VideoCOG to start.

' The DisplayBeamRowNumber controls all the action. The video driver sets it to the
' the row it is currently displaying. We stay in sync preparing the next row while
' it draws the last row we prepared.
'
' When the DisplayBeamRowNumber goes to 207, the last row is being drawn and the
' vertical retrace is about to begin. This signals the sprite engine to do all
' the sprite moving and flipping.
'
' When the sprite engine is done moving and flipping, it sets the DisplayBeamRowNumber
' to 250. This signals others that nobody is reading/writing the sprite data and it is
' safe to update the data. On the next-to-the-last invisbile blank-line at the top of the
' screen the display engine sets the DisplayBeamRowNumber to 254 as a warning that
' the update period is ending.
'
' External updaters should watch DisplayBeamRowNumber and quickly update their data
' when the value is 250.

stall    rdlong    tmp,boxComStat wz   ' On startup, wait for ...         
   if_z  jmp       #stall              ' ... the start signal     

main                       
         rdbyte  draw,dbrn                     ' This is the row the display is drawing

         cmp     draw,#255 wz                  ' This means the display is ...
  if_z   mov     draw,#0                       ' ... getting ready to draw ...
  if_z   jmp     #drawRow                      ' ... row zero

         cmp     draw,#254 wz                  ' This gives the outside ...
  if_z   jmp     #main                         ' ... world a brief ...
         cmp     draw,#250 wz                  ' ... moment to update ...
  if_z   jmp     #main                         ' ... the sprite data safely
         
         add     draw,#1                       ' We are one row ahead          

         cmp     draw,#208 wz                  ' Is the display drawing the last row?
  if_ne  jmp     #drawRow                      ' No ... get the next row ready


' --------------------------------------------------------------------------------------
' This is the vertical retrace. Lots of time to handle automatic features like
' sprite flipping and scripted motion.
                                                
         mov       spritePtr,#SpriteTable         ' Sprite 0
         mov       spriteCount,#NumSprites        ' 16 sprites to process
         
motionLoop

         rdword    spriteY,spritePtr
         cmp       spriteY,C_FFFF wz
  if_z   jmp       #skipMotion

' Read all the data from the descriptor. We'll change stuff and write it back later
         add       spritePtr,#2
         rdword    spriteX,spritePtr
         add       spritePtr,#2
         rdword    spritePic,spritePtr
         add       spritePtr,#2
         mov       simple,spritePic     
         rdbyte    spriteInfo,spritePtr
         add       spritePtr,#1
         shr       simple,#15
         rdbyte    xDelta,spritePtr
         add       spritePtr,#1
         mov       yDelta,xDelta
         shr       xDelta,#4
         and       yDelta,#15             
         rdbyte    xDelay,spritePtr
         add       spritePtr,#1
         rdbyte    yDelay,spritePtr
         add       spritePtr,#1
         rdbyte    xCount,spritePtr
         add       spritePtr,#1
         rdbyte    yCount,spritePtr
         add       spritePtr,#1
         rdbyte    spriteFlipTimer,spritePtr
         add       spritePtr,#1
         rdbyte    actionScriptTimer,spritePtr
         add       spritePtr,#1
         rdword    actionScriptPtr,spritePtr   

         mov       tmp3,spriteInfo             ' tmp3 contains ...
         shr       tmp3,#2                     ' ... number of images ...
         and       tmp3,#3 wz                  ' ... in flip-set

    if_z jmp       #noSpriteFlipping            ' Just the one ... no flipping

' --------------------------------------------------------------------------------------
' Automatic sprite flipping feature

         mov       spriteWidth,spriteInfo
         mov       spriteHeight,spriteWidth
         shr       spriteWidth,#6
         shr       spriteHeight,#4
         and       spriteHeight,#3 
         
         mov       ptr,#1           ' One 8x8 cell is 1 image slot
         shl       ptr,spriteWidth  ' Multiply by width         
         shl       ptr,spriteHeight ' Multiply by height    
         
         cmp       simple,#1 wz                 ' Complex sprites ...
   if_nz shl       ptr,#1            ' ... comsume twice the space (mask and image)   

         mov       loopsPerRow,spriteFlipTimer  ' Separate out ...
         and       loopsPerRow,#3               ' ... WW, VV, and UU fields
         mov       orHoldA,spriteFlipTimer      '
         shr       orHoldA,#2                   '
         and       orHoldA,#3                   '
         mov       orHoldB,spriteFlipTimer      '
         shr       orHoldB,#4                   '
         and       orHoldB,#3                   '
         
         sub       loopsPerRow,#1 wc            ' Count down the WW field
  if_nc  jmp       #flipDone                    ' Not time if it didn't underflow
         mov       loopsPerRow,#3               ' Reload the WW field
         sub       orHoldA,#1 wc                ' Count down the VV field (delay)
  if_nc  jmp       #flipDone                    ' Not time if it didn't underflow
         mov       orHoldA,spriteInfo           ' Reload from ...
         and       orHoldA,#3                   ' ... DD in sprite-info
         add       spritePic,ptr                ' Bump up to the next picture
         sub       orHoldB,#1 wc                ' Count down the UU field (num pics)
  if_nc  jmp       #flipDone                    ' Not time if it didn't underflow
         mov       orHoldB,spriteInfo           ' Reload from ...
         shr       orHoldB,#2                   ' ... PP in ...
         and       orHoldB,#3                   ' ... sprite info
         mov       tmp,orHoldB                  ' Number of pics to backup
         add       tmp,#1                       ' 3 means 4 pics ... add one
flipBack sub       spritePic,ptr                ' Backup ...
         djnz      tmp,#flipBack                ' ... sprite picture

flipDone shl       orHoldA,#2                    ' Recombine fields ...
         or        loopsPerRow,orHoldA           ' ... WW ...
         shl       orHoldB,#4                    ' ... VV ...
         or        loopsPerRow,orHoldB           ' ... and UU ...
         mov       spriteFlipTimer,loopsPerRow   ' ... into spriteFlipTimer

noSpriteFlipping

' --------------------------------------------------------------------------------------
' Automatic motion feature

         mov     orHoldA,#0                     ' Flag that motion was NOT made
         
         cmp     xCount,#0 wz
    if_z jmp     #doY
         sub     xCount,#1 wz
  if_nz  jmp     #doY
         and     xDelta,#%00001000 wz,nr
  if_nz  or      xDelta,C_SIGN_EXTEND
         mov     xCount,xDelay
         add     spriteX,xDelta
         or      orHoldA,#1                     ' Motion was made
         cmp     spriteX,#320 wz,wc
   if_ae mov     spriteY,C_FFFF 

  doY
         cmp     yCount,#0 wz
    if_z jmp     #doActionScript
         sub     yCount,#1 wz
  if_nz  jmp     #doActionScript
         and     yDelta,#%00001000 wz,nr
  if_nz  or      yDelta,C_SIGN_EXTEND
         mov     yCount,yDelay
         add     spriteY,yDelta
         or      orHoldA,#1                     ' Motion was made
         cmp     spriteY,#272 wz,wc
 if_ae   mov     spriteY,C_FFFF    

doActionScript

' --------------------------------------------------------------------------------------
' Action scripting feature

        cmp      orHoldA,#1 wz       ' No motion ...
 if_nz  jmp      #doWrite            ' ... nothing to do in script

' The sprite engine has no concept of sectors. The action script must be offset into the 
' desired cluster by the SETSPRITE command. But, we know that we are dealing with even
' 2K clusters ... we'll use a 0 offset within a cluster to mean no script. 

        and      actionScriptPtr,C_7FF wz,nr  
 if_z   jmp      #doWrite        
        sub      actionScriptTimer,#1 wz
 if_nz  jmp      #doWrite

doActionCommand        
        rdbyte   tmp,actionScriptPtr
        add      actionScriptPtr,#1
        cmp      tmp,#0 wz              ' 0 = short command
 if_z   jmp      #actionScriptShort
        cmp      tmp,#1 wz              ' 1 = long command
 if_z   jmp      #actionScriptLong
        cmp      tmp,#2 wz              ' 2 = jump
 if_z   jmp      #actionScriptJump

        mov      actionScriptPtr,#0
        jmp      #doWrite

actionScriptLong

' 1, spritePicLSB, spritePicMSB, spriteInfo, spriteFlipTimer, then on to 0

        rdbyte   spritePic,actionScriptPtr
        add      actionScriptPtr,#1
        rdbyte   tmp,actionScriptPtr
        add      actionScriptPtr,#1
        shl      tmp,#8
        or       spritePic,tmp
        rdbyte   spriteInfo,actionScriptPtr
        add      actionScriptPtr,#1
        rdbyte   spriteFlipTimer,actionScriptPtr
        add      actionScriptPtr,#1
        
actionScriptShort

' 0, xyDelta, xDelay (and xCount), yDelay (and yCount), actionScriptTimer
 
        rdbyte   xDelta,actionScriptPtr
        add      actionScriptPtr,#1
        mov      yDelta,xDelta
        shr      xDelta,#4
        and      yDelta,#15
        rdbyte   xDelay,actionScriptPtr
        add      actionScriptPtr,#1
        rdbyte   yDelay,actionScriptPtr
        add      actionScriptPtr,#1
        mov      xCount,xDelay
        mov      yCount,yDelay
        rdbyte   actionScriptTimer,actionScriptPtr
        add      actionScriptPtr,#1        
        jmp      #doWrite
        
actionScriptJump

' 2, offset from current position

        rdbyte   tmp,actionScriptPtr
        add      actionScriptPtr,#1
        rdbyte   tmp2,actionScriptPtr
        add      actionScriptPtr,#1
        shl      tmp2,#8
        or       tmp,tmp2
        and      tmp,C_8000 nr,wz
 if_nz  or       tmp,C_SIGN_EXTEND2
        add      actionScriptPtr,tmp
        jmp      #doActionCommand

' --------------------------------------------------------------------------------------
' Write the changes we made in automatic features back
' to the descriptor
'
doWrite  wrword    actionScriptPtr,spritePtr
         sub       spritePtr,#1
         wrbyte    actionScriptTimer,spritePtr
         sub       spritePtr,#1
         wrbyte    spriteFlipTimer,spritePtr
         sub       spritePtr,#1
         wrbyte    yCount,spritePtr
         sub       spritePtr,#1
         wrbyte    xCount,spritePtr
         sub       spritePtr,#1
         wrbyte    yDelay,spritePtr
         sub       spritePtr,#1
         wrbyte    xDelay,spritePtr
         sub       spritePtr,#1
         shl       xDelta,#4
         and       yDelta,#15
         or        xDelta,yDelta         
         wrbyte    xDelta,spritePtr
         sub       spritePtr,#1
         wrbyte    spriteInfo,spritePtr
         sub       spritePtr,#2
         wrword    spritePic,spritePtr
         sub       spritePtr,#2
         wrword    spriteX,spritePtr
         sub       spritePtr,#2
         wrword    spriteY,spritePtr  
         
skipMotion
         andn      spritePtr,#$000F           ' Point to ...
         add       spritePtr,#$10             ' ... next sprite
         djnz      spriteCount,#motionLoop    ' Do all sprites ... pray there is time


         mov       draw,#250                  ' Free up the sprite data ...
         wrbyte    draw,dbrn                  ' ... for external writers
         
         jmp       #main                      ' Back to the top

' --------------------------------------------------------------------------------------
' This happens every row
' --------------------------------------------------------------------------------------
' Draw the sprites on the current row       
' (As fast as possible ... we are chasing the TV beam.)
         
drawRow  mov       fillAreaHold,#SorOddMask      ' Assume odd row         
         and       draw,#1 nr,wz                 ' But if this is even ...    
   if_z  mov       fillAreaHold,#SorEvenMask     ' ... use the even row
         mov       fillArea2Hold,fillAreaHold    ' Pointer to the ...
         add       fillArea2Hold,#$80            ' ... correct image row
                
' Clear out the mask and image buffers before adding the individual sprites        
         mov       ptr,fillAreaHold                
         mov       count,#$10
         mov       spriteY,#0         
clear1   wrlong    spriteY,ptr
         add       ptr,#4
         djnz      count,#clear1
         mov       ptr,fillArea2Hold                 
         mov       count,#$10
         mov       spriteY,#0         
clear2   wrlong    spriteY,ptr
         add       ptr,#4
         djnz      count,#clear2                                                  
          
         mov       spritePtr,#SpriteTable        ' Start of sprite data
         mov       spriteCount,#NumSprites       ' Number of sprites
          
spriteLoop   

' Get the sprite's Y coordinate
         rdword    spriteY,spritePtr             ' Get the Y coordinate
         cmp       spriteY,C_FFFF wz             ' FFFF means ...
  if_z   jmp       #skipMe                       ' ... inactive
         add       spritePtr,#2                  ' Next data item

' Get the sprite's X coordinate.
         rdword    spriteX,spritePtr             ' Get the X coordinate
         add       spritePtr,#2                  ' Next data item

' Get the image number.
         rdword    spriteMsk,spritePtr           ' Get the image number
         add       spritePtr,#2                  ' Next data item
         mov       simple,spriteMsk              ' Simple ...
         shr       simple,#15                    ' ... flag         
         and       spriteMsk,C_FFF               ' Image without mask         
         
' Get the sprite geometry
         rdbyte    spriteWidth,spritePtr         ' Sprite geometry
                  
         mov       spriteHeight,spriteWidth      ' Peel out ...
         shr       spriteWidth,#6                ' ... width
         shr       spriteHeight,#4               ' Peel out ...
         and       spriteHeight,#3               ' ... height

         mov       pixelHeight,#8                ' Base cell is 8 high
         shl       pixelHeight,spriteHeight      ' 0=8, 1=16, 2=32, 3=64

         mov       bytesPerSprite,#16            ' One 8x8 cell is 16 bytes
         shl       bytesPerSprite,spriteWidth    ' Multiply by width         
         shl       bytesPerSprite,spriteHeight   ' Multiply by height

         mov       loopsPerRow,#1                ' One 8x8 cell takes one loop
         shl       loopsPerRow,spriteWidth       ' Multiply by width    
         
' Sprites are offset by 32 so that Y=0 can be off the top of the screen.
         sub       spriteY,#32                   ' Translate sprite coords to screen coords

' We need to know which row of the sprite-picture maps to the current
' drawing row. The current sprite may not even appear on the current
' drawing row ... we'll find that out as we go.
   
         mov       spriteRow,draw                ' Row being drawn on the screen
         sub       spriteRow,spriteY             ' Skip this sprite if ...
         cmp       spriteRow,pixelHeight wz,wc   ' ... it doesn't appear ...           
  if_ae  jmp       #skipMe                       ' ... on this row

' Locate the mask/image data.         
         shl       spriteMsk,#4                  ' 16 bytes per tile
         add       spriteMsk,TileImageMemory     ' Start of image data to spriteMsk

         shl       spriteRow,#1                  ' One 8x8 cell is 2 bytes per row
         shl       spriteRow,spriteWidth         ' Multiply by width
         add       spriteMsk,spriteRow           ' Offset to current row
         
         mov       spritePic,spriteMsk           ' Image data is ...
         cmp       simple,#1 wz                  ' ... later if ...
  if_nz  add       spritePic,bytesPerSprite      ' ... sprite is complex

         mov       orHoldA,#0                    ' Clear leftovers ...
         mov       orHoldB,#0                    ' ... along a single row

multiSprite          
         mov       fillArea,fillAreaHold         ' Reset after ...
         mov       fillArea2,fillArea2Hold       ' ... each sprite's contribution

         mov       tmp,#0                        ' Simple mask is "ignore-background"
         cmp       simple,#1                     ' But if complex ...
   if_nz rdword    tmp,spriteMsk                 ' ... load the mask
         add       spriteMsk,#2                  ' Bump the mask pointer
         rdword    tmp2,spritePic                ' Get the next image bits
         add       spritePic,#2                  ' Bump the image pointer

' Find the byte offset in within the row (4 pixels per byte)
' Like Y, X is offset by 32 to make X=0 off the screen to the left
         mov       xofs,spriteX                  ' Xofs = ...         
         shr       xofs,#2                       ' ... (x/4)-8 ...
         sub       xofs,#8                       ' ...

' Calculate the shift remainder
         mov       srem,spriteX                  ' Srem = ...
         and       srem,#3                       ' ... (x%4) * 2 ...
         shl       srem,#1                       ' ...

' At this point:
'   tmp       = mask
'   tmp2      = image bits
'   xofs      = byte address within row
'   srem      = shift amount for mask/image
'   fillArea  = pointer to start of mask row
'   fillArea2 = pointer to start of image row

' An 8x8 cell (we handle one 8x8 each pass here) is 16 bits which
' could roll into 3 bytes at most.

         add       fillArea,xofs                 ' May be off screen
         add       fillArea2,xofs                ' Image too
         shl       tmp,srem                      ' Proper bit ...
         shl       tmp2,srem                     ' ... alignment

' Byte 1
         'shr       tmp,#8                       ' Next byte in mask
         'shr       tmp2,#8                      ' Next byte in image
         'add       xofs,#1                      ' Next byte on row
         'add       fillArea,#1                  ' Next pointer in mask row
         'add       fillArea2,#1                 ' Next pointer in image row
         
         cmp       xofs,#63 wz,wc                ' It this byte out of the row?
  if_a   jmp       #byte2                        ' Yes ... ignore this byte

         or        tmp,orHoldA                   ' Pull in any pixels ...
         or        tmp2,orHoldB                  ' ... from the last 8x8 cell pass
    
         wrbyte    tmp,fillArea                  ' Store mask
         rdbyte    a,fillArea2                   ' OR the image bits ...
         or        a,tmp2                        ' ... (not a complete overlap
         wrbyte    a,fillArea2                   ' ... solution)

' Byte 2
byte2       shr       tmp,#8             
            shr       tmp2,#8             
            add       xofs,#1             
            add       fillArea,#1         
            add       fillArea2,#1        
            cmp       xofs,#63 wz,wc
     if_a   jmp       #byte3              
            wrbyte    tmp,fillArea
            rdbyte    a,fillArea2
            or        a,tmp2
            wrbyte    a,fillArea2

' Byte 3
byte3       shr       tmp,#8              
            shr       tmp2,#8             
            add       xofs,#1             
            add       fillArea,#1         
            add       fillArea2,#1        
            cmp       xofs,#63 wz,wc      
     if_a   jmp       #nextMulti          
            wrbyte    tmp,fillArea
            rdbyte    a,fillArea2
            or        a,tmp2
            wrbyte    a,fillArea2

         mov       orHoldA,tmp                   ' Leftover mask for next chunk
         mov       orHoldB,tmp2                  ' Leftover image for next chunk

nextMulti
         add       spriteX,#8                    ' Slide right 8 pixels for next chunk
         djnz      loopsPerRow,#multiSprite      ' Do all chunks for this sprite
  
skipMe   andn      spritePtr,#$000F              ' Point to ...
         add       spritePtr,#$10                ' ... next sprite
         djnz      spriteCount,#spriteLoop       ' Do all sprites ... pray there is time
         
' Wait for the display to start using the row we filled in before we
' start building another row.
waitOnNextRow
         rdbyte  spriteY,dbrn                    ' Wait for the display to ...
         cmp     spriteY,draw wc,wz              ' ... get to our data ...
  if_ne  jmp     #waitOnNextRow                  ' ... before starting more     

         jmp     #main                           ' Line after line after line
                  
a                  long 0
draw               long 0
fillArea           long 0
fillArea2          long 0
fillAreaHold       long 0
fillArea2Hold      long 0
ptr                long 0
count              long 0
spriteY            long 0
spriteX            long 0
spriteRow          long 0    

spriteCount        long 0
spritePtr          long 0

tmp                long 0
tmp2               long 0
tmp3               long 0    
spriteMsk          long 0
spritePic          long 0
spriteWidth        long 0
spriteHeight       long 0
pixelHeight        long 0
bytesPerSprite     long 0
loopsPerRow        long 0

orHoldA            long 0
orHoldB            long 0

xDelta             long 0
yDelta             long 0
xDelay             long 0
yDelay             long 0
xCount             long 0
yCount             long 0

spriteFlipTimer    long 0
actionScriptTimer  long 0
actionScriptPtr    long 0
spriteInfo         long 0

srem               long 0
xofs               long 0
simple             long 0


C_FFF              long $FFF
C_7FF              long $7FF
C_8000             long $00_00_80_00
C_FFFF             long $FFFF
C_SIGN_EXTEND      long $FF_FF_FF_F0
C_SIGN_EXTEND2     long $FF_FF_00_00

TileImageMemory    long TileMemory
dbrn               long DisplayBeamRowNumber

' VideoCOG's box (we will wait for it to clear before starting)
boxComStat         long MailboxMemory + VideoBoxNumber*32           

    fit        ' Must fit un