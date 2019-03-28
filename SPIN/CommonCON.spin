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
