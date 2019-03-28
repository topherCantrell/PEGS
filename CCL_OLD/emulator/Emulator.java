import java.util.*;
import java.io.*;

public class Emulator {
    
    Map<Integer,COG> cogs = new HashMap<Integer,COG>();
    RandomAccessFile inputFile;
    
    byte [] sharedRAM = new byte[2048*16];
    
    public Emulator(RandomAccessFile raf) {
        inputFile = raf;
        DiskCOG diskCOG = new DiskCOG(this);
        cogs.put(new Integer(0),diskCOG);
        cogs.put(new Integer(1),new VariableCOG(this));
        cogs.put(new Integer(2),new TVCOG(this));
        // sound
        // sprites
        
        int ofs = diskCOG.cache(0xFFFF,0);
        System.out.println(Integer.toString(ofs,16));
        diskCOG.printCacheTable();
        
        // load cluster 0
        // begin
        
    }
    
    public static void main(String [] args) throws Exception {
        
        RandomAccessFile raf = new RandomAccessFile(args[0],"rw");
        Emulator emu = new Emulator(raf);
        
        
        
        
    }
    
}
