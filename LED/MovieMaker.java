
import java.io.*;
import java.util.ArrayList;
import java.util.List;

public class MovieMaker
{
		
	public static void main(String [] args) throws Exception
	{
		
		ArrayList<byte[]> data = new ArrayList<byte[]>();
		int fc = loadFrames(data,"0.txt");
		System.out.println(fc);
		fc = loadFrames(data,"12.txt");
		System.out.println(fc);
		fc = loadFrames(data,"11.txt");
		System.out.println(fc);
		fc = loadFrames(data,"10.txt");
		System.out.println(fc);
		fc = loadFrames(data,"9.txt");
		System.out.println(fc);
		fc = loadFrames(data,"8.txt");
		System.out.println(fc);
		fc = loadFrames(data,"7.txt");
		System.out.println(fc);
		fc = loadFrames(data,"6.txt");
		System.out.println(fc);
		fc = loadFrames(data,"5.txt");
		System.out.println(fc);
		fc = loadFrames(data,"4.txt");
		System.out.println(fc);
		fc = loadFrames(data,"3.txt");
		System.out.println(fc);
		fc = loadFrames(data,"2.txt");
		System.out.println(fc);
		fc = loadFrames(data,"1.txt");
		System.out.println(fc);
		
		saveSpin(data);		
		
	}
	
	static int loadFrames(List<byte[]> data, String filename) throws Exception
	{
		Reader r = new FileReader(filename);
		BufferedReader br = new BufferedReader(r);
		int fc = 0;
		while(true) {
			String g = br.readLine();
			if(g==null) break;			
			byte [] bb = new byte[48*32];
			++fc;
			for(int z=0;z<32;++z) {
				g = br.readLine();
				for(int y=0;y<48;++y) {
					char cc = g.charAt(y);
					if(cc!='.') cc=1;
					else cc = 0;
					bb[z*48 + y] = (byte)cc;
				}				
			}
			data.add(bb);
			g = br.readLine();
		}
		return fc;
	}
	
	static void saveSpin(List<byte[]> data) throws IOException
	{
		
		OutputStream oss = new FileOutputStream("movieframes.spin");
		PrintStream pss = new PrintStream(oss);		
		
		pss.println("variable y\r\n\r\n");
				
		int width = 48;
		
		for(int z=0;z<data.size();++z) {
			if(z%8 == 0) {
				int mx = z+8;
				if(mx>data.size()) {
					mx=data.size();
				}

				pss.print("CLUSTER showFrame"+(z/8)+"\r\n");
				pss.print("\r\n");
				pss.print("if(y==0) {\r\n");
				pss.print("  memcopy frame0,0,48 \r\n");
				pss.print("} \r\n");
				pss.print("if(y==1) {\r\n");
				pss.print("  memcopy frame1,0,48 \r\n");
				pss.print("} \r\n");
				pss.print("if(y==2) {\r\n");
				pss.print("  memcopy frame2,0,48 \r\n");
				pss.print("} \r\n");
				pss.print("if(y==3) {\r\n");
				pss.print("  memcopy frame3,0,48 \r\n");
				pss.print("} \r\n");
				pss.print("if(y==4) {\r\n");
				pss.print("  memcopy frame4,0,48 \r\n");
				pss.print("} \r\n"); 
				pss.print("if(y==5) {\r\n");
				pss.print("  memcopy frame5,0,48\r\n"); 
				pss.print("} \r\n");
				pss.print("if(y==6) {\r\n");
				pss.print("  memcopy frame6,0,48\r\n"); 
				pss.print("} \r\n");
				pss.print("if(y==7) {\r\n");
				pss.print("  memcopy frame7,0,48\r\n"); 
				pss.print("} \r\n");
				pss.print("return\r\n"); 
				pss.print("\r\n");
				pss.print("----------\r\n");
			}
			pss.print("frame"+(z%8)+":\r\n");
			byte [] i = data.get(z);
			if(i[0]==-1) {
				pss.print("SEQUENCE {\r\n");
				String t = new String(i,1,i.length-1);
				for(int x=0;x<t.length();++x) {
					char cc = t.charAt(x);
					if(cc=='\n') {
						pss.print("\r");
					}
					pss.print(cc);
				}	
				pss.print("\r\n}\r\n\r\n");
			} else {				
				int [] spinDat = new int[192];
				// Lower right quadrant
				int pos = 0;
				for(int col=24;col<48;col=col+1) {
					for(int row=16;row<32;row=row+8) {				
						int da = 0;
						da = da | ((i[(row+0)*width+col]&1)<<0);
						da = da | ((i[(row+1)*width+col]&1)<<1);
						da = da | ((i[(row+2)*width+col]&1)<<2);
						da = da | ((i[(row+3)*width+col]&1)<<3);
						da = da | ((i[(row+4)*width+col]&1)<<4);
						da = da | ((i[(row+5)*width+col]&1)<<5);
						da = da | ((i[(row+6)*width+col]&1)<<6);
						da = da | ((i[(row+7)*width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}
				// Lower left quadrant
				for(int col=0;col<24;col=col+1) {
					for(int row=16;row<32;row=row+8) {				
						int da = 0;
						da = da | ((i[(row+0)*width+col]&1)<<0);
						da = da | ((i[(row+1)*width+col]&1)<<1);
						da = da | ((i[(row+2)*width+col]&1)<<2);
						da = da | ((i[(row+3)*width+col]&1)<<3);
						da = da | ((i[(row+4)*width+col]&1)<<4);
						da = da | ((i[(row+5)*width+col]&1)<<5);
						da = da | ((i[(row+6)*width+col]&1)<<6);
						da = da | ((i[(row+7)*width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}
				// Upper right quadrant
				for(int col=47;col>=24;col=col-1) {
					for(int row=15;row>0;row=row-8) {				
						int da = 0;
						da = da | ((i[(row-0)*width+col]&1)<<0);
						da = da | ((i[(row-1)*width+col]&1)<<1);
						da = da | ((i[(row-2)*width+col]&1)<<2);
						da = da | ((i[(row-3)*width+col]&1)<<3);
						da = da | ((i[(row-4)*width+col]&1)<<4);
						da = da | ((i[(row-5)*width+col]&1)<<5);
						da = da | ((i[(row-6)*width+col]&1)<<6);
						da = da | ((i[(row-7)*width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}
				// Upper left quadrant
				for(int col=23;col>=0;col=col-1) {
					for(int row=15;row>0;row=row-8) {				
						int da = 0;
						da = da | ((i[(row-0)*width+col]&1)<<0);
						da = da | ((i[(row-1)*width+col]&1)<<1);
						da = da | ((i[(row-2)*width+col]&1)<<2);
						da = da | ((i[(row-3)*width+col]&1)<<3);
						da = da | ((i[(row-4)*width+col]&1)<<4);
						da = da | ((i[(row-5)*width+col]&1)<<5);
						da = da | ((i[(row-6)*width+col]&1)<<6);
						da = da | ((i[(row-7)*width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}

				for(int zz=0;zz<spinDat.length;++zz) {
					pss.print(spinDat[zz]);
					if(zz!=(spinDat.length-1)) {
						pss.print(",");
					}				
				}
				pss.print("\r\n\r\n");
			}
			
		}		
				
		pss.flush();
		pss.close();
		
	}

}
