/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class DiskCOGCommand extends Command
{    
    int type;    
    long val;
    String clusterName;
    
    public DiskCOGCommand(CodeLine line,Cluster clus) {super(line,clus);} 
    
    public int getSize()
    {
        // All Disk commands are 1 long
        return 4;
    }    
     
    public String toSPIN(List<Cluster> clusters)
    {
        
        // Nothing to do in first pass
        if(clusters==null) return null;
        
        String tt = "' "+codeLine.text+"\r\n";
        int clus = -1;
        
        switch(type) {
            case 0: // RESERVE
                tt = tt + "  long %10_000__000___0011_0000___00000000___0000"+CodeLine.toBinaryString((int)val,4)+"\r\n";
                return tt;
            case 1: // WRITE
                tt = tt + "  long %10_000__000___0010_0000___00000000___00000000\r\n";
                return tt;
            case 2: // REFERENCE
                clus = clusters.indexOf(super.cluster);
                if(clus<0) {
                    return "# Cluster '"+cluster+"' not found";
                }
                tt = tt + "  long %10_000__000___0001_0010___"+CodeLine.toBinaryString(clus,16)+"\r\n";
                return tt;
            case 3: // DEREFERENCE
                tt = tt + "  long %10_000__000___0001_0001___11111111___11111111\r\n";
                return tt;
            case 4: // CACHEHINT
            	if(clusterName.equals("INDIRECT")) {
            		clus = 0xFFFE;
            	} else {
            		clus = Command.findClusterNumber(clusterName,clusters);
            	}
                if(clus<0) {
                    return "# Cluster '"+cluster+"' not found";
                }
                tt = tt + " long %10_000__000___0001_0000___"+CodeLine.toBinaryString(clus,16)+"\r\n";
                return tt;
        }
        
        return "# Internal error. Unknown command type.";
       
    }

}
