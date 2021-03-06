' -------------------------------------------------------------------------------  
''ExternalExample.spin
'' 
'' Copyright (C) Chris Cantrell October 11, 2008
'' Part of the PEGS project (PEGSKIT.com)
''
'' This is an example assembly program stored in a MIX program cluster and
'' loaded into a COG via the EXECUTE command (see Interpreter.spin).
''
'' Saved the compiled unit as a binary file. The MIX compiler includes a tool
'' to turn the binary file into MIX code for inclusion in your MIX program.
'' See the "External.mix" example.

pub start
'' Required by the compiler but does nothing here

dat
         org 0
        
top
         mov       x,par
         wrlong    x,t1
         rdlong    x,t2
         rdlong    y,t3
         add       x,y         
         wrlong    x,t4
         jmp       #top     

x   long 0
y   long 0
t1  long $7900
t2  long $7904
t3  long $7908
t4  long $790C