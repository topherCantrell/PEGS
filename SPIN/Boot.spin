CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

ScreenMap  = $200
TileMemory = $880

OBJ

  interpreter : "Interpreter"
  disk        : "DiskCOG"
  variable    : "VariableCOG"
  tvDriver    : "TV8x8"
  video       : "VideoCOG" 
  inputs      : "Inputs"
  sound       : "SoundCOG" 
  sprites     : "Sprites"   
    

PUB boot | i

  ' Setup all boxes with stall-flags set
  repeat i from $7800 to $7FFF
    byte[i] := 0

  ' Reserve 3 clusters (6144 bytes) for screen.
  ' System uses 1 cluster at end leaving 12 clusters
  ' for the user. 24K out of 32K. 
  byte[$7810] := 3
    
  ' Copy the TV driver params and color schemes
  longmove($7F60,@tvparams,32)

  ' The interpreter needs to know where the default CCL is
  word[$7FF8] := @defaultMIX  
  
  ' The interpreter needs to know how to move fonts
  word[$7FFA] := @fontTileData
  word[$7FFC] := @fontTileData_end - @fontTileData
  word[$7FFE] := TileMemory ' Start of tile data  

  ' Create locks for all mailboxes
  repeat i from 1 to 8
    locknew

  ' Start all the COGS (they will stall)    
  disk.start
  variable.start
  tvDriver.start
  sprites.start
  video.start
  sound.start 
  inputs.start
  
  ' sprite.start

  ' Start interpreter in boot mode. It will
  ' take over this boot cog and release the
  ' other cogs from thier stall state.
  interpreter.start      

DAT

' Reserve 3 clusters for the screen (6144 bytes)
' Current screen is 32*26*2 =  1664 bytes
'
' Screen 0200 - 087F
' Tiles  0880 - 17FF (248 pictures of 16 bytes each) 

fontTileData

  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0 
  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0     
  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0
  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0 
  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0
  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0
  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0
  long 0,0,0,0,  0,0,0,0,   0,0,0,0

  ' 31 Default cursor

  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11

  ' 32 SPACE
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  ' 33-47 Various symbols
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_11_00_11_00_00
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_11_00_11_00_00
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_11_00_00_00
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_00
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_11_11
  word  %00_00_11_00_00_00_11_11
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_11_11_00_00_00_11_00
  word  %00_11_11_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_11_11_00
  word  %00_00_00_00_11_00_00_11
  word  %00_00_00_00_00_11_11_00
  word  %00_00_00_00_11_00_00_11
  word  %00_00_00_11_00_00_00_11
  word  %00_00_11_00_00_00_00_11
  word  %00_11_00_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_00_00_00_11_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_11_00_00_00_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_11_11_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_11_11_11_11_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_11_11_00_00_00
  word  %00_00_00_11_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_00
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_00_11_00
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  '48-57 Numbers
  word  %00_00_11_11_11_11_11_00
  word  %00_11_11_00_00_00_00_11
  word  %00_11_00_11_00_00_00_11
  word  %00_11_00_00_11_00_00_11
  word  %00_11_00_00_00_11_00_11
  word  %00_11_00_00_00_00_11_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_11_11_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_00
  word  %00_00_11_11_11_11_00_00
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_11_00
  word  %00_00_00_00_00_00_11_00
  word  %00_00_11_00_00_00_00_11
  word  %00_00_11_00_00_00_00_11
  word  %00_11_11_11_11_11_11_11
  word  %00_00_11_00_00_00_00_00
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_00_11_00
  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_00
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_11_11_11_11_11_00
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  ' 58-64 More symbols
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_11_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_00_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_11_11_11_00_00
  word  %00_00_11_00_00_00_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_11_11_00_00_11
  word  %00_00_11_11_11_00_00_11
  word  %00_00_00_00_00_00_11_00
  word  %00_00_00_11_11_11_00_00
  word  %00_00_00_00_00_00_00_00

  ' 65-90 Uppercase letters

  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_11_00_00_00_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00 
  
  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_00

  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_00

  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00  
  
  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_11_11_11_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_11_11_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_11_11_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_00_00_00_11
  word  %00_00_00_00_11_11_00_11
  word  %00_00_00_00_00_00_11_11
  word  %00_00_00_00_11_11_00_11
  word  %00_00_11_11_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_11_00_00_00_11_11
  word  %00_11_00_11_00_11_00_11
  word  %00_11_00_00_11_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_11_11
  word  %00_11_00_00_00_11_00_11
  word  %00_11_00_00_11_00_00_11
  word  %00_11_00_11_00_00_00_11
  word  %00_11_11_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_00_00_00_00_11
  word  %00_11_00_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_11
  word  %00_00_00_11_00_00_00_11
  word  %00_00_11_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_11_00_00_00_00_00_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_11_11_11_11_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_00_00_00_11_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_11_00_00_11
  word  %00_11_00_00_11_00_00_11
  word  %00_00_11_00_11_00_11_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_00_00_00_11_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_11_00_00_00_11_00
  word  %00_11_00_00_00_00_00_11
  word  %00_00_00_00_00_00_00_00

  word  %00_11_00_00_00_00_00_11
  word  %00_11_00_00_00_00_00_11
  word  %00_00_11_00_00_00_11_00
  word  %00_00_00_11_00_11_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_11_11_11_11_11_11_11
  word  %00_00_11_00_00_00_00_00
  word  %00_00_00_11_00_00_00_00
  word  %00_00_00_00_11_00_00_00
  word  %00_00_00_00_00_11_00_00
  word  %00_00_00_00_00_00_11_00
  word  %00_11_11_11_11_11_11_11
  word  %00_00_00_00_00_00_00_00    

  ' 91-96 symbols

  long 0,0,0,0,  0,0,0,0,   0,0,0,0,  0,0,0,0
  long 0,0,0,0,  0,0,0,0

  ' 97- 122 Lowercase letters (Green)

  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_10_00_10_00_00
  word  %00_00_10_00_00_00_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_10_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_00

  word  %00_10_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_10_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_00

  word  %00_10_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_10_10_10_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_10_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_10_10_10_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_10_10_10_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_00
  word  %00_10_00_00_00_00_00_00
  word  %00_10_00_00_00_00_00_00
  word  %00_10_00_00_00_00_00_00
  word  %00_10_00_00_00_00_00_00
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_00_00_00_10
  word  %00_00_00_00_10_10_00_10
  word  %00_00_00_00_00_00_10_10
  word  %00_00_00_00_10_10_00_10
  word  %00_00_10_10_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_10_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_10_00_00_00_10_10
  word  %00_10_00_10_00_10_00_10
  word  %00_10_00_00_10_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_10_10
  word  %00_10_00_00_00_10_00_10
  word  %00_10_00_00_10_00_00_10
  word  %00_10_00_10_00_00_00_10
  word  %00_10_10_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_00_00_00_00_10
  word  %00_10_00_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_10
  word  %00_00_00_10_00_00_00_10
  word  %00_00_10_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_00_10_10_10_10_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_00
  word  %00_10_00_00_00_00_00_00
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_10_10_10_10_10_10
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_10_10_10_10_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_00_00_00_10_00
  word  %00_00_00_10_00_10_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_10_00_00_10
  word  %00_10_00_00_10_00_00_10
  word  %00_00_10_00_10_00_10_00
  word  %00_00_00_10_00_10_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_00_00_00_10_00
  word  %00_00_00_10_00_10_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_10_00_10_00_00
  word  %00_00_10_00_00_00_10_00
  word  %00_10_00_00_00_00_00_10
  word  %00_00_00_00_00_00_00_00

  word  %00_10_00_00_00_00_00_10
  word  %00_10_00_00_00_00_00_10
  word  %00_00_10_00_00_00_10_00
  word  %00_00_00_10_00_10_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_00_00_00_00

  word  %00_10_10_10_10_10_10_10
  word  %00_00_10_00_00_00_00_00
  word  %00_00_00_10_00_00_00_00
  word  %00_00_00_00_10_00_00_00
  word  %00_00_00_00_00_10_00_00
  word  %00_00_00_00_00_00_10_00
  word  %00_10_10_10_10_10_10_10
  word  %00_00_00_00_00_00_00_00  




