' -------------------------------------------------------------------------------
''TV8x8.spin
'' 
'' Copyright (C) Chris Cantrell October 11, 2008
'' Part of the PEGS project (PEGSKIT.com)
'' Based extensively on the Parllax driver:
''    TV Driver v1.1
''    (C) 2004 Parallax, Inc.
''
''##### SCREEN MAP #####
''
'' The TV8x8 driver generates a background from a map of 8x8 pixel tiles.
'' The map itself is 32x26 tiles. Each entry is 2 bytes. Thus the screen map
'' consumes 32*26*2 = 1664 bytes from 0380-0BFF. Each entry in the map has
'' the following format:
''   cccc_tttttttttttt
''     c is the color-scheme (0-15)
''     t is the tile number  
''
''##### TILE MEMORY #####
''
'' Tiles are 16 bytes each (8x8 pixels with 4 pixels per byte) beginning
'' right after the screen map at 0A00. Three 2K pages are reserved for the
'' screen at startup from 0000-17FF. Thus 0A00-17FF is 224 tiles. Extra
'' pagess can be reserved as needed for more image space. An extra 2K page
'' adds 128 more tile images.
''
''##### COLOR SETS #####
'' 
'' Color sets are loaded from memory 7F70-7FAF. Each set is four bytes, one
'' byte for each of four possible pixel colors. Changing the color immediately
'' changes the color of the tiles on the screen. Note color sets apply to TWO
'' 8x8 tiles. An odd numbered map entry uses the same color set as the even
'' numbered entry to its left.
''
''##### SPRITES #####
''
'' The TV8x8 driver works with one or two sprite generators. These sprite
'' generators stay one scan line ahead of the TV driver producing a single line
'' of pixel information to be drawn over the background.
''
'' Sprite pixel information includes a MASK to AND with the existing background
'' and an IMAGE to OR with the existing background. There are two sets of
'' MASK/IMAGE rows ... one that the TV driver reads and one that the sprite
'' generators fill.
''
'' There are two sets of sprite data allowing two generators to work on sprites
'' at the same time thus greatly increasing the number of sprites that can appear
'' on the same row.
''
'' Each MASK/IMAGE row is 80 bytes long. The first 8 bytes hold 32 pixels of data
'' for sprites that are off the screen to the left. The last 8 bytes hold 32
'' pixels of data off the screen to the right. Only the center 64 bytes is read by
'' the TV driver. This allows the sprite generators to quickly draw sprites that
'' drift on and off the screen along the sides.
''
'' In summary, there are 2 sets of sprite overlay data. Each set includes 2 MASK
'' and 2 IMAGE rows. Each row is 80 bytes long. 2*(2+2)*80 = 640 bytes at
'' memory 0100-037F. (The sprite table occupies 0000-00FF).
''
''##### Y OFFSET #####
''
'' The TV driver maintains a Y offset value allowing the screen to be scrolled
'' up or down by single pixel rows. The offset value at 7F68-7F69 defaults to
'' zero. Changing the value to 1 moves the entire display up row. Note that this
'' forces the driver to look beyond the normal screen map to get the entries for
'' the bottom row. Thus the first part of tile memory will be interpreted as an
'' extended screen map. This screen/tile mapping depends on how far the program
'' advances the Y offset. Careful planning of tile/map data is essential.
''
''##### SCROLL SCRIPTING #####
''
'' The TV driver processes a scrolling script after every screen refresh (60
'' times a second). This allows the application to set up a complex scrolling
'' strategy that is handled automatically by the driver ... no need for the
'' application to be involved.
''
'' The script pointer at 7F6A-7F6B points to the current script command (or
'' 0000 if no script is running). Scroll script commands are words as follows:
''
''   0001_ssssssssssss     GOTO +/- s (s is in WORDS) and do next
''   0010_bbbbbbbbbbbb     Set yOffset to b and do next
''   0011_ssssssssssss     Set yDelta to +/- s and do next
''   0100_wwwwwwwwwwww     Set the waitcount to w and do next
''   0101_nnnnnnnnnnnn     Set the scriptcount to n AND LOOP DESCRIBED BELOW
''
'' - At every refresh, the waitcount is decremented.
'' - When the waitcount reaches zero, the yDelta is added to the current yOffset
''   and the scriptcount is decremented
'' - When the scriptcount reaches zero, the next command script command is loaded
''
''##### HARDWARE #####
''
'' The Propeller hooks to the TV video as follows:
'' (taken from the Parallax Demo Board schematics)
''
''         R12 270Ω
'' P26 ────────────┳────────  TV Video
''                    │     ┌──
''        R13 560Ω    │     
'' P25 ────────────┫
''                    │
''        R14 1.1KΩ   │
'' P24 ────────────┘

