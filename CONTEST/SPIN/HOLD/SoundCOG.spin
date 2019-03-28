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
  
  coginit(SoundCOGNumber,@SoundCOG,0)

DAT      
         org 0

' Timing:
'
'  16 clocks : test for command (normal)
'  20 clocks : main loop calls (or NOP)
' 128 clocks : voice loop
' ----------
' 164 clocks
'
'   Then add configured modules (if any)
'     48 clocks : F/V sweepers (only one at a time)
'     20 clocks : S sequencer (normal)
'    104 clocks : N noise (takes 7 passes to change one value)
'
' FVSN                              Q
' 0000  164                     =  164
' 0001  164              + 104  =  268
' 0010  164         + 20        =  184
' 0011  164         + 20 + 104  =  288
' 0100  164    + 48             =  212
' 0101  164    + 48      + 104  =  316
' 0110  164    + 48 + 20        =  232
' 0111  164    + 48 + 20 + 104  =  336
' 1000  164    + 48             =  212
' 1001  164    + 48      + 104  =  316
' 1010  164    + 48 + 20        =  232
' 1011  164    + 48 + 20 + 104  =  336 
'
' ToneFrequency = CLOCK / (Q * M * N)
'   CLOCK = 80_000_000 clocks per second
'   Q     = Clocks per main loop (table above)
'   M     = Main loops between samples
'   N     = Samples per waveform (32, 16, 8, 4, 2)
'
' We are REALLY limited on code/data space here so for the single COG
' sound generator we will make the following simplifications:
' - Always 3 voices (no 1 or 2 voice options)
' - Only two sweepers: the VoiceA volume and frequency sweepers (one OR the other)
' - Only two waveforms: user wave and noise        

' Uses box 3

' ------------------------- Sound Command -----------------------------------
'
' xxxxxxxx_xxxxxx__0_SCC0_VVVVVV_IIII_R
' DDDDDDDD_LLLLLLLL_WW00FFFF_FFFFFFFF
'
' If S==0, only change frequency
' CC = voice (A,B,C)
' WW = waveform (0,1,2,3) 
' IIII = sweeper increment (extend MSB through long)
' R = sweeper repeat (1=repeat)
' DDDDDDDD = sweeper delay  (shifted left 6 bits)
' LLLLLLLL = sweeper length
' FFFFFFFFFFFF = frequency
' VVVV = volume

' ------------------------- Waveform Command -----------------------------------

' ------------------------- Sequence Command ----------------------------------- 

SoundCOG                    
           rdlong  tmp,boxComStat wz           ' On startup, wait for ...         
     if_z  jmp     #SoundCOG                   ' ... the start signal   

           mov     dira, #$3F                  ' Sound hardware here
           jmp     #top                        ' Begin processing

' --------------- Sweepers 12*4 = 48 clocks each -------
' ---- This for volume
sweeperAVol 
           sub     envACount,#1 wz             '    4 Time to process envelope?
    if_nz  jmp     #sweeperA_del1              '    4 No ... skip
           mov     envACount,envACountReload   ' A  4 Yes ... reload delay  
           add     volumeA,envADelta           ' A  4 Change volume
           and     volumeA,#63                 ' A  4 Stay in limits        
           sub     envALength,#1 wz            ' A  4 End of envelope period?
    if_nz  jmp     sweeperA_del2               ' A  4 No ... out            
           cmp     envARepeat,#1 wz            ' AB 4 Do we reload?
    if_nz  mov     envADelta,#0                ' AB 4 No ... no more changes
    if_z   mov     volumeA,envAVolReload       ' AB 4 Yes ... reset volume
    if_z   mov     envALength,envALengthReload ' AB 4 Yes ... reset envelope time   
sweeperAVol_ret                                ' 
           ret                                 '    4
sweeperA_del1                                  ' 
           mov     delay_var,#3                ' A  4
dh1        djnz    delay_var,#dh1              ' A  16 (4 + 4*3)         
sweeperA_del2                                  '
           mov     delay_var,#1                ' AB 4
dh2        djnz    delay_var,#dh2              ' AB 8 (4 + 4*1) 
           jmp     #sweeperAVol_ret            ' AB 4
