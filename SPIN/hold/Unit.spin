
' The variable manager should be idle most of the time. It should continuously
' update one of its locations with these seeds.
'
' http://charmian.sonoma.edu/~bryant/Fall2006/Phys381%20F06/GSL%20doc%20folder/GSL_Random%20Number%20Generation.doc
' for(int x=0;x<8;++x) {
'   B = 0         
'   A = Seed3         
'   if(Abit7) ++B
'   if(Abit6) ++B
'   if(Abit5) ++B
'   if(Abit0) ++B
'   Seed3 <- Seed2 <- Seed1 <- Bbit0    
' }   

' return Seed1

' **** Channel Command Format
' 1nnn00cc ivvvvvvv ffffffff ffffffff
'
'  i=indirect values (v and f taken from register pairs?)
'  c=chanel
'  v=volume
'  f=frequcency

' **** Music Command Format
' 1nnn010e -------- pppppppp pppppppp
'
' e=enable (1)
' p=pointer to music (point to end-command to stop without disable)

' **** Sweep Command Format
' 1nnnn10e iiiirxnn dddddddd xlllllll
'
' e = sweep processing enabled (1)
' i = signed decrement
' r = repeat(1) or hold last (0)
' x = 0 if volume is swept or 1 if frequency is swept
' nn = voice to use the sweep
' abc = apply sweep to a,b, and/or c (1)
' d = sweep period delay                             
' l = number of sweep periods

' **** Waveform Command Format
' 1nnnn11n l_aabbcc pppppppp pppppppp
'
' n = enable noise processing (1)
' l = 1 if p points to a buffer to pull into the waveform table aa
' aabbcc = waves to use for each voice (11 = noise)
' p = optional waveform pointer to set data

CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

VAR               
  long   mbox[8*8]   

PUB start   | i,j

   mbox[0] := 0

   cognew(@SoundMgr,@mbox)

   mbox[0] := $80_00_01_00
   'repeat j from 1 to 50
   '  repeat i from $100 to $300 step 8
   '    mbox[0] := $80_00_00_00 + i
   '    waitcnt(cnt+100000)
   
   waitcnt(cnt+100000000)
   mbox[0] := $81_00_01_FF

   'waitcnt(cnt+100000000)
   'mbox[0] := $80_00_01_00

   'waitcnt(cnt+100000000)
   'mbox[0] := $80_00_01_00

   'waitcnt(cnt+100000000)
   'mbox[0] := $80_00_00_00
   
   'waitcnt(cnt+100000000)
'   1nnn010e -------- pppppppp pppppppp
   'mbox[0] := $F5_00_00_00 + @sampleMusic   
   

DAT
      org    0

SoundMgr

      mov    boxCommand,par
      mov    dira, C_PINS      

' The timing loop is tightly wound with the expectation that 
' mailbox-commands and music-commands are very rare. The
' loop spins in constant time EXCEPT when processing a
' mailbox-command or music. The amount of time spent
' processing those is fast-as-possible. Hopefully these rare
' interrupts will not affect sound production noticeably.

' There are three functional blocks that can be turned on or off.
' When these blocks are off, they do not add cycles to the main
' timing loop:
'
' - Music Timer: Counts loops until the next note-event 
'   (adds 12 cycles if it is enabled)
'
' - Sweep Generator: Adjusts volume of selected voices
'   (adds N cycles if it is enabled)
'
' - Noice Generator: Generates a random waveform in "wave3"
'   (adds N cycles if it is enabled)
'
' With all of these turned off, the shortest run through the timing
' loop is 191 clocks (actually 12*16=192 to catch our HUB window).
'
' ##### Produced Frequency #####
'
' N is the number of clocks-per-pass. This depends on what functions
'   are enabled.
' The waveforms are all 16-sample quantitites played one sample at
'   a time repeating back to the 1st. Waveforms can be repeated within
'   the 16 samples such that:
' It takes Q passes for one complete wave cycle.
' M is the number of passes before advancing waveform. M=1 advances
'   the waveform every pass. M=2 advances it every other. M=3 every third.
' The clock frequence is 16*5MHz = 80_000_000 MHz
' Thus the produced frequency is:
'   F = 80_000_000 / (N*M*Q)
' Or to find the pass-count M to produce a desired frequency
'   M = 80_000_000 / (N*F*Q)     

'--------------------------------------------------------------
' Top of timing loop
'--------------------------------------------------------------

top
          
' --------- Check command in mailbox (15 clocks)
          rdlong   tmp1,boxCommand       ' 7 Read command from mailbox
          shl      tmp1,#1 nr,wc         ' 4 Test upper bit
    if_c  jmp      #doCommand            ' 4 Go handle command (out of timing section)

