' -------------------------------------------------------------------------------
''Boot.spin
'' 
'' Copyright (C) Chris Cantrell October 11, 2008
'' Part of the PEGS project (PEGSKIT.com)
''
'' The PEGS (Propeller Empowered Game System) is an all-in-one joystick with
'' an SD card slot for users to write their on games.
''
'' The system is a collection of COGS running Propeller assembly programs. These
'' COGS listen for command-requests in their own mailboxes and return replies
'' to the requests in the mailboxes.
''
'' The interpretted commands themselves are written in a MIX programming language.
'' The MIX compiler uses a mixture of assembly style and C flow constructs. The
'' language naturally breaks into 2K clusters stored on the SD card and loaded
'' into cache pages in Propeller RAM as needed. Thus a MIX program can be much
'' larger than the native 32K of the Propeller.
''
'' The PEGS system uses the entire 32K RAM. The main function of this module is
'' to get the various COGS running. The Interpreter object then moves data
'' around to fit the PEGS memory map (see below).
''
''##### COMMAND COGS #####
''
'' GOG 0 - (No mailbox) Interpreter   Reads commands and sends to target COGs
'' COG 1 - (Box 1) VariableCOG        Manages 128 user variables
'' COG 2 - (No mailbox) LEDd           
'' COG 3 - (Box 0) DiskCOG            Reads/writes SD clusters to cache pages
'' COG 4 - (Box 3) SoundCOG           Processes sound/music commands
'' COG 5 - (No mailbox) LEDc           
'' COG 6 - (No mailbox) LEDb           
'' COG 7 - (No mailbox) LEDa           
''
''##### MEMORY MAP #####
''
'' (First 2 cache pages reserved for screen memory. More can be
''  reserved as needed.)
'' 0000-05FF  LED display bits
'' 0600-0FFF  Sound/music script buffer
'' (Remaining cache pages)
'' 1000-77FF  12 2K cache pages
'' (Reserved top 2K system memory. Noteable entries follow.)
'' 7810       Number of reserved clusters (starts with 3)
'' 7811       Sectoers per FAT cluster on SD disk (0 means not mounted)
'' 7812       Booted flag (set to 1 when Interpreter is ready)
'' 7814-7817  1st sector number of MIX data on disk
'' 7E80-7F5F  Mailbox memory (6 boxes, 32 bytes each)
'' 7F6C       LED Refresh Control
'' 7F6E-7F6F  LED Base Memory
'' 7F80-7F8F  Music variables
''
''##### DEFAULT MIX PROGRAM #####
''
'' If no SD card is plugged in, the system runs the default program defined
'' here. 
''
'' ##### HARDWARE #####
''
'' ## Processor
''                                   3.3V
''                         │   │   │   │
''                       ┌─┴───┴───┴───┴──────┐
''               J2      │ 8  18  30  40   41 ├───── P0    
''              ┌──┐     │                 42 ├───── P1    
''              │1┼─────┤37 P30 (rx)      43 ├───── P2    
''              │2┼─────┤38 P31 (tx)      44 ├───── P3    
''              │3┼─────┤7  RESn           1 ├───── P4     
''              │4┼──┐  │                  2 ├───── P5    
''              └──┘    │                  3 ├───── P6     
''            Prop Clip  │                  4 ├───── P7    
''                       │       U2         9 ├───── P8     
''   3.3V        3.3V    │     P8X32A      10 ├───── P9    
''                     │                 11 ├───── P10  
''   │  U3     R2  10KΩ │                 12 ├───── P11  
'' ┌─┴────────┐   │      │                 13 ├─ P12
'' │ 8   SDA 5├───┻──────┤36 P29 (SDA)     14 ├─ P13
'' │     SCL 6├──────────┤35 P28 (SCL)     15 ├─ P14
'' │          │          │                 16 ├─ P15
'' │      WP 7├─┐        │                 19 ├─ P16
'' │      A0 1├─┫        │                 20 ├─ P17 
'' │      A1 2├─┫        │                 21 ├─ P18
'' │ 4    A2 3├─┫        │                 22 ├─ P19
'' └─┬────────┘ │        │                 23 ├─ P20
''   │ 24LC256          │                 24 ├─ P21
''                 X1   │                 25 ├─ P22
''                ┌─────┤28 (XI)          26 ├─ P23  - LED
''                | 5MHz │                 31 ├─ P24  ┐
''                └──────┤29 (XO)          32 ├─ P25  ├ SD
''                       │                 33 ├─ P26  │
''                       │ 5  17  27  39   34 ├─ P27  ┘  
''                       └─┬───┬───┬───┬──────┘
''                         │   │   │   │
''                                  
''
'' ## Power
''                                                      3.3V
''                                  U1 LM2937IMP-3.3   │
''                                 ┌───────────────┐   │
''            5V PC supply  ───┳───┤1 VIn    VOut 3├───┫
''                          C1    │      2 GND    │    C2
''                       0.1uF │   └──────┬────────┘   │ 10uF
''                                                   
'' 
''  ## See DiskCOG.spin (SD Card hardware)
''
CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

