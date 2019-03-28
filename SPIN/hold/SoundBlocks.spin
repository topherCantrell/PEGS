' The audio system has 3 independently programmable voices.
'
' Each voice points to one of 3 loaded waveforms or a 4th waveform
' that is always random values (for noise). The 3 waveforms are initialized 
' to square, triangle, and sign. These can be changed with an external command.
'
' Each voice has a delay value that controls how many voice-loops pass between
' waveform value changes. The longer the delay, the lower the frequency of the
' voice output.
'
' Each voice has a volume decrease. This value is subtracted from the 
' waveform values -- efectively shifting the entire waveform down linearly.
'
' The envelope functionality controls volume of the output voice.
'  - The increment value is how much to add (or subtract) from the voice
'    volume attenuator at each envelope pass.
'  - The delay defines how many voice-loops define a envelope tick.
'  - The length defines how many envelope ticks are performed.
'  - The reload is 1 if the envelope should repeat when envelope ticks are done.

' Channel commands contain the following information
' (c) Channel: 2 bits (A,B,C)
' (f) Delay: 16 bits
' (v) Volume Decrease: 4 bits (0-15)
' (w) Waveform: 2 bits (0,1,2,Noise)
' (i) Envelope increment: 4 bits (signed)
' (d) Envelope delay: 8 bits
' (l) Envelope length: 8 bits
' (r) Envelope reload: 1 bit

' **** Channel Command Format
' 1nnn0ccc vvvvwwii iir----- --------
' dddddddd llllllll ffffffff ffffffff

' **** Waveform Command Format
' 1nnn1www -------- pppppppp pppppppp
'
'  where p is the pointer within the cluster to the 16 bytes for the waveform
'  note that the waveform command runs outside of the voice-loop. Be sure
'  to turn off sound before updating a waveform.

' **** Music Command Format
' 1nnn1111 --------- pppppppp pppppppp
'
'   where p is pointer to music script
'   (ANY subsequent commands will end music processing)
'
'   Music scripts are sequences of WORD commands
'    0000 dddd dddddddd   d is delay event ... wait d voice-loops
'    -11- ---- --------   end of script
'    10nn ffff ffffffff   n is voice, f is frequency

DAT

' -------- Envelope A (56 clocks)
         sub    envTimeA, #1  wz              ' 4
   if_nz jmp    #lpA2                         ' 4
         mov    envTimeA,envDelayA            ' A4
         adds   volumeA,envVolDeltaA wc       ' A4
   if_c  mov    volumeA,#0                    ' A4
         cmp    volumeA,#15 wz,wc             ' A4
   if_a  mov    volumeA,#15                   ' A4
         sub    envCycleCountA,#1 wz          ' A4
   if_nz jmp    #lpA3                         ' A4    
         mov    envCycleCountA,envNumCyclesA  '   C4      
         cmp    envReloadA,#1 wz              '   C4
   if_nz mov    envVolDeltaA,#0               '   C4
   if_z  mov    volumeA,volumeOrgA            '   C4
         jmp    #computeNoise                 '   C4
lpA3     nop                                  '  D4
         nop                                  '  D4
         nop                                  '  D4
         nop                                  '  D4
         jmp    #computeNoise                 '  D4
lpA2     nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4
         nop                                  ' B4

' Mix voices together and clip

computeNoise