' ---- This for frequency                     
sweeperAFreq 
           sub     envACount,#1 wz             '    4 Time to process envelope?        
    if_nz  jmp     #sweeperAF_del1             '    4 No ... skip
           mov     envACount,envACountReload   ' A  4 Yes ... reload delay  
           add     delayA,envADelta            ' A  4 Change freqency
           and     delayA,C_FFF                '    4 Stay in limits        
           sub     envALength,#1 wz            '    4 End of envelope period?
    if_nz  jmp     sweeperAF_del2              '    4 No ... out            
           cmp     envARepeat,#1 wz            ' AB 4 Do we reload?
    if_nz  mov     envADelta,#0                ' AB 4 No ... no more changes
    if_z   mov     delayA,envAFreqReload       ' AB 4 Yes ... reset volume
    if_z   mov     envALength,envALengthReload ' AB 4 Yes ... reset envelope time   
sweeperAFreq_ret                               '
           ret                                 '    4                                    
sweeperAF_del1                                 '
           mov     delay_var,#3                ' A  4
dh3        djnz    delay_var,#dh2              ' A  16 (4 + 4*3)   
sweeperAF_del2                                 '
           mov     delay_var,#1                ' AB 4
dh4        djnz    delay_var,#dh2              ' AB 8 (4 + 4*1)  
           jmp     #sweeperAFreq_ret           ' AB 4

' SoundCOG mailbox

boxComStat long    MailboxMemory + SoundBoxNumber*32
boxDat1Ret long    MailboxMemory + SoundBoxNumber*32 +4
boxDat2    long    MailboxMemory + SoundBoxNumber*32 +8
boxDat3    long    MailboxMemory + SoundBoxNumber*32 +12
boxDat4    long    MailboxMemory + SoundBoxNumber*32 +16
boxDat5    long    MailboxMemory + SoundBoxNumber*32 +20
boxDat6    long    MailboxMemory + SoundBoxNumber*32 +24
boxOfs     long    MailboxMemory + SoundBoxNumber*32 +28

tmp        long 0
tmp2       long 0
tmp3       long 0     

randomSeed long RandomSeedStart  ' Noise random number seed   

valA       long 0   ' Value for the mixer
holdA      long 0   ' Last waveform sample

seqAcnt    long 0   ' Count until next sequencer event
seqAptr    long 0   ' Current sequence pointer
seqAptrOrg long 0   ' Fist word in sequence  

C_SP1      long %1_000000000          ' Adds 1 to the destination field of an instruction
C_SP2      long %000100000_000000000  ' ANDs off #32 of destination field
C_COND     long %000000_0000_1111_000000000_000000000 ' Condition field of instruction
C_SEF      long %0100000000000000     ' Long-command bit in sequence commands

C_7FF      long $7FF
C_FFF      long $FFF                                            
C_8000     long $8000
C_FFFF     long $FFFF 
C_FFFFFFF0 long $FFFFFFF0
          
' --------------------------------------------------------------------
' --------------------------------------------------------------------
' WAVE-0 is 32 longs starting at cog address $40
wave0 
 long 21,0,21,0,21,0,21,0,21,0,21,0,21,0,21,0
 long 21,0,21,0,21,0,21,0,21,0,21,0,21,0,21,0
' --------------------------------------------------------------------
' --------------------------------------------------------------------

' -------- NOISE   104 clocks
'
' Make 6 passes then store on 7th. Thus keep voice delay greater than 6 or you 
' will pass the noise generator.
'
noise      sub     t3,#1 wz          '   4 After 6 passes ...
     if_z  jmp     #noise_1          '   4 ... go store value

           mov     t1,randomSeed     ' A 4 Get SEEDC ...
           shr     t1,#16            ' A 4 ... AND ...
           and     t1,#$E1           ' A 4 ... $E1 (magic number)         
           mov     t2,#0             ' A 4 Count of 1's in t1         

           ' No loop here ... as fast as possible
           ' Count the number of 1 bits t1
         
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1
           shr     t1,#1 wc          ' A 4 Bit to carry
           addx    t2,#0             ' A 4 Count it if 1         
                                        
           shl     randomSeed,#1     ' A 4 Roll the lower bit ...
           shr     t2,#1 wc          ' A 4 ... of count ...
     if_c  or      randomSeed,#1     ' A 4 ... into lower bit of seed
noise_ret
           ret                       '   4
   
t3         long 1
t2         long 0
t1         long 0
t4         long 0
delay_var  long 0 
valB       long 0

' --------------------------------------------------------------------
' --------------------------------------------------------------------
' WAVE-1 is 32 longs starting at cog address $80. Used for NOISE.
wave1
long    $1f, $19, $13, $d, $8, $4, $1, $0, $0, $0, $1, $4, $8, $d, $13, $19
long    $1f, $25, $2b, $31, $36, $3a, $3d, $3e, $3f, $3e, $3d, $3a, $36, $31, $2b, $25
' --------------------------------------------------------------------
' --------------------------------------------------------------------
  
