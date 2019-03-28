
import java.io.*;

public class Externalizer 
{
	
	public static void main(String[] args) throws Exception
	{
		InputStream is = new FileInputStream(args[0]);		
		is.skip(24);
		byte [] data = new byte[is.available()];
		is.read(data);
		is.close();
		
		OutputStream os = new FileOutputStream(args[1]);
		PrintStream ps = new PrintStream(os);
		ps.print("CLUSTER "+args[0]+"\r\n");
		ps.print("\r\nEXECUTE COG=n, PAR=p\r\n");
		ps.print("\r\n---------------------------------\r\n\r\n");
		
		int ds = 0;
		
		for(int x=0;x<data.length;++x) {
			int a = data[x];
			if(a<0) a=a+256;
			String s = Integer.toString(a,16);
			while(s.length()<2) {
				s="0"+s;			
			}
			if(ds==0) {
				ps.print("    ");
			} else {
				ps.print(",");
			}
			ps.print("0x"+s);
		    ds=ds+1;
		    if(ds==16) {
		    	ds=0;
		    	ps.print("\r\n");
		    }
		}
		ps.print("\r\n");
		ps.flush();
		ps.close();

	}

}
