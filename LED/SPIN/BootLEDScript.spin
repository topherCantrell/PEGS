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

  disk        : "DiskCOG"  
  led2        : "LED2"
  gc          : "GC"
  ledEngine   : "LEDScriptEngine"      

PUB boot | i

  ' Clear out reserved cluster
  repeat i from $7800 to $7FFF
    byte[i] := 0

  ' Reserve 3 clusters for LED and sound.  
  byte[$7810] := 3
      
  ' Create locks for all mailboxes
  repeat i from 1 to 6
    locknew  
      
  ' Start all the COGS (they will stall until SystemBooted is 1)
  'gc.start(1)     
  'disk.start(2)  
  led2.start(3,0,0)      ' Lower right + left
  led2.start(4,4,96)   ' Upper right + left
  
  ledEngine.start(5,@testLEDScript)

  ' In production the engines will pull their start address from
  ' the given param address when released allowing the loader
  ' to set the addresses.
  'soundEngine.start(6,nnnn)
                
  ' Start loader. It will reserve memory, load scripts,
  ' release the stalled cogs

  ' loader.start

  ' For testing ... comment out the disk cog and let the
  ' system run in the SPIN OS form
  byte[SystemBooted] := 1

DAT

testLEDScript

  byte  %0_0000_11_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_01_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_11_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_01_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_11_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_01_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_11_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_01_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_11_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE
  byte  %0_0000_01_0,  $00,$70       ' Set and clear draw canvas to 7000
   byte  %0_0001_00_0,  $00,$70       ' Render canvas
  byte  %1_10101_10,   $00             ' PAUSE

  
 'byte  %0_0011_00_0,   1,  2        ' Plot point
 byte  %0_0100_00_0,   5,7
 byte  %0_0101_00_0,   45,22          ' Line
 byte  %0_0001_00_0,  $00,$70       ' Render canvas
 byte  %1_00010_11,  %11111110      ' GOTO -2 (infinitie loop)
 
 byte  %0_0000_01_0,  $00,$70       ' Set and clear draw canvas to 7000
 byte  %1_00000_00,   $00,$70, $11  ' Write AA to canvas at 7000
 byte  %0_0001_00_0,  $00,$70       ' Render canvas
 byte  %1_10101_10,   $00             ' PAUSE
 byte  %1_00000_00,   $00,$70, $88  ' Write AA to canvas at 7000
 byte  %0_0001_00_0,  $00,$70       ' Render canvas
 byte  %1_10101_10,   $00             ' PAUSE 
 byte  %1_00010_11,   %11101100       ' GOTO -2 (infinite loop)         
