/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;

public class CORECompiler
{ 
            
    public static void main(String [] args) throws Exception
    {
    	
    	// CORE script processor does NOT allow data or clusters
    	Compiler compiler = new Compiler(false,false);
    	
    	compiler.addParser(new Parse_SETCONST(0,Command_SETCONST_CORE.class));
    	compiler.addParser(new Parse_SETMEM(1,Command_SETMEM_CORE.class));
    	compiler.addParser(new Parse_GOTO(2,Command_GOTO_CORE.class));
    	compiler.addParser(new Parse_BRANCHIF(3,Command_BRANCHIF_CORE.class));    	
        compiler.addParser(new Parse_BRANCHIFNOT(4,Command_BRANCHIFNOT_CORE.class));        
        compiler.addParser(new Parse_BRANCHIFCARRY(5,Command_BRANCHIFCARRY_CORE.class));
        compiler.addParser(new Parse_BRANCHIFNOTCARRY(6,Command_BRANCHIFNOTCARRY_CORE.class));        
        compiler.addParser(new Parse_CALL(7,Command_CALL_CORE.class));
        compiler.addParser(new Parse_RETURN(8,Command_RETURN_CORE.class));
        compiler.addParser(new Parse_INC(9,Command_INC_CORE.class));
        compiler.addParser(new Parse_DEC(10,Command_DEC_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.ADDCONST,11,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.ADDMEM,12,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.SUBCONST,13,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.SUBMEM,14,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.ANDCONST,15,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.ANDMEM,16,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.ORCONST,17,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.ORMEM,18,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.XORCONST,19,Command_MATH_CORE.class));
        compiler.addParser(new Parse_MATH_CORE(Command_MATH_CORE.Function.XORMEM,20,Command_MATH_CORE.class));
        compiler.addParser(new Parse_PAUSE(21,Command_PAUSE_CORE.class));
        compiler.addParser(new Parse_SYNC(22,Command_SYNC_CORE.class));
        compiler.addParser(new Parse_ADDWORDMEM(23,Command_ADDWORDMEM_CORE.class));
        
        // Parse the root file
        String er = compiler.parse(args[0]);
        if(er!=null) {
            System.out.println(er);
            return;
        } 
        
        // Compile the code
        er = compiler.compile();
        if(er!=null) {
            System.out.println(er);
            return;
        }        
        
        OutputStream oos = new FileOutputStream(args[1]);
        er = compiler.writeSPIN(new PrintStream(oos));
        if(er!=null) {
            System.out.println(er);
            return;
        }               
       
    } 
    
    /*
    public static String writeBinary(OutputStream os,Compiler compiler) throws IOException
    {
        
        for(int x=0;x<compiler.clusters.size();++x) {
            int clusSize = 0;
            for(int y=0;y<compiler.clusters.get(x).commands.size();++y) {
                Command cc = compiler.clusters.get(x).commands.get(y);
                CodeLine c = cc.getCodeLine();  
                int siz = cc.getSize();
                byte [] b = new byte[siz];
                String e = cc.toBinary(compiler.clusters,b);
                if(e!=null) {                    
                    return "## "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.text.trim();                    
                }
                os.write(b,0,siz);
                clusSize+=siz;
            }
            System.out.println("CLUSTER '"+compiler.clusters.get(x).name+"' "+clusSize+" bytes.");
            if(clusSize>2048) {
                return "# CLUSTER '"+compiler.clusters.get(x).name+"' exceeds 2048 bytes.";
            }
            while(clusSize<2048) {
                os.write(0);
                ++clusSize;
            }
        }
        return null;
    } 
    */
    
}