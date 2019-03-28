import java.io.*;

public class LineDiff
{
    
    public static void main(String [] args) throws Exception
    {
        Reader ra = new FileReader(args[0]);
        BufferedReader bra = new BufferedReader(ra);
        
        Reader rb = new FileReader(args[1]);
        BufferedReader brb = new BufferedReader(rb);
        
        int lineNumber = 0;
        while(true) {
            String a = bra.readLine();
            if(a==null) break;
            String b = brb.readLine();
            if(b==null) break;
            
            ++lineNumber;
            
            if(!a.equals(b)) {
                System.out.println("Line "+lineNumber);
                System.out.println(a);
                System.out.println(b);
            }
            
        }
        
    }
    
}
