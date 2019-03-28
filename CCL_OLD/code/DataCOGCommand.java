package code;

import java.util.*;

public class DataCOGCommand extends COGCommand
{
     List<String> spriteLines = null;
     List<Integer> data = new ArrayList<Integer>();
     
     public DataCOGCommand(CodeLine line,Cluster clus) {super(line,clus);}
     
     public boolean isData() {return true;}
     
     public int getSize()
     {   
         return data.size();
     }
     
      // "This is a string!\n",0
    // reserve(104),PADALIGN(4),88,0x24,WORD(7),BYTE(3),LONG(0)
    
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    // |..W..W.W   ........   WW..WW..
    
    public String parseItems(String s,List<String> items)
    {        
        String inString=null;
        String item = "";
        int p = 0;
        while(true) {
            // Handle reaching the end of a data line
            if(p>=s.length()) {
                if(inString!=null) {
                    return "Open \" without a close \"";
                }
                if(item.length()==0) {
                    return "Empty data item";
                }
                items.add(item);
                return null;
            }
            // Handle inside a string
            if(inString!=null) {
                if(s.charAt(p)=='\\' && (p+1)==s.length()) {
                    return "Open \" without a close \"";
                }
                if(s.charAt(p)=='\\' && s.charAt(p+1)=='"') {
                    inString=inString+"\"";
                    p=p+2;
                    continue;
                }
                if(s.charAt(p)=='\\' && s.charAt(p+1)=='n') {
                    inString=inString+"\n";
                    p=p+2;
                    continue;
                }
                if(s.charAt(p)=='"') {
                    item = inString;                    
                    inString=null;
                    p=p+1;
                    continue;
                }
                inString = inString + s.charAt(p);
                p=p+1;
                continue;
            }
            // Not in a string.
            if(s.charAt(p)=='"') {
                inString = "\"";
                p=p+1;
                continue;
            }
            if(s.charAt(p)==' ') {
                p=p+1;
                continue;
            }
            if(s.charAt(p)==',') {
                if(item.length()==0) {
                    return "Empty data item";
                }
                items.add(item);
                item="";
                p=p+1;
                continue;
            }
            item = item+s.charAt(p);
            p=p+1;
        }       
    }
    
    public char[] SPRITECHARS = {'.','W','G','R'};
    
    public String parseSpriteData(String data, CodeLine c, Cluster cluster)
    {
        DataCOGCommand r = null;
        if(cluster.commands.size()>0 && 
            cluster.commands.get(cluster.commands.size()-1) instanceof DataCOGCommand)
        {
            r = (DataCOGCommand)cluster.commands.get(cluster.commands.size()-1);
            if(r.spriteLines==null || r.spriteLines.size()==8) {
                r=null;
            }
        }
        if(r==null) {
            r = new DataCOGCommand(c,cluster);
            r.spriteLines = new ArrayList<String>();
            cluster.commands.add(r);
        }
        byte [] bb = data.toUpperCase().getBytes();
        byte [] nb = new byte[bb.length];
        int pos = 0;
        for(int x=0;x<bb.length;++x) {
            if(bb[x]==' ' || bb[x]=='|') continue;
            boolean fnd=false;
            for(int z=0;z<SPRITECHARS.length;++z) {
                if(bb[x]==SPRITECHARS[z]) {
                    fnd = true;
                    nb[pos++]=(byte)('0'+z);
                    break;
                }
            }
            if(!fnd) {
                return "Invalid sprite picture character '"+(char)bb[x]+"'";
            }
        }
        data = new String(nb,0,pos);
        r.spriteLines.add(data);
        if(r.spriteLines.size()>1) {
            if(r.spriteLines.get(r.spriteLines.size()-2).length() !=
               r.spriteLines.get(r.spriteLines.size()-1).length())
            {
                return "All 8 sprite picture lines must have the same length";
            }
        }
        if(r.spriteLines.size()==8) {
            for(int x=0;x<r.spriteLines.get(0).length()*2;++x) {
                r.data.add(new Integer(0xAA));
            }
            for(int y=0;y<8;++y) {
                String row = r.spriteLines.get(y);
                for(int x=0;x<row.length();x=x+8) {
                    int a = (row.charAt(x+4)-'0') | (row.charAt(x+5)-'0')<<2 | (row.charAt(x+6)-'0')<<4 | (row.charAt(x+7)-'0')<<6;
                    r.data.set((x/8)*16+y*2+1,new Integer(a));
                    a = (row.charAt(x+0)-'0') | (row.charAt(x+1)-'0')<<2 | (row.charAt(x+2)-'0')<<4 | (row.charAt(x+3)-'0')<<6;
                    r.data.set((x/8)*16+y*2,new Integer(a));
                }
            }
        }
        return "";
    }

