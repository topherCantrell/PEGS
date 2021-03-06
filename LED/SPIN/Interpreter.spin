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
'' various configuration tables to system memory. 
''
'' The Boot.spin starts all the COGs. All the COGS are designed to stall until
'' a global "GO" flag is set in system memory. The Boot.spin writes the address
'' of the default MIX program (runs if an SD card is not present).
''
'' The Interpreter continues the boot process when it starts. It clears the
'' reserved 2K pages at the beginning of RAM and moves the default MIX program
'' to page 14 (as far away from LED/Sound memory as possible allowing a program
'' to safely extend the reserved memory if needed).
''
'' Next the Interpreter releases the COGs by writing the global "GO" flag.
''
'' The Interpreter requests a MOUNT and attempts to load cluster 0 into
'' page 14 (over the default program). Then it begins executing the MIX program
'' at offset 0. 

CON
      
DebugPin = %00000000_10000000_00000000_00000000

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

{
InputMode = $7813
GC1Data   = $7800
GC2Data   = $7808
KeyStates = $7E2C
}

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
         jmp       #memCopyCommand     ' 006
         jmp       #executeCommand     ' 007

'' MEMCOPY SRC, DST, LEN
'' 0_110_0n_nnnnnnnn__s_ssssssss__d_dddddddd
'' s is LONG address
'' d is LONG address
'' n is number of LONGS
memCopyCommand
         mov       ptr, com            ' Pull ...
         shr       ptr,#9              ' ... the ...
         and       ptr,#$1FF           ' ... source address
         shl       ptr,#2              ' LONG aligned
         add       ptr,baseCluster     ' Within our cluster

         mov       tmp, com            ' Pull ...                      
         and       tmp,#$1FF           ' ... the dest address
         shl       tmp,#2              ' LONG aligned         

         shr       com,#18             ' Pull the ...
         and       com,#$1FF            ' ... number of longs
memC1
         rdlong    tmp2,ptr            ' Read long
         add       ptr,#4              ' Next source
         wrlong    tmp2,tmp            ' Write long
         add       tmp,#4              ' Next destination
         djnz      com,#memC1          ' Do all LONGs

         jmp       #mainLoop           ' Next command     

''
'' EXECUTE COG=c, PAR=p
'' Load the following binary data into COG c and execute it with
'' given PAR value. The binary code must follow the EXECUTE
'' command with a 4 byte gap between (usually an added STOP command).
'' An implicit RETURN is made after the EXECUTE command.
''   0_111_0000_00000ccc_pppppppp_pppppppp
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

         ' tmp = cluster, com = offset

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
          ' tmp = cluster, com = offset  
         mov       tmp,data1           ' New cluster value (offset left alone)
         jmp       #gotoCommand        ' Continue with GOTO

''
'' CALL Vn
'' Change program counter to offset o within cluster number stored in Vn.
'' The return cluster/offset is pushed onto call stack.
''   0_000_101_00000000_vvvvvvvv_ooooooooo
callVn
        mov tmp,#0
         call      #fetchVar           ' Fetch Vn (n in tmp) to data1
         ' tmp = cluster, com = offset 
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


''
'' GETJOYSTICK Vn
'' Read the joystick/button inputs to the given variable.
'' Return format in Vn: 000S000F0rsudrl
''   0_110_0000_00000000_0000_vvvvvvvv
{
getJoystick

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
    if_z or         B,#1
         and       tmp,#4 nr, wz
    if_z or        A,#2
         and       tmp,#8 nr, wz
    if_z or        A,#4
         and       tmp,#16 nr, wz
    if_z or         B,#16
         and       tmp,#32 nr, wz
    if_z or         B,#2
         and       tmp,#64 nr, wz
    if_z or        A,#16
         and       tmp,#128 nr, wz
    if_z or        A,#1
         
         mov       tmp,A
         shl       B,#8
         or        tmp,B 

         call      #storeVar           ' Store the result
         jmp       #mainLoop           ' Done
}