SpriteCOGNumberA   = 5
SpriteCOGNumberB   = 6

LEDBuffer   = $0000
SoundScript = $0600

LEDControl = $7F6C

SystemBooted      = $7812  ' System-booted flag. Non-zero when booted.
                     
OBJ

  interpreter : "Interpreter"
  disk        : "DiskCOG"
  variable    : "VariableCOG" 
  sound       : "SoundCOG"
  led2        : "LED2"
  gc          : "GC"       

PUB boot | i

  ' Clear out reserved cluster
  repeat i from $7800 to $7FFF
    byte[i] := 0

  ' Reserve 3 clusters for LED and sound.  
  byte[$7810] := 3
  
  ' The interpreter needs to know where the default CCL is
  word[$7FF8] := @defaultMIX  
    
  ' Create locks for all mailboxes
  repeat i from 1 to 6
    locknew

  ' System is not booted yet (interpreter will finish the boot)
  byte[SystemBooted] := 0
      
  ' Start all the COGS (they will stall)      
  disk.start
  variable.start  
  sound.start
  
  led2.start(2,0,LEDBuffer+0)      ' Lower right + left
  led2.start(5,4,LEDBuffer+48*2)   ' Upper right + left

  gc.start(6)
  
  ' COG 7 currently free!
 
  ' Start interpreter in boot mode. It will
  ' take over this boot cog and release the
  ' other cogs from thier stall state.
  interpreter.start
    
DAT
        
defaultMIX
' Cluster 'LEDGraphics'
' call ClearScreen
  long %0_000_001_1111111111111111_000100001

' x=0
  long  %10_111_001__00_000_111_10001010_0000_1011
    long %00000000_000000000000_000000000000

' _if_1_1:
' _if_1_expression:
' _loop_1_start:
' x<30
  long  %10_111_001__00_000_111_10001010_0011_1011
    long %00000000_000000000000_000000011110

' BRANCH-IFNOT _if_1_false
  long %0_000_010_1111111111111111_000001110

' _if_1_true:
' y=x
  long  %10_111_001__00_000_111_10001000_0000_1011
    long %00000001_000000000000_000000000000

' c=1
  long  %10_111_001__00_000_111_10001010_0000_1011
    long %00000010_000000000000_000000000001

' call plot
  long %0_000_001_1111111111111111_000101101

' _loop_1_continue:
' ++x
  long  %10_111_001__00_000_111_11000010_0000_0000
    long %00000000_000000000000_000000000001

' GOTO _loop_1_start
  long %0_000_000_1111111111111111_000000011

' _loop_1_end:
' _if_1_end:
' _if_1_false:
' y=10
  long  %10_111_001__00_000_111_10001010_0000_1011
    long %00000001_000000000000_000000001010

' _if_2_1:
' _if_2_expression:
' _loop_2_start:
' y<24
  long  %10_111_001__00_000_111_10001010_0011_1011
    long %00000001_000000000000_000000011000

' BRANCH-IFNOT _if_2_false
  long %0_000_010_1111111111111111_000011011

' _if_2_true:
' x=35
  long  %10_111_001__00_000_111_10001010_0000_1011
    long %00000000_000000000000_000000100011

