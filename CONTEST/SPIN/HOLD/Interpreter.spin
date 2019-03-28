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
  
  coginit(0,@Interpreter,$FFFC)

DAT      
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
         jmp        #mainLoop          ' 007

' GETINPUTS p
getInputs

         mov       t2,com              ' Result variable ...
         and       t2,#255             ' ... to t2 (for storeVar)
         
         mov       A,#0                ' Final ...
         mov       B,#0                ' ... value     

         mov       tmp,ina             ' Read ...
         shr       tmp,#14             ' ... switch ...
         and       tmp,#$FF            ' ... inputs

         and       tmp,#1 nr, wz
    if_z or        A,#8
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

' DEBUG v
debugCommand
         and       com,#1 wz           ' 1 or 0
   if_z  andn      outa,C_DEBUG_PIN    ' 0 = LED off
   if_nz or        outa,C_DEBUG_PIN    ' 1 = LED on
         jmp       #mainLoop           ' Done

' PAUSE v
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
         jmp       #mainLoop           '
stop     jmp       #stop               '

' GOTO Vn
gotoVn
         call      #fetchVar           ' Fetch Vn (n in tmp) to data1
         mov       tmp,data1           ' New cluster value (offset left alone)
         jmp       #gotoCommand        ' Continue with GOTO

' CALL Vn
callVn
         call      #fetchVar           ' Fetch Vn (n in tmp) to data1
         mov       tmp,data1           ' New cluster value (offset left alone)
         jmp       #callCommand        ' Continue with CALL

' BRANCH-IF
ifCommand
         cmp       lastCOGRet,#0 wz
   if_nz jmp       #gotoCommand
         jmp       #mainLoop

' BRANCH-IFNOT
ifnotCommand
         cmp       lastCOGRet,#0 wz
   if_nz jmp       #mainLoop   

' GOTO
gotoCommand  
         cmp       tmp,C_FFFF wz
         mov       pc,com
   if_nz call      #changeCluster       
         jmp       #mainLoop

' CALL
callCommand
         mov       tmp2,stackPtr
         add       tmp2,#stack
         movd      sp1,tmp2
         add       stackPtr,#1
         mov       tmp2,clusterNumber
         shl       tmp2,#9
         mov       t1,pc
         shr       t1,#2
         or        tmp2,t1       
sp1      mov       0,tmp2
         jmp       #gotoCommand

' RETURN
returnCommand
         sub       stackPtr,#1
         mov       tmp2,stackPtr
         add       tmp2,#stack
         movs      sp2,tmp2
         nop
sp2      mov       tmp,0
         mov       com,tmp
         shr       tmp,#9
         and       com,#$1FF
         shl       com,#2
         jmp       #gotoCommand   

changeCluster
         cmp       tmp,clusterNumber wz ' Are we already using the requested cluster?
   if_z  jmp       changeCluster_ret    ' Yes ... ignore this request
         mov       box,#0               ' The DiskCOG
         mov       cStat,C_LOAD_CLUSTER ' CACHE command (passes current cluster)
         or        cStat,tmp            ' Put cluster in command   
         mov       ofs,baseCluster      ' Our current cluster (we are releasing our hold on it)    
         call      #cogTalk             ' Fetch the cluster
         mov       clusterNumber,tmp    ' Assume it works. Nothing else to do if it doesn't.      
         mov       baseCluster,data1    ' New memory offset                                        
changeCluster_ret  
         ret                     

cogCommand 
         mov       tmp2,#0             ' Short command has no other data
         mov       box,com             ' Box number for ...
         shr       box,#28             ' ... short command
         cmp       box,#$0F wz         ' Is this a long command?
       
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
         mov       lastCOGRet,data1    ' Remember response        
         jmp       #mainLoop           ' Next command

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
       mov       ptr,box        ' 32 bytes ...
       shl       ptr,#5         ' ... per box                   
       add       ptr,baseBox    ' Point to target box
       add       ptr,#4         ' Save command for last
cogTalk1
       lockset   box wc         ' Get the lock ... 
 if_nc jmp       #cogTalk1      ' ... on the mailbox  
       wrlong    data1,ptr      ' Write the data
       add       ptr,#4
       wrlong    data2,ptr
       add       ptr,#4
       wrlong    data3,ptr
       add       ptr,#4
       wrlong    data4,ptr
       add       ptr,#4
       wrlong    data5,ptr
       add       ptr,#4
       wrlong    data6,ptr
       add       ptr,#4
       wrlong    ofs,ptr        ' Write the offset              
       sub       ptr,#7*4       ' Back to command now
       wrlong    cStat,ptr      ' Write the command