' --------- Check the music sequencer (8 clocks)
          andn     musicEnab,#0 nr,wz    ' 4 Is music going?          
     if_z jmp      #sweep                ' 4 No ... skip it          

' --------- Timeout music sequencer block (20 clocks)
music     cmp      musptr,#0 wz          ' 4 If the pointer is null ...
    if_z  mov      musdelay,#1           ' 4 ... never use it
          cmp      musdelay,#0 wz        ' 4 Time for music processing?
    if_z  jmp      #muscm                ' 4 Yes ... go do it (out of timing section)
          sub      musdelay,#1           ' 4 Count down  

' --------- Check the sweeper (8 clocks)
sweep     andn     sweepEnab,#0 nr,wz    ' 4 Is the sweeper running?
'    if_z jmp      #noise                ' 4 No ... skip it
' Not currently implemented
' Must take constant time and fall into "noise"

{
' --------- Check the noise generator (8 clocks)
noise     andn     noiseEnab,#0 nr,wz    ' 4 Is the noise generator running?
     if_z jmp      #voiceA               ' 4 No ... skip it
     
           mov      tmp2,#0
           mov      tmp1,rndSeed
           shl      tmp1,#1 wc
      if_c add      tmp2,#1
           shl      tmp1,#1 wc
      if_c add      tmp2,#1
           shl      tmp1,#1 wc
      if_c add      tmp2,#1
           shl      tmp1,#4
           shl      tmp1,#1 wc
      if_c add      tmp2,#1           
           shl      rndSeed,#1
           and      tmp2,#1
           or       rndSeed,#tmp2
           mov      tmp1,rndSeed
           and      tmp1,#15
noisePtr   mov      wave3,tmp1
           add      noisePtr,C_1DES
           and      noisePtr,C_32DES     

' for(int x=0;x<8;++x) {
'   B = 0         
'   A = Seed3         
'   if(Abit7) ++B
'   if(Abit6) ++B
'   if(Abit5) ++B
'   if(Abit0) ++B
'   Seed3 <- Seed2 <- Seed1 <- Bbit0    
' }   
    
' Not currently implemented
' Must take constant time and fall into "voiceA"

' --------------- Voice A,B,C (9*4*3 + 24 = 132 clocks) ------- 
 }
voicesThree
voiceA3   mov    valA, wave1        ' 4      Pointer is in instruction. Read from waveform table.
          sub    timeA,#1 wz        ' 4      Time for new sample?
    if_nz jmp    #lpA13             ' 4      No ... use the old sample
          mov    holdA,valA         '   A4   Remember this sample
          mov    timeA,delayA       '   A4   Reload delay
          add    voiceA3, #1        '   A4   Bump rotating ...
          andn   voiceA3, #32       '   A4   ... waveform pointer            
vA13      sub    valA, volumeA wc   ' 4      Subtract volume
     if_c mov    valA, #0           ' 4      Floor at 0
  
voiceB    mov    valB, wave1        ' 4      Pointer is in instruction. Read from waveform table.
          sub    timeB,#1 wz        ' 4      Time for new sample?
    if_nz jmp    #lpB13             ' 4      No ... use the old sample
          mov    holdB,valB         '   A4   Remember this sample
          mov    timeB,delayB       '   A4   Reload delay
          add    voiceB, #1         '   A4   Bump rotating ...
          andn   voiceB, #32        '   A4   ... waveform pointer            
vB13      sub    valB, volumeB wc   ' 4      Subtract volume
     if_c mov    valB, #0           ' 4      Floor at 0

voiceC    mov    valC, wave1        ' 4      Pointer is in instruction. Read from waveform table.
          sub    timeC,#1 wz        ' 4      Time for new sample?
    if_nz jmp    #lpC13             ' 4      No ... use the old sample
          mov    holdC,valC         '   A4   Remember this sample
          mov    timeC,delayC       '   A4   Reload delay
          add    voiceC, #1         '   A4   Bump rotating ...
          andn   voiceC, #32        '   A4   ... waveform pointer            
vC13      sub    valC, volumeC wc   ' 4      Subtract volume
     if_c mov    valC, #0           ' 4      Floor at 0
 
' -------- Mixer (24 clocks) --------
                
          add    valA,valB          ' 4
          add    valA,valC          ' 4
          cmp    valA,#15 wz,wc     ' 4
     if_a mov    valA,#15           ' 4
          mov    outa,valA          ' 4    
          jmp    #top               ' 4

lpA13     mov    valA,holdA         '   B4   Use the sample from last time (noise table could change)
          nop                       '   B4          
          nop                       '   B4
          jmp    #vA13              '   B4