    public String parse(CodeLine c, Cluster cluster)
    {
        String s=c.text.trim();    
        
        // Sprite data
        if(s.startsWith("|")) {
            return parseSpriteData(s,c,cluster);
        } 
        
        DataCOGCommand dcc = new DataCOGCommand(c,cluster);
        
        List<String> items = new ArrayList<String>();
        String e = parseItems(s,items);
        if(e!=null) return e;
        for(int x=0;x<items.size();++x) {
            s = items.get(x);
            if(s.startsWith("\"")) {
                for(int y=1;y<s.length();++y) {
                    dcc.data.add(new Integer(s.charAt(y)));
                }
                continue;
            }
            String ss = s.toUpperCase();
            int size = 255;
            int bytes = 1;
            int special = 0;
            if(ss.startsWith("RESERVE(")) {
                special = 1;
                s = s.substring(8,s.length()-1).trim();
            } else if(ss.startsWith("PADALIGN(")) {
                special = 2;
                s = s.substring(9,s.length()-1).trim();
            } else if(ss.startsWith("WORD(")) {
                size = 65535;
                bytes = 2;
                s = s.substring(5,s.length()-1).trim();
            } else if(ss.startsWith("BYTE(")) {
                size = 255;
                bytes = 1;
                s = s.substring(5,s.length()-1).trim();
            } else if(ss.startsWith("LONG(")) {
                // TOPHER ... how to handle large constants!
                size = 0xFFFFFFFF;
                bytes = 4;
                s = s.substring(5,s.length()-1).trim();
            }
            
            long val = 0;
            try {
                val = CodeLine.parseNumber(s);
            } catch (Exception ee) {
                return "Invalid number '"+s+"'";
            }
            if(size>0 && val>size) {
                return "Number '"+s+"' is larger than "+bytes+" bytes ("+size+")";
            }
            
            if(special==1) {
                for(int z=0;z<val;++z) dcc.data.add(new Integer(0));
            } else if(special==2) {
                int sizeToHere=0;
                for(int z=0;z<cluster.commands.size();++z) {
                    sizeToHere=sizeToHere + cluster.commands.get(z).getSize();
                }
                sizeToHere = sizeToHere + dcc.data.size();
                sizeToHere = sizeToHere % (int)val;
                if(sizeToHere>0) {
                    sizeToHere = (int)val - sizeToHere;
                }
                for(int z=0;z<sizeToHere;++z) dcc.data.add(new Integer(0));
            } else {
                int yy = dcc.data.size();
                for(int z=0;z<bytes;++z) {
                    dcc.data.add(yy,new Integer((int)(val%256)));
                    val = val >> 8;
                }
            }
        }
        cluster.commands.add(dcc);
        return "";
    }
     
     public String toSPIN(List<Cluster> clusters)
     {
         
         if(clusters==null) return null;
         
         if(spriteLines!=null && spriteLines.size()!=8) {
             // In case the file ended in the middle of a sprite picture
             return "# There must be 8 lines in the sprite picture";
         }
         
         if(data.size()==0) return null;
         
         String tt = "' "+codeLine.text+"\r\n";
         tt = tt + "  byte  ";
         for(int x=0;x<data.size();++x) {
             if(x>0) tt=tt+", ";
             tt=tt+"$"+Integer.toString(data.get(x).intValue(),16);             
         }
         
         return tt;
     }
     
    public String toBinary(List<Cluster> clusters, byte [] dest)
    {
        for(int x=0;x<data.size();++x) {
            dest[x] = data.get(x).byteValue();
        }
        return null;
    }
     
}
