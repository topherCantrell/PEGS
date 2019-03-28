
import java.io.*;

public class ImageFlip
{
	public static void main(String [] args) throws Exception
	{
		FileReader fr = new FileReader(args[0]);
		BufferedReader br = new BufferedReader(fr);
		while(true) {
			String g = br.readLine();
			if(g==null) break;
			for(int x=g.length()-1;x>=0;--x) {
				System.out.print(g.charAt(x));
			}
			System.out.println("\r\n");
		}
		br.close();
	}
}
