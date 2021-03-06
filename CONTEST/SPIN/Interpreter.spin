' -------------------------------------------------------------------------------
''Interpreter.spin
'' 
'' Copyright (C) Chris Cantrell October 10, 2008
'' Part of the PEGS project (PEGSKIT.com)
''
'' The Interpreter reads COG commands from the current cluster and passes them
'' to the requested mailbox for processing. The Interpreter itself handles
'' several commands mostly related to program flow (GOTO, BRANCH-IF, CALL,
'' RETURN, etc.) Other specialized COGS process commands appearing in their
'' specific mailboxes.
''
'' The Interpreter commands are listed in detail below, but here is a summary
'' of the rich capabilities:
''
''   GOTO/CALL/RETURN        - Jumps and subroutine calls
''   Indirect GOTO/CALL      - Indirect jumps and subroutine calls
''   BRANCH-IF/BRANCH-IFNOT  - Conditional jumps
''   PAUSE/STOP              - Sleep and halt
''   DEBUG                   - Turn the LED on or off
''   EXECUTE                 - Reload any COG with a binary program from the disk
''   SAVE/LOAD VARIABLES     - Save/restore the program variables on disk
''   GETINPUTS               - Read the joystick inputs to a program variable
''
''##### MAILBOX SYSTEM #####
''
'' There are seven mailboxes in the upper system memory. Each is 8 LONGs as
'' follows:
''
''  Command/Status  - Requests have upper bit set / When finished bit is cleared.
''  Data1/Return    - Optional request data / Return value
''  Data2           - Optional request data
''  Data3           - Optional request data
''  Data4           - Optional request data
''  Reserved        - Not currently used
''  Reserved        - Not currently used
''  Cluster Offset  - Base cluster address of requester
''
'' To send a request, the sender must acquire the HUB lock for the desired
'' mailbox (by number 0-6). The sender then writes any data needed in the
'' request first followed by the command value, whose upper bit is set.
'' The sender waits for the upper bit to clear and reads the return value
'' from the mailbox. Finally, the sender releases the HUB lock making the
'' box available for other senders.
''
'' Some COG commands will pass pointer offsets in the request. A PRINT command,
'' for instance, passes the offset to the string of characters to be printed.
'' The handling COG needs to know the physical address of the data and adds
'' the offset to the "Cluster Offset". Clusters may be loaded into memory
'' at any page address, and the base+offset strategy allows the handling COG
'' to calculate absolute RAM addresses.
''
''##### EXPECTED COGS #####
''
'' A number of default COGs are initialized at boot, but they may be replaced
'' with binary programs loaded from disk via the EXECUTE instruction (below).
'' However, all COGs expect to find the following COGs listening to the
'' given mailboxes:
''   DiskCOG using box 0      - used to cache clusters from the SD card
''   VariableCOG using box 1  - manages all program variables
''
''##### MIX PROGRAM COMMAND FORMATS #####
''
'' MIX program commands are loaded from the current cluster in LONG increments.
'' If the upper bit of the command is zero, the command is handled by the
'' Interpreter. The various FLOW commands are described below. 
''
'' Commands with the upper bit set are variable-length commands that are loaded
'' and passed to the target mailbox specified in the command. There are two
'' types of these COG commands: short and long as follows:
''
''   1o_bbb_zzzzzzzzzzzzzzzzzzzzzzzzzzz
''     Short form (single LONG command)
''     b is the target mailbox (000-110)
''     z is the request data
''     o is 'oneway' (1 means receiver releases lock)
''
''   1o_111_bbb_ss_zzzzzzzzzzzzzzzzzzzzzz
''   zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
''   ...
''     Long form (variable LONG command)
''     b is the target mailbox (000-110)
''     s is the number of extra LONGs (0 means 1, 1 means 2, etc.)
''     z is the request data
''     o is 'oneway' (1 means receiver releases lock)
''
''##### BOOT PROCESS #####
''
'' A little shuffling is required to get the data from RAM in the way
'' SPIN programs are arranged to RAM in the way the MIX environment
'' needs it.
''
'' The Boot.spin process first clears out the upper 2K of system memory (it
'' assumes the native SPIN program doesn't reach that high). Then it copies
'' various configuration tables to system memory. This data includes video
'' driver info and sprite driver info.
''
'' The Boot.spin writes the address of the default screen font images to system
'' memory and starts all the COGs. All the COGS are designed to stall until
'' a global "GO" flag is set in system memory. The Boot.spin writes the address
'' of the default MIX program (runs if an SD card is not present).
''
'' The Interpreter continues the boot process when it starts. It clears the
'' reserved 2K pages at the beginning of RAM and moves the default fonts to
'' their proper location. Then it moves the default MIX program to page 14
'' (as far away from screen memory as possible allowing a program to safely
'' extend the reserved memory if needed).
''
'' Next the Interpreter releases the COGs by writing the global "GO" flag.
''
'' The Interpreter requests a MOUNT and attempts to load cluster 0 into
'' page 14 (over the default program). Then it begins executing the MIX program
'' at offset 0. 
''
''##### HARDWARE #####
''
'' The Interpreter manages the joystick hardware: eight switches and an LED.
'' The Joystick-switches, buttons and LED are connected to the
'' Propeller as follows:
''                           
''                        3.3V
''           ┌───┳───┳───╋───┳────┳───┳───┐
''           R3 R4 R5 R6 R28 R7 R8 R9 ─ All 10KΩ
'' P21 ─────┻───┼───┼───┼───┼────┼───┼───┼────┐ Up
'' P16 ─────────┻───┼───┼───┼────┼───┼───┼────┫ Down
'' P14 ─────────────┻───┼───┼────┼───┼───┼────┫ Left
'' P17 ─────────────────┻───┼────┼───┼───┼────┫ Right    Joystick switches
'' P15 ─────────────────────┻────┼───┼───┼────┫ Fire     and buttons
'' P18 ──────────────────────────┻───┼───┼────┫ Start
'' P19 ──────────────────────────────┻───┼────┫ Select
'' P20 ──────────────────────────────────┻────┫ Reset
''                                               

CON
      
DebugPin = $08_00_00_00

' VariableCOG command for get-variable
VariableGetCommand = %10_111_001__00_000_111_00_10_10_00_0111_1011
' VariableCOG command for variable-set (oneway)
VariableSetCommand = %10_111_001__01_000_110_10_00_10_10_0000_1011

MountCommand = %10_000__000___0000_0000___00000000___00000000
LoadCluster  = %10_000__000___0001_0011___00000000___00000000

Cluster0          = $8000 - 2048*2
Cluster1          = $8000 - 2048*3

NumberReserved  = $7810
SystemBooted    = $7812
MailboxMemory   = $7E80
 

PUB start 
'' Start the Interpreter (in boot mode)  
  coginit(0,@Interpreter,$FFFC)

DAT

''
''Interpreter Commands: 
         org       0
              
Interpreter

' Interpreter controls the debug LED
         mov       dira,C_DEBUG_PIN    ' The interpreter controlls the debug pin    

' If we are booting up, do special stuff
         mov       ofs,par             ' Cluster number to boot (FFFC if starting up)
         cmp       ofs,C_FFFC wz       ' Are we still initializing the system ...
  if_z   jmp       #boot               ' ... yes, go finish setting up

' GOTO par:0
         mov       tmp,par             ' Passed in cluster number
         mov       com,#0              ' Offset 0
         jmp       #gotoCommand        ' Do a GOTO command
       
mainLoop
         mov       tmp,pc              ' PC ...        
         add       tmp,baseCluster     ' ... plus base
         rdlong    com,tmp             ' Get the next CCL command
         
         add       pc,#4               ' Bump program counter
         shl       com,#1 nr,wc        ' Check upper bit         
   if_c  jmp       #cogCommand         ' If 1 do COG command
         mov       tmp,com             ' tmp = ...
         shr       tmp,#28 wz          ' ... command field
         add       tmp,#commandTable   ' Offset into list of jumps
         jmp       tmp                 ' Take the jump to the command

commandTable
         jmp       #destCommand        ' 000
         jmp       #returnCommand      ' 001
         jmp       #pauseCommand       ' 002
         jmp       #debugCommand       ' 003
         jmp        #mainLoop          ' 004
         jmp       #vario              ' 005
         jmp       #getInputs          ' 006
         jmp       #executeCommand     ' 007

''
'' EXECUTE COG=c, PAR=p
'' Load the following binary data into COG c and execute it with
'' given PAR value. The binary code must follow the EXECUTE
'' command with a 4 byte gap between (usually an added STOP command).
'' An implicit RETURN is made after the EXECUTE command.
''   0_111_0000_cccc_pppppppp_pppppppp
executeCommand  
         add       pc,#4               ' Skip the added STOP command
         mov       ptr,pc              ' Point to the ...
         add       ptr,baseCluster     ' ... code 
                  
         mov       tmp,com             ' tmp = ...
         shr       tmp,#16             ' ... COG ...
         and       tmp,#7              ' ... number
         
         and       com,C_FFFF          ' com = par         
         
         shr       com,#2              ' Force lower 2 bits to zero
         shl       com,#18             ' Into position          
         
         shr       ptr,#2              ' Force lower 2 bits to zero
         shl       ptr,#4              ' Into ...         
         or        com,ptr             ' ... position           
         
         andn      com,#8              ' Specify COG number manually
         or        com,tmp             ' COG number into position          
         
         coginit   com                 ' Start new program in target COG
         jmp       #returnCommand      ' Implied RETURN after EXECUTE

''
'' GETINPUTS Vn
'' Read the joystick/button inputs to the given variable.
'' Return format in Vn: 000S000F0rsudrl

getInputs

         mov       t2,com              ' Result variable ...
         and       t2,#255             ' ... to t2 (for storeVar)
         
         mov       A,#0                ' Final ...
         mov       B,#0                ' ... value     

         mov       tmp,ina             ' Read ...
         shr       tmp,#14             ' ... switch ...
         and       tmp,#$FF            ' ... inputs

         and       tmp,#1 nr, wz       ' Mapping switches ...
    if_z or        A,#8                ' ... to format given above
         and       tmp,#2 nr, wz
    if_z or        B,#1
         and       tmp,#4 nr, wz
    if_z or        A,#2
         and       tmp,#8 nr, wz
    if_z or        A,#4
         and       tmp,#16 nr, wz
    if_z or        B,#16
         and       tmp,#32 nr, wz
    if_z or        B,#2
         and       tmp,#64 nr, wz
    if_z or        A,#16
         and       tmp,#128 nr, wz
    if_z or        A,#1
         
         mov       tmp,A
         shl       B,#8
         or        tmp,B 

         call      #storeVar           ' Store the result
         jmp       #mainLoop           ' Done

''
'' DEBUG b
'' Turn debug light on (b=1) or off (b=0)
''   0_011_000000000000000000000000000b
debugCommand
         and       com,#1 wz           ' 1 or 0
   if_z  andn      outa,C_DEBUG_PIN    ' 0 = LED off
   if_nz or        outa,C_DEBUG_PIN    ' 1 = LED on
         jmp       #mainLoop           ' Done

''
'' PAUSE t
'' Pause for t clock ticks. At 80MHz all ones is 3.3554432 seconds.
''   0_010_tttttttttttttttttttttttttttt
pauseCommand
         and       com,C_0FFFFFFF      ' Get the pause value
         add       com,cnt             ' 80MZ: 80_000_000 cnts per sec
         waitcnt   com,com             ' Wait for the clock
         jmp       #mainLoop           ' Done 

' GOTO, CALL, BRANCH-IF, BRANCH-IFNOT
destCommand
         mov       tmp2,com            ' tmp2 ...
         shr       tmp2,#25            ' ...
         and       tmp2,#7 wz          ' ... = command type
       
         mov       tmp,com             ' Original command
         shr       tmp,#9              ' tmp ...
         and       tmp,C_FFFF          ' ... = cluster
         and       com,#$1FF           ' com ...
         shl       com,#2              ' ... = offset

         add       tmp2,#destComTable
         jmp       tmp2

destComTable
         jmp       #gotoCommand        ' 
         jmp       #callCommand        ' 
         jmp       #ifnotCommand       ' 
         jmp       #ifCommand          ' 
         jmp       #gotoVn             '
         jmp       #callVn             '
         jmp         #mainLoop         '         
stop     jmp       #stop               '

''
'' STOP
'' Halt the program with an infinite loop.
''   0_000_111_0000000000000000000000000

''
'' NOOP
'' Do nothing .
''   0_000_110_0000000000000000000000000

''
'' GOTO Vn
'' Change program counter to offset o within cluster number stored in Vn.
''   0_000_100_00000000_vvvvvvvv_ooooooooo  
gotoVn
         call      #fetchVar           ' Fetch Vn (n in tmp) to data1
         mov       tmp,data1           ' New cluster value (offset left alone)
         jmp       #gotoCommand        ' Continue with GOTO

''
'' CALL Vn
'' Change program counter to offset o within cluster number stored in Vn.
'' The return cluster/offset is pushed onto call stack.
''   0_000_101_00000000_vvvvvvvv_ooooooooo
callVn
         call      #fetchVar           ' Fetch Vn (n in tmp) to data1
         mov       tmp,data1           ' New cluster value (offset left alone)
         jmp       #callCommand        ' Continue with CALL

''
'' BRANCH-IFNOT c:o
'' Change program counter to offset o within cluster c if last COG.
'' command (usually a VariableCOG command) was zero.
''   0_000_010_cccccccccccccccc_ooooooooo
ifnotCommand
         cmp       lastCOGRet,#0 wz
   if_z  jmp       #gotoCommand
         jmp       #mainLoop

''
'' BRANCH-IF c:o
'' Change program counter to offset o within cluster c if last COG.
'' command (usually a VariableCOG command) was non-zero.
''   0_000_011_cccccccccccccccc_ooooooooo
ifCommand
         cmp       lastCOGRet,#0 wz
   if_nz jmp       #gotoCommand
         jmp       #mainLoop   
''
'' GOTO c:o
'' Change program counter to offset o within cluster c.
''   0_000_000_cccccccccccccccc_ooooooooo
gotoCommand
         mov       pc,com              ' Set offset in current cluster
         cmp       tmp,C_FFFF wz       ' If requesting another clsuter ...                  
   if_nz call      #changeCluster      ' ... change to requested cluster 
         jmp       #mainLoop           ' Next command
''
'' CALL c:o
'' Change program counter to offset o within cluster c.
'' The return cluster/offset is pushed onto call stack.
''   0_000_001_cccccccccccccccc_ooooooooo
callCommand
         mov       tmp2,stackPtr       ' Point to next slot in ...
         add       tmp2,#stack         ' ... COG stack memory 
         movd      sp1,tmp2            ' Use this pointer later
         add       stackPtr,#1         ' Bump the stack pointer
         mov       tmp2,clusterNumber  ' Clurent cluster number ...
         shl       tmp2,#9             ' ... shifted to top of long
         mov       t1,pc               ' Program counter ...
         shr       t1,#2               ' ... must be long-aligned (save bits)
         or        tmp2,t1             ' Combine cluster and offset
sp1      mov       0,tmp2              ' Save return cluster/offset on stack
         jmp       #gotoCommand        ' A regular GOTO from here
''
'' RETURN
'' Pop the cluster/offset from the call stack.
''   0_001_0000000000000000000000000000
returnCommand
         sub       stackPtr,#1         '
         mov       tmp2,stackPtr       '
         add       tmp2,#stack         '
         movs      sp2,tmp2            '
         nop                           '
sp2      mov       tmp,0               '
         mov       com,tmp             '
         shr       tmp,#9              '
         and       com,#$1FF           '
         shl       com,#2              '
         jmp       #gotoCommand        '
'
changeCluster
         cmp       tmp,clusterNumber wz ' If the requested cluster is ...
   if_z  jmp       changeCluster_ret    ' ... current cluster, ignore request 
         mov       box,#0               ' The DiskCOG's mailbox
         mov       cStat,C_LOAD_CLUSTER ' LOAD command
         or        cStat,tmp            ' Put requested cluster in command value   
         mov       ofs,baseCluster      ' Our current cluster (releasing)    
         call      #cogTalk             ' Fetch the cluster
         call      #cogTalkWait         ' Wait for reply
         mov       clusterNumber,tmp    ' Current cluster is now loaded      
         mov       baseCluster,data1    ' New memory offset to loaded page                                        
changeCluster_ret  
         ret                     

cogCommand 
         mov       tmp2,#0             ' Short command has no other data
         mov       oneway,com          ' Hold onto oneway flag
         mov       box,com             ' Box number for ...
         shr       box,#27             ' ... short ...
         and       box,#7              ' ... command
         cmp       box,#7   wz         ' Is this a long command?
       
   if_nz jmp       #cc1                ' Nope ... got what we need
         mov       box,com             ' Box number ...
         shr       box,#24             ' ... for ...
         and       box,#7              ' ... long command
         mov       tmp2,com            ' Number ...
         shr       tmp2,#22            ' ... of extra ...
         and       tmp2,#3             ' ... longs
         add       tmp2,#1             ' (At least 1 for a long command)
         mov       ptr,#data1          ' Start dest of additional data

cc4      movd      ccp1,ptr
         mov       tmp,pc              ' PC ...
         add       tmp,baseCluster     ' ... plus base
ccp1     rdlong    0,tmp               ' Get the next CCL command
         add       pc,#4               ' Bump program counter
         add       ptr,#1              ' Bump destination
         djnz      tmp2,#cc4           ' Move all additionals       
       
cc1      and       box,#7              ' Strip top bit of short command
         mov       cStat,com           ' Command
         mov       ofs,baseCluster     ' This cluster's base
       
         call      #cogTalk            ' Send command
         and       oneway,C_ONEWAY wz  ' Check oneway flag
   if_z  call      #cogTalkWait        ' Wait for reply (if not oneway)
         mov       lastCOGRet,data1    ' Remember response        
         jmp       #mainLoop           ' Next command

' -----------------------------------------------------------------------------
' This function sends a command to the requested cog. 
'   box          - mailbox number to send to
'   cStat        - command to send
'   data1-data5  - data words
'   ofs          - offset value
' Returns (next function waits for the reply)
'   com          - return status
'   data1        - return value
'
cogTalk  mov       ptr,box             ' 32 bytes ...
         shl       ptr,#5              ' ... per box                   
         add       ptr,baseBox         ' Point to target box
         add       ptr,#4              ' Write command lastly
cogTalk1 lockset   box wc              ' Wait for lock ... 
   if_nc jmp       #cogTalk1           ' ... on the mailbox  
         wrlong    data1,ptr           ' Write data1
         add       ptr,#4              '
         wrlong    data2,ptr           ' Write data2
         add       ptr,#4              '
         wrlong    data3,ptr           ' Write data3
         add       ptr,#4              '
         wrlong    data4,ptr           ' Write data4
         add       ptr,#4              '
         wrlong    data5,ptr           ' Write data5
         add       ptr,#4              '
         wrlong    data6,ptr           ' Write data6
         add       ptr,#4              '          
         wrlong    ofs,ptr             ' Write the offset              
         sub       ptr,#7*4            ' Now write the ...
         wrlong    cStat,ptr           ' ... command value    
cogTalk_ret
         ret
'
cogTalkWait
         rdlong    com,ptr             ' Wait for ...
         shl       com,#1 nr, wc       ' ... status bit to ...
   if_c  jmp       #cogTalkWait        ' clear out
         add       ptr,#4              ' Read the ...
         rdlong    data1,ptr           ' ... return value
         lockclr   box                 ' Release our lock
cogTalkWait_ret
         ret 

' ----------------------------
' Mailbox parameters to send
'
box    long  0
'
cStat  long  0
data1  long  0
data2  long  0
data3  long  0
data4  long  0
data5  long  0
data6  long  0
ofs    long  0
' ----------------------------
   
com    long  0
tmp    long  0 
tmp2   long  0
ptr    long  0
t1     long  0

baseBox        long  MailboxMemory  ' The base of the mailboxes
clusterNumber  long  $FFFF  ' The code cluster's number. Initially FFFF to force a load.
baseCluster    long  Cluster0 ' The address of the default cluster in memory (just in case)
stackPtr       long  0  ' Next available stack location
pc             long  0  ' Program counter within current cluster
lastCOGRet     long  0  ' Result from last COG command (for conditional flow)
ourBox         long  0  ' Our box number (could be multiple interpreters)
oneway         long  0

C_DEBUG_PIN    long  DebugPin
C_TST long $7900

C_LOAD_CLUSTER long  LoadCluster

C_0FFFFFFF     long  $0F_FF_FF_FF
C_FFFF         long  $00_00_FF_FF
C_ONEWAY       long  $40_00_00_00

'-----------------------------------------------------------
' This function stores a value in a given variable
'   t2 the variable
'   tmp the value
' Returns
'   t2 is automatically incremented for the next store
'
storeVar
         mov       cStat,C_VARST       ' Command to store variable
         mov       data1,t2            ' Destination ...         
         shl       data1,#24           ' ... variable
         mov       data2,tmp           ' Large value
         mov       box,#1              ' Variable COG
         call      #cogTalk            ' Store variable
         call      #cogTalkWait
         add       t2,#1  
storeVar_ret
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
         call      #cogTalkWait
         add       tmp,#1
fetchVar_ret
         ret

' VariableCOG command for variable-set
C_VARST    long    VariableSetCommand
' VariableCOG command for variable-lookup
C_VARLK    long    VariableGetCommand
C_FFF      long    $FFF

t2         long 0
A          long 0
B          long 0
p          long 0


''
'' SAVEVARIABLES BUFFER=b, START=Vs, COUNT=n
'' Write n variables, starting with Vs, to the current cluster at offset b.
'' This command is usually followed by a DiskCOG WRITE. 
''   0_101_1_nnnnnnnn_ssssssss_bbbbbbbbbbb
''
'' LOADVARIABLES BUFFER=b, START=Vs, COUNT=n
'' Read n variables, starting with Vs, from the current cluster at offset b.
''   0_101_0_nnnnnnnn_ssssssss_bbbbbbbbbbb

vario    mov       p,com               ' Pointer ...
         and       p,#$1FF             ' ... to p
         add       p,baseCluster       ' Absolute address
         
         mov       tmp,com             ' Start ...
         shr       tmp,#11             ' ... variable ...
         and       tmp,#255            ' ... number
         
         mov       B,com               ' Number ...
         shr       B,#19               ' ... of ...
         and       B,#255              ' ... variables
         
         mov       A,com               ' Get ...
         shr       A,#27             ' ... I/O ...
         and       A,#1 wz             ' ... direction         
         
  if_z   mov       t2,tmp              ' Zero means ...
  if_z   jmp       #varioInLoop        ' ... input

' tmp = start
' B = cnt
' p = memory pointer

varioOutLoop
         call      #fetchVar           ' Get the next variable value
         wrlong    data1,p             ' Write it to memory        
         add       p,#4                ' Next memory address
         djnz      B,#varioOutLoop     ' Do all
         jmp       #mainLoop           ' Done

' t2 = start
' B = cnt
' p = memory pointer
varioInLoop
         rdlong    tmp,p               ' Get value from memory
         add       p,#4                ' Next memory address
         call      #storeVar           ' Store the variable
         djnz      B,#varioInLoop      ' Do all
         jmp       #mainLoop           ' Done

' #########################################################################
' #########################################################################

' The boot code is only used once. The stack can
' reuse the space.

stack
boot

' Move default CCL to cluster 0    
         mov       com,C_BOOTINFO      ' Boot info passed
         rdword    tmp2,com            ' Source (Default CCL)
         mov       ptr,C_CLUS0         ' Destination (Cluster0)
         mov       tmp,C_2048          ' Size (2K)
         call      #bootMove           ' Move the default CCL 
    
' Move fonts to cluster 1
         add       com,#2
         rdword    tmp2,com            ' Source (Font Tile Data)
         mov       ptr,C_CLUS1         ' Destination (Cluster1)
         add       com,#2
         rdword    tmp,com             ' Size (Passed in)        
         call      #bootMove 
 
' Clear reserved memory
         mov       ofs,#0              ' Clear value
         mov       tmp2,#0             ' Destination (start of memory)
         rdbyte    tmp,C_NUMRES        ' Size (passed in)  
         shl       tmp,#9              ' Size (reserved * 512 longs)   
boot1    wrlong    ofs,tmp2
         add       tmp2,#4
         djnz      tmp,#boot1 
    
' Move fonts to final location
         rdword    tmp,com             ' Re-read the size of font data
         mov       tmp2,C_CLUS1        ' Source (Cluster1)
         add       com,#2
         rdword    ptr,com             ' Destination (passed in)
         call      #bootMove    

' Release cogs
         mov       ofs,#1
         wrbyte    ofs,C_BOOTED

' Send DiskCOG a mount command. If it reports back fail, then
' set the baseCluster to 0 and the cluster offset as if the cluster 
' has already been loaded. That way "changeCluster" from GOTO 0:0 
' will do nothing and we'll run the default CCL program already in 
' memory. Otherwise set the baseCluster to FFFF to force a 
' load on GOTO 0:0.

         mov       box,#0              ' DiskCOG
         mov       cStat,C_MOUNT       ' Mount command
         call      #cogTalk            ' Mount the CFLASH
         call      #cogTalkWait        ' Wait for result
         cmp       data1,#0 wz         ' 0 means OK 
 if_z    jmp       #bootMounted        ' If OK ... GOTO will load cluster 0  

         mov       clusterNumber,#0    ' If not OK, trick GOTO into NOT loading (use default)

bootMounted 
  
' GOTO 0:0
         mov       tmp,#0
         mov       com,#0   
         jmp       #gotoCommand

' tmp  = number of bytes
' tmp2 = source
' ptr  = destination
' (mangles ofs)
bootMove
         rdbyte    ofs,tmp2
         add       tmp2,#1
         wrbyte    ofs,ptr
         add       ptr,#1
         djnz      tmp,#bootMove
bootMove_ret
         ret

C_BOOTINFO  long $7FF8
C_CLUS0     long Cluster0
C_CLUS1     long Cluster1
C_2048      long 2048
C_NUMRES    long NumberReserved
C_BOX0      long MailboxMemory
C_FFFC      long $FFFC

C_MOUNT     long  MountCommand

C_BOOTED    long  SystemBooted

    fit        ' Must fit under COG [$1F0] 