cogTalk2
       rdlong    com,ptr        ' Wait for ...
       shl       com,#1 nr, wc  ' ... status bit to ...
 if_c  jmp       #cogTalk2      ' clear out
       add       ptr,#4         ' Read the ...
       rdlong    data1,ptr      ' ... return value
       lockclr   box            ' Release our lock
cogTalk_ret
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

C_DEBUG_PIN    long  DebugPin

C_LOAD_CLUSTER long  LoadCluster

C_0FFFFFFF     long  $0F_FF_FF_FF
C_FFFF         long  $00_00_FF_FF

' #########################################################################
' #########################################################################
' The VideoCOG filled up, so we overflow the tokenize function into
' the interpreter.   

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

' VariableCOG command for variable-set
C_VARST    long    VariableSetCommand
' VariableCOG command for variable-lookup
C_VARLK    long    VariableGetCommand
C_FFF      long    $FFF

t2         long 0
A          long 0
B          long 0
p          long 0

' --------------------------------------------------------------------------------
' [101] VARIO inOut,plabel(word aligned), start, number
' 0 101 innn | nnnnnsss | sssssppp| pppppppp

vario

         mov       p,com               ' Pointer ...
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
        call      #fetchVar            ' Get the next variable value
        wrlong    data1,p              ' Write it to memory        
        add       p,#4                 ' Next memory address
        djnz      B,#varioOutLoop      ' Do all
        jmp       #mainLoop            ' Done

' t2 = start
' B = cnt
' p = memory pointer
varioInLoop
        rdlong   tmp,p                 ' Get value from memory
        add      p,#4                  ' Next memory address
        call     #storeVar             ' Store the variable
        djnz     B,#varioInLoop        ' Do all
        jmp      #mainLoop             ' Done

' #########################################################################
' #########################################################################

' The boot code is only used once. The stack can
' reuse the space.

stack
boot

' Move default CCL to cluster 0    
    mov      com,C_BOOTINFO  ' Boot info passed
    rdword   tmp2,com        ' Source (Default CCL)
    mov      ptr,C_CLUS0     ' Destination (Cluster0)
    mov      tmp,C_2048      ' Size (2K)
    call     #bootMove       ' Move the default CCL 
    
' Move fonts to cluster 1
    add     com,#2
    rdword  tmp2,com         ' Source (Font Tile Data)
    mov     ptr,C_CLUS1      ' Destination (Cluster1)
    add     com,#2
    rdword  tmp,com          ' Size (Passed in)        
    call    #bootMove 
 
' Clear reserved memory
    mov     ofs,#0           ' Clear value
    mov     tmp2,#0          ' Destination (start of memory)
    rdbyte  tmp,C_NUMRES     ' Size (passed in)  
    shl     tmp,#9           ' Size (reserved * 512 longs)   
boot1
    wrlong  ofs,tmp2
    add     tmp2,#4
    djnz    tmp,#boot1 
    
' Move fonts to final location
    rdword  tmp,com          ' Re-read the size of font data
    mov     tmp2,C_CLUS1     ' Source (Cluster1)
    add     com,#2
    rdword  ptr,com          ' Destination (passed in)
    call    #bootMove    

' Release cogs
    mov  ofs,#1
    mov  com,#6
boot2
    wrlong ofs,C_BOX0
    add  C_BOX0,#32
    djnz  com,#boot2    

' Send DiskCOG a mount command. If it reports back fail, then
' set the baseCluster to 0 and the cluster offset as if the cluster 
' has already been loaded. That way "changeCluster" from GOTO 0:0 
' will do nothing and we'll run the default CCL program already in 
' memory. Otherwise set the baseCluster to FFFF to force a 
' load on GOTO 0:0.

      mov    box,#0           ' DiskCOG
      mov    cStat,C_MOUNT    ' Mount command
      call   #cogTalk         ' Mount the CFLASH 
      cmp    data1,#0 wz      ' 0 means OK 
 if_z jmp   #bootMounted      ' If OK ... GOTO will load cluster 0  

      mov   clusterNumber,#0  ' If not OK, trick GOTO into NOT loading (use default)

bootMounted 
  
' GOTO 0:0
    mov  tmp,#0
    mov  com,#0   
    jmp  #gotoCommand

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

    fit        ' Must fit under COG [$1F0] 