fontTileData_end

' Goes to $7F60
tvparams
  long    0               'status
  long    1               'enable
  long    %11_0000        'pins
  long    %00000          'mode (16x16, color, composite-color, progressive, NTSC)
  long    ScreenMap       'screen
  long    $7FA0           'colors
  long    16              'hc 
  long    13              'vc 
  long    10              'hx
  long    1               'vx
  long    0               'ho
  long    0               'vo
  long    0               'broadcast (turned off to save power)  
  long    TileMemory      'tileMemory
  long    0               ' Pad to 16 longs     
  long    0               ' Pad to 16 longs

' Goes to $7FA0
color_schemes
  
  long    $05_6C_BC_02
  
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02 
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02 
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02 
  long    $BC_6C_05_02
  long    $BC_6C_05_02
  long    $BC_6C_05_02    

defaultMIX
' Cluster ''
' @0    (0)
' MEM(M_INPUTMODE)=3
  long  %1_111_0001__01_000_011_10111010_0000_1011
    long %00000000_000000000000_000000000011
    long %1000000000111100000010011

' @12    (3)
' CLS
  long  %1_111_0010___00_0_00000___00000000___00000000
    long %00100000_00011010_0000000000100000
' @20    (5)
' SETCURSOR 0,0
  long %1_010_0010___00_0_00100___00000000__00000000
' @24    (6)
' v0=0
  long  %1_111_0001__00_000_111_10001010_0000_1011
    long %00000000_000000000000_000000000000

' @32    (8)
' _if_1_1:
' _if_1_expression:
' _loop_1_start:
' v0<10
  long  %1_111_0001__00_000_111_10001010_0011_1011
    long %00000000_000000000000_000000001010

' @40    (10)
' BRANCH-IFNOT _if_1_false
' CLUSTER:65535   OFFSET:15
  long %0_000_010_1111111111111111_000001111

' @44    (11)
' _if_1_true:
' print "HELLO TEST\n"
  long  %1_010_0000___00_0_00001___0000000001000000
' @48    (12)
' _loop_1_continue:
' ++V0
  long  %1_111_0001__00_000_111_11000010_0000_0000
    long %00000000_000000000000_000000000001

' @56    (14)
' GOTO _loop_1_start
' CLUSTER:65535   OFFSET:8
  long %0_000_000_1111111111111111_000001000

' @60    (15)
' _loop_1_end:
' _if_1_end:
' _if_1_false:
' STOP
' CLUSTER:65535   OFFSET:0
  long %0_000_111_1111111111111111_000000000

' @64    (16)
' _msg_4:
' "HELLO TEST\n",0
  byte  $48, $45, $4c, $4c, $4f, $20, $54, $45, $53, $54, $a, $0