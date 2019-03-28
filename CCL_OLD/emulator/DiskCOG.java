import java.util.*;
import java.io.*;


class CacheTableEntry {
    int refCount;
    int localPage;
    int diskCluster;
}



public class DiskCOG extends COG {
    
    List<CacheTableEntry> cacheTable = new ArrayList<CacheTableEntry>();
    
    public DiskCOG(Emulator emu) {
        super(emu);
        
        for(int x=0;x<15;++x) {
            CacheTableEntry cte = new CacheTableEntry();
            if(x<3) {
                cte.refCount = 0xFF;
            } else {
                cte.refCount = 0;
            }
            cte.localPage = x;
            cte.diskCluster = 0xFFFF;
            cacheTable.add(cte);
        }
        
    }
    
    public long [] execute(long [] data) {
        return null;
    }
    
    // ----------------------------
    
    int indAlready;
    int indCurrent;
    int indLastFree;
    int indLastZero;
    
    void searchCache(int currentOffset, int reqCluster) {
        
        currentOffset = currentOffset / 2048;
        indAlready = 0xFFFF;
        indCurrent = 0xFFFF;
        indLastFree = 0xFFFF;
        indLastZero = 0xFFFF;
        for(int x=0;x<cacheTable.size();++x) {
            CacheTableEntry ent = cacheTable.get(x);
            if(ent.localPage == currentOffset) indCurrent = x;
            if(ent.diskCluster == reqCluster) indAlready = x;
            if(ent.diskCluster == 0xFFFF) indLastFree = x;
            if(ent.refCount == 0) indLastZero = x;
        }
        
    }
    
    void printCacheTable() {
        
        for(int x=0;x<cacheTable.size();++x) {
            CacheTableEntry ent = cacheTable.get(x);
            System.out.println(""+x+" "+ent.refCount+" "+ent.localPage+" "+ent.diskCluster);
        }
        
    }
    
    int cache(int currentOffset, int reqCluster) {
        
        try {
            
            searchCache(currentOffset,reqCluster);
            
            if(currentOffset!=0xFFFF && indCurrent!=0xFFFF) {
                if(cacheTable.get(indCurrent).refCount>0) {
                    --cacheTable.get(indCurrent).refCount;
                }
            }
            
            if(reqCluster==0xFFFF) {
                return 0xFFFF;
            }
            
            boolean loadData = false;
            
            if(indAlready!=0xFFFF) {
                cacheTable.add(cacheTable.get(indAlready));
                cacheTable.remove(indAlready);
            } else if(indLastFree!=0xFFFF) {
                cacheTable.add(cacheTable.get(indLastFree));
                cacheTable.remove(indLastFree);
                loadData = true;
            } else if(indLastZero!=0xFFFF) {
                cacheTable.add(cacheTable.get(indLastZero));
                cacheTable.remove(indLastZero);
                loadData = true;
            }
            
            ++cacheTable.get(14).refCount;
            int localAddress = cacheTable.get(14).localPage*2408;
            
            if(loadData) {
                System.out.println(reqCluster);
                emu.inputFile.seek(reqCluster*2048);
                emu.inputFile.read(emu.sharedRAM,localAddress,2048);
                cacheTable.get(14).diskCluster = reqCluster;
            }
            
            return localAddress;
            
        } catch (IOException e) {
            e.printStackTrace();
            return 0xFFFF;
            
        }        
        
    }    
    
}