' c=1
  long  %10_111_001__00_000_111_10001010_0000_1011
    long %00000010_000000000000_000000000001

' call plot
  long %0_000_001_1111111111111111_000101101

' _loop_2_continue:
' ++y
  long  %10_111_001__00_000_111_11000010_0000_0000
    long %00000001_000000000001_000000000001

' GOTO _loop_2_start
  long %0_000_000_1111111111111111_000010000

' _loop_2_end:
' _if_2_end:
' _if_2_false:
' call RefreshScreen
  long %0_000_001_1111111111111111_000011101

' stop
  long %0_000_111_0000000000000000000000000

' RefreshScreen:
' mem(REFRESH)=1
  long  %10_111_001__01_000_011_10111010_0000_1011
    long %00000000_000000000000_000000000001
    long %1000000000111111101101100

' return
  long %0_001_0000000000000000000000000000

' ClearScreen:
' memcopy clearFrame,0,48
  long %0_110_0_000110000_010000111_000000000

' return
  long %0_001_0000000000000000000000000000

' GetPoint:
' call CalcMem
  long %0_000_001_1111111111111111_000111101

' c = mem(xr) & bp
  long  %10_111_001__01_000_101_11001100_0000_0111
    long %00000010_000000000000_000000000101
    long %1000000010000000000000011

' _if_3_1:
' _if_3_expression:
' c>0
  long  %10_111_001__00_000_111_10001010_0101_1011
    long %00000010_000000000000_000000000000

' BRANCH-IFNOT _if_3_false
  long %0_000_010_1111111111111111_000101100

' _if_3_true:
' c=1
  long  %10_111_001__00_000_111_10001010_0000_1011
    long %00000010_000000000000_000000000001

' _if_3_end:
' _if_3_false:
' return
  long %0_001_0000000000000000000000000000

' Plot:
' call CalcMem
  long %0_000_001_1111111111111111_000111101

' _if_4_1:
' _if_4_expression:
' c!=0
  long  %10_111_001__00_000_111_10001010_0010_1011
    long %00000010_000000000000_000000000000

' BRANCH-IFNOT _if_4_false
  long %0_000_010_1111111111111111_000110110

' _if_4_true:
' mem(xr) = mem(xr) | bp
  long  %10_111_001__10_000_001_11111100_0000_1000
    long %00000000_000000000000_000000000101
    long %1000000010000000000000011
    long %1000000010000000000000011

' GOTO _if_4_end
  long %0_000_000_1111111111111111_000111100

' _if_4_false:
' bp = ~bp
  long  %10_111_001__00_000_111_10001000_0000_1010
    long %00000101_000000000000_000000000101

' mem(xr) = mem(xr) & bp
  long  %10_111_001__10_000_001_11111100_0000_0111
    long %00000000_000000000000_000000000101
    long %1000000010000000000000011
    long %1000000010000000000000011

' _if_4_end:
' return
  long %0_001_0000000000000000000000000000

' CalcMem:
' tx = x
  long  %10_111_001__00_000_111_10001000_0000_1011
    long %00000110_000000000000_000000000000

' ty = y
  long  %10_111_001__00_000_111_10001000_0000_1011
    long %00000111_000000000000_000000000001

' _if_5_1:
' _if_5_expression:
' y<16
  long  %10_111_001__00_000_111_10001010_0011_1011
    long %00000001_000000000000_000000010000

' BRANCH-IFNOT _if_5_false
  long %0_000_010_1111111111111111_001100011

' _if_6_1:
' _if_6_expression:
' _if_5_true:
' x<24
  long  %10_111_001__00_000_111_10001010_0011_1011
    long %00000000_000000000000_000000011000

' BRANCH-IFNOT _if_6_false
  long %0_000_010_1111111111111111_001010100

' _if_6_true:
' xr = tx * 2
  long  %10_111_001__00_000_111_11000010_0000_0010
    long %00000011_000000000110_000000000010

' yr = ty / 8
  long  %10_111_001__00_000_111_11000010_0000_0011
    long %00000100_000000000111_000000001000

' yo = ty % 8
  long  %10_111_001__00_000_111_11000010_0000_0100
    long %00001000_000000000111_000000001000

