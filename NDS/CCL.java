import java.io.*;
import java.util.*;
import javax.swing.*;
import java.awt.*;

public class CCL {    
    
    // This is the tile-graphics canvas
    TileGrid tg = new TileGrid(32,26);
    
    // Keyboard listener (simulates PS pad)
    GCPad gcPad = new GCPad();
        
    class CodeLine {
        String filename;
        int lineNumber;
        String content;
    }
    
    String errorCondition; 
    String currentLine;
    String firstWord;
    java.util.List clusterList = new ArrayList();
    
    java.util.List inputLines = new ArrayList();
    int currentInputLine = 0;
    
    Random rand = new Random();
    
    Map tokens = new HashMap();
    
    java.util.List substitutions = new ArrayList();
    int usedRegister = 0;
    
    String makeSubstitutions(String s) {
        for(int x=0;x<substitutions.size();++x) {
            String [] v = (String [])substitutions.get(x);
            while(true) {
                int i = s.indexOf(v[0]);
                if(i<0) break;
                s = s.substring(0,i)+v[1]+s.substring(i+v[0].length());
            }
        }
        return s;
    }
    
    void addSubstitution(String a, String b) {
        // If b is null then we are naming the next available registers
        if(b==null) {
            b = "V" + usedRegister;
            ++usedRegister;
        }
        
        String [] v = {a,b};
        
        // Make sure that the longest substitutions appear first in the list
        int i = 0;
        for(;i<substitutions.size();++i) {
            String [] vv = (String [])substitutions.get(i);
            if(vv[0].length()<a.length()) break;
        }
        substitutions.add(i,v);
        //for(int x=0;x<substitutions.size();++x) {
        //  String [] vv = (String [])substitutions.get(x);
        //  System.out.println(":"+vv[0]+":"+vv[1]+":");
        //}
    }
    
    String readNextLine() throws Exception {
        while(true) {
            if(currentInputLine>=inputLines.size()) {
                currentLine = null;
                return null;
            }
            CodeLine cc = (CodeLine)inputLines.get(currentInputLine++);
            currentLine = cc.content;
            currentLine = currentLine.trim();
            int i = currentLine.indexOf(";");
            if(i>=0) {
              currentLine = currentLine.substring(0,i);
            }
            //if(currentLine.startsWith(";")) continue;
            if(currentLine.length()==0) continue;
            break;
        }
        StringTokenizer st=new StringTokenizer(currentLine);
        firstWord = st.nextToken().toUpperCase();
        return currentLine;
    }
    
    public int convertNumber(String num) {
        num = num.trim();
        if(num.startsWith("0x")) {
            return Integer.parseInt(num.substring(2),16);
        }
        return Integer.parseInt(num);
    }
    
    public void error(String details) {
        CodeLine cc = (CodeLine)inputLines.get(currentInputLine);
        System.out.println("ERROR '"+cc.filename+"' line "+cc.lineNumber+" "+details);
        System.out.println(currentLine);
        errorCondition = details;
    }    
    
