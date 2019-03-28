package code;

import java.util.*; 
import java.io.*;

public class FlowCOGCommand extends COGCommand
{    
    int type;
    long subtype;
    String cluster;
    String offset;
    
    public FlowCOGCommand(CodeLine line,Cluster clus) {super(line,clus);} 
    
    public int getSize()
    {
        // All Interpreter commands are 1 long
        return 4;
    }
    
    String getCluster(String m)
    {
        int i = m.indexOf(":");
        if(i>0) {
            return m.substring(0,i).trim();
        }
        return "";
    }
    
    String getOffset(String m)
    {
        int i = m.indexOf(":");
        if(i>0) {
            return m.substring(i+1).trim();
        }
        return m;
    }
    
    public String parse(CodeLine c, Cluster cluster)
    {
        String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.startsWith("GOTO ")) {
            s = s.substring(5);
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            fc.cluster = getCluster(s);
            fc.offset = getOffset(s);
            fc.type = 0;
            fc.subtype = 0;
            cluster.commands.add(fc);
            return "";
        } else if(ss.startsWith("CALL ")) {
            s = s.substring(5);
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            fc.cluster = getCluster(s);
            fc.offset = getOffset(s);
            fc.type = 0;
            fc.subtype = 1;
            cluster.commands.add(fc);
            return "";
        } else if(ss.startsWith("BRANCH-IF ")) {
            s = s.substring(10);
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            fc.cluster = getCluster(s);
            fc.offset = getOffset(s);
            fc.type = 0;
            fc.subtype = 3;
            cluster.commands.add(fc);
            return "";
        } else if(ss.startsWith("BRANCH-IFNOT ")) {
            s = s.substring(13);
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            fc.cluster = getCluster(s);
            fc.offset = getOffset(s);
            fc.type = 0;
            fc.subtype = 2;
            cluster.commands.add(fc);
            return "";
        } else if(ss.equals("STOP")) {
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            fc.cluster = "";
            fc.offset = "";
            fc.type = 0;
            fc.subtype = 7;
            cluster.commands.add(fc);
            return "";
        } else if(ss.equals("RETURN")) {
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            fc.type = 1;            
            cluster.commands.add(fc);
            return "";
        } else if(ss.startsWith("PAUSE ")) {
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            s=s.substring(6).trim();            
            try {
                fc.subtype = Integer.parseInt(s);
            } catch (Exception e) {
                return "Invalid pause number";
            }
            double a = fc.subtype;
            // Value given in milliseconds. Convert to seconds.
            a=a/1000.0;
            // Convert to ticks.
            a=a*80000000.0;
            fc.subtype = Math.round(a);
            fc.type = 2;            
            cluster.commands.add(fc);
            return "";
        } else if(ss.startsWith("DEBUG ")) {
            FlowCOGCommand fc = new FlowCOGCommand(c,cluster);
            s=s.substring(6).trim();
            try {
                fc.subtype = Integer.parseInt(s);
            } catch (Exception e) {
                return "Invalid debug value";
            }
            if(fc.subtype<0 || fc.subtype>1) {
                return "Invalid debug value";
            }
            fc.type = 3;            
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
        if(type==0) {
            Cluster clus = super.cluster;
            int clusNum = 0xFFFF;
            if(cluster.length()>0) {
                clusNum=COGCommand.findClusterNumber(cluster,clusters);
                if(clusNum<0) {
                    return "# Cluster '"+cluster+"' not found";
                }
                clus = clusters.get(clusNum);                
            }
            int ofs = 0;
            if(offset.length()>0) {
                ofs = COGCommand.findOffsetToLabel(clus,offset);
                if(ofs<0) {
                    return "# Label '"+offset+"' not found";
                }
            }
            tt = tt+"  long %0_000_"+CodeLine.toBinaryString((int)subtype,3)+"_"+CodeLine.toBinaryString(clusNum,16)+
              "_"+CodeLine.toBinaryString(ofs/4,9)+"\r\n";            
        } else {
            tt = tt+"  long %0_"+CodeLine.toBinaryString(type,3)+"_"+CodeLine.toBinaryString((int)subtype,28)+"\r\n";
        }        
        return tt;
    }
    
}