''
'' GETINPUTS p,var
'' Get input for players based on input mode (keyboard or pads)
'' Return 16 bit format is: 000SYXBA0LRZudrl
''   0_110_p_000_00000000_00000000_vvvvvvvv
{
getInputs
'
' Return 16 bit format is:
'000SYXBA0LRZudrl
'
         mov       t2,com              ' Result variable ...
         and       t2,#255             ' ... to t2 (for storeVar)
         shr       com,#27             ' Player number in 1st bit

         rdbyte    t1,inMode           ' Input driver type
         cmp       t1,#3 wz            ' Go handle ...
  if_z   jmp       #getInKB            ' ... keyboard decode

         and       com,#1 wz           ' Pick ... 
  if_z   mov       ptr,gc1Store        ' ... GC1 data or ...
  if_nz  mov       ptr,gc2Store        ' ... GC2 data

         rdlong    tmp,ptr             ' Get the correct player's data
         shr       tmp,#16             ' Only interested in switches
         and       tmp,gcMask          ' Make the unused bits 0
         call      #storeVar           ' Store the result
         jmp       #mainLoop           ' Done

getInKB
         rdbyte    V_24,K_24
         rdbyte    V_11,K_11
         rdbyte    V_4,K_4
         rdbyte    V_30,K_30
         rdbyte    V_1,K_1
         rdbyte    V_6,K_6
         rdbyte    V_15,K_15
         rdbyte    V_14,K_14
         rdbyte    V_12,K_12
         rdbyte    V_25,K_25
         
         and       com,#1 wz           ' If player 2 ...
  if_nz  jmp       #getInKB2           ' ... go decode those keys

' Player 1 decode
' 000 S   Y     X      B     A    0 L R Z u d r l
' 000 1 enter r-ctrl r-alt space  0 [ ] \ u d r l

         mov       tmp,V_24
         and       tmp,#3
         and       V_24,#8 nr, wz
  if_nz  or        tmp,#4
         and       V_24,#4 nr, wz
  if_nz  or        tmp,#8
         and       V_11,#16 nr, wz
  if_nz  or        tmp,#16
         and       V_11,#32 nr, wz
  if_nz  or        tmp,#32
         and       V_11,#8 nr,wz
  if_nz  or        tmp,#64
  
         mov       A,V_4         
         and       A,#1
         and       V_30,#32 nr, wz
  if_nz  or        A,#2
         and       V_30,#8 nr, wz
  if_nz  or        A,#4
         and       V_1,#32 nr, wz
  if_nz  or        A,#8
         and       V_6,#2 nr, wz
  if_nz  or        A,#16

getInKBS    
         shl       A,#8
         or        tmp,A 

         call      #storeVar           ' Store the result
         jmp       #mainLoop           ' Done

getInKB2

' Player 2 decode
' 000 S   Y     X      B     A    0 L R Z u d r l
' 000 2  tab   esc   l-alt l-crtl 0 q w e s x c z

         mov       tmp,#0
         mov       A,#0

         and       V_15,#4 nr, wz
  if_nz  or        tmp,#1
         and       V_12,#8 nr, wz
  if_nz  or        tmp,#2
         and       V_15,#1 nr, wz
  if_nz  or        tmp,#4
         and       V_14,#8 nr, wz
  if_nz  or        tmp,#8
         and       V_12,#32 nr, wz
  if_nz  or        tmp,#16
         and       V_14,#128 nr, wz
  if_nz  or        tmp,#32
         and       V_14,#2 nr, wz
  if_nz  or        tmp,#64

         and       V_30,#4 nr, wz
  if_nz  or        A,#1
         and       V_30,#16 nr, wz
  if_nz  or        A,#2
         and       V_25,#8 nr, wz
  if_nz  or        A,#4
         and       V_1,#2 nr, wz
  if_nz  or        A,#8
         and       V_6,#4 nr, wz
  if_nz  or        A,#16      
         jmp       #getInKBS

K_24 long KeyStates+24
K_11 long KeyStates+11
K_4  long KeyStates+4
K_30 long KeyStates+30
K_1  long KeyStates+1
K_6  long KeyStates+6
K_15 long KeyStates+15
K_14 long KeyStates+14
K_12 long KeyStates+12
K_25 long KeyStates+25

V_24 long 0
V_11 long 0
V_4  long 0
V_30 long 0
V_1  long 0
V_6  long 0
V_15 long 0
V_14 long 0
V_12 long 0
V_25 long 0
'C_P15 long %00000000_00000000_10000000_00000000
gc1store   long  GC1Data
gc2store   long  GC2Data
inMode     long  InputMode
gcMask     long  %0001111101111111
}
 
