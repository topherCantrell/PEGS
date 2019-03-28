/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

/**
 * This class encapsulates data items kept in the data sections. Data items
 * are lists of bytes.
 */
public class DataCOGCommand extends Command
{    
    // The list of bytes
     List<Integer> data = new ArrayList<Integer>();
     
     /**
      * This constructs a new DataCOGCommand.
      * @param line the CodeLine
      * @param clus the current Cluster
      */
     public DataCOGCommand(CodeLine line,Cluster clus) {super(line,clus);}
     
     /**
      * Returns true. This is data.
      * @return true
      */
     public boolean isData() {return true;}
     
     /**
      * Rerturns the number of bytes in the list.
      */
     public int getSize()
     {   
         return data.size();
     }
     
     /**
      * Converts the command's list of data to a comma-separated list of
      * SPIN hex numbers.
      * @param clusters the master list of clusters
      * @return the spin (no errors from here)
      */
     public String toSPIN(List<Cluster> clusters)
     {
         
         if(clusters==null) return null;
         
         if(data.size()==0) return null;
         
         String tt = "' "+codeLine.text+"\r\n";
         tt = tt + "  byte  ";
         for(int x=0;x<data.size();++x) {
             if(x>0) tt=tt+", ";
             tt=tt+"$"+Integer.toString(data.get(x).intValue(),16);          
         }
         
         return tt;
     }
     
     /**
      * This method converts the data to pure binary form for storage
      * in MIX file.
      * @param clusters the master list of clusters
      * @param dest the pre-sized data array
      * @return always null ... this can't fail
      */
    public String toBinary(List<Cluster> clusters, byte [] dest)
    {
        for(int x=0;x<data.size();++x) {
            dest[x] = data.get(x).byteValue();
        }
        return null;
    }
     
}
