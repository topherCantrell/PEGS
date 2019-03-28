' -------------------------------------------------------------------------------
''VariableCOG.spin
'' 
'' Copyright (C) Chris Cantrell October 11, 2008
'' Part of the PEGS project (PEGSKIT.com)
''
'' The VariableCOG houses the 128 LONG variables available to MIX programs.
'' This COG implements basic data manipulation expression in the following
'' format:
''
''  DEST ending LEFT operation RIGHT
''   V0    =    V1      +        5   (for example)
''
'' All of the fields are optional, and variables may be dereferenced for
'' indirect variable access. Here are some assignment examples:
''
''   V10 = V2 + 123
''   V2 = 0
''   [V1] = [V2] << 4
''   current[V8] = mem(V4) & rand
''
'' Ending operations include comparisons usually coupled with the Interpreter's
'' BRANCH-IF and BRANCH-IFNOT instructions (see Interpreter.spin). The final
'' result of the expression is returned to the caller.
''
''   5 <= V1 & 0b1101
''   V4 & 0xFF
''   V8
''   nextKey == 0
''
''##### EXPRESSION COMMAND ENCODING #####
''
'' Variable expressions are common in MIX programs, and this encoding format
'' is intended to reduce the size of common commands at the expense of
'' encoding and parser complexity. A program like the MIX compiler is the best
'' way to generate these encodings.
''
'' All expression are coded in the following format:
''   1_111_0_bbb__ss_000_DLR__xy_dd_ll_rr__pppp_eeee
''   ... additional LONGs as needed ...
''
'' The b and s fields are normal COG command encoding (see Interpreter.spin).
''
'' eeee ending    :  =, ==, !=, <, <=, >, >=, NOTHING (return op result)
'' oooo operation :  +, -, *, /, %, <<, >> &, |, ^, ~, NOTHING (use right)
''
'' The DLR bits indicate the size of the DEST, LEFT, and RIGHT fields.
'' A 1 means the field is short. A 0 means the field is a full LONG.
'' If any of the DLR bits are one, the first additional data LONG is:
''   DDDDDDDD_LLLLLLLLLLLL_RRRRRRRRRRRR
'' Additional LONGS follow as needed for large DEST, LEFT, and RIGHT in that
'' order.
''
'' The x and y bits indidicate if a field is used. X=1 if DEST is used.
'' Y=1 if LEFT is used. An unused field defaults to 0 and consumes no space
'' in the command encoding.
''
'' The d, l, and r bits indicate the type of the field as follows:
''   00 = Constant (large or small field)
''   01 = Variable reference (always small field)
''   10 = Indirect variable reference (always small field)
''   11 = Special type (see below ... always large field)
''
'' Special type fields are interpreted as follows:
''   000000ss_00000ttt_vvvvvvvvvvvvvvvv
''     ss is size of access (where applicable) 1, 2, or 4 bytes.
''     tt is the special type:
''       000  RAM access (v is address)
''       001  Indirect RAM access (v is the variable holding address)
''       010  RAM in current cluster (v is the variable holding offset)
''       100  Register in VariableCOG (v is the register address)
''       101  Random value (write to set seed)
 
CON

RandomSeedStart = $00_B4_F0_1A

VariableBoxNumber  = 1
VariableCOGNumber  = 1  

MailboxMemory = $7E80
SystemBooted  = $7812 
 

PUB start 
'' Start the VariableCOG  
  coginit(VariableCOGNumber,@VariableCOG,0)

DAT      
         org 0

VariableCOG 
  
stall    rdbyte    tmp,C_BOOTED wz    ' Wait for ...
  if_z   jmp       #stall              ' ... interpreter to boot

main     rdlong    tmp,boxComStat      ' Read the command
         shl       tmp,#1 nr, wc       ' If upper bit is clear ...
   if_nc jmp       #main               ' ... keep waiting for command   

' Parse the processing operations and flags

         mov       abc,tmp             ' Get ...
         shr       abc,#16             ' ... the ...
         and       abc,#7              ' ... abc status
         
         mov       flags,tmp           ' Get ...
         shr       flags,#8            ' ... the ...
         and       flags,#$FF          ' ... FLAGS
         
         mov       process,tmp         ' Get ...
         shr       process,#4          ' ... the ...
         and       process,#$0F        ' ... PROCESS
         
         mov       op,tmp              ' Get the ...
         and       op,#$0F             ' ... OP         