' TODO
' - Version that handles horizontal scrolling  (add scrolling-script commmands)
' - Version that handles indirect-tile-pointers (flip-script?)

CON

  fntsc         = 3_579_545     'NTSC color frequency
  lntsc         = 3640          'NTSC color cycles per line * 16
  sntsc         = 624           'NTSC color cycles per sync * 16     
  
  colortable    = $180          'start of colortable inside cog (180-1BF = 16 color sets)  
  
PUB start(cogNumber,parameterBlock)
'' Start the TV8x8 driver
coginit(cogNumber,@entry,parameterBlock) 
   
DAT   

         org

'
' Entry
'
entry    mov       t1,par
         rdword    _screen,t1              ' Tile-map memory (word aligned)
         add       t1,#2                            
         rdword    _tileMemory,t1          ' Tile-image memory (word aligned)
         add       t1,#2
         rdword    _colors,t1              ' Color table in memory (long aligned)
         add       t1,#2
         rdword    CSorEvenMaskDriverA,t1  ' Start of dual sprite-overlay-memory (word aligned)
         add       t1,#2
         mov       yOffsetMem,t1           ' Address of yOffset
         add       t1,#2
         mov       scriptPtrMem,t1         ' Address of script pointer
         add       t1,#2
         mov       overlayRowNum,t1        ' Address of DisplayBeamRowNumber
         add       t1,#2
         mov       C_RETCNT,t1             ' Address of RetraceCounter
                                   
         ' Sprite-overlay locations
         add       CSorEvenMaskDriverA,#8
         mov       CSorOddMaskDriverA,CSorEvenMaskDriverA
         add       CSorOddMaskDriverA,#$50
         mov       CSorEvenImageDriverA,CSorOddMaskDriverA
         add       CSorEvenImageDriverA,#$50
         mov       CSorOddImageDriverA,CSorEvenImageDriverA
         add       CSorOddImageDriverA,#$50
         mov       CSorEvenMaskDriverB,CSorOddImageDriverA
         add       CSorEvenMaskDriverB,#$50
         mov       CSorOddMaskDriverB,CSorEvenMaskDriverB
         add       CSorOddMaskDriverB,#$50
         mov       CSorEvenImageDriverB,CSorOddMaskDriverB
         add       CSorEvenImageDriverB,#$50
         mov       CSorOddImageDriverB,CSorEvenImageDriverB
         add       CSorOddImageDriverB,#$50
         mov       CSorEvenMaskDriverDoneA,CSorEvenMaskDriverA
         add       CSorEvenMaskDriverDoneA,#64
         mov       CSorOddMaskDriverDoneA,CSorOddMaskDriverA
         add       CSorOddMaskDriverDoneA,#64                        

         ' Hardware parameters
         mov       vcfg,C_VCFG
         mov       dira,C_DIRA
         mov       ctra,C_CTRA
         mov       frqa,C_FRQA                     
                        
'
' Superfield
'
superfield
         mov       taskptr,#tasks      'reset tasks
         mov       phaseflip,phasemask ' set phase flip

         rdword    x,C_RETCNT          ' Bump the ...
         add       x,#1                ' ... vertical retrace ...
         wrword    x,C_RETCNT          ' ... counter 
                        
         mov       x,vinv              'do invisible back porch lines