noise_1  ' Store noise value. Must eat 92 clocks total.
           mov     t1,randomSeed     ' A 4 Get random ...
           and     t1,#63            ' A 4 ... six bits
noise_2    mov     wave1,t1          ' A 4 Store the next value
           add     noise_2,C_SP1     ' A 4 Bump the waveform pointer
           andn    noise_2,C_SP2     ' A 4 Wrap the pointer
           mov     t1,#14            ' A 4 14-instructions-wasted
noise_3    djnz    t1,#noise_3       ' A 60 (4 + 14*4)                                        
           mov     t3,#7             ' A 4 start over at the beginning
           jmp     #noise_ret        ' A 4 Out 

' --------------------------------------------------------------------
' --------------- Voice A,B,C (9*4*3 + 20 = 128 clocks) -------

lpA13      mov     valA,holdA        ' A 4 Use the sample from last time (noise table could change)
           nop                       ' A 4          
           nop                       ' A 4
           jmp     #vA13             ' A 4

lpB13      mov     valB,holdB        ' B 4   Use the sample from last time (noise table could change)
           nop                       ' B 4          
           nop                       ' B 4
           jmp     #vB13             ' B 4

lpC13      mov     valC,holdC        ' C 4   Use the sample from last time (noise table could change)
           nop                       ' C 4          
           nop                       ' C 4
           jmp     #vC13             ' C 4

voicesThree
voiceA     mov     valA, wave0       '   4 Pointer is in instruction. Read from waveform table.
           sub     timeA,#1 wz       '   4 Time for new sample?
    if_nz  jmp     #lpA13            '   4 No ... use the old sample
           mov     holdA,valA        ' A 4 Remember this sample
           mov     timeA,delayA      ' A 4 Reload delay
           add     voiceA, #1        ' A 4 Bump rotating ...
           andn    voiceA, #32       ' A 4 ... waveform pointer            
vA13       sub     valA, volumeA wc  '   4 Subtract volume
     if_c  mov     valA, #0          '   4 Floor at 0
  
voiceB     mov     valB, wave0       '   4 Pointer is in instruction. Read from waveform table.
           sub     timeB,#1 wz       '   4 Time for new sample?
    if_nz  jmp     #lpB13            '   4 No ... use the old sample
           mov     holdB,valB        ' B 4 Remember this sample
           mov     timeB,delayB      ' B 4 Reload delay
           add     voiceB, #1        ' B 4 Bump rotating ...
           andn    voiceB, #32       ' B 4 ... waveform pointer            
vB13       sub     valB, volumeB wc  '   4 Subtract volume
     if_c  mov     valB, #0          '   4 Floor at 0
                                   
voiceC     mov     valC, wave0       '   4      Pointer is in instruction. Read from waveform table.
           sub     timeC,#1 wz       '   4      Time for new sample?
    if_nz  jmp     #lpC13            '   4      No ... use the old sample
           mov     holdC,valC        ' C 4 Remember this sample
           mov     timeC,delayC      ' C 4 Reload delay
           add     voiceC, #1        ' C 4 Bump rotating ...
           andn    voiceC, #32       ' C 4 ... waveform pointer            
vC13       sub     valC, volumeC wc  '   4 Subtract volume
     if_c  mov     valC, #0          '   4 Floor at 0
 
' -------- Mixer (20 clocks) --------
                
           add     valA,valB         ' 4 Voice A + B ...
           add     valA,valC         ' 4 ... + C
           cmp     valA,#63 wz,wc    ' 4 Overflow?
     if_a  mov     valA,#63          ' 4 Yes ... ceiling at 63
     
           mov     outa,valA         ' 4 Write sound sample 
                       
top    
           rdlong  tmp,boxComStat    ' 8 Read command box
           shl     tmp,#1 nr, wc     ' 4 Test upper bit for command
     if_c  jmp     #processCommand   ' 4 New command ... go process it

mainCommands
confN  if_always  call     #noise          ' 4 + 104 clocks (always)
confS  if_always  call     #sequencerA     ' 4 +  20 clocks (normally)
confV  if_never   call     #sweeperAVol    ' 4 +  48 clocks (always)
confF  if_always  call     #sweeperAFreq   ' 4 +  48 clocks (always)
                  jmp      #voicesThree    ' 4 + 128 clocks (always)  

            ' 336 total clocks (normally)
            ' 336 / 16 = 21 ... exactly 21 hub windows normally
            
