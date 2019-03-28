/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

/**
 * This class parses numeric data items in the data section of a cluster.
 */
public class DataCOGParser implements Parser 
{       
	
	@Override
	public void addDefines(Map<String, String> subs) 
	{
		subs.put("TRUE","1");
		subs.put("FALSE","0");
	}
    
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

    public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
    {
        String s=c.text.trim();    
        
        DataCOGCommand dcc = new DataCOGCommand(c,cluster);
        
        List<String> items = new ArrayList<String>();
        String e = parseItems(s,items);
        if(e!=null) return e;
        for(int x=0;x<items.size();++x) {
            s = items.get(x);
            String rep = subs.get(s.toUpperCase());
            if(rep!=null) s = rep;
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
                for(int z=0;z<bytes;++z) {
                    dcc.data.add(new Integer((int)(val%256)));
                    val = val >> 8;
                }
            }
        }
        cluster.commands.add(dcc);
        return "";
    }
     
}
