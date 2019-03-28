CON

InputMode = $7813
GC1Data   = $7800
GC2Data   = $7808

' VariableCOG command for get-variable
VariableGetCommand = %1_111_0001__00_000_111_00_10_10_00_0111_1011
' VariableCOG command for variable-set
VariableSetCommand = %1_111_0001__01_000_110_10_00_10_10_0000_1011

KeyStates = $7E2C

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
         jmp       #tokenize           ' 004
         jmp       #vario              ' 005
         jmp       #getInputs          ' 006
         jmp        #mainLoop          ' 007

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
C_P15 long %00000000_00000000_10000000_00000000

' GETINPUTS p
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

baseBox        long  $7E80  ' The base of the mailboxes
clusterNumber  long  $FFFF  ' The code cluster's number. Initially FFFF to force a load.
baseCluster    long  $8000 - 2048*2 ' The address of the default cluster in memory (just in case)
stackPtr       long  0  ' Next available stack location
pc             long  0  ' Program counter within current cluster
lastCOGRet     long  0  ' Result from last COG command (for conditional flow)
ourBox         long  0  ' Our box number (could be multiple interpreters)

C_DEBUG_PIN    long  $08_00_00_00

C_LOAD_CLUSTER long  %1_000__0000___0001_0011___00000000___00000000
 '             long  %1_000__0000___0011_0000___00000000___00000010

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
maxCnt     long 0
buf        long 0
dict       long 0
A          long 0
B          long 0
p          long 0
q          long 0
token      long 0
C_INPUTEND long $FFFE  ' End-of-input value
C_NOTFOUND long $FFFF  ' Token-not-found value

gc1store   long  GC1Data
gc2store   long  GC2Data
inMode     long  InputMode
gcMask     long  %0001111101111111

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

' --------------------------------------------------------------------------------
' [100] TOKENIZE buffer-input, dictionary, max-tokens
'   0 100 mmmm | bbbbbbbb | bbbbdddd | dddddddd
'
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

' #########################################################################
' #########################################################################

' The boot code is only used once. The stack can
' reuse the space.

stack   ' Here to the bottom is 51 addresses. Advertise 50 levels max.
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
C_CLUS0     long $8000 - 2048*2
C_CLUS1     long $8000 - 2048*3
C_2048      long 2048
C_NUMRES    long $7810
C_BOX0      long $7E80
C_FFFC      long $FFFC

C_MOUNT     long  %1_000__0000___0000_0000___00000000___00000000

C_1111      long $04_04_01_01

    fit        ' Must fit under COG [$1F0] 