' bp = 128 >> yo
  long  %10_111_001__00_000_111_11001000_0000_0110
    long %00000101_000010000000_000000001000

' xr = 191 - xr
  long  %10_111_001__00_000_111_11001000_0000_0001
    long %00000011_000010111111_000000000011

' xr = xr - yr
  long  %10_111_001__00_000_111_11000000_0000_0001
    long %00000011_000000000011_000000000100

' GOTO _if_6_end
  long %0_000_000_1111111111111111_001100010

' _if_6_false:
' tx = tx - 24
  long  %10_111_001__00_000_111_11000010_0000_0001
    long %00000110_000000000110_000000011000

' xr = tx * 2
  long  %10_111_001__00_000_111_11000010_0000_0010
    long %00000011_000000000110_000000000010

' yr = ty / 8
  long  %10_111_001__00_000_111_11000010_0000_0011
    long %00000100_000000000111_000000001000

' yo = ty % 8
  long  %10_111_001__00_000_111_11000010_0000_0100
    long %00001000_000000000111_000000001000

' bp = 128 >> yo
  long  %10_111_001__00_000_111_11001000_0000_0110
    long %00000101_000010000000_000000001000

' xr = 143 - xr
  long  %10_111_001__00_000_111_11001000_0000_0001
    long %00000011_000010001111_000000000011

' xr = xr - yr
  long  %10_111_001__00_000_111_11000000_0000_0001
    long %00000011_000000000011_000000000100

' _if_6_end:
' GOTO _if_5_end
  long %0_000_000_1111111111111111_010000101

' _if_7_1:
' _if_7_expression:
' _if_5_false:
' x<24
  long  %10_111_001__00_000_111_10001010_0011_1011
    long %00000000_000000000000_000000011000

' BRANCH-IFNOT _if_7_false
  long %0_000_010_1111111111111111_001110101

' _if_7_true:
' ty=ty-16
  long  %10_111_001__00_000_111_11000010_0000_0001
    long %00000111_000000000111_000000010000

' xr = tx * 2
  long  %10_111_001__00_000_111_11000010_0000_0010
    long %00000011_000000000110_000000000010

' yr = ty / 8
  long  %10_111_001__00_000_111_11000010_0000_0011
    long %00000100_000000000111_000000001000

' yo = ty % 8
  long  %10_111_001__00_000_111_11000010_0000_0100
    long %00001000_000000000111_000000001000

' bp = 1 << yo
  long  %10_111_001__00_000_111_11001000_0000_0101
    long %00000101_000000000001_000000001000

' xr = 48 + xr
  long  %10_111_001__00_000_111_11001000_0000_0000
    long %00000011_000000110000_000000000011

' xr = xr + yr
  long  %10_111_001__00_000_111_11000000_0000_0000
    long %00000011_000000000011_000000000100

' GOTO _if_7_end
  long %0_000_000_1111111111111111_010000101

' _if_7_false:
' ty=ty-16
  long  %10_111_001__00_000_111_11000010_0000_0001
    long %00000111_000000000111_000000010000

' tx=tx-24
  long  %10_111_001__00_000_111_11000010_0000_0001
    long %00000110_000000000110_000000011000

' xr = tx * 2
  long  %10_111_001__00_000_111_11000010_0000_0010
    long %00000011_000000000110_000000000010

' yr = ty / 8
  long  %10_111_001__00_000_111_11000010_0000_0011
    long %00000100_000000000111_000000001000

' yo = ty % 8
  long  %10_111_001__00_000_111_11000010_0000_0100
    long %00001000_000000000111_000000001000

' bp = 1 << yo
  long  %10_111_001__00_000_111_11001000_0000_0101
    long %00000101_000000000001_000000001000

' xr = 0 + xr
  long  %10_111_001__00_000_111_11001000_0000_0000
    long %00000011_000000000000_000000000011

' xr = xr + yr
  long  %10_111_001__00_000_111_11000000_0000_0000
    long %00000011_000000000011_000000000100

' _if_5_end:
' _if_7_end:
' return
  long %0_001_0000000000000000000000000000

' STOP
  long %0_000_111_0000000000000000000000000

' clearFrame:
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0
' 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  byte  $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0, $0