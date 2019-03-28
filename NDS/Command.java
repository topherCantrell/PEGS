
import java.io.*;
import java.util.*;

public abstract class Command
{
    
String text;
    String [] label = new String[10];
    
    int id;    
    
    void addLabel(String lab)
    {
        for(int x=0;x<label.length;++x) {
            if(label[x]==null) {
                label[x] = lab;
                break;
            }
        }
    }
    
    public int getBinarySize()
    {
        return 4;
    }
    
    public Command(int id,String text)
    {
        this.id = id;
        this.text = text;
    }
    
    abstract void writeBinary(Cluster c,OutputStream os, List allClusters) throws IOException;
    
}