' Parse the 1 or 4 byte values as given

         mov       ptr,boxDat2         ' Be ready for multiple words         
         rdlong    tmp,boxDat1Ret      ' 1st data has any single-byte values  
         
         mov       tmpD,tmp            ' If D is single-byte ...
         shr       tmpD,#24            ' ... then this ... 
         and       tmpD,#$FF           ' ... is its value
         mov       tmpL,tmp            ' If L is single-byte ...
         shr       tmpL,#12            ' ... then this ...
         and       tmpL,C_FFF          ' ... is its value
         mov       tmpR,tmp            ' If R is single-byte then this ...
         and       tmpR,C_FFF          ' ... is its value

         mov       tmpX,flags          ' Line DL ..
         shr       tmpX,#6             ' ... over ...
         shl       tmpX,#1             ' ... a and b
         or        tmpX,#1             ' R is always used     
         
         and       tmpX,abc nr,wz      ' First long contains singles?
  if_z   jmp       #parse1             ' No ... use first long as-is  
  
         rdlong    tmp,ptr             ' Next long 
         add       ptr,#4              ' Advance long pointer 
         
parse1   and       abc,#4 nr,wz        ' Is D 4 bytes? 
  if_nz  jmp       #parse2             ' No ... skip over   
         mov       tmpD,tmp            ' Use the full 32 bit value       
         rdlong    tmp,ptr             ' In case we need next. 
         add       ptr,#4              ' Advance long pointer
         
parse2   and       abc,#2 nr,wz        ' Is D 4 bytes?
  if_nz  jmp       #parse3             ' No ... skip over
         mov       tmpL,tmp            ' Use the full 32 bit value         
         rdlong    tmp,ptr             ' In case we need next. 
         add       ptr,#4              ' Advance long pointer 
                                                                 
parse3   and       abc,#1 nr,wz        ' Is R short?
  if_nz  jmp       #parse4             ' Yes ... we have it         
         mov       tmpR,tmp            ' Use the full 32 bit value 

' Get the actual values for LEFT and RIGHT ... variable, [variable], or special
  
parse4   mov       tmpX,tmpR           ' tmpR value
         mov       flagX,flags         ' R ...          
         and       flagX,#3            ' ... flags
         call      #getValue           ' Get L value         
         mov       tmpR,tmpX           ' Move it to R         
         
         and       flags,#64 nr,wz     ' Is the L even used?
 if_z    jmp       #parse5             ' No ... skip
         mov       tmpX,tmpL           ' tmpL value
         mov       flagX,flags         ' L ...
         shr       flagX,#2            ' ... ... 
         and       flagX,#3            ' ... flags
         call      #getValue           ' Get L value
         mov       tmpL,tmpX           ' Move it to L         
 
' Do OP on LEFT and RIGHT
 
parse5   add       op,#opTable         ' Execute ...         
         jmp       op                  ' ... numbered routine

opTable  jmp       #opAdd              '
         jmp       #opSub              '
         jmp       #opMultiply         '
         jmp       #opDivide           '
         jmp       #opModulo           '
         jmp       #opLeft             '
         jmp       #opRight            '
         jmp       #opAND              '
         jmp       #opOR               '
         jmp       #opXOR              '
         jmp       #opNOT              '
         jmp       #doNothing          '         
         
doNothing

         mov       tmpL,tmpR           ' Invalid ... use RIGHT value
         
' Process PROCESS and DEST

handleResult

         cmp       process,#0 wz       ' Handle ...
    if_z jmp       #prAssign           ' ... assignment

         and       flags,#128 nr,wz    ' Every other op depends on D's value
 if_z    jmp       #parse6             ' D used? No ... skip
         mov       tmpX,tmpD           ' tmpD value
         mov       flagX,flags         ' D ...
         shr       flagX,#4            ' ... ...
         and       flagX,#3            ' ... flags
         call      #getValue           ' Get D value
         mov       tmpD,tmpX           ' Move it to D

parse6   add       process,#procTable  ' Execute ...
         jmp       process             ' ... numbered routine
         