processCommand 
           mov     t1,tmp                ' Get ...
           shr     t1,#18                ' ... command ...
           and     t1,#15 wz             ' ... value
     if_z  jmp     #commandSoundChannel  ' 0 means channel command
           cmp     t1,#1 wz              ' 1 means ...
     if_z  jmp     #commandSequencer     ' ... init sequencer
           cmp     t1,#2 wz              ' 2 means ...
     if_z  jmp     #commandConfig        ' ... configure blocks

commandWaveform                          ' Assume else is waveform
           mov     t3,tmp                ' WW ...
           shr     t3,#16                ' ... is ...
           and     t3,#3                 ' ... waveform
           add     t3,#1                 ' 1 based index
           shl     t3,#6                 ' At $40 or $80
            
           and     tmp,C_FFFF            ' Memory pointer
           rdlong  t2,boxOfs             ' Cluster ...
           add     tmp,t2                ' ... offset

           mov     t2,#32                ' 32 bytes to load
comwf2     movd    comwf1,t3             ' To local memory pointer
           add     t3,#1                 ' Next local address
comwf1     rdbyte  0,tmp                 ' Read the waveform value (6 bits used)
           add     tmp,#1                ' Next shared memory
           djnz    t2,#comwf2            ' Do all 32
            
commandFinish  
           mov     tmp,#1                ' Clear upper bit ...
           wrlong  tmp,boxComStat        ' ... signal command finished
           jmp     #mainCommands         ' Back into processing loop

commandConfig                                                       
           and     tmp,#8 nr,wz          ' Set ALWAYS ...
     if_z  andn    confF,C_COND          ' ... or NEVER ...
     if_nz or      confF,C_COND          ' ... condition bits ...
           and     tmp,#4 nr,wz          ' ... in ...
     if_z  andn    confV,C_COND          ' ... main ...
     if_nz or      confV,C_COND          ' ... loop ...
           and     tmp,#2 nr,wz          ' ... calls
     if_z  andn    confS,C_COND          '
     if_nz or      confS,C_COND          '
           and     tmp,#1 nr,wz          '
     if_z  andn    confN,C_COND          '
     if_nz or      confN,C_COND          '                        
           jmp     #commandFinish        ' Back to main loop

commandSoundChannel
           mov     tmp2,tmp              ' A full sound command ...
           rdlong  tmp3,boxDat1Ret       ' ... is two longs
           call    #fullChannelCommand   ' Shared function (with sequencer)
           jmp     #commandFinish        ' Back to main loop      
            
commandSequencer
           and     tmp,C_FFFF wz         ' All 0s means ...
    if_z   mov     seqAcnt,#0            ' ... turn sequencer off ...
    if_z   jmp     #commandFinish        ' ... and continue 
           rdlong  seqAPtr,boxOfs        ' Get the base address
           add     seqAPtr,tmp           ' Add the offset
           mov     seqAptrOrg,seqAPtr    ' Remember start address
           mov     seqACnt,#1            ' Force new sequence to start    
           jmp     #commandFinish        ' Back to main loop

'------------------------------------------------------------------------

fullChannelCommand

' tmp2 = xxxxxxxx_xxxxxx__0_SCC0_VVVVVV_IIII_R
' tmp3 = DDDDDDDD_LLLLLLLL_WW00FFFF_FFFFFFFF

' xxxx = normal mailbox protocol

' If S==0, only change frequency

' CC = voice (A,B,C)

' WW = waveform (0,1,2,3) 
' IIII = sweeper increment (extend MSB through long)
'  - envNDelta
' R = sweeper repeat (1=repeat)
'  - envNRepeat