lpB13     mov    valB,holdB         '   B4   Use the sample from last time (noise table could change)
          nop                       '   B4          
          nop                       '   B4
          jmp    #vB13              '   B4      

lpC13     mov    valC,holdC         '   B4   Use the sample from last time (noise table could change)
          nop                       '   B4          
          nop                       '   B4
          jmp    #vC13              '   B4   

' --------------- Voice A,B (9*4*2 + 20 = 92 clocks) ------- 

voicesTwo
voiceA2   mov    valA, wave1        ' 4      Pointer is in instruction. Read from waveform table.
          sub    timeA,#1 wz        ' 4      Time for new sample?
    if_nz jmp    #lpA12             ' 4      No ... use the old sample
          mov    holdA,valA         '   A4   Remember this sample
          mov    timeA,delayA       '   A4   Reload delay
          add    voiceA2, #1        '   A4   Bump rotating ...
          andn   voiceA2, #32       '   A4   ... waveform pointer            
vA12      sub    valA, volumeA wc   ' 4      Subtract volume
     if_c mov    valA, #0           ' 4      Floor at 0
  
voiceB2   mov    valB, wave2        ' 4      Pointer is in instruction. Read from waveform table.
          sub    timeB,#1 wz        ' 4      Time for new sample?
    if_nz jmp    #lpB12             ' 4      No ... use the old sample
          mov    holdB,valB         '   A4   Remember this sample
          mov    timeB,delayB       '   A4   Reload delay
          add    voiceB2, #1        '   A4   Bump rotating ...
          andn   voiceB2, #32       '   A4   ... waveform pointer            
vB12      sub    valB, volumeB wc   ' 4      Subtract volume
     if_c mov    valB, #0           ' 4      Floor at 0
 
' -------- Mixer (20 clocks) --------
                
          add    valA,valB          ' 4          
          cmp    valA,#15 wz,wc     ' 4
     if_a mov    valA,#15           ' 4
          mov    outa,valA          ' 4    
          jmp    #top               ' 4

lpA12     mov    valA,holdA         '   B4   Use the sample from last time (noise table could change)
          nop                       '   B4          
          nop                       '   B4
          jmp    #vA12              '   B4

lpB12     mov    valB,holdB         '   B4   Use the sample from last time (noise table could change)
          nop                       '   B4          
          nop                       '   B4
          jmp    #vB12              '   B4  

' --------------- Voice A (9*4 + 16 = 52 clocks) ------- 

voicesOne
voiceA1   mov    valA, wave1        ' 4      Pointer is in instruction. Read from waveform table.
          sub    timeA,#1 wz        ' 4      Time for new sample?
    if_nz jmp    #lpA11             ' 4      No ... use the old sample
          mov    holdA,valA         '   A4   Remember this sample
          mov    timeA,delayA       '   A4   Reload delay
          add    voiceA1, #1        '   A4   Bump rotating ...
          andn   voiceA1, #32       '   A4   ... waveform pointer            
vA11      sub    valA, volumeA wc   ' 4      Subtract volume
     if_c mov    valA, #0           ' 4      Floor at 0
 
' -------- Mixer (16 clocks) --------                
                   
          cmp    valA,#15 wz,wc     ' 4
     if_a mov    valA,#15           ' 4
          mov    outa,valA          ' 4    
          jmp    #top               ' 4

lpA11     mov    valA,holdA         '   B4   Use the sample from last time (noise table could change)
          nop                       '   B4          
          nop                       '   B4
          jmp    #vA11              '   B4

'--------------------------------------------------------------
' End of timing loop
'--------------------------------------------------------------

rndSeed   long     $72_56_84_92
          
muscm     rdword   tmp2,musptr        ' Get the next music command             
          mov      tmp1,tmp2          ' Get the ...
          shr      tmp1,#12           ' ... correct ...
          and      tmp1,#3            ' ... voice
          cmp      tmp1,#3 wz         ' Valid voice?
    if_z  jmp      #musover           ' No ... end of music 
          add      musptr,#2          ' Bump the cursor 
          and      tmp2,C_15 nr,wz    ' What kind of command?
    if_nz jmp      #muscmNOTE         ' Upper bit set ... NOTE command (on or off)
                                      ' Must be a music-delay command
          shl      tmp2,#8            ' Divide music loop significantly
          mov      musdelay,tmp2      ' Store count
          jmp      #voicesThree       ' Keep processing 