procTable
         jmp       #prAssign           ' 
         jmp       #prEquals           '
         jmp       #prNotEquals        '
         jmp       #prLess             '
         jmp       #prLessEquals       '
         jmp       #prGreater          '
         jmp       #prGreaterEquals    '
         jmp       #final              '         
         
final    wrlong    tmpL,boxDat1Ret     ' Final result from tmpL               
         mov       tmpL,#1             ' Return ...
         wrlong    tmpL,boxComStat     ' ... status (Done)
         jmp       #main               ' Next command

' --------------------------------------------------------------------------------------
' Operations
                                                  
opAdd    add       tmpL,tmpR 
         jmp       #handleResult
opSub    sub       tmpL,tmpR
         jmp       #handleResult
opLeft   shl       tmpL,tmpR
         jmp       #handleResult
opRight  shr       tmpL,tmpR
         jmp       #handleResult
opAND    and       tmpL,tmpR
         jmp       #handleResult
opOR     or        tmpL,tmpR
         jmp       #handleResult  
opXOR    xor       tmpL,tmpR
         jmp       #handleResult
opNOT    xor       tmpR,C_FFFFFFFF
         mov       tmpL,tmpR
         jmp       #handleResult

opMultiply
         mov       t1,tmpL
         and       t1,C_FFFF
         mov       t2,tmpR
         and       t2,C_FFFF
         call      #multiply
         mov       tmpL,t1
         jmp       #handleResult

opDivide         
         mov       t1,tmpL
         and       t1,C_FFFF
         mov       t2,tmpR
         and       t2,C_FFFF
         call      #divide         
         mov       tmpL,t1
         and       tmpL,C_FFFF         
         jmp       #handleResult

opModulo
         mov       t1,tmpL
         and       t1,C_FFFF
         mov       t2,tmpR
         and       t2,C_FFFF
         call      #divide         
         mov       tmpL,t1
         shr       tmpL,#16
         and       tmpL,C_FFFF         
         jmp       #handleResult  

' --------------------------------------------------------------------------------------
' Processes

prEquals
         cmp       tmpD,tmpL wz
  if_z   mov       tmpL,#1
  if_nz  mov       tmpL,#0
         jmp       #final

prNotEquals
         cmp       tmpD,tmpL wz
  if_nz  mov       tmpL,#1
  if_z   mov       tmpL,#0
         jmp       #final

prLess
         cmp       tmpD,tmpL wz, wc
  if_b   mov       tmpL,#1
  if_ae  mov       tmpL,#0
         jmp       #final

prLessEquals
         cmp       tmpD,tmpL wz, wc
  if_be  mov       tmpL,#1
  if_a   mov       tmpL,#0
         jmp       #final

prGreater
         cmp       tmpD,tmpL wz, wc
  if_a   mov       tmpL,#1
  if_be  mov       tmpL,#0
         jmp       #final

prGreaterEquals
         cmp       tmpD,tmpL wz, wc
  if_ae  mov       tmpL,#1
  if_b   mov       tmpL,#0
         jmp       #final

' -------------------------------------------------------------------------------------
' Set numeric value of term
' tmpD is destination
' flags is type-flags
' tmpL is value
prAssign and       flags,#128 nr,wz    ' If DEST is not used ...
  if_z   jmp       #final              ' ... skip assignment 
         and       flags,#32 nr,wz     ' DEST special?
  if_nz  jmp       #prAssignSpecial    ' Yes ... go do it 
         and       flags,#16 nr,wz     ' Indirect?
  if_z   jmp       #prA1               ' No ... go store 
         add       tmpD,#varMem        ' Index into variable memory
         movs      sv1,tmpD            ' Store register ...
         nop                           ' ... into pointer source
sv1      mov       tmpD,0              ' Lookup the value
prA1     add       tmpD,#varMem        ' Index into variables
prA2     movd      sv2,tmpD            ' Store destination ...
         nop                           ' ... into pointer
sv2      mov       0,tmpL              ' Put TMPL into variable or register
         jmp       #final              ' Finish up

