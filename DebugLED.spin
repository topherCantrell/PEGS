CON
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000
 
PUB start | i,j, t,u

  outa[0] := 0
  outa[1] := 0
  outa[2] := 0
  outa[3] := 0
  
  dira[0] := 1
  dira[1] := 1
  dira[2] := 1
  dira[3] := 1  

  i:= 0
  repeat
    t := outa & $FF_FF_FF_F0
    t := t | i
    outa:=t
    i:=i+1
    i:=i&$f   
    waitcnt(10000+cnt)
     