black    call      #hsync              'do hsync
         waitvid   burst,sync_high2    'do black 
         jmpret    taskret,taskptr     'call task section
         djnz      x,#black            'another black line?
                        
         mov       x,vb                'do visible back porch lines
         sub       x,#2                ' Do all blank lines ...           
         call      #blank_lines        ' ... except last two

         mov       onum,#254           ' Next to last: warn that the ...
         wrbyte    onum,overlayRowNum  ' ... screen is about to be drawn

         mov       x,#1                ' Next to last ...
         call      #blank_lines        ' ... blank line                

         mov       onum,#255           ' Last line: tell sprite engines to ...
         wrbyte    onum,overlayRowNum  ' ... start building first row

         mov       x,#1                ' Last ...
         call      #blank_lines        ' ... blank line

         mov       screen,_screen      ' Point to first tile (upper-leftmost)
         add       screen,yOffsetRows  ' Whole-row offsets           
         and       line,C_0FFFFFFF
         or        line,yOffsetLines     
         mov       y,_vt               ' Number of rows (26*8)         
 
         mov       onum,#0             'Drawing row 0

         ' Reset the sprite overlay row pointers to the beginning of the overlays
         mov       overlayMaskA,CSorEvenMaskDriverA
         mov       ovImageA,CSorEvenImageDriverA
         mov       overlayMaskB,CSorEvenMaskDriverB
         mov       ovImageB,CSorEvenImageDriverB
                                                 
renderLine                   

         wrbyte    onum,overlayRowNum  ' Tell sprite engines which row we are rendering
                        
         call      #hsync              'do hsync

         mov       vscl,hb             'do visible back porch pixels
         xor       tile,colortable
         waitvid   tile,#0

         mov       x,_ht               ' Number of tiles per row (32)
         mov       vscl,hx             ' set horizontal expand                           

doTile 
         rdword    tile,screen         ' Tile value (cccc_nnnnnnnnnnnn)                                    
          or       tile,line           ' Put it in form: r018CPPP                         
          rol      tile,#4             ' tile = tile * 16 + row (rolled from left into right)
         mov       colorHold,tile      ' colorHold is now ...
         shr       colorHold,#16       ' ... 0000_018c (offset to color memory in COG)
          and      tile,C_FFFF         ' Just the PPPr (offset in tile image memory)
          add      tile,_tileMemory    ' Point to 8 pixels (2 bytes)                 
         rdword    pixels,tile         ' Read the data
          movs     a_color,colorHold   ' Pointer used in a moment          
          add       screen,#2          ' 2nd tile
         rdword    tile2,screen        ' Get the pixel data 
          or       tile2,line          '
          rol      tile2,#4            ' (Same process as 1st tile)
         and       tile2,C_FFFF        '
         add       tile2,_tileMemory   '
           add     screen,#2           ' Point to next tile (filling the wait-on-window) 
           mov     tile,phaseflip      ' Phase flip (filling the wait-on-window)
         rdword    pixels2,tile2       '
           shl     pixels2,#16         '
           or      pixels,pixels2      '

' Start sprite overlay                    
         rdlong    omask,overlayMaskA  ' Get next sprite overlay mask LONG (1st set of sprites)                        
          add      overlayMaskA,#4     ' Bump pointer to next LONG
a_color   xor      tile,0              ' Get color (filling the wait-on-window)
         
         rdlong    oimage,ovImageA     ' Get next sprite overlay image LONG (1st set)                    
          add      ovImageA,#4         ' Bump pointer to next LONG
          andn     pixels,omask        ' Mask out pixels  
         
         rdlong    omask,overlayMaskB  ' Get next sprite overlay mask LONG (2nd set of sprites)
          add      overlayMaskB,#4     ' Bump pointer to next LONG  
          or       pixels,oimage       ' Overlay the bits from the 1st set of sprites                  
          
         rdlong    oimage,ovImageB     ' Get next sprite overlay image LONG (2nd set)                     
          add      ovImageB,#4         ' Bump pointer to next LONG       
          andn     pixels,omask        ' Mask out pixels
         or        pixels,oimage       ' Overlay the bits from the 2nd set of sprites                                                                           
