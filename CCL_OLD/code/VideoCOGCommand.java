package code;
import java.util.*;
import java.io.*;

public class VideoCOGCommand extends COGCommand
{    
    
    int type; // 0 = CLS
    boolean varForm;
    int tileNumber;
    int x,y,width,height;
    String label;
    
    public VideoCOGCommand(CodeLine line,Cluster clus) {super(line,clus);} 
    
    public int getSize()
    {     
        int size = 0;
        switch(type) {
            case 0:
                if(varForm) size= 4;
                else size= 8;
                break;
            case 1:
                size= 4;
                break;
            case 2:
                size= 8;
                break;
            case 3:
                size= 4;
                break;
            case 4:
                size = 4;
                break;
            case 5:
                size = 8;
                break;
            case 6: // SETCURSOR
                size = 4;
                break;
            case 7: // SETCURSORINFO
                if(varForm) size=4;
                else size=8;
                break;
            case 8: // INITTILES
                size = 8;
                break;
            case 9: // SETTILE
                if(varForm) size=4;
                else size=8;
                break;
            case 10: // GETTILE
                if(varForm) size=4;
                else size=8;
                break;
        }                       
        return size;
    }
    
    public void addDataSectionIfNeeded(CodeLine c, Cluster cluster) {
        boolean fnd = false;
        for(int x=0;x<cluster.lines.size();++x) {
            if(cluster.lines.get(x).text.trim().toUpperCase().equals("--DATA--")) {
                fnd = true;
                break;
            }
        }
        if(!fnd) {
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"--DATA--");
            cluster.lines.add(cc);
        }
    }
    
    public String parse(CodeLine c, Cluster cluster)
    {
        String s = c.text;
        String ss = s.toUpperCase();                
        
        if(ss.equals("CLS") || ss.startsWith("CLS ")) {
            ss = ss.substring(3).trim();            
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 0;
            vc.tileNumber = 32;
            if(ss.length()>0) {                
                try {
                    vc.tileNumber = (int)CodeLine.parseNumber(ss);
                } catch (Exception e) {
                    return "Invalid number '"+ss+"'";
                }
            }            
            vc.width = 32;
            vc.height = 26;
            cluster.commands.add(vc);    
            
            int i = cluster.lines.indexOf(c);
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"SETCURSOR 0,0");
            cluster.lines.add(i+1,cc);
            
            return "";
        }
        
        // CLS
        // CLS n
        // RECTANGLE Vn
        // RECTANGLE x,y,width,height,tileNumber
        if(ss.startsWith("RECTANGLE ")) {
            StringTokenizer st=new StringTokenizer(ss.substring(10).trim().toUpperCase(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 0;
            if(st.countTokens()==1) {
                vc.varForm = true;
                ss = st.nextToken();
                if(!ss.startsWith("V")) {
                    return "Expected 'RECTANGLE Vn'";
                }
                try {
                    vc.tileNumber = (int)CodeLine.parseNumber(ss.substring(1));
                } catch(Exception e) {
                    return "Invalid variable number '"+ss+"'";
                }
                cluster.commands.add(vc);
                return "";
            }
            if(st.countTokens()!=5) {
                return "Expected 'RECTANGLE x,y,width,height,tileNumber'";
            }
            try {
                vc.x = (int)CodeLine.parseNumber(st.nextToken());
                vc.y = (int)CodeLine.parseNumber(st.nextToken());
                vc.width = (int)CodeLine.parseNumber(st.nextToken());
                vc.height = (int)CodeLine.parseNumber(st.nextToken());
                vc.tileNumber = (int)CodeLine.parseNumber(st.nextToken());                
            } catch (Exception e) {
                return "Invalid number";
            }
            cluster.commands.add(vc);
            return "";
        }
        
        // PRINT "HELLO"
        // PRINT msg1
        // PRINT msg[Vn]
        if(ss.startsWith("PRINT ")) {
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 1;    
            s=s.substring(6).trim();            
            if(s.startsWith("\"")) {
                addDataSectionIfNeeded(c,cluster);
                String t = s+",0";
                CodeLine cc = new CodeLine(c.lineNumber,c.file,t);
                s = "_msg_"+c.lineNumber;
                cc.labels.add(s);
                cluster.lines.add(cc);                
            }
            int i = s.indexOf("[");
            if(i>=0) {
                if(!s.endsWith("]")) {
                    return "Missing ']'";
                }
                String j = s.substring(i+1,s.length()-1);
                s = s.substring(0,i);
                if(!j.startsWith("V") && !j.startsWith("v")) {
                    return "Excptected [Vn]";
                }
                try {
                    vc.y = (int)CodeLine.parseNumber(j.substring(1));
                } catch (Exception e) {
                    return "Invalid variable number";
                }
                vc.type = 2;
            }
                                
            vc.label = s;
            cluster.commands.add(vc);
            return "";                
        }
        
        if(ss.startsWith("PRINTVAR ")) {
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 3;  
            s=s.substring(9).trim().toUpperCase(); 
            if(s.charAt(0)!='V') {
                return "Expected PRINTVAR Vn";
            }
            try {
                vc.y = (int)CodeLine.parseNumber(s.substring(1));
            } catch (Exception e) {
                return "Invalid variable number";
            }
            cluster.commands.add(vc);
            return "";               
        }
        
        if(ss.startsWith("GETNUMBER ")) {
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 4;  
            s=s.substring(9).trim().toUpperCase(); 
            if(s.charAt(0)!='V') {
                return "Expected PRINTVAR Vn";
            }
            try {
                vc.y = (int)CodeLine.parseNumber(s.substring(1));
            } catch (Exception e) {
                return "Invalid variable number";
            }
            cluster.commands.add(vc);
            return "";               
        }
        
        if(ss.startsWith("GETLINE ")) {
            StringTokenizer st=new StringTokenizer(s.substring(8).trim(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 5;
            
            if(st.countTokens()!=2) {
                return "Expected GETLINE ptr,size";
            }
            
            vc.label = st.nextToken();
                        
            try {
                vc.y = (int)CodeLine.parseNumber(st.nextToken());
            } catch (Exception e) {
                return "Invalid number";
            }
            cluster.commands.add(vc);
            
            int i = findOffsetToLabel(cluster,vc.label);
            if(i<0) {
                addDataSectionIfNeeded(c,cluster);
                CodeLine cc = new CodeLine(c.lineNumber,c.file,"reserve("+(vc.y+1)+")");
                cc.labels.add(vc.label);
                cluster.lines.add(cc);
            }
            
            return "";               
        }
        
        if(ss.startsWith("SETCURSOR ")) {
            StringTokenizer st=new StringTokenizer(s.substring(9).trim(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 6;
            
            if(st.countTokens()==1) {
                vc.varForm = true;
                s = st.nextToken();
                if(s.charAt(0)!='V') {
                    return "Expected SETCURSOR Vn";
                }
                try {
                    vc.y = (int)CodeLine.parseNumber(s.substring(1));
                } catch (Exception e) {
                    return "Invalid variable number";
                }
            } else {   
                if(st.countTokens()!=2) {
                    return "Expected SETCURSOR x,y";
                }
                try {
                    vc.x = (int)CodeLine.parseNumber(st.nextToken());
                    vc.y = (int)CodeLine.parseNumber(st.nextToken());
                } catch (Exception e) {
                    return "Invalid number";
                }
            }

            cluster.commands.add(vc);
            return "";
        }
        
        if(ss.startsWith("SETCURSORINFO ")) {
            StringTokenizer st=new StringTokenizer(s.substring(14).trim(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 7;
            
            if(st.countTokens()!=3) {
                return "Expected SETCURSORINFO tileA,tileB,blinkRate";
            }
            try {
                vc.x = (int)CodeLine.parseNumber(st.nextToken());
                vc.y = (int)CodeLine.parseNumber(st.nextToken());
                vc.width = (int)CodeLine.parseNumber(st.nextToken());
            } catch (Exception e) {
                return "Invalid number";
            }
            
            cluster.commands.add(vc);
            return "";
        }

        if(ss.startsWith("INITTILES ")) {
            StringTokenizer st=new StringTokenizer(s.substring(10).trim(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 8;
            
            if(st.countTokens()!=3) {
                return "Expected INITTILES ptr,start,count";
            }
            try {
                vc.label = st.nextToken();
                vc.x = (int)CodeLine.parseNumber(st.nextToken());
                vc.y = (int)CodeLine.parseNumber(st.nextToken());                
            } catch (Exception e) {
                return "Invalid number";
            }
            
            cluster.commands.add(vc);
            return "";
        }
        
        if(ss.startsWith("SETTILE ")) {
            StringTokenizer st=new StringTokenizer(s.substring(8).trim(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 9;
            
            if(st.countTokens()==1) {
                vc.varForm = true;
                s = st.nextToken();
                if(s.charAt(0)!='V') {
                    return "Expected SETTILE Vn";
                }
                try {
                    vc.y = (int)CodeLine.parseNumber(s.substring(1));
                } catch (Exception e) {
                    return "Invalid variable number";
                }
            } else {   
                if(st.countTokens()!=3) {
                    return "Expected SETCURSOR x,y";
                }
                try {
                    vc.x = (int)CodeLine.parseNumber(st.nextToken());
                    vc.y = (int)CodeLine.parseNumber(st.nextToken());
                    vc.width = (int)CodeLine.parseNumber(st.nextToken());
                } catch (Exception e) {
                    return "Invalid number";
                }
            }

            cluster.commands.add(vc);
            return "";
        }
        
         if(ss.startsWith("GETTILE ")) {
            StringTokenizer st=new StringTokenizer(s.substring(8).trim(),",");
            VideoCOGCommand vc = new VideoCOGCommand(c,cluster);
            vc.type = 10;
            
            if(st.countTokens()==1) {
                vc.varForm = true;
                s = st.nextToken();
                if(s.charAt(0)!='V') {
                    return "Expected GETTILE Vn";
                }
                try {
                    vc.y = (int)CodeLine.parseNumber(s.substring(1));
                } catch (Exception e) {
                    return "Invalid variable number";
                }
            } else {   
                if(st.countTokens()!=3) {
                    return "Expected GETTILE x,y,Vn";
                }
                try {
                    vc.x = (int)CodeLine.parseNumber(st.nextToken());
                    vc.y = (int)CodeLine.parseNumber(st.nextToken());
                    s = st.nextToken();
                    if(!s.startsWith("V")) {
                        return "Expected SETTILE x,y,Vn";
                    }
                    vc.width = (int)CodeLine.parseNumber(s.substring(1));
                } catch (Exception e) {
                    return "Invalid number";
                }
            }

            cluster.commands.add(vc);
            return "";
        }
        
       
        
        return null;
    }
    
    public String toSPIN(List<Cluster> clusters)
    {
        if(clusters==null) return null;
        
        String tt = "' "+codeLine.text+"\r\n";
        int i;
        switch(type) {
            case 0:
                if(varForm) {
                    tt = tt+"  long  %1_010_0000___00_1_00000___00000000"+
                      "___"+CodeLine.toBinaryString(tileNumber,8);
                } else {
                    tt = tt+"  long  %1_111_0010___00_0_00000___"+CodeLine.toBinaryString(x,8)+
                      "___"+CodeLine.toBinaryString(y,8)+"\r\n";
                    tt = tt+"    long %"+CodeLine.toBinaryString(width,8)+"_"
                      + CodeLine.toBinaryString(height,8)+"_"
                      + CodeLine.toBinaryString(tileNumber,16);
                }
                
                return tt;
            case 1:
                i = COGCommand.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
                tt = tt+"  long  %1_010_0000___00_0_00001___"+CodeLine.toBinaryString(i,16);
                
                return tt;
            case 2:
                i = COGCommand.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
                tt = tt+"  long  %1_111_0010___00_0_00010___"+CodeLine.toBinaryString(i,16)+"\r\n";
                tt = tt+"    long %"+CodeLine.toBinaryString(y,32);
                
                return tt;
            case 3:
                tt = tt+"  long %1_010_0000___00_0_00011___00000000___"+CodeLine.toBinaryString(y,8);
                
                return tt;
                
            case 4:
                tt = tt+"  long %1_010_0000___00_0_00110___00000000___"+CodeLine.toBinaryString(y,8);
                return tt;
                
            case 5:
                i = COGCommand.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "Could not find label '"+label+"'";
                }
                tt = tt+"  long %1_111_0010___00_0_00111___"+CodeLine.toBinaryString(i,16)+"\r\n";
                tt = tt+"   long %"+CodeLine.toBinaryString(y,32);
                return tt;
            case 6: // SETCURSOR
                if(varForm) {
                    tt = tt+"  long %1_010_0100___00_1_00100___00000000__"+CodeLine.toBinaryString(y,8);
                    return tt;
                }
                tt = tt+"  long %1_010_0010___00_0_00100___"+CodeLine.toBinaryString(x,8)+"__"+CodeLine.toBinaryString(y,8);
                return tt;
            case 7: // SETCURSORINFO
                tt = tt+"  long %1_111_0010___00_0_00101___"+CodeLine.toBinaryString(width,16)+"\r\n";
                tt = tt+"  long %"+CodeLine.toBinaryString(x,16)+"__"+CodeLine.toBinaryString(y,16);
                return tt;
            case 8: // INITTILES
                i = COGCommand.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "Could not find label '"+label+"'";
                }
                tt=tt+"  long %1_111_0010___00_0_01000___"+CodeLine.toBinaryString(i,16)+"\r\n";
                tt=tt+"  long %"+CodeLine.toBinaryString(x,16)+"__"+CodeLine.toBinaryString(y,16);
                return tt;
            case 9: // SETTILE
                if(varForm) {
                    tt=tt+"  long %1_010_0000___00_1_01001___00000000__"+CodeLine.toBinaryString(y,8);
                    return tt;
                }
                tt = tt+"  long %1_111_0010___00_0_01001___"+CodeLine.toBinaryString(x,8)+"__"+CodeLine.toBinaryString(y,8)+"\r\n";
                tt = tt+"  long %"+CodeLine.toBinaryString(width,32);
                return tt;
            case 10: // GETTILE
                if(varForm) {
                    tt=tt+"  long %1_010_0000___00_1_01010___00000000__"+CodeLine.toBinaryString(y,8);
                    return tt;
                }
                tt = tt+"  long %1_111_0010___00_0_01010___"+CodeLine.toBinaryString(x,8)+"__"+CodeLine.toBinaryString(y,8)+"\r\n";
                tt = tt+"  long %"+CodeLine.toBinaryString(width,32);
                return tt;
        }
        return "#Unrecognized VideoCOGCommand type '"+type+"'";
    }    
   
    
}