''
'' TOKENIZE buffer-input, dictionary, max-tokens
''   0_100_mmmm_bbbbbbbbbbbb_dddddddddddd
{
tokenize

         mov       t2,#0               ' We always store in variable 0 and up         

         mov       buf,com             ' Strip ...
         shr       buf,#12             ' ... buffer ...
         and       buf,C_FFF           ' ... offset
         add       buf,baseCluster     ' Absolute address
         
         mov       dict,com            ' Strip dict ...
         and       dict,C_FFF          ' ... offset
         add       dict,baseCluster    ' Absolute address
         
         mov       maxCnt,com          ' Strip ...
         shr       maxCnt,#24          ' ... max-count ...
         and       maxCnt,#15          ' ... field

         add       maxCnt,#1           ' We exit on 0          

findNextInputWord
         sub       maxCnt,#1 wz        ' Processed all the words we wanted?
  if_z   jmp       #mainLoop           ' Yes ... done
stripSpace
         rdbyte    A,buf               ' Get next user input character            
         cmp       A,#32 wz            ' Is it white space?
  if_nz  jmp       #noSpaces           ' No ... go use it from here
         add       buf,#1              ' Skip over ...
         jmp       #stripSpace         ' ... whitespace
noSpaces cmp       A,#0 wz             ' Is this the end of the user input? 
  if_nz  jmp       #doNextInputWord    ' No ... go proecess it
         mov       tmp,C_INPUTEND      ' End of input marker
         call      #storeVar           ' Store variable
         jmp       #mainLoop           ' Done
         
doNextInputWord         

         mov       q,dict              ' Start of dictionary (several passes)

getNextToken
         rdbyte    token,q             ' First byte of token 
         add       q,#1                ' Bump pointer
         rdbyte    A,q                 ' Second byte of pointer
         add       q,#1                ' Bump pointer
         shl       A,#8                ' Combine bytes ...
         or        token,A             ' ... LSB first 
         cmp       token,C_FFFF wz     ' End of token list?
  if_nz  jmp       #checkNextToken     ' No ... go check it
         mov       tmp,C_NOTFOUND      ' Token not found marker
         call      #storeVar           ' Store variable
skipInputWord
         rdbyte    A,buf               ' Get input character
         cmp       A,#0 wz
  if_z   jmp       #findNextInputWord  ' Zero ... end of word         
         cmp       A,#32 wz            ' Is it a space?
  if_z   jmp       #findNextInputWord  ' Yes ... end of word          
         add       buf,#1              ' Skip over character         
         jmp       #skipInputWord      ' Skip to end of word

checkNextToken         
         mov       p,buf               ' Keep start of word intact           
         
cmpToken rdbyte    A,p                 ' Get next input character
         add       p,#1                ' Bump input pointer
           
         cmp       A,#$61 wz,wc        ' Lowercase A
  if_b   jmp       #cmpIsUp            ' Below that ... no need to upper it
         cmp       A,#$7A wz,wc        ' Lowercase Z
  if_a   jmp       #cmpIsUp            ' Above that ... no need to upper it
         andn      A,#32               ' Convert lower to upper
            
cmpIsUp  rdbyte    B,q                 ' Get next character from token   
         add       q,#1                ' Bump token pointer
         cmp       B,#0 wz             ' Are we at the end of the token?
  if_z   jmp       #atEndOfToken       ' Yes ... go see if input-word is ended 
         cmp       A,B wz              ' Are the characters the same?         
  if_z   jmp       #cmpToken           ' Yes ... go keep checking   
        
skipToEndOfToken
         rdbyte    B,q                 ' Get next character from token
         add       q,#1                ' Bump token pointer
         cmp       B,#0 wz             ' At end of token?
  if_nz  jmp       #skipToEndOfToken   ' No ... go to next character
         jmp       #getNextToken       ' We know this doesn't match

atEndOfToken
         cmp       A,#32 wz            ' End of token. End of word too?
  if_z   jmp       #tokenFound         ' Space means end of word
         cmp       A,#0 wz             ' Zero means end of word
  if_nz  jmp       #getNextToken       ' Something else ... no match
         sub       p,#1                ' Don't skip the 0

tokenFound 
         mov       tmp,token           ' Store token ...
         call      #storeVar           ' ... in next variable
         mov       buf,p               ' Skip over the word
         jmp       #findNextInputWord  ' Start a new word

maxCnt     long 0
buf        long 0
dict       long 0
q          long 0
token      long 0
C_INPUTEND long $FFFE  ' End-of-input value
C_NOTFOUND long $FFFF  ' Token-not-found value
}    

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
 
' Clear reserved memory
         mov       ofs,#0              ' Clear value
         mov       tmp2,#0             ' Destination (start of memory)
         rdbyte    tmp,C_NUMRES        ' Size (passed in)  
         shl       tmp,#9              ' Size (reserved * 512 longs)   
boot1    wrlong    ofs,tmp2
         add       tmp2,#4
         djnz      tmp,#boot1
                  
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

CONTROL  long $7F6C 

    fit        ' Must fit under COG [$1F0] 