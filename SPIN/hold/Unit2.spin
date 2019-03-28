  
CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

VAR               
  long   mbox[8*8]   

PUB start   | i,j

   mbox[0] := 0

   cognew(@SoundMgr,@mbox)
   

DAT
      org    0

SoundMgr

      mov    dira, C_PINS

here  mov    tmp,cur
      add    tmp,#wave
      movs   ptr,tmp
      add    cur,#1
      and    cur,#$3F
ptr   mov    val,wave
      mov    outa,val

      mov    del,rel
dela  djnz   del,#dela
      
            
      jmp   #here      


cur    long 0
tmp    long 0

val    long 0
del    long 1

rel    long $200

C_PINS         long   $00_00_00_3F

wave

 long 32
 long 35
 long 38
 long 41
 long 44
 long 47
 long 49
 long 52
 long 54
 long 56
 long 58
 long 60
 long 61
 long 62
 long 63
 long 63
 long 63
 long 63
 long 63
 long 62
 long 61
 long 60
 long 58
 long 56
 long 54
 long 52
 long 49
 long 47
 long 44
 long 41
 long 38
 long 35
 long 32
 long 28
 long 25
 long 22
 long 19
 long 16
 long 14
 long 11
 long 9
 long 7
 long 5
 long 3
 long 2
 long 1
 long 0
 long 0
 long 0
 long 0
 long 0
 long 1
 long 2
 long 3
 long 5
 long 7
 long 9
 long 11
 long 14
 long 16
 long 19
 long 22
 long 25
 long 28