' End sprite overlay 
                                                
         waitvid   tile,pixels         ' Shift out the next 16 pixels (2 tiles + sprites) 

         djnz      x,#doTile            ' Do all 32 tiles (16 groups of 2) on this row    

         sub       screen,hc2x         'repoint to first tile in same line           

         mov       vscl,hf             'do visible front porch pixels
         mov       tile,phaseflip      '
         xor       tile,colortable     '
         waitvid   tile,#0             '

         
' Reset the sprite overlay mask and driver pointers when time
         cmp       overlayMaskA,CSorEvenMaskDriverDoneA wz                         
    if_z mov       overlayMaskA,CSorOddMaskDriverA
    if_z mov       ovImageA,CSorOddImageDriverA         
    if_z mov       overlayMaskB,CSorOddMaskDriverB
    if_z mov       ovImageB,CSorOddImageDriverB 

         cmp       overlayMaskA,CSorOddMaskDriverDoneA wz                         
    if_z mov       overlayMaskA,CSorEvenMaskDriverA
    if_z mov       ovImageA,CSorEvenImageDriverA
    if_z mov       overlayMaskB,CSorEvenMaskDriverB
    if_z mov       ovImageB,CSorEvenImageDriverB                   

         add       onum,#1             ' Tell sprite generators to start next row
         
         add       line,lineadd wc     ' Next line in sprite row         
    if_c add       screen,hc2x         ' End of sprite row ... move to next sprite row

         djnz      y,#renderLine       ' Do all 26*8 rows 
                       
         mov       x,vf         
         call      #blank_lines        

         call      #hsync              'if required, do short line
         mov       vscl,hrest          '
         waitvid   burst,sync_high2    '
         
         call      #vsync_high         'do high vsync pulses

         movs      vsync1,#sync_low1   'do low vsync pulses
         movs      vsync2,#sync_low2   '
         call      #vsync_low          '

         call      #vsync_high         'do high vsync pulses

         mov       vscl,hhalf          'if odd frame, do half line
         waitvid   burst,sync_high2

         jmp       #superField         ' Do next frame
         
'
' Blank lines
'
blank_lines
         call      #hsync              'do hsync
         xor       tile,colortable     'do background
         waitvid   tile,#0
         djnz      x,#blank_lines
blank_lines_ret
         ret
         
'
' Horizontal sync
'
hsync
         mov       vscl,sync_scale1    'do hsync       
         mov       tile,phaseflip
         xor       tile,burst
         waitvid   tile,sync_normal
         mov       vscl,hvis           'setup in case blank line
         mov       tile,phaseflip
hsync_ret
         ret
         
'
' Vertical sync
'
vsync_high
         movs      vsync1,#sync_high1      'vertical sync
         movs      vsync2,#sync_high2               
vsync_low
         mov       x,vrep
vsyncx   mov       vscl,sync_scale1
vsync1   waitvid   burst,sync_high1
         mov       vscl,sync_scale2
vsync2   waitvid   burst,sync_high2
         djnz      x,#vsyncx
vsync_low_ret
vsync_high_ret
         ret
         
'
' Tasks - performed in sections during invisible back porch lines
'
tasks                                                               
         ' Calculate yOffsetRows and yOffsetLines from current yOffset.
         ' Do these first and let the auto-scroll affect the next pass.
         ' Gives us the whole screen to process the auto-scroll.

         rdword    yOffsetRows,yOffsetMem
         mov       yOffsetLines,yOffsetRows
         shr       yOffsetRows,#3
         shl       yOffsetRows,yOffsetShifts
         and       yOffsetLines,#7
         shl       yOffsetLines,#28+1

         jmpret    taskptr,taskret          ' Break and return later                  

' Auto-scroll script
         
         rdword    onum,scriptPtrMem wz     ' Get the script pointer
    if_z mov       waitcount,#0             ' Reset
    if_z mov       scriptcount,#0           ' Reset
    if_z jmp       #noScript                ' 0 ... no script     

         cmp       waitcount,#0 wz          ' Waiting for next movement?
  if_nz  sub       waitcount,#1             ' Yes. Decrement the count ...
  if_nz  jmp       #noScript                ' ... and skip motion

         cmp       scriptcount,#0 wz        ' Waiting for next script tick?
  if_z   jmp       #processScript           ' No. Go handle script.   
  
         sub       scriptcount,#1           ' Decrement the script tick         
         rdword    oimage,yOffsetMem        ' Get the current yOffset
         add       oimage,yDelta            ' Change the yOffset
         wrword    oimage,yOffsetMem        ' Write back the new yOffset
         jmp       #noScript                ' Done

