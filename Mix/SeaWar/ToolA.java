import java.io.BufferedReader;
import java.io.FileReader;
import java.util.Random;



public class ToolA
{
	public static void main(String [] args) throws Exception
	{
		FileReader f = new FileReader("SeaWar.mix");
		BufferedReader br = new BufferedReader(f);
		Random rand = new Random();
		while(true) {
			String g = br.readLine();
			if(g==null) break;
			if(g.startsWith(".") && g.length()>100) {
				String rr = "";
				for(int x=0;x<g.length();++x) {
					char a = g.charAt(x);
					if(a=='W') {
						int i = rand.nextInt(3);
						if(i==0) a='W';
						if(i==1) a='R';
						if(i==2) a='G';						
					}
					
					rr=rr+a;
				}			
				g = rr;
			}
			System.out.print(g+"\r\n");
		}
	}
}