' DDDDDDDD = sweeper delay  (shifted left 6 bits)
'  - envNCount and envNCountReload
' LLLLLLLL = sweeper length
'  - envNLenth and envNLengthReload
' FFFFFFFFFFFF = frequency
'  - delayN and and envNFreqReload
' VVVV = volume
'  - volumeN and envNVolReload
' timeA to 1                      

           mov     t1,tmp2                 ' CC ...
           shr     t1,#12                  ' ... is ...
           and     t1,#3                   ' ... channel
       
           mov     t2,tmp2                 ' S ...
           shr     t2,#14                  ' ... is ...
           and     t2,#1 wz                ' ... simple-frequency-command flag
     if_z  jmp     #fcc_simple1            ' Ignore all envelope stuff if simple  

           mov     t3,tmp3                 ' WW ...
           shr     t3,#14                  ' ... is ...
           and     t3,#3                   ' ... waveform
           add     t3,#1                   ' 1 based index
           shl     t3,#6                   ' At $40 or $80       
       
           cmp     t1,#0 wz                '       
     if_z  movs    voiceA,t3               '    
           cmp     t1,#1 wz                ' Set correct voice  
     if_z  movs    voiceB,t3               ' pointer
           cmp     t1,#2 wz                ' 
     if_z  movs    voiceC,t3               ' 
       
           mov     envXRepeat,tmp2         ' R is ...
           and     envXRepeat,#1           ' ... envelope repeat flag
                  
           mov     envXDelta,tmp2          ' IIII ...
           shr     envXDelta,#1            ' ... is ...
           and     envXDelta,#15           ' ... delta
           and     envXDelta,#8 nr,wz      ' 4-bit ...
    if_nz  or      envXDelta,C_FFFFFFF0    ' ... envelope sign extend
 
           mov     volumeX,tmp2            ' VVVVVV ...
           shr     volumeX,#5              ' ... is ...
           and     volumeX,#63             ' ... volume
           mov     envXVolReload,volumeX   ' Init reload too      

           mov     envXCountReload,tmp3    ' DDDDDDDD is ...
           shr     envXCountReload,#24     ' ... envelope time
           shl     envXCountReload,#6
           mov     envXCount,envXCountReload ' Init count too     

           mov     envXLengthReload,tmp3   ' LLLLLLLL ...
           shr     envXLengthReload,#16    ' ... is ...
           and     envXLengthReload,#$FF   ' ... envelope length
           mov     envXLength,envXLengthReload ' Init time too 
       
fcc_simple1  

           mov     delayX,tmp3             ' FFFF_FFFFFFFF ...
           and     delayX,C_FFF            ' ... frequency
           mov     envXFreqReload,delayX   ' Init reload too
           mov     timeX,#1                ' Restart sampler 
  
           cmp     t1,#0 wz                ' 
     if_z  mov     t3,#volumeA             ' Get the destination
           cmp     t1,#1 wz                ' pointer to 
     if_z  mov     t3,#volumeB             ' t3
           cmp     t1,#2 wz                ' 
     if_z  mov     t3,#volumeC             '  
  
           mov     t4,#volumeX             ' Source pointer to t4
           mov     t1,#11                  ' Full command moves 11      

           cmp     t2,#1 wz                ' 
     if_nz mov     t1,#3                   ' Short form only uses
     if_nz add     t3,#8                   ' last three
           cmp     t2,#1 wz                '
     if_nz add     t4,#8                   '
         
fcc_move
           movd    fcc_ptr,t3              ' Copy from ...
           movs    fcc_ptr,t4              ' ... paramsX ...
           nop                             ' ... to ...
fcc_ptr    mov     0,0                     ' ... target ...
           add     t3,#1                   ' ... voice ...
           add     t4,#1                   ' ... data
           djnz    t1,#fcc_move            '''
                
fullChannelCommand_ret
           ret
            
'------------------------------------------------------------------------
'
' Sequencer delay is # of main loops before counting. The incoming 12-bit
' value is left shifted 8 bits to make the pause.

seqA_del1  nop                           ' 4
           nop                           ' 4
sequencerA_ret
           ret                           ' 4
sequencerA   
           cmp     seqAcnt,#0 wz         ' 4 Is sequencer enabled?
     if_z  jmp     #seqA_del1            ' 4 No ... delay 2 and out
           sub     seqAcnt,#1 wz         ' 4 Time for a new command?
     if_nz jmp     #sequencerA_ret       ' 4 No ... delay and out
     
           rdword  tmp,seqAptr           ' Next event
           add     seqAptr,#2            ' Bump sequence pointer                        
           and     tmp,C_8000 nr,wz      ' Test upper bit
     if_z  jmp     #seqA_chan            ' Upper bit 0 means channel command
           mov     tmp2,tmp              ' Upper 4 bits ...
           shr     tmp2,#12              ' ... is command
           and     tmp2,#3 wz            ' 0 means ...  
     if_z  jmp     #seqA_delay           ' ... delay (most common)          
           cmp     tmp2,#1 wz            ' 1 means ...     
     if_z  jmp     #seqA_goto            ' ... goto                    
' Stop sequencer 
           mov     seqACnt,#0            ' Disable the sequencer
           jmp     #sequencerA_ret       ' Out             