' Store special value
' ss_tt__vvvv
' ss = 1,2 or 4
' tt:
' 0      mem[constant]            ss
' 1      mem[Vn]                  ss
' 2      cluster[Vn]              ss
' 3      ignored
' 4      localRegister            long
' 5      random seed              long
prAssignSpecial
         mov       flagX,tmpD          ' Get ...
         shr       flagX,#16 wz        ' ... number of ...
         mov       numBytes,flagX      ' ... bytes ...
         shr       numBytes,#8         ' ... and ...
         and       flagX,#255          ' ... type
         and       tmpD,C_FFFF        ' Value without specialness

         add       flagX,#storeSpecial ' Execute ...
         jmp       flagX               ' ... numbered routine

storeSpecial
         jmp       #svMem              ' 0 = mem[constant] (ss bytes)
         jmp       #svMemV             ' 1 = mem[Vn] (ss bytes)
         jmp       #svLocal            ' 2 = cluster[Vn] (ss bytes)
         jmp       #final              ' 3 = ignored
         jmp       #prA2               ' 4 = localRegister (4 bytes)                  
         jmp       #svSeed             ' 5 = random seed (4 bytes)


svLocal  rdlong    t1,boxOfs           ' Get offset to current sector
         and       tmpD,#$FF           ' Get the register value
         add       tmpD,#varMem        ' Index into register array
         movs      svLV,tmpD           ' Get ...
         nop                           ' .... variable ...
svLV     mov       tmpD,0              ' ... value
         add       tmpD,t1             ' Add our local index
         jmp       #svMem              ' Store byte, word, or long
            
svMemV   and       tmpD,#$FF           ' Get the register value
         add       tmpD,#varMem        ' Index into register array
         movs      svV,tmpD            ' Get ...
         nop                           ' .... variable ...
svV      mov       tmpD,0              ' ... value


svMem    cmp       numBytes,#1 wz      ' Write tmpL ...
  if_z   wrbyte    tmpL,tmpD           ' ... to memory ...
  if_z   jmp       #final              ' ... at tmpD ...
         cmp       numBytes,#2 wz      ' ... as byte ...
  if_z   wrword    tmpL,tmpD           ' ... word ...
  if_nz  wrlong    tmpL,tmpD           ' ... or long
         jmp       #final              ' Finish up

svSeed   mov       randomSeed,tmpL     ' Set random seed
         jmp       #final              ' Finish up  

' -------------------------------------------------------------------------------------
' Get numeric value of term
' tmpX is value (tmpL, tmpR, tmpD)
' flagX is type-flags
getValue
         cmp       flagX,#2 wz         ' 2 means constant
  if_z   jmp       #getValue_ret       ' If it is a constant, we have it  
         cmp       flagX,#3 wz         ' 3 means special
  if_z   jmp       #getValueSpecial    ' Go do specials 
         add       flagX,#1            ' At least one lookup (two if indirect)
getvLook add       tmpX,#varMem        ' Index into variable memory
gvReg2   movs      gv1,tmpX            ' Store into source
         nop                           ' Kill a cycle before using changed source
gv1      mov       tmpX,0              ' Lookup the value         
         djnz      flagX,#getvLook     ' Loopup again if indirect
getValue_ret
         ret

' Fetch special value
' ss_tt__vvvv
' ss = 1,2 or 4
' tt:
' 0      mem[constant]            ss
' 1      mem[Vn]                  ss
' 2      cluster[Vn]              ss
' 3      nextKey                  word
' 4      localRegister            long
' 5      random value             long

gvReg    mov       flagX,#1         
         jmp       #gvReg2
        
 
getValueSpecial         
         mov       flagX,tmpX          ' Get ...
         shr       flagX,#16 wz        ' ... number of ...
         mov       numBytes,flagX      ' ... bytes ...
         shr       numBytes,#8         ' ... and ...
         and       flagX,#255          ' ... type
         and       tmpX,C_FFFF        ' Value without specialness  
         add       flagX,#fetchSpecial ' Execute ...
         jmp       flagX               ' ... numbered routine
         
fetchSpecial
         jmp       #gvMem              ' 0 = mem[constant]  (ss bytes)
         jmp       #gvMemV             ' 1 = mem[Vn]        (ss bytes)
         jmp       #gvLocal            ' 2 = cluster[Vn]    (ss bytes)
         jmp       #gvRnd              ' 3 = nextKey        (2 bytes)
         jmp       #gvReg              ' 4 = localRegister  (4 bytes)
         jmp       #gvRnd              ' 5 = random value   (4 bytes)
         
                                        
