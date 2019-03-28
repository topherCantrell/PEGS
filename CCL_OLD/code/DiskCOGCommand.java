package code;

import java.util.*; 
import java.io.*;

public class DiskCOGCommand extends COGCommand
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
    
    
    public String parse(CodeLine c, Cluster cluster)
    {
        String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.startsWith("RESERVE ")) {            
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);    
            s = s.substring(8).trim();
            try {
                fc.val = CodeLine.parseNumber(s);
            } catch (Exception e) {                
                return "Invalid numeric constant";                
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
        } else if(ss.startsWith("CACHEHINT ")) {            
            DiskCOGCommand fc = new DiskCOGCommand(c,cluster);
            fc.type = 4;
            fc.clusterName=s.substring(9).trim();    
            cluster.commands.add(fc);
            return "";
        } 
        return null;
    }
        
    public String toSPIN(List<Cluster> clusters)
    {
        
        // Nothing to do in first pass
        if(clusters==null) return null;
        
        String tt = "' "+codeLine.text+"\r\n";
        int clus = -1;
        
        switch(type) {
            case 0: // RESERVE
                tt = tt + "  long %1_000__0000___0011_0000___00000000___0000"+CodeLine.toBinaryString((int)val,4)+"\r\n";
                return tt;
            case 1: // WRITE
                tt = tt + "  long %1_000__0000___0010_0000___00000000___00000000\r\n";
                return tt;
            case 2: // REFERENCE
                clus = clusters.indexOf(super.cluster);
                if(clus<0) {
                    return "# Cluster '"+cluster+"' not found";
                }
                tt = tt + "  long %1_000__0000___0001_0010___"+CodeLine.toBinaryString(clus,16)+"\r\n";
                return tt;
            case 3: // DEREFERENCE
                tt = tt + "  long %1_000__0000___0001_0001___11111111___11111111\r\n";
                return tt;
            case 4: // CACHEHINT
                clus = COGCommand.findClusterNumber(clusterName,clusters);
                if(clus<0) {
                    return "# Cluster '"+cluster+"' not found";
                }
                tt = tt + " long %1_000__0000___0001_0000___"+CodeLine.toBinaryString(clus,16)+"\r\n";
                return tt;
        }
        
        return "# Internal error. Unknown command type.";
       
    }
    
}