muscmNOTE cmp      tmp1,#0 wz         ' Are we doing voice A?
    if_z  jmp      #muscA             ' Yes ... go do it
          cmp      tmp1,#1 wz         ' Are we doing voice B?
    if_z  jmp      #muscB             ' Yes ... go do it
muscC     and      tmp2,C_FREQ wz     ' Mask off frequency
   if_z   mov      volumeC,#255       ' If note-off, turn volume all the way down ...
   if_z   jmp      #voicesThree       '  ... and keep processing until we find a delay
          mov      volumeC,volumeOrgC ' Turn note on by restoring volume
          mov      delayC,tmp2        ' New frequency count
          mov      timeC,#1           ' Reload on next pass
          andn     voiceC,#15         ' ... wave phases
          jmp      #voicesThree       ' Keep processing  
muscB     and      tmp2,C_FREQ wz     ' Mask off frequency
   if_z   mov      volumeB,#255       ' If note-off, turn volume all the way down ...
   if_z   jmp      #voicesThree       '  ... and keep processing until we find a delay
          mov      volumeB,volumeOrgB ' Turn note on by restoring volume
          mov      delayB,tmp2        ' New frequency count
          mov      timeB,#1           ' Reload on next pass
          andn     voiceB,#15         ' Reset phase
          jmp      #voicesThree       ' Keep processing

          long     0,0,0,0,0,0,0,0,0
wave1     long     0,5,0,5,0,5,0,5,0,5,0,5,0,5,0,5 
          
muscA     and      tmp2,C_FREQ wz     ' Mask off frequency
   if_z   mov      volumeA,#255       ' If note-off, turn volume all the way down ...
   if_z   jmp      #voicesThree       '  ... and keep processing until we find a delay
          mov      volumeA,volumeOrgA ' Turn note on by restoring volume
          mov      delayA,tmp2        ' New frequency count
          mov      timeA,#1           ' Reload on next pass
          andn     voicesThree,#15    ' Reset phase
          jmp      #voicesTHree       ' Keep processing

          
          
musover   mov      musdelay,C_ALLF    ' Max delay    
          sub      musptr,#2          ' Back up so we hit the end next time
          jmp      #voicesThree       ' Keep processing
 
doCommand 
          mov      tmp2,tmp1          ' Hold          
          shr      tmp2,#26           ' Get the ...
          and      tmp2,#3            ' ... command number
          cmp      tmp2,#0 wz
    if_z  jmp      #doChannel
          cmp      tmp2,#1 wz
    if_z  jmp      #doMusic
          cmp      tmp2,#2 wz
    if_z  jmp      #doSweep
' wave
doSweep   ' Not currently implemented
          wrlong   C_0,boxCommand
          jmp      #voicesThree
          
doChannel
' 1nnn00cc ivvvvvvv ffffffff ffffffff
          mov      tmp2,tmp1
          mov      tmp3,tmp1
          and      tmp2,C_FFFF
          shr      tmp3,#16
          and      tmp3,#255
          shr      tmp1,#24
          and      tmp1,#3
          cmp      tmp1,#0 wz
    if_z  jmp      #doCA
          cmp      tmp1,#1 wz
    if_z  jmp      #doCB
          mov      delayC,tmp2
          mov      volumeC,tmp3
          mov      volumeOrgC,tmp3
          wrlong   C_0,boxCommand
          jmp      #voicesThree
          
doCA      mov      delayA,tmp2
          mov      volumeA,tmp3
          mov      volumeOrgA,tmp3
          wrlong   C_0,boxCommand
          jmp      #voicesThree

          long     0,0,0,0,0
wave3     long     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

doCB      mov      delayB,tmp2
          mov      volumeB,tmp3
          mov      volumeOrgB,tmp3
          wrlong   C_0,boxCommand
          jmp      #voicesThree
        
doMusic
' 1nnn010e -------- pppppppp pppppppp
          mov      musptr,tmp1
          and      musptr,C_FFFF
          shr      tmp1,#24
          mov      musicEnab,tmp1
          and      musicEnab,#1
          mov      musdelay,#0          
          wrlong   C_0,boxCommand
          jmp      #voicesThree
          

' -------------------------------------------------------------------
' Functional block enables (affects number of clocks in main loop) 
'
musicEnab      long   0       ' 1 if music is enabled
sweepEnab      long   0       ' 1 if sweep is enabled
noiseEnab      long   0       ' 1 if noise is enabled

