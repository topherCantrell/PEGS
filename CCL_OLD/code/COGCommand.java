package code;

import java.util.*;
import java.io.*;

/**
 * COGCommands turn parsed commands into CCL binary. The various parsers
 * create subclasses of this class. This class also contains static
 * helper methods needed by many commands.
 */
public abstract class COGCommand
{
    
    /**
     * Helper method to find a particular cluster within the master list
     * of clusters.
     * @param cn the name of the cluster
     * @param clusters the master list of clusters to search
     * @return the index of the cluster or -1 if not found
     */
    public static int findClusterNumber(String cn,List<Cluster> clusters)
    {
        for(int x=0;x<clusters.size();++x) {
            if(clusters.get(x).name.equals(cn)) return x;
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
        int curOffset = 0;
        for(int x=0;x<c.commands.size();++x) {
            CodeLine cc = c.commands.get(x).getCodeLine();
            for(int y=0;y<cc.labels.size();++y) {
                if(cc.labels.get(y).equals(lab)) {
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
    public COGCommand(CodeLine line, Cluster clus) {codeLine = line;cluster = clus;}      
    
    /**
     * Returns true if the COGCommand is data chunk (false if code).
     * @return true if data
     */
    public boolean isData() {return false;}
    
    /**
     * Returns the CodeLine that generated the binary (used for error reports)
     * @return the CodeLine
     */
    public CodeLine getCodeLine() {return codeLine;}
    
    public void setCodeLine(CodeLine codeLine) {this.codeLine = codeLine;}
    
    
    
    
    
    
    /**
     * This method parses the given code line and adds the resulting COGCommand(s)
     * to the cluster.
     * @param c the CodeLine to parse
     * @param cluster the CodeLine's container
     * @return null if doesn't belong to us, "" if OK, or  message if parse error
     */
    public abstract String parse(CodeLine c, Cluster cluster);
    
    /**
     * Converts the command to binary form.
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
    
    /**
     * Processes any special data structure (Sprites, Waveforms, Sequences).
     * @param type the type from the structure
     * @param code the list of lines from the cluster
     * @param data the data command to fill out
     */
    public String processSpecialData(String type, List<CodeLine> code, DataCOGCommand data)
    {
        return null; // No special data processing by default
    }
    
}
