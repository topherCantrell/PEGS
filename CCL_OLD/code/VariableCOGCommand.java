package code;

import java.util.*;
import java.io.*;

public class VariableCOGCommand extends COGCommand
{
    
    int process;
    int op;
    
    int size;
    
    boolean destUsed;
    boolean leftUsed;    
    int typeDest;
    int typeLeft;
    int typeRight;
    int sizeDest;
    int sizeLeft;
    int sizeRight;
    long dest;
    long left;
    long right;    
    
    public VariableCOGCommand(CodeLine line,Cluster clus) {super(line,clus);}
    
    public int getSize()
    {
        int ts = 1; // The first long (command)
        if( (sizeDest==1 && destUsed) || (sizeLeft==1 && leftUsed) || sizeRight==1) {
            ++ts; // DLR is present
        }
        if(sizeDest==4) ++ts;
        if(sizeLeft==4) ++ts;
        if(sizeRight==4) ++ts;           
        return ts*4;
    }
    
    String [] SYMBS = {
        "=","==","!=","<","<=",">",">=",               // 7 PROCESS
        "+","-","*","/","%","<<",">>","&","|","^","~"  // 11 OP
    };    
    
    int findFirstSymbol(String s)
    {
        int symPos = s.length()+1;
        int symSize = 0;
        int symNum = -1;
        for(int x=0;x<SYMBS.length;++x) {
            int i = s.indexOf(SYMBS[x]);
            if(i>=0 && i<=symPos && symSize<=SYMBS[x].length()) {
                symPos = i;
                symSize = SYMBS[x].length();
                symNum = x;
            }
        }
        return symNum;
    }
    
    public String parse(CodeLine c, Cluster cluster)
    {
        boolean ours = false;
        if( (c.text.charAt(0)=='v') || (c.text.charAt(0)=='V') || (c.text.charAt(0)=='[')) 
        {
            ours = true;
        }
        if(c.text.charAt(0)>='0' && c.text.charAt(0)<='9') {
            ours = true;
        }
        if(!ours) return null;
        
        // [DEST PROCESS] LEFT [OP RIGHT]
        
        // TYPE ... 0=variable, 1=variable-ind, 2=constant, 3=special
        //  Special: 0=memory[constant], 1=register[constant], 2=memory[var], 15=RANDOM
        String [] value = {"","",""};
        long [] val = {0,0,0};
        int [] type = {-1,-1,-1};
        int [] size = {-1,-1,-1};        
        int process=-1;        
        int op=-1;        
        boolean destUsed = false;
        boolean leftUsed = false;
        
        String s = c.text;
        int i = findFirstSymbol(s);
        if(i>=0 && i<7) {
            process = i;
            int j = s.indexOf(SYMBS[i]);
            value[0] = s.substring(0,j).trim();       
            s = s.substring(j+SYMBS[i].length());
        }
        
        i = findFirstSymbol(s);
        if(i>=7) {
            op = i-7;
            int j = s.indexOf(SYMBS[i]);
            value[2] = s.substring(j+SYMBS[i].length()).trim();
            s = s.substring(0,j).trim();
        }
        
        value[1] = s.trim();
        
        // Move "left" to "right" if there is no operation
        if(op==-1 && value[2].equals("")) {
            value[2] = value[1];            
            value[1]="";                
        }
        
        for(int x=0;x<3;++x) {
            if((value[x].startsWith("[") && (!value[x].endsWith("]"))) ||
             (value[x].endsWith("]") && (!value[x].startsWith("[")))) {
                return "[ ] bracket mismatch";
            }  
            if(value[x].length()==0) {
                type[x] = 2;
                val[x] = 0;
                size[x] = 1;
            } else if(value[x].startsWith("VMEM")) {
                type[x] = 3;
                size[x] = 4;
                i = value[x].indexOf("(");
                if(i<0) {
                    return "VMEM(...) missing '('";
                }
                int j = value[x].lastIndexOf(")");
                if(j<0) {
                    return "VMEM(...) missing ')'";
                }
                s = value[x].substring(i+1,j).trim();
                int sptype = 0;
                if(s.startsWith("V") || s.startsWith("v")) {
                    sptype = 2;
                    s=s.substring(1);
                }
                try {
                    val[x] = CodeLine.parseNumber(s);
                } catch (Exception e) {
                    return "Invalid memory address";
                }
                if(val[x]<0 || val[x]>0xFFFF) {
                    return "Invalid memory address";
                }
                if(sptype==2 && val[x]>127) {
                    return "Invalid register number";
                }
                val[x] = val[x] | sptype<<16;
            } else if(value[x].equals("VRAND")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0xF0000;
            } else if(value[x].equals("VDIR")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0x101FE;
            } else if(value[x].equals("VOUT")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0x101F4;
            } else if(value[x].equals("VIN")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0x101F2;
            } else if(value[x].equals("VKEY")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0x3000;                
            } else if(value[x].startsWith("VKEYSTATE")) {
                type[x] = 3;
                size[x] = 4;
                i = value[x].indexOf("(");
                if(i<0) {
                    return "VKEYSTATE(...) missing '('";
                }
                int j = value[x].lastIndexOf(")");
                if(j<0) {
                    return "VKEYSTATE(...) missing ')'";
                }
                s = value[x].substring(i+1,j).trim();
                int sptype = 4;
                if(s.startsWith("V") || s.startsWith("v")) {
                    sptype = 5;
                    s=s.substring(1);
                }
                try {
                    val[x] = CodeLine.parseNumber(s);
                } catch (Exception e) {
                    return "Invalid number";
                }                
                if(sptype==5 && val[x]>127) {
                    return "Invalid register number";
                }
                val[x] = val[x] | sptype<<16;
            } else if(value[x].startsWith("V") || value[x].startsWith("v")) {
                type[x] = 0;
                size[x] = 1;
                value[x] = value[x].substring(1);
                try {
                    val[x] = CodeLine.parseNumber(value[x]);
                } catch (Exception e) {
                    return "Invalid register number";
                }
                if(val[x]<0 || val[x]>127) {
                    return "Invalid register number";
                }
            } else if(value[x].startsWith("[")) {
                type[x] = 1;
                size[x] = 1;
                value[x] = value[x].substring(2,value[x].length()-1);
                try {
                    val[x] = CodeLine.parseNumber(value[x]);
                } catch (Exception e) {
                    return "Invalid register number";
                }
                if(val[x]<0 || val[x]>127) {
                    return "Invalid register number";
                }
            } else {
                type[x] = 2;
                try {       
                    val[x] = CodeLine.parseNumber(value[x]);                    
                } catch (Exception e) {
                    return "Invalid numeric constant";
                }
                if(x==0) {
                    if(val[x]<256) {
                        size[x] = 1;
                    } else {
                        size[x] = 4;
                    }
                } else {
                     if(val[x]<4096) {
                        size[x] = 1;
                    } else {
                        size[x] = 4;
                    }
                }
            }
        }
        
        if(op<0) {
            op = 15;
        }
        if(process<0) {
            process = 15;
        }
        if(value[0].length()>0) {
            destUsed = true;
        }
        if(value[1].length()>0) {
            leftUsed = true;
        }
        
        VariableCOGCommand v = new VariableCOGCommand(c,cluster);      
        v.destUsed = destUsed;
        v.leftUsed = leftUsed;
        v.op = op;
        v.process = process;
        v.dest = val[0];
        v.typeDest = type[0];
        v.sizeDest = size[0];        
        v.left = val[1];
        v.typeLeft = type[1];
        v.sizeLeft = size[1];
        v.right = val[2];
        v.typeRight = type[2];
        v.sizeRight = size[2];
                
        cluster.commands.add(v);
        
        return "";
    }
    