processScript
         jmpret    taskptr,taskret          ' Break and return later     
         rdword    omask,onum               ' Get next command
         add       onum,#2                  ' Bump pointer
         mov       oimage,omask             ' For command nibble
         wrword    onum,scriptPtrMem        ' Write the pointer back         
         shr       oimage,#12               ' Get the command
         and       omask,C_FFF              ' Just the constant

         cmp       oimage,#1 wz             ' 1_sss ...
  if_z   jmp       #amGOTO                  ' ... GOTO +/- sss
         cmp       oimage,#2 wz             ' 2_bbb ...
  if_z   jmp       #amYOFF                  ' ... yOffset = bbb
         cmp       oimage,#3 wz             ' 3_sss ...
  if_z   jmp       #amYDEL                  ' ... yDelta = +/- sss
         cmp       oimage,#4 wz             ' 4_www ...
  if_z   jmp       #amCNT                   ' ... waitcount = www

         mov       scriptcount,omask        ' Z_nnn ...
         and       scriptcount,C_FFF        ' ... set scriptcount ...         
         jmp       #noScript                ' ... to nnn

amGOTO   jmpret    taskptr,taskret          ' Break and return later
         and       omask,C_800 nr, wz       ' Sign ...
  if_nz  or        omask,C_FFFFF800         ' ... extend
         shl       omask,#1                 ' Everything is a word
         add       onum,omask               ' Set new ...
         wrword    onum,scriptPtrMem        ' ... script pointer           
         jmp       #processScript           ' Do next script task
         
amYDEL   and       omask,C_800 nr, wz       ' Sign ...
  if_nz  or        omask,C_FFFFF800         ' ... extend
         mov       yDelta,omask             ' Set yDelta  
         jmp       #processScript           ' Out

amCNT    jmpret    taskptr,taskret          ' Break and return later
         mov       waitcount,omask          ' Set ...
         and       scriptcount,C_FFF        ' ... scriptcount
         jmp       #processScript           ' Do next script task
         
amYOFF   jmpret    taskptr,taskret          ' Break and return later
         and       omask,C_FFF              ' Write absolute ...         
         wrword    omask,yOffsetMem         ' ... yOffset
         
noScript          

' Load any changed colors
                   
colors
         jmpret    taskptr,taskret     ' Break and return later

         mov       t1,#8               ' Load next 8 colors into colortable
colorloop
         mov       t2,colorreg         ' 2 passes will get all 16 colors
         shr       t2,#9-2
         and       t2,#$FC
         add       t2,_colors
colorreg
         rdlong    colortable,t2
         add       colorreg,d0
         andn      colorreg,d6
         djnz      t1,#colorloop          
         jmp       #colors             ' Do all colors (last task is repeated through frame)


scriptcount             long    0
C_800                   long    $800
C_FFFF_F8000            long    $FFFF_F800
d0                      long    1 << 9 << 0
d6                      long    1 << 9 << 6
phaseflip               long    $00000000
phasemask               long    $F0F0F0F0
line                    long    $00_18_00_00   '($180<<12 ... start of the colortable in COG ram)
sync_high1              long    %0101010101010101010101_101010_0101
sync_high2              long    %01010101010101010101010101010101       'used for black
sync_low1               long    %1010101010101010101010101010_0101
sync_low2               long    %01_101010101010101010101010101010

CSorEvenMaskDriverA     long 0
CSorEvenMaskDriverDoneA long 0
CSorOddMaskDriverA      long 0
CSorOddMaskDriverDoneA  long 0
CSorEvenImageDriverA    long 0
CSorOddImageDriverA     long 0        

CSorEvenMaskDriverB     long 0
CSorOddMaskDriverB      long 0
CSorEvenImageDriverB    long 0
CSorOddImageDriverB     long 0  

overlayMaskA      long  0       
ovImageA          long  0
overlayMaskB      long  0       
ovImageB          long  0