gvRnd    mov       t3,#8               ' 8 passes (change lower 8 bits)
gvRND2   mov       t1,randomSeed       ' Get SEEDC ...
         shr       t1,#16              ' ... AND ...
         and       t1,#$E1             ' ... $E1 (magic number)
         mov       t2,#0               ' Count ...
gvRND1   shr       t1,#1 wc, wz        ' ... 1 bits ...
         addx      t2,#0               ' ... in ...
  if_nz  jmp       #gvRND1             ' SEEDC & $E1
         shl       randomSeed,#1       ' Roll the lower bit ...
         shr       t2,#1 wc            ' ... of count ...
  if_c   or        randomSeed,#1       ' ... into lower bit of seed
         djnz      t3,#gvRND2          ' All 8 passes         
         mov       tmpX,randomSeed     ' Value is the new seed
         jmp       #getValue_ret

         
gvLocal  rdlong    t1,boxOfs           ' Get offset to current sector
gvLV     and       tmpX,#$FF           ' Get the register number
         add       tmpX,#varMem        ' Index into variable array
         movs      gvLV1,tmpX          ' Read ...
         nop                           ' ... variable ...         
gvLV1    mov       tmpX,0              ' ... value
         add       tmpX,t1             ' Add our local index         
         jmp       #gvMem              ' Get byte, word, or long
         
         
gvMemV   and       tmpX,#$FF           ' Get the register number
         add       tmpX,#varMem        ' Index into variable array
         movs      gvV,tmpX            ' Read ...
         nop                           ' ... variable ...         
gvV      mov       tmpX,0              ' ... value


gvMem    cmp       numBytes,#1 wz      ' Read ...
  if_z   rdbyte    tmpX,tmpX           ' ... value ...
  if_z   jmp       #getValue_ret       ' ... as byte ...
         cmp       numBytes,#2 wz      ' ... word ...
  if_z   rdword    tmpX,tmpX           ' ... or ...
  if_nz  rdlong    tmpX,tmpX           ' ... long
         jmp       #getValue_ret       ' Done

' -------------------------------------------------------------------------------------
' Multiply
'
'   in:  t1 = 16-bit multiplicand (t1[31..16] must be 0)
'        t2 = 16-bit multiplier
'   out: t1 = 32-bit product
'
multiply
         mov       t3,#16
         shl       t2,#16
         shr       t1,#1 wc
mloop
  if_c   add       t1,t2 wc
         rcr       t1,#1 wc
         djnz      t3,#mloop
multiply_ret
         ret

' -------------------------------------------------------------------------------------
' http://forums.parallax.com/forums/attach.aspx?a=16161
' Divide t1[31..0] by t2[15..0] (t2[16] must be 0)
' on exit, quotient is in t1[15..0] and remainder is in t1[31-16]
'
divide   shl       t2,#15
         mov       t3,#16
dloop    cmpsub    t1,t2 wc
         rcl       t1,#1
         djnz      t3,#dloop
divide_ret
         ret

' Just a randomly chosen seed
randomSeed long    RandomSeedStart

tmp        long    0
ptr        long    0

t1         long    0
t2         long    0
t3         long    0
t4         long    0

abc        long    0
flags      long    0
process    long    0
op         long    0
tmpD       long    0
tmpL       long    0
tmpR       long    0

tmpX       long    0
flagX      long    0
numBytes   long    0

' VariableCOG uses box 1
boxComStat long    MailboxMemory+VariableBoxNumber*32
boxDat1Ret long    MailboxMemory+VariableBoxNumber*32+4
boxDat2    long    MailboxMemory+VariableBoxNumber*32+8
boxDat3    long    MailboxMemory+VariableBoxNumber*32+12
boxDat4    long    MailboxMemory+VariableBoxNumber*32+16
boxDat5    long    MailboxMemory+VariableBoxNumber*32+20
boxDat6    long    MailboxMemory+VariableBoxNumber*32+24
boxOfs     long    MailboxMemory+VariableBoxNumber*32+28
    
C_FFF      long   $FFF
C_FFFF     long   $FFFF
C_FFFFFFFF long   $FFFFFFFF

C_BOOTED           long SystemBooted 

varMem ' 128 variables initialized to 0
           long    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
           long    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
           long    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
           long    0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
       
VariableCOG_end
           fit        ' Must fit under COG [$1F0] 