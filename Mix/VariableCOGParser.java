import java.util.*;

public class VariableCOGParser implements Parser 
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
    
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
            if(i<0) continue;
            if(i<symPos || (i==symPos && symSize<=SYMBS[x].length()) ) {
                symPos = i;
                symSize = SYMBS[x].length();
                symNum = x;
            }
        }
        return symNum;
    }
    
    public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
    {
        
        // We are last in the chain ... we assume this command is ours.        
        
        // [DEST end] [LEFT op] RIGHT
        
        String [] value = {"","",""};
        String [] label = {null,null,null};
        long [] val = {0,0,0};
        int [] type = {-1,-1,-1};
        int [] size = {-1,-1,-1};        
        int process=-1;        
        int op=-1;        
        boolean destUsed = false;
        boolean leftUsed = false;
        String rep = null;
        
        String s = c.text;         
        
        
        // Allow for ++n, n++, --n, and n--
        if(s.endsWith("++") || s.endsWith("--")) {
            String a = s.substring(0,s.length()-2);
            String b = s.substring(s.length()-2);
            s = b+a;
        }
        if(s.startsWith("++") || s.startsWith("--")) {
            String a = s.substring(2);
            char b = s.charAt(0);
            s = a+"="+a+b+"1";            
        }         
                        
        
        // IF statements may be written with compares flipped around. We will
        // order things correctly here.
        // For instance "IF(V1 & 1 > 0)" becomes "IF(0 < V1 & 1)".
        String flips = s;
        int fi = findFirstSymbol(flips);        
        if(fi>=7) {            
            int fij = flips.indexOf(SYMBS[fi]);
            flips = flips.substring(fij+SYMBS[fi].length());
            int fik = findFirstSymbol(flips);
            if(fik>=0 && fik<7) {
                fi = s.indexOf(SYMBS[fik]);
                int sfi = SYMBS[fik].length();
                String fa = s.substring(0,fi);
                String fb = s.substring(fi,fi+sfi);
                String fc = s.substring(fi+sfi);
                if(fb.equals("<"))       fb=">";
                else if(fb.equals("<=")) fb=">=";
                else if(fb.equals(">"))  fb="<";
                else if(fb.equals(">=")) fb="<=";
                s = fc+fb+fa;
                System.out.println(":"+s+":");
            }
        }        
        
        // Find ENDING if there is one
        int i = findFirstSymbol(s);        
        if(i>=0 && i<7) {
            process = i;
            int j = s.indexOf(SYMBS[i]);
            value[0] = s.substring(0,j).trim().toUpperCase();       
            s = s.substring(j+SYMBS[i].length());
        }
        
        // Find OP if there is one
        i = findFirstSymbol(s);
        if(i>=7) {
            op = i-7;
            int j = s.indexOf(SYMBS[i]);
            value[2] = s.substring(j+SYMBS[i].length()).trim().toUpperCase();
            s = s.substring(0,j).trim();
        }
        
        // We've stripped off the beginning (DEST) and end (RIGHT).
        // What's left is the LEFT.
        value[1] = s.trim().toUpperCase();
        
        // Move "left" to "right" if there is no operation
        if(op==-1 && value[2].equals("")) {
            value[2] = value[1];            
            value[1]="";                
        }
                
        // Process the 3 value terms DLR
        for(int x=0;x<3;++x) {
            // Check for bracket mismatches (if there are any brackets)
            if((value[x].startsWith("[") && (!value[x].endsWith("]"))) ||
             (value[x].endsWith("]") && (!value[x].startsWith("[")))) {
                return "[ ] bracket mismatch";
            } 
            
            // No term ... constant ZERO
            if(value[x].length()==0) {
                type[x] = 2;
                val[x] = 0;
                size[x] = 1;
            } 
            
            // ADDRESS-OF term is a constant (filled in later)
            else if(value[x].startsWith("@")) {
                // Addresses will be 2K (small size) and we can't
                // resolve them till later.
                type[x] = 2;
                size[x] = 1;
                s = value[x].substring(1).trim();
                rep = subs.get(s.toUpperCase());
                if(rep!=null) s=rep.toUpperCase();
                label[x] = s;                
            } 
            
            // MEM(0x100,byte) MEM(V100,word)
            else if(value[x].startsWith("MEM")) {
                type[x] = 3;
                size[x] = 4;                
                i = value[x].indexOf("(");
                if(i<0) {
                    return "MEM(...) missing '('";
                }
                int j = value[x].lastIndexOf(")");
                if(j<0) {
                    return "MEM(...) missing ')'";
                }
                s = value[x].substring(i+1,j).trim();
                int sptype = 0;
                
                // Process the arguments in the parenthesis
                ArgumentList aList = new ArgumentList(s,subs);
                Argument a = aList.getArgument("VARIABLE",0);
                if(a!=null && a.isVariable) {
                    aList.removeArgument("VARIABLE",0);
                    if(!a.isVariableOK) {
                        return "Invalid VARIABLE value '"+a.value+"' in '"+s+"'. Must be "+Argument.validVariableForm+".";
                    }
                    sptype = 1;
                    val[x] = (int)a.longValue;
                } else {
                    a = aList.removeArgument("ADDRESS",0);
                    if(a==null) {
                        return "Missing ADDRESS or VARIABLE value in '"+s+"'. Must be 0-65535 or "+Argument.validVariableForm+".";
                    }
                    if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
                        return "Invalid ADDRESS value '"+a.value+"' in '"+s+"'. Must be 0-65535.";
                    }
                    //sptype = 0;
                    val[x] = (int)a.longValue;
                }                
                int moveSize = 1;
                a = aList.removeArgument("SIZE",1);
                if(a!=null) {
                    if(a.value.equals("BYTE")) {
                        moveSize = 1;
                    } else if(a.value.equals("WORD")) {
                        moveSize = 2;
                    } else if(a.value.equals("LONG")) {
                        moveSize = 4;
                    } else {
                        return "Invalid SIZE value '"+a.value+"' in '"+s+"'. Must be BYTE, WORD, or LONG.";
                    }
                }
                // Make sure there is nothing else in the parenthesis
                String rem = aList.reportUnremovedValues();
                if(rem.length()!=0) {
                    return "Unexpected: '"+rem+"' in '"+s+"'.";
                }                
                // Construct the special type
                val[x] = val[x] | moveSize<<24 | sptype<<16;
            } 
            
            // RAND
            else if(value[x].equals("RAND")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0x50000;
            }  
            
            // NEXTKEY
            else if(value[x].equals("NEXTKEY")) {
                type[x] = 3;
                size[x] = 4;
                val[x] = 0x30000;                
            }  
            
            // REGISTER(0x100)
            else if(value[x].startsWith("REGISTER")) {
                type[x] = 3;
                size[x] = 4;
                i = value[x].indexOf("(");
                if(i<0) {
                    return "REGISTER(...) missing '('";
                }
                int j = value[x].lastIndexOf(")");
                if(j<0) {
                    return "REGISTER(...) missing ')'";
                }
                s = value[x].substring(i+1,j).trim();
                
                // Process the arguments in the parenthesis
                ArgumentList aList = new ArgumentList(s,subs);
                Argument a =  aList.removeArgument("ADDRESS",0);
                if(a==null) {
                    return "Missing ADDRESS value in '"+s+"'. Must be 0-511.";
                }
                if(!a.longValueOK || a.longValue<0 || a.longValue>511) {
                    return "Invalid ADDRESS value '"+a.value+"' in '"+s+"'. Must be 0-511.";
                }                
                val[x] = (int)a.longValue | 0x40000;                                
                
                // Make sure there is nothing else in the parenthesis
                String rem = aList.reportUnremovedValues();
                if(rem.length()!=0) {
                    return "Unexpected: '"+rem+"' in '"+s+"'.";
                }                                
            }  
            
            // CLUSTER(0x100)
            else if(value[x].startsWith("CURRENT")) {
                type[x] = 3;
                size[x] = 4;
                i = value[x].indexOf("(");
                if(i<0) {
                    return "CURRENT(...) missing '('";
                }
                int j = value[x].lastIndexOf(")");
                if(j<0) {
                    return "CURRENT(...) missing ')'";
                }
                s = value[x].substring(i+1,j).trim();
                
                // Process the arguments in the parenthesis
                ArgumentList aList = new ArgumentList(s,subs);
                Argument a = aList.removeArgument("VARIABLE",0);
                if(a==null || !a.isVariable) {
                    return "Missing VARIABLE value in '"+s+"'. Must be "+Argument.validVariableForm+".";
                    
                } 
                if(!a.isVariableOK) {
                    return "Invalid VARIABLE value '"+a.value+"' in '"+s+"'. Must be "+Argument.validVariableForm+".";
                }
                
                val[x] = (int)a.longValue | 0x20000;
                
                int moveSize = 1;
                a = aList.removeArgument("SIZE",1);
                if(a!=null) {
                    if(a.value.equals("BYTE")) {
                        moveSize = 1;
                    } else if(a.value.equals("WORD")) {
                        moveSize = 2;
                    } else if(a.value.equals("LONG")) {
                        moveSize = 4;
                    } else {
                        return "Invalid SIZE value '"+a.value+"' in '"+s+"'. Must be BYTE, WORD, or LONG.";
                    }
                }
                // Make sure there is nothing else in the parenthesis
                String rem = aList.reportUnremovedValues();
                if(rem.length()!=0) {
                    return "Unexpected: '"+rem+"' in '"+s+"'.";
                }                
                // Construct the special type
                val[x] = val[x] | moveSize<<24;
                             
            }
            
            // Simple variable reference like "V100"
            else if(value[x].startsWith("V") ||
                (subs.get(value[x].toUpperCase())!=null && 
                  subs.get(value[x].toUpperCase()).toUpperCase().startsWith("V")) ) {
                type[x] = 0;
                size[x] = 1;
                Argument a = new Argument(value[x],subs);
                if(!a.isVariable || !a.isVariableOK) {
                    return "Invalid VARIABLE value '"+value[x]+"'. Must be "+Argument.validVariableForm+".";
                }
                val[x] = (int)a.longValue;                
            } 
            
            // Indirect variable reference like "[V100]"
            else if(value[x].startsWith("[")) {
                type[x] = 1;
                size[x] = 1;
                value[x] = value[x].substring(1,value[x].length()-1);               
                Argument a = new Argument(value[x],subs);
                if(!a.isVariable || !a.isVariableOK) {
                    return "Invalid VARIABLE value '"+value[x]+"'. Must be "+Argument.validVariableForm+".";
                }
                val[x] = (int)a.longValue; 
            } 
            
            // Nothing else ... it MUST be a constant value
            else {
                rep = subs.get(value[x].toUpperCase());
                if(rep!=null) value[x] = rep.toUpperCase();
                type[x] = 2;
                try {       
                    val[x] = CodeLine.parseNumber(value[x]);                    
                } catch (Exception e) {
                    return "Syntax error '"+value[x]+"'";                    
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
        
        // OP and ENDING values for "not-specified"
        if(op<0) {
            op = 11;
        }
        if(process<0) {
            process = 7;
        }
        
        // Flags for dest-used and left-used
        if(value[0].length()>0) {
            destUsed = true;
        }
        if(value[1].length()>0) {
            leftUsed = true;
        }
        
        // All the info to build the command
        VariableCOGParser.NCOGCommand v = new VariableCOGParser.NCOGCommand(c,cluster);    
        v.destLabel = label[0];
        v.leftLabel = label[1];
        v.rightLabel = label[2];
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
    
    static class NCOGCommand extends Command
    {
    	int process;
        int op;
        
        int size;
        
        String destLabel = null;
        String leftLabel = null;
        String rightLabel = null;
        
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
        
        public NCOGCommand(CodeLine line,Cluster clus) {super(line,clus);}
        
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
        
        public String toSPIN(List<Cluster> clusters)
        {
            
            if(destLabel!=null) {
                System.out.println("A");
                dest = Command.findOffsetToLabel(cluster,destLabel);
                if(dest<0) {
                    return "#Could not find label '"+destLabel+"'";
                }
            }
            if(leftLabel!=null) {
                System.out.println("B");
                left = Command.findOffsetToLabel(cluster,leftLabel);
                if(left<0) {
                    return "#Could not find label '"+leftLabel+"'";
                }
            }
            if(rightLabel!=null) {
                right = Command.findOffsetToLabel(cluster,rightLabel);
                if(right<0) {
                    System.out.println("OOPS "+rightLabel);
                    return "#Could not find label '"+rightLabel+"'";
                }
            }
            
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
            tt = tt+"  long  %10_111_001__"+CodeLine.toBinaryString(ts,2)+"_000_"+
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
            
        }

    }
    
    
}