' -------------------------------------------------------------------
' Data structures for the 3 voices 
'
' VOICE A
'
delayA         long    $280       ' Number of passes before advancing waveform
volumeOrgA      long   0       ' Volume/frequency
'
timeA          long   1       ' Counts number of passes (reloaded with delay)
volumeA        long   0      ' Current volume decrementer (reloaded with volumeOrg)
'
' VOICE B                       
'
delayB         long   0       ' Number of passes before advancing waveform
volumeOrgB      long   0       ' Volume/frequency
'
timeB          long   0       ' Counts number of passes (reloaded with delay)
volumeB        long   0      ' Current volume decrementer (reloaded with volumeOrg)
'
' VOICE C
'                       
delayC         long   0       ' Number of passes before advancing waveform
volumeOrgC      long   0       ' Volume/frequency
'
timeC          long   0       ' Counts number of passes (reloaded with delay)
volumeC        long   0      ' Current volume decrementer (reloaded with volumeOrg)
'
' -------------------------------------------------------------------
' Sweep parameters
'
sweepDelay       long   0     ' Number of passes in sweep tick
sweepNumCycles   long   0     ' Total number of sweep ticks (before end or reload)
sweepReload      long   0     ' 1 = reload volume/freq and sweep ticks when done
sweepDelta       long   0     ' This is extended to 32-bit math (subtracted from volume/freq)
' 
sweepCycleCount  long   0     ' Counts sweep ticks (reloaded with sweepNumCycles)
sweepTime        long   0     ' Counts sweep in an sweep tick (sweepDelay)
'
' -------------------------------------------------------------------
' Music
'
musdelay       long   0
musptr         long   0


valA           long   0
valB           long   0
valC           long   0           
tmp1           long   0
tmp2           long   0
tmp3           long   0
holdA          long   0
holdB          long   0
holdC          long   0

boxCommand     long   0

C_0            long   0
C_15           long   $80_00
C_FREQ         long   $0F_FF
C_FFFF         long   $FF_FF
C_ALLF         long   $FF_FF_FF_FF
C_PINS         long   $00_00_00_0F
C_7FFFFFFF     long   $7F_FF_FF_FF
C_1DES         long   %000000_0000_0000_000000001_000000000
C_32DES        long   %000000_0000_0000_000100000_000000000

' Padding
long 0, 0, 0, 0 ,0 



' Each wave MUST be at $40 or $80 etc
wave2
 long 2,0,2,0,2,0,2,0,2,0,2,0,2,0,2,0

  
samplemusic

  word   $8000+387 ' Voice 0 ON  387
  word   $9000+488 ' Voice 1 ON  488
  word   $a000+774 ' Voice 2 ON  774
word $261 ' PAUSE 609
    word $a000 ' Voice 2 OFF
word $98 ' PAUSE 152
  word   $a000+975 ' Voice 2 ON  975
word $1c9 ' PAUSE 457
    word $a000 ' Voice 2 OFF
word $72 ' PAUSE 114
  word   $a000+1302 ' Voice 2 ON  1302
word $98 ' PAUSE 152
    word $a000 ' Voice 2 OFF
word $26 ' PAUSE 38
  word   $a000+1160 ' Voice 2 ON  1160
word $130 ' PAUSE 304
    word $a000 ' Voice 2 OFF
word $4c ' PAUSE 76
  word   $a000+1302 ' Voice 2 ON  1302
word $345 ' PAUSE 837
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
word $2ad ' PAUSE 685
  word   $8000+651 ' Voice 0 ON  651
  word   $9000+774 ' Voice 1 ON  774
word $98 ' PAUSE 152
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
word $26 ' PAUSE 38
  word   $8000+651 ' Voice 0 ON  651
  word   $9000+774 ' Voice 1 ON  774
word $98 ' PAUSE 152
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
word $26 ' PAUSE 38
  word   $8000+580 ' Voice 0 ON  580
  word   $9000+730 ' Voice 1 ON  730
word $130 ' PAUSE 304
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
word $4c ' PAUSE 76
  word   $8000+547 ' Voice 0 ON  547
  word   $9000+689 ' Voice 1 ON  689
word $4c ' PAUSE 76
    word $a000 ' Voice 2 OFF
word $e4 ' PAUSE 228
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
word $4c ' PAUSE 76
  word   $8000+517 ' Voice 0 ON  517
  word   $9000+651 ' Voice 1 ON  651
  word   $a000+1302 ' Voice 2 ON  1302
word $130 ' PAUSE 304
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
    word $a000 ' Voice 2 OFF
word $4c ' PAUSE 76
  word   $8000+488 ' Voice 0 ON  488
  word   $9000+580 ' Voice 1 ON  580
  word   $a000+1160 ' Voice 2 ON  1160
word $130 ' PAUSE 304
    word $8000 ' Voice 0 OFF
    word $9000 ' Voice 1 OFF
    word $a000 ' Voice 2 OFF

    
  word  $FFFF



            