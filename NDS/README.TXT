
java CCL battleship.ccl battleship.bin             -- Compile/emulate battleship
java CCLBINtoNDS battleship.bin battleship.nds     -- Convert battleship to .NDS

-- CCL compiler/emulator
CCL.java
Command.java
Cluster.java
DataCommand.java
COGCommand.java
FlowCommand.java
GCPad.java
TileGrid.java
TilePanel.java

-- Compiled Battleship BIN ready for SD card
battleship.bin

-- CCL files for Battleship program
FontTiles.ccl
GCPadConstants.ccl
BoardDataConstants.ccl
BoardTiles.ccl
PlaceShips.ccl
Battleship.ccl
CPU.ccl

-- Converts CCL .BIN files to .NDS file playable on DS
CCLBINtoNDS.java

-- Compiled CCL project (see below)
CCL.nds

-- Helper tools used in development
MakeData.java       -- Turns .BIN file into DISK_DATA.CPP for DS/GBA project testing
MakeBlankData.java  -- Makes blank DISK_DATA.CPP for final DS/GBA project

-- Directory contains the CPP implementation of CCL for the Nintendo DS (and GBA).
-- Install DEVKITPRO, launch a command-prompt and CD to this directory. Type "MAKE".
CCL\
CCL\source     -- Source files

-- Propeller project (.spin files)
SPIN\