seqA_delay     ' Set the delay
           and     tmp,C_FFF
           shl     tmp,#8                ' Lower the resolution
           mov     seqAcnt,tmp           ' New count
           jmp     #sequencerA_ret       ' Out    
seqA_goto      ' Jump in the sequence (repeat)
           and     tmp,C_FFF             ' Offset within song
           add     tmp,seqAptrOrg        ' Get address ...
           mov     seqAptr,tmp           ' ... to picku up at
seqNext    mov     seqAcnt,#1            ' Process next event immediately
           jmp     #sequencerA_ret       ' Out
     
seqA_chan               
' Channel command
           and     tmp,C_SEF nr,wz       ' Long command (has sweeper data)?
     if_nz jmp     #seqA_chan1           ' Yes ... go read another 2 words
           mov     tmp2,tmp              ' Voice number and no-sweep flag
           mov     tmp3,tmp              ' Frequency ...
           and     tmp3,C_FFF            ' ... to second long
           jmp     #seqA_chan2           ' Do command
seqA_chan1        
           rdword  tmp2,seqAptr          ' Read ...
           add     seqAptr,#2            ' ... two ...
           rdword  tmp3,seqAptr          ' ... more ...
           add     seqAptr,#2            ' ... words
           shl     tmp2,#16              ' Assemble them ...
           or      tmp3,tmp2             ' ... into a long
           mov     tmp2,tmp                       
seqA_chan2              
           call    #fullChannelCommand   ' Process the command

           jmp     #seqNext              ' Out

' Some of these values have been moved up to align wave tables at $40 and $80

'valA             long   0         ' Value for the mixer
'holdA            long   0         ' Last waveform sample
'
volumeA           long   0         ' Volume to subtract from waveform sample
envACount         long   0         ' Count till next envelope tic
envACountReload   long   0         ' Reload of envelope tic count 
envADelta         long   0         ' Amount to ADD to volume or frequency each tic
envALengthReload  long   0         ' Total length of envelope
envALength        long   0         ' Tic count till end of envelope 
envARepeat        long   0         ' 1 if envelope repeats
envAVolReload     long   0         ' If repeat, Reload of volume
envAFreqReload    long   0         ' If repeat, reload of frequency
delayA            long   0         ' Frequency (reloads time)
timeA             long   0         ' Loops till next waveform sample  

'valB             long   0
holdB             long   0
'
volumeB           long   0         ' Volume to subtract from waveform sample
envBCount         long   0         ' Count till next envelope tic
envBCountReload   long   0         ' Reload of envelope tic count 
envBDelta         long   0         ' Amount to ADD to volume or frequency each tic
envBLengthReload  long   0         ' Total length of envelope
envBLength        long   0         ' Tic count till end of envelope 
envBRepeat        long   0         ' 1 if envelope repeats
envBVolReload     long   0         ' If repeat, Reload of volume
envBFreqReload    long   0         ' If repeat, reload of frequency
delayB            long   0         ' Frequency (reloads time)
timeB             long   0         ' Loops till next waveform sample

valC              long   0
holdC             long   0
'
volumeC           long   0         ' Volume to subtract from waveform sample
envCCount         long   0         ' Count till next envelope tic
envCCountReload   long   0         ' Reload of envelope tic count 
envCDelta         long   0         ' Amount to ADD to volume or frequency each tic
envCLengthReload  long   0         ' Total length of envelope
envCLength        long   0         ' Tic count till end of envelope 
envCRepeat        long   0         ' 1 if envelope repeats
envCVolReload     long   0         ' If repeat, Reload of volume
envCFreqReload    long   0         ' If repeat, reload of frequency
delayC            long   0         ' Frequency (reloads time)
timeC             long   0         ' Loops till next waveform sample

volumeX           long   0         ' Volume to subtract from waveform sample
envXCount         long   0         ' Count till next envelope tic
envXCountReload   long   0         ' Reload of envelope tic count 
envXDelta         long   0         ' Amount to ADD to volume or frequency each tic
envXLengthReload  long   0         ' Total length of envelope
envXLength        long   0         ' Tic count till end of envelope 
envXRepeat        long   0         ' 1 if envelope repeats
envXVolReload     long   0         ' If repeat, Reload of volume
envXFreqReload    long   0         ' If repeat, reload of frequency
delayX            long   0         ' Frequency (reloads time)
timeX             long   0         ' Loops till next waveform sample  
  
lastAddressUsed

    fit        ' Must fit unde