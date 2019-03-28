/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;

public class MIXCompiler
{ 
            
    public static void main(String [] args) throws Exception
    {
    	
    	// MIX compiler allows multi-clusters and data-sections
    	Compiler compiler = new Compiler(true,true);
    	
    	// TODO Make the disk-cog's INDIRECT a general memory location
        //      that other cogs can use ... a less fancy "variable"
        //      technique
        
        // TODO break out separate structure commands like we do below
        
        // Special multi-line complex structures in the data section
        compiler.addStructureParser(new VideoDataStructureCommand());
        compiler.addStructureParser(new SoundDataStructureCommand());
        
        // Code section parsers
        
        // TODO Break out other commands in other systems
        // TODO Ability to pass in a "base" number for a command and
        //      figure that out from the SPIN configuration. Ability
        //      to figure out what commands to add from the SPIN.
        // TODO Move all SPIN flavors to the main directory and
        //      differentiate them by name

        compiler.addParser(new Parse_BRANCHIFNOT());
        compiler.addParser(new Parse_BRANCHIF());
        compiler.addParser(new Parse_CALL());
        compiler.addParser(new Parse_DEBUG());
        compiler.addParser(new Parse_EXECUTE());
        compiler.addParser(new Parse_GETINPUTS());
        compiler.addParser(new Parse_GETJOYSTICK());
        compiler.addParser(new Parse_GOTO(Command_GOTO_MIX.class));
        compiler.addParser(new Parse_INPUTMODE());
        compiler.addParser(new Parse_LOADVARIABLES());
        compiler.addParser(new Parse_MEMCOPY());
        compiler.addParser(new Parse_NOOP());
        compiler.addParser(new Parse_PADMODE());
        compiler.addParser(new Parse_PAUSE());
        compiler.addParser(new Parse_RETURN());
        compiler.addParser(new Parse_RUMBLE());
        compiler.addParser(new Parse_SAVEVARIABLES());
        compiler.addParser(new Parse_STOP());
        compiler.addParser(new Parse_TOKENIZE());
                
        compiler.addParser(new DiskCOGParser());        
        compiler.addParser(new VideoCOGParser());        
        compiler.addParser(new SoundCOGParser());       
        // VariableCOGCOmmand should be added last. It assumes everything
        // was meant for it.
        compiler.addParser(new VariableCOGParser()); 
                
        // DataCOGCommand should be added last. It assumes everything
        // was meant for it.        
        compiler.addDataParser(new DataCOGParser());
        
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
        
        // If the raw SPIN is requested, write it
        if(args.length>2) {
            OutputStream oos = new FileOutputStream(args[2]);
            er = compiler.writeSPIN(new PrintStream(oos));
            if(er!=null) {
                System.out.println(er);
                return;
            }            
        }        
         
        // Write the binary file
        OutputStream os = new FileOutputStream(args[1]);
        er = writeBinary(os,compiler);
        os.flush();
        os.close();
        if(er!=null) {
            System.out.println(er);
            return;
        }              
        
    } 
    
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
    
}