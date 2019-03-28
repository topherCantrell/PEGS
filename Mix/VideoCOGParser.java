/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class VideoCOGParser implements Parser 
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
    
    public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
    {
        String s = c.text;
        String ss = s.toUpperCase();               
        
        // CLS
        // CLS n
        if(ss.equals("CLS") || ss.startsWith("CLS ")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);           
            
            s = s.substring(3).trim();            
            ArgumentList aList = new ArgumentList(s,subs); 
            
            vc.tileNumber = 32;
            
            Argument a = aList.removeArgument("TILE",0);
            if(a!=null) {
                if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                    return "Invalid TILE value '"+a.value+"'. Must be 0-65535.";
                }
                vc.tileNumber = (int)a.longValue;
            }     
            
            a = aList.removeArgument("COLORSET",1);
            if(a!=null) {
                if(!a.longValueOK || a.longValue<0 || a.longValue>15) {
                    return "Invalid COLORSET value '"+a.value+"'. Must be 0-15.";
                }
                vc.tileNumber = vc.tileNumber & 0x0FFF;
                vc.tileNumber = vc.tileNumber | (int)(a.longValue<<12);
            }
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 0;            
            vc.width = 32;
            vc.height = 26;
            cluster.commands.add(vc);    
            
            int i = cluster.lines.indexOf(c);
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"SETCURSOR 0,0");
            cluster.lines.add(i+1,cc);
            
            return "";
        }
        
        // WAITFORVERTICALRETRACE
        if(ss.equals("WAITFORVERTICALRETRACE")) {            
            int i = cluster.lines.indexOf(c);
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"MEM(M_DRAWROW)==250");
            cc.labels.add("_waitForVerticalRetrace_"+(i+1));
            cluster.lines.add(i+1,cc);
            cc = new CodeLine(c.lineNumber,c.file,"BRANCH-IFNOT _waitForVerticalRetrace_"+(i+1));
            cluster.lines.add(i+2,cc);            
            return "";
        }
        
        if(ss.equals("SETCOLOR") || ss.startsWith("SETCOLOR ")) {
            s = s.substring(8).trim();
            ArgumentList aList = new ArgumentList(s,subs);            
            Argument a = aList.removeArgument("INDEX",0);
            if(a==null) {
                return "Missing INDEX value. Must be 0-15.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>15) {
                return "Invalid INDEX value '"+a.value+". Must be 0-15.";
            }            
            int n = (int)a.longValue;
            a = aList.removeArgument("C0",1);
            if(a==null) {
                return "Missing CO value. Must be 0-255.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                return "Invalid CO value '"+a.value+". Must be 0-255.";
            }
            long c0 = a.longValue;            
            a = aList.removeArgument("C1",2);
            if(a==null) {
                return "Missing C1 value. Must be 0-255.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                return "Invalid C1 value '"+a.value+". Must be 0-255.";
            }
            long c1 = a.longValue;            
            a = aList.removeArgument("C2",3);
            if(a==null) {
                return "Missing C2 value. Must be 0-255.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                return "Invalid C2 value '"+a.value+". Must be 0-255.";
            }
            long c2 = a.longValue;            
            a = aList.removeArgument("C3",4);
            if(a==null) {
                return "Missing C3 value. Must be 0-255.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                return "Invalid C3 value '"+a.value+". Must be 0-255.";
            }
            long c3 = a.longValue;
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            c0 = c0 | (c1<<8) | (c2<<16) | (c3<<24);
            
            int i = cluster.lines.indexOf(c);
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"MEM(M_COLORSCHEME_"+n+",LONG)="+c0);
            cluster.lines.add(i+1,cc);
            
            return "";
            
        }
        
        
        // RECTANGLE Vn
        // RECTANGLE x,y,width,height,tileNumber
        if(ss.equals("RECTANGLE") || ss.startsWith("RECTANGLE ")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(9).trim();            
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                aList.removeArgument("VARIABLE",0);
                vc.varForm = true;
                if(!a.isVariableOK) {
                    return "Invalid VARIABLE value '"+a.value+"' in '"+s+"' Must be "+Argument.validVariableForm+"."; 
                }                
                vc.tileNumber = (int)a.longValue;                
            } else {
                a = aList.removeArgument("X",0);
                if(a==null) {
                    return "Missing X value. Must be 0-31.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>32) {
                    return "Invalid X value '"+a.value+"'. Must be 0-31.";
                }
                vc.x = (int)a.longValue;
                a = aList.removeArgument("Y",1);
                if(a==null) {
                    return "Missing Y value. Must be 0-255.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                    return "Invalid Y value '"+a.value+"'. Must be 0-255.";
                }
                vc.y = (int)a.longValue; 
                a = aList.removeArgument("WIDTH",2);
                if(a==null) {
                    return "Missing WIDTH value. Must be 0-32..";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>32) {
                    return "Invalid WIDTH value '"+a.value+"'. Must be 0-32.";
                }
                vc.width = (int)a.longValue; 
                a = aList.removeArgument("HEIGHT",3);
                if(a==null) {
                    return "Missing HEIGHT value. Must be 0-255.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                    return "Invalid HEIGHT value '"+a.value+"'. Must be 0-255.";
                }
                vc.height = (int)a.longValue; 
                a = aList.removeArgument("TILE",4);
                if(a==null) {
                    return "Missing TILE value. Must be 0-65525.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                    return "Invalid TILE value. Must be 0-65535.";
                }
                vc.tileNumber = (int)a.longValue; 
                a = aList.removeArgument("COLORSET",1);
                if(a!=null) {
                    if(!a.longValueOK || a.longValue<0 || a.longValue>15) {
                        return "Invalid COLORSET value '"+a.value+"'. Must be 0-15.";
                    }
                    vc.tileNumber = vc.tileNumber & 0x0FFF;
                    vc.tileNumber = vc.tileNumber | (int)(a.longValue<<12);
                }                
            }
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 0;            
            cluster.commands.add(vc);
            
            return "";
        }
        
        // PRINT "HELLO"
        // PRINT msg1
        // PRINT msg[Vn]
        if(ss.equals("PRINT") || ss.startsWith("PRINT ")) {
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);               
            
            s=s.substring(5).trim(); 
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.removeArgument("MESSAGE",0);
            if(a==null) {
                return "Missing MESSAGE value.";
            }
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
                                    
            // Shortcut string litterals
            if(a.value.startsWith("\"")) {                
                if(!a.value.endsWith("\"")) {
                    return "Missing closing quote.";
                }
                addDataSectionIfNeeded(c,cluster);
                String t = a.orgCase+",0";
                CodeLine cc = new CodeLine(c.lineNumber,c.file,t);
                vc.type = 1; 
                vc.label = "_msg_"+c.lineNumber;
                cc.labels.add(vc.label);
                cluster.lines.add(cc);                  
            } else if(a.value.indexOf("[")>=0) {       
                
                int i = a.value.indexOf("[");            
                if(!a.value.endsWith("]")) {
                    return "Missing ']'";
                }
                
                Argument aa = new Argument(a.value.substring(i+1,a.value.length()-1),subs);
                
                if(!aa.isVariable || !aa.isVariableOK) {
                    return "Invalid variable '"+aa.value+"'. Must be "+Argument.validVariableForm+".";
                }
                
                vc.label = a.value.substring(0,i).trim();        
                vc.y = (int)aa.longValue;
                
                vc.type = 2;
            } else {
                vc.type = 1; 
                vc.label = a.value;
            }                  
            
            cluster.commands.add(vc);
            return "";                
        }                
        
        // PRINTVAR Vn
        if(ss.equals("PRINTVAR") || ss.startsWith("PRINTVAR ")) {             
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(8).trim();            
            ArgumentList aList = new ArgumentList(s,subs); 
            
            Argument a = aList.removeArgument("VARIABLE",0);
            if(a==null) {
                return "Missing VARIABLE value. Must be "+Argument.validVariableForm+".";
            }
            if(!a.isVariable || !a.isVariableOK) {                
                return "Invalid VARIABLE value '"+a.value+"'. Must be "+Argument.validVariableForm+".";                 
            } 
            vc.y = (int)a.longValue; 
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }            
            
            vc.type = 3;                         
            cluster.commands.add(vc);
            
            return "";               
        }
        
        // INPUTVAR Vn
        if(ss.equals("INPUTVAR") || ss.startsWith("INPUTVAR ")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(8).trim();            
            ArgumentList aList = new ArgumentList(s,subs); 
            
            Argument a = aList.removeArgument("VARIABLE",0);
            if(a==null) {
                return "Missing VARIABLE value. Must be "+Argument.validVariableForm+".";
            }
            if(!a.isVariable || !a.isVariableOK) {                
                return "Invalid VARIABLE value '"+a.value+"'. Must be "+Argument.validVariableForm+".";                 
            } 
            vc.y = (int)a.longValue; 
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }  
            
            vc.type = 4;  
            vc.y = (int) a.longValue;
            
            cluster.commands.add(vc);
            return "";               
        }
                
        // INPUTLINE buf,size
        if(ss.equals("INPUTLINE") || ss.startsWith("INPUTLINE ")) {            
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(9).trim();
            ArgumentList aList = new ArgumentList(s,subs); 
            
            Argument a = aList.removeArgument("BUFFER",0);
            if(a==null) {
                return "Missing BUFFER value. Must be a label in the data section.";                
            }
            vc.label = a.value;
            
            a = aList.removeArgument("SIZE",1);
            if(a==null) {
                return "Missing SIZE value. Must be 0-2048.";                
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>2048) {
                return "Invalid SIZE value '"+a.value+"'. Must be 0-2048.";
            }            
            vc.y = (int) a.longValue;           
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 5;
            cluster.commands.add(vc);            
           
            return "";               
        }
        
        // SETCURSOR Vn
        // SETCURSOR x,y
        if(ss.equals("SETCURSOR") || ss.startsWith("SETCURSOR ")) {            
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(9).trim();            
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                aList.removeArgument("VARIABLE",0);
                if(!a.isVariableOK) {
                    return "Invalid VARIABLE value '"+a.value+"'. Must be "+Argument.validVariableForm+"."; 
                }
                vc.varForm = true;                
                vc.y = (int)a.longValue;                
            } else {
                a = aList.removeArgument("X",0);
                if(a==null) {
                    return "Missing X value. Must be 0-31.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>32) {
                    return "Invalid X value '"+a.value+"'. Must be 0-31.";
                }
                vc.x = (int)a.longValue;
                a = aList.removeArgument("Y",1);
                if(a==null) {
                    return "Missing Y value. Must be 0-255.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                    return "Invalid Y value '"+a.value+"'. Must be 0-255.";
                } 
                vc.y = (int)a.longValue;
            }
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 6;
            cluster.commands.add(vc);
            
            return "";
            
        }
        
        // SETCURSORINFO tileA,tileB,blinkRate
        if(ss.equals("SETCURSORINFO") || ss.startsWith("SETCURSORINFO ")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(13).trim();            
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.removeArgument("TILEA",0);
            if(a==null) {
                return "Missing TILEA value. Must be 0-65535.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                return "Invalid TILEA value '"+a.value+"'. Must be 0-65535.";
            }
            vc.x = (int)a.longValue;
            a = aList.removeArgument("TILEB",1);
            if(a==null) {
                return "Missing TILEB value. Must be 0-65535.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                return "Invalid TILEB value '"+a.value+"'. Must be 0-65535.";
            }
            vc.y = (int)a.longValue;
            a = aList.removeArgument("BLINKRATE",2);
            if(a==null) {
                return "Missing BLINKRATE value. Must be 1-65535.";
            }
            if(!a.longValueOK || a.longValue<1 || a.longValue>65535) {
                return "Invalid BLINKRATE value '"+a.value+"'. Must be 1-65535.";
            }
            vc.width = (int)a.longValue;
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 7;
            cluster.commands.add(vc);
            
            return "";
            
        }
        
        // INITTILES ptr,start,count
        if(ss.equals("INITTILES") || ss.startsWith("INITTILES ")) {            
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
                        
            s = s.substring(9).trim();            
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.removeArgument("DATA",0);
            if(a==null) {
                return "Missing DATA value. Must be label in the data section.";
            }
            vc.label = a.value;            
            a = aList.removeArgument("START",1);
            if(a==null) {
                return "Missing START value. Must be 0-4095.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>4095) {
                return "Invalid START value '"+a.value+"'. Must be 0-4095.";
            }
            vc.x = (int)a.longValue;            
            a = aList.removeArgument("COUNT",2);
            if(a==null) {
                return "Missing COUNT value. Must be 1-4096.";
            }
            if(!a.longValueOK || a.longValue<1 || a.longValue>4096) {
                return "Invalid COUNT value '"+a.value+"'. Must be 1-4096.";
            }
            vc.y = (int)a.longValue;
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 8;
            cluster.commands.add(vc);
            
            return "";
            
        }
        
        // SETTILE Vn
        // SETTILE x,y,tile
        if(ss.equals("SETTILE") || ss.startsWith("SETTILE ")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(7).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                aList.removeArgument("VARIABLE",0);
                vc.varForm = true;
                if(a.longValue<0 || a.longValue>127) {
                    return "Invalid variable 'V"+a.value+"'. Must be V0-V127.";
                }
                vc.y = (int)a.longValue;
            } else {                
                a = aList.removeArgument("X",0);
                if(a==null) {
                    return "Missing X value. Must be 0-31.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>31) {
                    return "Invalid X value '"+a.value+"'. Must be 0-31.";
                }
                vc.x = (int)a.longValue;
                
                a = aList.removeArgument("Y",1);
                if(a==null) {
                    return "Missing Y value. Must be 0-255.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                    return "Invalid Y value '"+a.value+"'. Must be 0-255.";
                }
                vc.y = (int)a.longValue;
                a = aList.removeArgument("TILE",2);
                if(a==null) {
                    return "Missing TILE value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                    return "Invalid TILE value '"+a.value+"'.";
                }
                vc.width = (int)a.longValue;
            }
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            vc.type = 9;
            cluster.commands.add(vc);
            return "";
            
        }

        // GETTILE VN
        // GETTILE x,y,VN
         if(ss.equals("GETTILE") || ss.startsWith("GETTILE ")) {
             
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 10;
            
            s = s.substring(7).trim();            
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                aList.removeArgument("VARIABLE",0);
                vc.varForm = true;
                if(a.longValue<0 || a.longValue>127) {
                    return "Invalid variable 'V"+a.value+"'. Must be V0-V127.";
                }
                vc.y = (int)a.longValue;                
            } else {
                a = aList.removeArgument("X",0);
                if(a==null) {
                    return "Missing X value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>32) {
                    return "Invalid X value '"+a.value+"'. Must be 0-31.";
                }
                vc.x = (int)a.longValue;
                a = aList.removeArgument("Y",1);
                if(a==null) {
                    return "Missing Y value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                    return "Invalid Y value '"+a.value+"'. Must be 0-255.";
                }
                vc.y = (int)a.longValue; 
                a = aList.removeArgument("TILE",2);
                if(a==null) {
                    return "Missing TILE value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                    return "Invalid TILE value '"+a.value+"'.";
                }
                vc.width = (int)a.longValue;                 
            }
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            cluster.commands.add(vc);
            return "";            
            
        }
        
        if(ss.equals("SETSPRITE") || ss.startsWith("SETSPRITE")) {
            s = s.substring(9).trim();            
            
            ArgumentList aList = new ArgumentList(s,subs);
                                    
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 11;
            
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                a = aList.removeArgument("VARIABLE",0);
                if(!a.longValueOK || a.longValue<0 || a.longValue>127) {
                    return "Invalid VARIABLE value '"+a.value+"'. Must be 0-127.";
                }
                vc.y = (int)a.longValue;
                vc.varForm = true;
                
                a=aList.removeArgument("ACTIONSCRIPT",1);
                if(a!=null) {
                    vc.label = a.value;                    
                }
                
            } else {
                
                a = aList.removeArgument("SPRITE",0);
                if(a==null) {
                    return "Missing SPRITE value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>15) {
                    return "Invalid SPRITE value '"+a.value+"'. Must be 0-15.";
                }
                vc.n = (int)a.longValue;
                
                a = aList.removeArgument("X",1);
                if(a==null) {
                    return "Missing X value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>=320) {
                    return "Invalid X value '"+a.value+"'. Must be 0-319.";
                }
                vc.x = (int)a.longValue;
                
                a = aList.removeArgument("Y",2);
                if(a==null) {
                    return "Missing Y value.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>=272) {
                    return "Invalid Y value '"+a.value+"'. Must be 0-271.";
                }
                vc.y = (int)a.longValue;
                
                a = aList.removeArgument("IMAGE",4);
                String it = "IMAGE";
                if(a==null) {
                    a = aList.removeArgument("SIMPLEIMAGE",4);
                    it = "SIMPLEIMAGE";
                }
                if(a==null) {
                    return "Missing IMAGE or SIMPLEIMAGE value.";
                }
                if(!a.longValueOK || a.longValue<0) {
                    return "Invalid "+it+" value '"+a.value+"'. Must be 0-4095.";
                }
                vc.pic = (int)a.longValue;
                if(it.equals("SIMPLEIMAGE")) {
                    vc.pic = vc.pic | 0x8000;
                }
                
                a = aList.removeArgument("WIDTH",5);
                if(a==null) {
                    return "Missing WIDTH value.";
                }
                if(!a.longValueOK || (a.longValue!=8 && a.longValue!=16 && a.longValue!=32 && a.longValue!=64)) {
                    return "Invalid WIDTH value '"+a.value+"'. Must be 8, 16, 32, or 64.";
                }
                switch((int)a.longValue) {
                    case 8:
                        vc.width=0;
                        break;
                    case 16:
                        vc.width=1;
                        break;
                    case 32:
                        vc.width=2;
                        break;
                    case 64:
                        vc.width=3;
                        break;
                }
                
                a = aList.removeArgument("HEIGHT",6);
                if(a==null) {
                    return "Missing HEIGHT value.";
                }
                if(!a.longValueOK || (a.longValue!=8 && a.longValue!=16 && a.longValue!=32 && a.longValue!=64)) {
                    return "Invalid HEIGHT value '"+a.value+"'. Must be 8, 16, 32, or 64.";
                }
                switch((int)a.longValue) {
                    case 8:
                        vc.height=0;
                        break;
                    case 16:
                        vc.height=1;
                        break;
                    case 32:
                        vc.height=2;
                        break;
                    case 64:
                        vc.height=3;
                        break;
                }
                
                // Optionals                                
                
                a = aList.removeArgument("NUMPICS",6);
                if(a!=null) {
                    if(!a.longValueOK || a.longValue<1 || a.longValue>4) {
                        return "Invalid NUMPICS value '"+a.value+"'. Must be 1, 2, 3, or 4.";
                    }
                    vc.numPics = (int)a.longValue - 1; // ONE is assumed
                }
                
                a = aList.removeArgument("FLIPDELAY",7);
                if(a!=null) {
                    if(vc.numPics==0) {
                        return "Cannot specify FLIPDELAY without NUMPICS>1.";
                    }
                    if(!a.longValueOK || a.longValue<0 || a.longValue>3) {
                        return "Invalid FLIPDELAY value '"+a.value+"'. Must be 0, 1, 2, or 3.";
                    }
                    vc.flipDelay = (int)a.longValue;
                }
                
                vc.flipTimer = vc.numPics<<4 | vc.flipDelay<<2 | 3;
                
                a = aList.removeArgument("FLIPTIMER",8);
                if(a!=null) {
                    if(vc.numPics==0) {
                        return "Cannot specify FLIPTIMER without NUMPICS>1.";
                    }
                    if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                        return "Invalid FLIPTIMER value '"+a.value+"'. Must be 0-255.";
                    }
                    vc.flipTimer = (int)a.longValue;
                }
                
                a=aList.removeArgument("ACTIONSCRIPT",15);
                if(a!=null) {
                    vc.label = a.value;
                    vc.actionScriptTimer = 1;
                    vc.deltaX=1;vc.delayX=1;vc.xCount=1;
                }
                
                a=aList.removeArgument("DELTAX",9);
                if(a!=null) {
                    if(!a.longValueOK || a.longValue<-8 || a.longValue>7) {
                        return "Invalid DELATAX value '"+a.value+"'. Must be -8 to 7.";
                    }
                    vc.deltaX = (int)a.longValue;
                    if(vc.deltaX<0) vc.deltaX=16+vc.deltaX;
                }
                a=aList.removeArgument("DELTAY",10);
                if(a!=null) {
                    if(!a.longValueOK || a.longValue<-8 || a.longValue>7) {
                        return "Invalid DELATAY value '"+a.value+"'. Must be -8 to 7.";
                    }
                    vc.deltaY = (int)a.longValue;
                    if(vc.deltaY<0) vc.deltaY=16+vc.deltaY;
                }
                a=aList.removeArgument("DELAYX",11);
                if(a!=null) {
                    if(vc.deltaX==0) {
                        return "Cannot specify a DELAYX without a non-zero DELTAX.";
                    }
                    if(!a.longValueOK || a.longValue<=0 || a.longValue>255) {
                        return "Invalid DELAYX value '"+a.value+"'. Must be 1-255.";
                    }
                    vc.delayX = (int)a.longValue;
                }
                a=aList.removeArgument("DELAYY",12);
                if(a!=null) {
                    if(vc.deltaY==0) {
                        return "Cannot specify a DELAYY without a non-zero DELTAY.";
                    }
                    if(!a.longValueOK || a.longValue<=0 || a.longValue>255) {
                        return "Invalid DELAYY value '"+a.value+"'. Must be 1-255.";
                    }
                    vc.delayY = (int)a.longValue;
                }
                vc.xCount = vc.delayX;
                vc.yCount = vc.delayY;
                a=aList.removeArgument("XCOUNT",13);
                if(a!=null) {
                    if(vc.deltaX==0) {
                        return "Cannot specify a XCOUNT without a non-zero DELTAX.";
                    }
                    if(!a.longValueOK || a.longValue<1 || a.longValue>255) {
                        return "Invalid XCOUNT value '"+a.value+"'. Must be 1-255.";
                    }
                    vc.xCount = (int)a.longValue;
                }
                a=aList.removeArgument("YCOUNT",14);
                if(a!=null) {
                    if(vc.deltaY==0) {
                        return "Cannot specify a YCOUNT without a non-zero DELTAY.";
                    }
                    if(!a.longValueOK || a.longValue<1 || a.longValue>255) {
                        return "Invalid YCOUNT value '"+a.value+"'. Must be 1-255.";
                    }
                    vc.yCount = (int)a.longValue;
                }
                
                a=aList.removeArgument("ACTIONSCRIPTTIMER",16);
                if(a!=null) {
                    if(vc.label==null) {
                        return "Cannont specify ACTIONSCRIPTTIMER without an ACTIONSCRIPT value.";
                    }
                    if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                        return "Invalid ACTIONSCRIPTTIMER value '"+a.value+"'. Must be 0-255.";
                    }
                    vc.actionScriptTimer = (int)a.longValue;
                }
                
                String rem = aList.reportUnremovedValues();
                if(rem.length()!=0) {
                    return "Invalid values: '"+rem+"'";
                }
                
            }
            
            cluster.commands.add(vc);
            return "";
        }

        if(ss.equals("GETSPRITE") || ss.startsWith("GETSPRITE")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(9).trim();            
            ArgumentList aList = new ArgumentList(s,subs); 
            
            Argument a = aList.removeArgument("VARIABLE",0);
            if(a==null) {
                return "Missing VARIABLE value. Must be "+Argument.validVariableForm+".";
            }
            if(!a.isVariable || !a.isVariableOK) {                
                return "Invalid VARIABLE value '"+a.value+"'. Must be "+Argument.validVariableForm+".";                 
            } 
            vc.y = (int)a.longValue; 
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }            
            
            vc.type = 12;                         
            cluster.commands.add(vc);
            
            return "";                        
        }
        
        if(ss.equals("SCROLLSCRIPT") || ss.startsWith("SCROLLSCRIPT")) {
            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            
            s = s.substring(12).trim();            
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.removeArgument("DATA",0);
            if(a==null) {
                return "Missing DATA value. Must be label in the data section.";
            }
            vc.label = a.value; 

            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Invalid values: '"+rem+"'";
            }       
        
            vc.type = 13;
            cluster.commands.add(vc);
            return "";                   
            
        }
            
        
        return null;
    }   

    public void addDataSectionIfNeeded(CodeLine c, Cluster cluster) {
        boolean fnd = false;
        for(int x=0;x<cluster.lines.size();++x) {
            if(cluster.lines.get(x).text.trim().startsWith("---")) {
                fnd = true;
                break;
            }
        }
        if(!fnd) {
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"---");
            cluster.lines.add(cc);
        }
    }
    
}

