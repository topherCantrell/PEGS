/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class DiskCOGParser implements Parser 
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
    
    public String parse(CodeLine c, Cluster cluster,Map<String,String> defines)
    {
        String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("RESERVE") || ss.startsWith("RESERVE ")) {            
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);    
            s = s.substring(7).trim();
            ArgumentList aList = new ArgumentList(s,defines); 
            Argument a = aList.removeArgument("COUNT",0);
            if(a==null) {
                return "Missing COUNT value. Must be 1-10.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>10) {
                return "Invalid COUNT value '"+a.value+"'. Must be 1-10.";
            }
            fc.val = (int)a.longValue;
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            fc.type = 0;            
            cluster.commands.add(fc);
            return "";
        } else if(ss.equals("WRITE")) {
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);            
            fc.type = 1;            
            cluster.commands.add(fc);
            return "";
        } else if(ss.equals("REFERENCE")) {
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);            
            fc.type = 2;
            cluster.commands.add(fc);
            return "";
        } else if(ss.equals("DEREFERENCE")) {
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);            
            fc.type = 3;
            cluster.commands.add(fc);
            return "";
        } else if(ss.equals("CACHEHINT") || ss.startsWith("CACHEHINT ")) {            
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);
            s = s.substring(9).trim();
            
            ArgumentList aList = new ArgumentList(s,defines); 
            Argument a = aList.removeArgument("CLUSTER",0);
            if(a==null) {
                return "Missing CLUSTER value. Must be the name of a cluster.";
            }            
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            fc.type = 4;
            fc.clusterName=a.value;    
            cluster.commands.add(fc);
            return "";
        } 
        return null;
    }
    
}