omask             long  0
oimage            long  0
onum              long  0

overlayRowNum     long  0  ' Drawing row number
C_RETCNT          long  0  ' Frame count in shared memory

C_CLKFREQ  long $04_C4_B4_00           ' Hardcoded clock frequency for the PEGS project
C_FFFF     long $FFFF
C_7EE0     long $7EE0
C_0FFFFFFF long $0FFFFFFF

C_FFFFF800 long $FFFFF800
                     
C_FFF      long $FFF
C_F000     long $F000

C_VCFG     long $5C_00_07_07
C_DIRA     long $07_00_00_00
C_CTRA     long $07_00_00_00
C_FRQA     long $16_E8_B9_FC

_screen                 long     0 
_colors                 long     0 
_tileMemory             long     0 
_ht                     long     32/2      
_vt                     long     26*8 
taskptr                 long     0         
taskret                 long     0
t1                      long     0
t2                      long     0
x                       long     0                
y                       long     0
hf                      long     228
hb                      long     228
vf                      long     17
vb                      long     18
hx                      long     $A0_A0
hc2x                    long     32*2   ' Bytes in tile-map row (32 words)
screen                  long     0
offsets                 long     0
tile                    long     0
pixels                  long     0
lineadd                 long     $20_00_00_00
tile2                   long     0
pixels2                 long     0
colorHold               long     0

hvis                    long     lntsc - sntsc      
hrest                   long     lntsc / 2 - sntsc
hhalf                   long     lntsc / 2
vvis                    long     243
vinv                    long     10
vrep                    long     6
burst                   long     $02_8A

yOffsetRows             long     0 ' yOffset >> yShifts
yOffsetLines            long     $00_00_00_00 ' ((yOffset % 8)*2) << 28
yOffsetShifts           long     6 ' 2^yOffsetShifts = hc2x

fcolor                  long     fntsc                      
sync_scale1             long     sntsc >> 4 << 12 + sntsc
sync_scale2             long     67 << 12 + lntsc / 2 - sntsc
sync_normal             long     %0101_00000000_01_10101010101010_0101

scriptPtrMem            long     0
yOffsetMem              long     0
waitcount               long     0
yDelta                  long     0

bottom     

         fit       colortable          'fit underneath colortable ($180-$1BF)
          
' ScreenMemory
'   Screen memory is a map of tile numbers for each tile 32x26 from left to right
'   and top to bottom. Each tile number is a word as follows:
'     cccc_tttttttttttt
'     cccc = the desired color set for the tile
'     tttttttttttt = the tile number index into TileMemory
'   Even though all tiles have color set values, odd numbered tiles use the color set
'   of the tile to their immediate left. For instance, tiles 0 and 1 both use the color
'   specified for tile 0 (color set for tile 1 is ignored).
'
' TileMemory
'  Tile images are 16 bytes long. That's 2-bit-pixels, 4 pixels-per-byte, 2 bytes
'  (8 pixels) per row and eight rows per image.
'
' Colors
'  There are 16 possible color sets defined in shared RAM. Each set has 4 colors.
'  Each color is 1 byte. That's 4 bytes (1 long) per color set and 16 color sets
'  for 64 bytes. From the Parallax TV driver on colors:
'
'  tv_colors  (From Parallax TV driver documentation)
'
'    pointer to longs which define colorsets
'      number of longs must be 1..64
'      each long has four 8-bit fields which define colors for 2-bit (four color) pixels
'      first long's bottom color is also used as the screen background color
'      8-bit color fields are as follows:
'        bits 7..4: chroma data (0..15 = blue..green..red..)*
'        bit 3: controls chroma modulation (0=off, 1=on)
'        bits 2..0: 3-bit luminance level:
'          values 0..1: reserved for sync - don't use
'          values 2..7: valid luminance range, modulation adds/subtracts 1 (beware of 7)
'          value 0 may be modulated to produce a saturated color toggling between levels 1 and 7
'
'      * because of TV's limitations, it doesn't look good when chroma changes abruptly -
'        rather, use luminance - change chroma only against a black or white background for
'        best appearance