/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;
import java.io.*;

/**
 * COGCommands turn parsed commands into CCL binary. The various parsers
 * create subclasses of this class. This class also contains static
 * helper methods needed by many commands.
 */
public abstract class Command
{
	
	/**
     * Destinations are specified as "cluster:label" where either part
     * is optional. This returns the "cluster" portion or "" if not
     * given.
     * @param m the destination string
     * @return the cluster label
     */
    static String getCluster(String m)
    {
        int i = m.indexOf(":");
        if(i>0) {
            return m.substring(0,i).trim();
        }
        return "";
    }
    
    /**
     * Destinations are specified as "cluster:label" where either part
     * is optional. This returns the "label" portion or m if not
     * given.
     * @param m the destination string
     * @return the offset label
     */
    static String getOffset(String m)
    {
        int i = m.indexOf(":");
        if(i>0) {
            return m.substring(i+1).trim();
        }
        return m;
    }
    
    /**
     * Helper method to find a particular cluster within the master list
     * of clusters.
     * @param cn the name of the cluster
     * @param clusters the master list of clusters to search
     * @return the index of the cluster or -1 if not found
     */
    public static int findClusterNumber(String cn,List<Cluster> clusters)
    {
        String ccn = cn.toUpperCase();
        for(int x=0;x<clusters.size();++x) {
            if(clusters.get(x).name.toUpperCase().equals(ccn)) return x;
        }
        return -1;
    }
    
    /**
     * This helper method finds the offset to the given label within the
     * given cluster.
     * @param c the target cluster
     * @param lab the label string
     * @return the binary offset to the command or -1 if label is not found
     */
    public static int findOffsetToLabel(Cluster c, String lab)
    {
        lab = lab.toUpperCase();
        int curOffset = 0;
        for(int x=0;x<c.commands.size();++x) {
            CodeLine cc = c.commands.get(x).getCodeLine();
            for(int y=0;y<cc.labels.size();++y) {
                if(cc.labels.get(y).toUpperCase().equals(lab)) {
                    return curOffset;
                }
            }
            curOffset = curOffset + c.commands.get(x).getSize();
        }
        return -1;
    }    
    
    protected CodeLine codeLine; // The CodeLine that produced this binary
    protected Cluster cluster;   // The Cluster this command belongs in
        
    /**
     * Constructs a new COGCommand.
     * @param line the CodeLine
     * @param clus the Cluster
     */
    public Command(CodeLine line, Cluster clus) {codeLine = line;cluster = clus;}
    
    public Command() {}
    
    public void setCluster(Cluster clus) {cluster = clus;}
        
    /**
     * Returns the CodeLine that generated the binary (used for error reports)
     * @return the CodeLine
     */
    public CodeLine getCodeLine() {return codeLine;}
    
    /**
     * Changes the codeline.
     * @param codeLine the new CodeLine
     */
    public void setCodeLine(CodeLine codeLine) {this.codeLine = codeLine;}
       
    /**
     * Converts the command to binary form. It assumes the "toSPIN" method
     * returns pure binary.
     * @param clusters the master list of clusters
     * @param dest the byte array sized by "getSize".
     * @return any error string or null if OK
     */
    public String toBinary(List<Cluster> clusters, byte [] dest)
    {
        String s = toSPIN(clusters);
        if(s.startsWith("#")) return s;        
        try {
            ByteArrayInputStream bais = new ByteArrayInputStream(s.getBytes());
            InputStreamReader isr = new InputStreamReader(bais);
            BufferedReader br = new BufferedReader(isr);
            int ind=0;
            while(true) {
                String g = br.readLine();
                if(g==null) break;
                g = g.trim();
                if(g.startsWith("'")) continue;
                int i = g.indexOf("%");
                s = "0b"+g.substring(i+1);
                long h = CodeLine.parseNumber(s);
                dest[ind+3] = (byte)((h>>24)&0xFF);
                dest[ind+2] = (byte)((h>>16)&0xFF);
                dest[ind+1] = (byte)((h>>8)&0xFF);
                dest[ind+0] = (byte)((h>>0)&0xFF); 
                ind = ind + 4;
                
            }
        } catch (IOException e) {
            return e.getMessage();
        }       
        return null;
    }
    
    /**
     * Converts the command to SPIN language data commands.
     * @param clusters the master list of clusters
     * @return any error string (starts with "#") or SPIN text
     */
    public abstract String toSPIN(List<Cluster> clusters);
    
    /**
     * Returns the size of the binary of the command.
     * @return size of the command
     */
    public abstract int getSize();   
    
}