    public String parseCluster(String first, Cluster c) throws Exception {
        c.name = first.substring(8);
        //System.out.println(":"+c.name+":");
        
        String [] currentLabel = new String[10];
        int cp = 0;
        
        int ifLevel = 0;
        
        while(true) {
            String g = readNextLine();
            
            // End of file
            if(g==null) {
                firstWord = "CLUSTER";
            } else {
                g = makeSubstitutions(g);
            }
            
            // End of cluster
            if(firstWord.equals("CLUSTER")) {
                
                int labnum = 100;
                
                // Step through the commands
                // For IF
                //    Find close or else at this level
                //    Add a label to next line and fail-jump that label
                // For ELSE
                //    Find close at this level
                //    Add a label to next line and convert to GOTO to that label
                // For CLOSE
                //    Remove
                
                for(int x=0;x<c.commands.size();++x) {
                    Command tc = (Command)c.commands.get(x);
                    if(tc.id!=4 && tc.id!=5 && tc.id!=6) continue;
                    FlowCommand fc = (FlowCommand)tc;
                    
                    //System.out.println(":"+tc.id);
                    
                    if(fc.id==4) {
                        int ff = x;
                        while(true) {
                            ++ff;
                            Command ttc = (Command)c.commands.get(ff);
                            if(ttc.id!=5 && ttc.id!=6) continue;
                            FlowCommand fz =(FlowCommand)ttc;
                            if(fz.nestLevel!=fc.nestLevel) continue;
                            Command nxt = (Command)c.commands.get(ff+1);
                            nxt.addLabel("_intern_"+labnum);
                            fc.offset = "_intern_"+labnum;
                            ++labnum;
                            break;
                        }
                    } else if(fc.id==6) {
                        int ff = x;
                        while(true) {
                            ++ff;
                            Command ttc = (Command)c.commands.get(ff);
                            if(ttc.id!=5) continue;
                            FlowCommand fz =(FlowCommand)ttc;
                            if(fz.nestLevel!=fc.nestLevel) continue;
                            Command nxt = (Command)c.commands.get(ff+1);
                            nxt.addLabel("_intern_"+labnum);
                            FlowCommand nfc = new FlowCommand(1,g);
                            nfc.offset = "_intern_"+labnum;
                            ++labnum;
                            c.commands.set(x,nfc);
                            break;
                        }
                    } else {
                        Command nxt = (Command)c.commands.get(x+1);
                        for(int y=0;y<fc.label.length;++y) {
                            if(fc.label[y]!=null) {
                                nxt.addLabel(fc.label[y]);
                            }
                        }
                        c.commands.remove(x);
                        x=x-1;
                    }
                }
                
                return g;
            }
            
            // Label
            if(g.endsWith(":")) {
                String nl = g.substring(0,g.length()-1);
                for(int x=0;x<c.commands.size();++x) {
                    Command cc = (Command)c.commands.get(x);
                    for(int y=0;y<cc.label.length;++y) {
                        if(nl.equals(cc.label[y])) {
                            errorCondition = "Label already defined";
                            return null;
                        }
                    }
                }
                currentLabel[cp++] = nl;
                continue;
            }
            
            if(firstWord.equals("GOTO") || firstWord.equals("CALL")) {
                int id = 1;
                if(firstWord.equals("CALL")) id=2;
                FlowCommand fc = new FlowCommand(id,g);
                g = g.substring(5).trim();
                int i = g.indexOf(":");
                if(i>=0) {
                    fc.cluster = g.substring(0,i);
                    fc.offset = g.substring(i+1);
                } else {
                    fc.offset = g;
                }
                c.commands.add(fc);
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
                 
            if(firstWord.equals("RETURN")) {
                FlowCommand fc = new FlowCommand(3,g);
                c.commands.add(fc);
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(g.toUpperCase().startsWith("IF(")) {
                FlowCommand fc = new FlowCommand(4,g);
                c.commands.add(fc);
                ++ifLevel;
                fc.nestLevel = ifLevel;
                int j = g.indexOf(")");
                COGCommand vc = new COGCommand(10,g);
                String e = parseVar(g.substring(3,j),vc);
                if(e!=null) {
                    errorCondition = e;
                    return null;
                }
                c.commands.add(vc);
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(g.toUpperCase().startsWith("}")) {
                FlowCommand fc = null;
                if(g.endsWith("{")) {
                    //System.out.println("FOUND }ELSE{");
                    fc = new FlowCommand(6,g);
                } else {
                    //System.out.println("FOUND }");
                    fc = new FlowCommand(5,g);
                }
                c.commands.add(fc);
                fc.nestLevel = ifLevel;
                if(fc.id==5) {
                    if(ifLevel<1) {
                        errorCondition = "Stack underflow";
                        return null;
                    }
                    --ifLevel;
                }
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(g.startsWith("#")) {
                DataCommand dc = new DataCommand(100,g);
                g=g.substring(1).trim();
                
                if(g.toUpperCase().startsWith("ALIGN")) {
                    int cth = 0;
                    for(int x=0;x<c.commands.size();++x) {
                        Command co = (Command)c.commands.get(x);
                        cth = cth + co.getBinarySize();
                    }
                    
                    if(g.toUpperCase().equals("ALIGN WORD")) {
                        if( (cth%2)==0 ) dc=null;
                        else {
                            dc.data.add(new Integer(0x55));
                        }
                    } else if(g.toUpperCase().equals("ALIGN LONG")) {
                        if( (cth%4)==0 ) dc=null;
                        else {
                            for(int x=0;x<4-(cth%4);++x) {
                                dc.data.add(new Integer(0x55));
                            }
                        }
                    }
                    
                    if(dc!=null) {
                        c.commands.add(dc);
                        for(int x=0;x<cp;++x) dc.label[x] = currentLabel[x];
                    }
                    cp=0;
                    continue;
                    
                }
                
                while(true) {
                    if(g.startsWith("\"")) {
                        int j = g.indexOf('"',1);
                        if(j<0) {
                            errorCondition = "Missing quote";
                            return null;
                        }
                        for(int x=1;x<j;++x) {
                            dc.data.add(new Integer(g.charAt(x)));                        
                        }
                        g=g.substring(j+1).trim();
                        if(g.startsWith(",")) g=g.substring(1).trim();
                        if(g.length()==0) break;
                    } else if(g.startsWith("|")) {

                        // Read 8 rows
                        String [] drs = new String[8];
                        drs[0] = g.substring(1).trim();
                        for(int xx=1;xx<drs.length;++xx) {
                          drs[xx] = readNextLine().trim();
                          drs[xx] = drs[xx].substring(1).trim().substring(1);
                        }     

                        for(int xx=0;xx<drs.length;++xx) {
                          while(true) {
                            int ii = drs[xx].indexOf(" ");
                            if(ii<0) break;
                            drs[xx] = drs[xx].substring(0,ii)+drs[xx].substring(ii+1);
                          }                          
                        }

                        byte [] bb = new byte[8*drs[0].length()];                        
                        for(int xx=0;xx<8;++xx) {   
                          for(int zz=0;zz<drs[0].length();++zz) {
                            if(drs[xx].charAt(zz)=='W') bb[drs[0].length()*xx+zz]=1;
                            else if(drs[xx].charAt(zz)=='G') bb[drs[0].length()*xx+zz]=2;
                            else if(drs[xx].charAt(zz)=='R') bb[drs[0].length()*xx+zz]=3;                    
                          }                                                
                        }

                        for(int xx=0;xx<drs[0].length()/8;++xx) {
                          for(int yy=0;yy<8;++yy) {
                            int fi = yy*drs[0].length()+xx*8;
                            dc.data.add(new Integer((bb[fi+0]) | (bb[fi+1]<<2) | (bb[fi+2]<<4) | (bb[fi+3]<<6)));
                            dc.data.add(new Integer((bb[fi+4]) | (bb[fi+5]<<2) | (bb[fi+6]<<4) | (bb[fi+7]<<6)));                                   }
                        }
                        break;           

                    }
                    
                    else {
                        //System.out.println(">>"+g+"<<");
                        int j = g.indexOf(",");
                        if(j<0) {
                            dc.data.add(new Integer(convertNumber(g)));
                            break;
                        } else {
                            dc.data.add(new Integer(convertNumber(g.substring(0,j))));
                            g=g.substring(j+1).trim();
                        }
                    }
                }
                c.commands.add(dc);
                for(int x=0;x<cp;++x) dc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            
            
            
            // COG COMMANDS
            
            if(firstWord.equals("PRINT")) {
                COGCommand cc = new COGCommand(11,g);
                g = g.substring(6).trim();
                if(g.endsWith("]")) {
                    int i = g.indexOf("[");
                    cc.varA = Integer.parseInt(g.substring(i+2,g.length()-1));
                    cc.paramA = g.substring(0,i);
                } else {
                    cc.paramA = g;
                    cc.varA = -1;
                }
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("INPUTTOKENS")) {
                COGCommand cc = new COGCommand(12,g);
                cc.paramA = g.substring(12).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("INPUT")) {
                COGCommand cc = new COGCommand(13,g);
                cc.paramA = g.substring(6).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("PRINTVAR")) {
                COGCommand cc = new COGCommand(14,g);
                cc.paramA = g.substring(9).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("STICK")) {
                COGCommand cc = new COGCommand(20,g);
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("SETTILEDATA")) {
                COGCommand cc = new COGCommand(21,g);
                cc.paramA = g.substring(11).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("SETTILE")) {
                COGCommand cc = new COGCommand(22,g);
                cc.paramA = g.substring(7).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("TILEBLOCK")) {
                COGCommand cc = new COGCommand(23,g);
                cc.paramA = g.substring(9).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("GETTILE")) {
                COGCommand cc = new COGCommand(24,g);
                cc.paramA = g.substring(7).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("TILETEXT")) {
                COGCommand cc = new COGCommand(25,g);
                cc.paramA = g.substring(8).trim();                
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
                       
            
            if(firstWord.equals("READPAD")) {
                COGCommand cc = new COGCommand(30,g);
                cc.paramA = g.substring(8).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("SOUND")) {
                COGCommand cc = new COGCommand(31,g);
                cc.paramA = g.substring(5).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            
            
            
            if(g.toUpperCase().startsWith("V") || g.startsWith("[")) {
                COGCommand cc = new COGCommand(10,g);
                String e = parseVar(g,cc);
                if(e!=null) {
                    errorCondition = e;
                    return null;
                }
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            errorCondition = "Syntax error";
            return null;
            
        }
        
    }
    
    int findOp(String g, String [] set) {
        for(int x=0;x<set.length;++x) {
            int ii = g.indexOf(set[x]);
            if(ii>=0) {
                if(set[x].equals("<")) {
                    if(g.charAt(ii+1)=='<' || g.charAt(ii-1)=='<') {
                        continue;
                    }
                }
                if(set[x].equals(">")) {
                    if(g.charAt(ii+1)=='>' || g.charAt(ii-1)=='>') {
                        continue;
                    }
                }
                return x;
            }
        }
        return -1;
    }
    
    String parseVar(String g, COGCommand cc) {
        //System.out.println(">>"+g+"<<");
        String oog = g;
        
        // {RA o} {RB m} {C}
        
        // o : !=, >=, <=, <, >, =
        // m : +,-,PAU,&,|,~,<<,>>,RND
        
        while(true) {
            int i = g.indexOf(" ");
            if(i<0) break;
            g = g.substring(0,i)+g.substring(i+1);
        }
        
        //System.out.println("::"+g+"::");
        
        // Find m (if any)
        String [] mset ={"RND","<<",">>","+","-","&","|","~","PAUSE"};
        int m = findOp(g,mset);
        
        // Find o (if any)
        String [] oset = {"!=",">=","<=","==","<",">","="};
        int o = findOp(g,oset);

        //System.out.println(":"+m+":"+o+":");
        
        if(o>=0 && m>=0) {
            if(g.indexOf(oset[o]) == g.indexOf(mset[o])) {
                //System.out.println("HEY:"+o+":"+m+":"+g+":");
                // They can't be the same.
                o=-1;
            }
        }
        
        cc.math = m;
        cc.op = o;
        cc.varA = -1;
        cc.varB = -1;
        
        if(o>=0) {
            int i = g.indexOf(oset[o]);
            String asi = g.substring(1,i);
            //System.out.println("::"+asi+"::");
            if(asi.endsWith("]")) {
                cc.varAIsPtr = true;
                asi = asi.substring(1,asi.length()-1);
            }
            cc.varA = Integer.parseInt(asi);
            g = g.substring(i+oset[o].length());
        }
        
        if(m>=0) {
            int i = g.indexOf(mset[m]);
            //System.out.println(o+"::"+i+"::"+g+"::");
            if(i==0) {
                // This allows for "x = RND 1" forms
                cc.varB = cc.varA;
            } else {
                cc.varB = Integer.parseInt(g.substring(1,i));
            }
            g = g.substring(i+mset[m].length());
            //System.out.println("::"+g+"::");
            if(g.charAt(0)=='V' || g.charAt(0)=='v') {
                cc.constant = convertNumber(g.substring(1));
                cc.constIsVariable = true;
            } else {
                cc.constant = convertNumber(g);
            }
        } else {
            if(g.charAt(0)=='[') {
                g = g.substring(1).trim();
                cc.varB = Integer.parseInt(g.substring(1,g.length()-1));
                cc.varBIsPtr = true;
            } else if(g.charAt(0)=='V' || g.charAt(0)=='v') {
                cc.varB = Integer.parseInt(g.substring(1));
            } else {
                cc.constant = convertNumber(g);
            }
        }
        
        if(cc.varB<0) {
            // No B invloved ... expression becomes A= "0+" right
            cc.math=3;
        }
        if(cc.math<0) {
            cc.math=3;
            cc.constant = 0;
        }
        
        // No operation is required ... allows for "PAUSE 20" and "if(X&0x11)"
        //if(cc.op<0) {
        //    throw new RuntimeException("Must have operation:"+oog);
        //}
        
        
        
        //if(cc.varA>256) {
        //if(cc.varAIsPtr || cc.varBIsPtr) {
        //System.out.println(">>"+oog+"<<");
        //System.out.println(cc);
        //if(cc.math<0) System.exit(0);
        //}
        
        return null;
    }
    
    void loadCodeLines(String filename) throws Exception {
        int lineNumber=0;
        FileReader fr = new FileReader(filename);
        BufferedReader br = new BufferedReader(fr);
        while(true) {
            String g = br.readLine();
            ++lineNumber;
            if(g==null) break;
            String og = g.trim().toUpperCase();
            if(og.startsWith("INCLUDE ")) {
                og = og.substring(8).trim();
                loadCodeLines(og);
            } else {
                CodeLine c = new CodeLine();
                c.filename = filename;
                c.lineNumber = lineNumber;
                c.content = g;
                inputLines.add(c);
            }
        }
        br.close();
    }
    
    public CCL(String filename) throws Exception {
        
        loadCodeLines(filename);
        
        for(int x=0;x<inputLines.size();++x) {
            CodeLine cc = (CodeLine)inputLines.get(x);
            String g = cc.content.trim();
            String og = g.toUpperCase();
            if(og.startsWith("DEFINE ")) {
                String a = g.substring(7).trim();
                int i = a.indexOf(" ");
                if(i<0) {
                    error("Bad define format");
                }
                String b = a.substring(i+1).trim();
                a = a.substring(0,i);
                addSubstitution(a,b);
                cc.content = ";"+cc.content;
            } else if(og.startsWith("VARIABLE ")) {
                String a = g.substring(9).trim();
                addSubstitution(a,null);
                cc.content = ";"+cc.content;
            }
        }
        
        String g = readNextLine();
        if(g==null) return;
        
        if(!firstWord.equals("CLUSTER")) {
            error("Expected 'CLUSTER'");
            return;
        }
        
        while(true) {
            Cluster c = new Cluster();
            g = parseCluster(g,c);
            if(errorCondition!=null) {
                error(errorCondition);
                return;
            }
            clusterList.add(c);
            if(g==null) break; // End normally
        }
        
    }
    
    void writeBinary(OutputStream os) throws Exception {
        for(int x=0;x<clusterList.size();++x) {
            Cluster c = (Cluster)clusterList.get(x);
            int clsize = 0;
            for(int y=0;y<c.commands.size();++y) {
                Command com = (Command)c.commands.get(y);
                com.writeBinary(c,os,clusterList);
                clsize = clsize + com.getBinarySize();
            }
            if(clsize>2048) {
                throw new RuntimeException("Cluster '"+c.name+"' is "+clsize+" (>2048)");
            }
            while(clsize<2048) {
                os.write(0);
                ++clsize;
            }
        }
        
    }
    
    Cluster findCluster(String clus) {
        for(int x=0;x<clusterList.size();++x) {
            Cluster ret = (Cluster)clusterList.get(x);
            if(ret.name.equals(clus)) return ret;
        }
        return null;
    }
    
    static int findLabel(Cluster c, String label) {
        for(int x=0;x<c.commands.size();++x) {
            Command cc = (Command)c.commands.get(x);
            for(int y=0;y<cc.label.length;++y) {
                if(label.equals(cc.label[y])) return x;
            }
        }
        return -1;
    }
    
    public int doVarOp(COGCommand c2, int [] variables) {
        
        variables[126] = gcPad.keyPadValueA;
        variables[127] = gcPad.keyPadValueB;
        //System.out.println(c2);
        int rBv = 0;
        if(c2.varB>=0) {
            rBv = variables[c2.varB];
            if(c2.varBIsPtr) {
                rBv = variables[rBv];
            }
        }
        int cVal = c2.constant;
        if(c2.constIsVariable) {
            cVal = variables[cVal];
        }
        int rAv = 0;
        if(c2.varA>=0) {
            rAv = variables[c2.varA];
            if(c2.varAIsPtr) {
                rAv = variables[rAv];
            }
        }
        //"RND","<<",">>","+","-","&","|","~"
        switch(c2.math) {
            case 0:
                rBv = rand.nextInt()&cVal;
                if(rBv<0) rBv = -rBv;
                break;
            case 1:
                rBv = rBv << cVal;
                break;
            case 2:
                //System.out.println(">> "+rBv + " " +cVal);
                rBv = rBv >> cVal;
                break;
            case 3:
            case -1:
                rBv = rBv + cVal;
                break;
            case 4:
                rBv = rBv - cVal;
                break;
            case 5:
                rBv = rBv & cVal;
                break;
            case 6:
                rBv = rBv | cVal;
                break;
            case 7:
                rBv = ~rBv;
                break;
            case 8:
                cVal = cVal / 67000;
                //System.out.println(cVal);
                try{Thread.sleep(cVal);} catch (Exception eee) {}
                
                break;
            default:
                throw new RuntimeException("Unknown math:"+c2.math);
        }
        //"!=",">=","<=","==","<",">","="
        switch(c2.op) {
            case 0:
                if(rAv != rBv) rBv = 1;
                else rBv=0;
                break;
            case 1:
                if(rAv >= rBv) rBv = 1;
                else rBv = 0;
                break;
            case 2:
                if(rAv<=rBv) rBv=1;
                else rBv=0;
                break;
            case 3:
                if(rAv==rBv) rBv=1;
                else rBv=0;
                break;
            case 4:
                if(rAv<rBv) rBv=1;
                else rBv=0;
                break;
            case 5:
                if(rAv>rBv) rBv=1;
                else rBv=0;
                break;
            case 6:
                if(c2.varAIsPtr) {
                    variables[variables[c2.varA]] = rBv;
                } else {
                    variables[c2.varA] = rBv;
                }
                break;
            case -1:
                break;
            default:
                throw new RuntimeException("Unknown op:"+c2.op);
        }
        return rBv;
    }
    
    
    public void play() throws IOException {
        JFrame jf = new JFrame("TileGrid");
        jf.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        jf.getContentPane().add(BorderLayout.CENTER,tg);
        jf.pack();
        jf.setVisible(true);
        jf.addKeyListener(gcPad);
        
        Cluster currentCluster = (Cluster)clusterList.get(0);
        int currentCommand = 0;
        
        int [] variables = new int[128];
        
        ArrayList stack = new ArrayList();
        
        while(true) {
            Command c = (Command)currentCluster.commands.get(currentCommand);
            
            //System.out.println("::"+c.id);
            switch(c.id) {
                case 1: // GOTO
                    FlowCommand f1 = (FlowCommand)c;
                    if(f1.cluster!=null) {
                        currentCluster = findCluster(f1.cluster);
                    }
                    currentCommand = findLabel(currentCluster,f1.offset);
                    if(currentCommand<0) {
                        throw new RuntimeException("Could not find:"+f1.cluster+":"+f1.offset+":");
                    }
                    continue;
                case 2: // CALL
                    FlowCommand f2 = (FlowCommand)c;
                    stack.add(currentCluster);
                    stack.add(new Integer(currentCommand+1));
                    //System.out.println("HERE");
                    if(f2.cluster!=null) {
                        currentCluster = findCluster(f2.cluster);
                    }
                    currentCommand = findLabel(currentCluster,f2.offset);
                    if(currentCommand<0) {
                        throw new RuntimeException("Could not find:"+f2.cluster+":"+f2.offset+":");
                    }
                    continue;
                case 3: // RETURN
                    if(stack.size()==0) {
                        System.out.println("Stack underflow.");
                        return;
                    }
                    Integer ij = (Integer)stack.remove(stack.size()-1);
                    currentCommand = ij.intValue();
                    currentCluster = (Cluster)stack.remove(stack.size()-1);
                    continue;
                case 4: // IF
                    FlowCommand ci = (FlowCommand)c;
                    COGCommand cif = (COGCommand)currentCluster.commands.get(currentCommand+1);
                    int vv = doVarOp(cif,variables);
                    if(vv==0) {
                        currentCommand = findLabel(currentCluster,ci.offset);
                        if(currentCommand<0) {
                            throw new RuntimeException("Could not find:"+ci.offset+":");
                        }
                        continue;
                    }
                    break;
                case 100: // #
                    throw new RuntimeException("Should not be executing data command.");
                case 20:
                    break; // Stick
                case 10: // Variable op
                    COGCommand c2 = (COGCommand)c;
                    doVarOp(c2,variables);
                    break;
                    
                    
                case 11: // Print
                    COGCommand cc = (COGCommand)c;
                    int ind = 0;
                    if(cc.varA>=0) {
                        ind = variables[cc.varA];
                    }
                    if(ind>0) {
                        int g=readNextData(currentCluster,cc.paramA);
                        for(int x=0;x<ind;++x) {
                            while(true) {
                                if(g==0) break;
                                g = readNextData(currentCluster,null);
                            }
                            g = readNextData(currentCluster,null);
                        }
                        while(true) {
                            if(g==0) break;
                            System.out.print((char)g);
                            g = readNextData(currentCluster,null);
                        }
                    } else {
                        int g=readNextData(currentCluster,cc.paramA);
                        while(true) {
                            if(g==0) break;
                            System.out.print((char)g);
                            g = readNextData(currentCluster,null);
                        }
                    }
                    break;
                case 12: // tokeninit
                    COGCommand cti = (COGCommand)c;
                    int g=readNextData(currentCluster,cti.paramA);
                    while(true) {
                        String token="";
                        while(true) {
                            if(g==0) break;
                            token = token + (char)g;
                            g = readNextData(currentCluster,null);
                        }
                        if(token.length()==0) break;
                        g = readNextData(currentCluster,null);
                        tokens.put(token, new Integer(g));
                        g = readNextData(currentCluster,null);
                    }
                    break;
                    
                case 13: // Input
                    
                    COGCommand ctin = (COGCommand)c;
                    
                    StringTokenizer sst = new StringTokenizer(ctin.paramA,",");
                    int vn = Integer.parseInt(sst.nextToken().trim().substring(1));
                    int maxTokens = Integer.parseInt(sst.nextToken().trim());
                    
                    BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
                    String gg = in.readLine();
                    gg=gg.toUpperCase();
                    StringTokenizer st = new StringTokenizer(gg," ");
                    int cn = st.countTokens();
                    if(cn>maxTokens) cn=maxTokens;
                    variables[vn++]=cn;
                    for(int z=0;z<cn;++z) {
                        String tt = st.nextToken();
                        Integer vav = (Integer)tokens.get(tt);
                        if(vav==null) {
                            variables[vn++] = 0xFFFF;
                        } else {
                            variables[vn++] = vav.intValue();
                        }
                    }
                    
                    break;
                    
                    
                case 14: // printvar
                    COGCommand c2c = (COGCommand)c;
                    int v = Integer.parseInt(c2c.paramA.substring(1));
                    System.out.print(variables[v]);
                    break;
                    
                case 21:  // settiledata
                    ctin = (COGCommand)c;
                    sst = new StringTokenizer(ctin.paramA,",");
                    int slot = Integer.parseInt(sst.nextToken().trim());                    
                    int numb = Integer.parseInt(sst.nextToken().trim());
                    int [][] dat = new int[numb][16];
                    dat[0][0] = readNextData(currentCluster,sst.nextToken());
                    for(int y=0;y<numb;++y) {
                        for(int x=0;x<16;++x) {
                            if(x==0 && y==0) continue;
                            dat[y][x] = readNextData(currentCluster,null);
                        }
                    }
                    for(int x=0;x<numb;++x) {
                        tg.setTileData(x+slot,dat[x]);
                    }
                    tg.redrawGrid();
                    break;
                    
                case 22: // settile
                    ctin = (COGCommand)c;
                    slot = 0;
                    sst = new StringTokenizer(ctin.paramA,",");
                    String go = sst.nextToken().trim();
                    if(go.startsWith("V")) {
                        vv = Integer.parseInt(go.substring(1));
                        tg.setTile(variables[vv],variables[vv+1],variables[vv+2]+slot);
                    } else {
                        int xp = Integer.parseInt(go);
                        int yp = Integer.parseInt(sst.nextToken().trim());
                        slot = slot + Integer.parseInt(sst.nextToken().trim());
                        tg.setTile(xp,yp,slot);
                    }
                    
                    break;
                    
                case 23: // tileblock
                    ctin = (COGCommand)c;
                    sst = new StringTokenizer(ctin.paramA,",");
                    go = sst.nextToken().trim();
                    int xp = 0;
                    int yp = 0;
                    int wid = 0;
                    int hei = 0;
                    if(go.startsWith("V")) {
                        vv = Integer.parseInt(go.substring(1));
                        xp = variables[vv];
                        yp = variables[vv+1];
                        wid = variables[vv+2];
                        hei = variables[vv+3];
                        slot = variables[vv+4];
                    } else {
                        xp = Integer.parseInt(go);
                        yp = Integer.parseInt(sst.nextToken().trim());
                        wid = Integer.parseInt(sst.nextToken().trim());
                        hei = Integer.parseInt(sst.nextToken().trim());
                        slot = Integer.parseInt(sst.nextToken().trim());
                    }
                    //System.out.println("::"+xp+"::"+yp+"::"+wid+"::"+hei+"::"+slot+"::");
                    for(int y=0;y<hei;++y) {
                        for(int x=0;x<wid;++x) {
                            tg.setTile(xp+x,yp+y,slot);
                        }
                    }
                    break;
                    
                case 24: // gettile
                    ctin = (COGCommand)c;
                    sst = new StringTokenizer(ctin.paramA,",");
                    go = sst.nextToken().trim();
                    int var = 0;
                    if(go.startsWith("V")) {
                        vv = Integer.parseInt(go.substring(1));
                        xp = variables[vv];
                        yp = variables[vv+1];
                        var = vv+2;
                    } else {
                        xp = Integer.parseInt(go);
                        yp = Integer.parseInt(sst.nextToken().trim());
                        var = Integer.parseInt(sst.nextToken().trim().substring(1));
                    }
                    slot = tg.getTile(xp,yp);
                                        
                    variables[var] = slot;
                    //System.out.println(var+" "+variables[var]);
                    break;
                    
                case 25:  // tiletext
                    COGCommand cco = (COGCommand)c;
                    sst = new StringTokenizer(cco.paramA,",");
                    xp = Integer.parseInt(sst.nextToken().trim());
                    yp = Integer.parseInt(sst.nextToken().trim());
                    String ptr = sst.nextToken().trim();
                    int yg=readNextData(currentCluster,ptr);
                    while(true) {
                        if(yg==0) break;
                          tg.setTile(xp,yp,yg);
                          xp=xp+1;
                          if(xp==32) {
                            xp = 0;
                            yp = yp + 1;
                          }
                          yg = readNextData(currentCluster,null);
                    }
                    break; 
                    
                default:
                    throw new RuntimeException("Unknown command id "+c.id);
            }
            ++currentCommand;
        }
        
        
    }
    
    int curData = 0;
    int cmdPnt = 0;
    public int readNextData(Cluster currentCluster,String label) {
        if(label!=null) {
            curData = findLabel(currentCluster,label);
            if(curData<0) {
                throw new RuntimeException("Could not find label:"+label+":");
            }
            cmdPnt = 0;
        }
        Command c = (Command)currentCluster.commands.get(curData);
        if(!(c instanceof DataCommand)) {
            throw new RuntimeException("Expected a data command");
        }
        DataCommand dc = (DataCommand)c;
        Integer ii = (Integer)dc.data.get(cmdPnt++);
        if(cmdPnt == dc.data.size()) {
            cmdPnt = 0;
            ++curData;
        }
        return ii.intValue();
    }
    
    public static void main(String [] args) throws Exception {
        
        CCL ccl = new CCL(args[0]);
        
        if(ccl.errorCondition!=null) {
            return;
        }
        
        System.out.println("Number of variables reserved: "+ccl.usedRegister);
        
        for(int x=0;x<ccl.clusterList.size();++x) {
            Cluster c = (Cluster)ccl.clusterList.get(x);
            int prSize = 0;
            //System.out.println("::"+c.numberOfProgramCommands);
            for(int y=0;y<c.commands.size();++y) {
                Command co = (Command)c.commands.get(y);
                //System.out.println(":"+co.id);
                prSize += co.getBinarySize();
            }
            System.out.println("CLUSTER '"+c.name+"' size="+prSize);
        }
        
        
        System.out.println();
        
        if(args.length>1) {
            OutputStream os = new FileOutputStream(args[1]);
            ccl.writeBinary(os);
            os.flush();
            os.close();
        }
        
        ccl.play();
        
    }
    
}