    public String toSPIN(List<Cluster> clusters)
    {
        
        // %1_111_0001__ss000abc__flags__process__op       DLR DEST LEFT RIGHT
        int ts = 0;
        boolean useDLR= false;
        if( (sizeDest==1 && destUsed) || (sizeLeft==1 && leftUsed) || sizeRight==1) {
            ++ts; // DLR is present
            useDLR = true;
        }
        if(sizeDest==4) ++ts;
        if(sizeLeft==4) ++ts;
        if(sizeRight==4) ++ts;   
        size = (ts+1)*4;        
        --ts; // These are "extra" so don't count the 1st one
        
        // First pass all we care about is size
        if(clusters==null) return null;
        
        int flags = typeDest<<4 | typeLeft<<2 | typeRight;
        if(destUsed) flags = flags | 128;        
        if(leftUsed) flags = flags | 64;   
        
        int tsizeDest = sizeDest;
        int tsizeLeft = sizeLeft;
        int tsizeRight = sizeRight;
        
        if(sizeDest==4) tsizeDest=0;
        if(sizeLeft==4) tsizeLeft=0;
        if(sizeRight==4) tsizeRight=0;
        
        String tt = "' "+codeLine.text+"\r\n";
        tt = tt+"  long  %1_111_0001__"+CodeLine.toBinaryString(ts,2)+"_000_"+
            CodeLine.toBinaryString(tsizeDest,1)+CodeLine.toBinaryString(tsizeLeft,1)+CodeLine.toBinaryString(tsizeRight,1)+
            "_"+CodeLine.toBinaryString(flags,8)+"_"+
            CodeLine.toBinaryString(process,4)+"_"+CodeLine.toBinaryString(op,4)+"\r\n";
        
        if(useDLR) {    
            int fa=(int)dest;
            int fb=(int)left;
            int fc=(int)right;
            if(!destUsed || tsizeDest==0) fa=0;
            if(!leftUsed || tsizeLeft==0) fb=0;
            if(tsizeRight==0) fc=0;
            tt=tt+"    long %" + CodeLine.toBinaryString(fa,8) + "_" + CodeLine.toBinaryString(fb,12) + 
                "_" + CodeLine.toBinaryString(fc,12)+"\r\n";
        }
        
        if(tsizeDest==0) {
            tt=tt+"    long %"+Long.toString(dest,2)+"\r\n";
        }
        if(tsizeLeft==0) {
            tt=tt+"    long %"+Long.toString(left,2)+"\r\n";
        }
        if(tsizeRight==0) {            
            tt=tt+"    long %"+Long.toString(right,2)+"\r\n";
        }  
        
        return tt;
        
        /*
        String ret = "";
        ret+=codeLine.text+" "+ts+"\r\n";
        ret+="DEST=  type="+typeDest+" size="+sizeDest+" used="+destUsed+" val="+Long.toString(dest,16)+"\r\n";
        ret+="   PROCESS="+process+"\r\n";
        ret+="LEFT=  type="+typeLeft+" size="+sizeLeft+" used="+leftUsed+" val="+Long.toString(left,16)+"\r\n";
        ret+="   OP="+op+"\r\n";
        ret+="RIGHT= type="+typeRight+" size="+sizeRight+" val="+Long.toString(right,16)+"\r\n";         
        return ret;
         */

    }
    
}
