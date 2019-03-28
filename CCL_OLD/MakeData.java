import java.io.*;

public class MakeData
{
    
    
    public static void main(String [] args) throws Exception
    {
        
        OutputStream os = new FileOutputStream("data.bin");        
        
        for(int y=0;y<30;++y) {
            
            os.write(y);
            for(int x=1;x<2048;++x) {
                os.write((byte)x);
            }
            
        }
        
        os.flush();
        os.close();
        
    }
    
}
