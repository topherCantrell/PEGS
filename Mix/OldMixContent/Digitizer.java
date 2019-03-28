
import java.io.*;
import java.util.ArrayList;
import java.util.List;

public class Digitizer {

	int [][] pixData;
	List<Integer> colors;
	int width;
	int height;
	
	public static long readValue(byte [] data, int offset, int numBytes)
	{
		long ret = 0;
		for(int x=numBytes-1;x>=0;--x) {
			int a = data[offset+x];
			if(a<0) a=a+256;
			ret = ret << 8;
			ret = ret + a;
		}
		return ret;
	}
	
	public Digitizer(String fname) throws Exception
	{
		InputStream is = new FileInputStream(fname);
		byte [] data = new byte[is.available()];
		is.read(data);
		is.close();	
		
		int dataStart = (int)readValue(data,10,4);
		int width = (int)readValue(data,18,4);
		int height = (int)readValue(data,22,4);
		int bitsPerPixel = (int)readValue(data,28,2);
		
		pixData = new int[width][height];
		
		int dataWidth = width;
		while(dataWidth%4!=0) {
		   dataWidth=dataWidth+1;
		}
		
		for(int x=0;x<width;++x) {
			for(int y=0;y<height;++y) {
				int a = data[dataStart+y*dataWidth+x];
				if(a<0) a=a+256;
				pixData[x][height-1-y]=a;
			}
		}
		
		colors = new ArrayList<Integer>();
		for(int x=0;x<width;++x) {
			for(int y=0;y<height;++y) {
				if(!colors.contains(pixData[x][y])) {
					colors.add(pixData[x][y]);
				}
				pixData[x][y] = colors.indexOf(pixData[x][y]);
			}
		}
		
		
		System.out.println("Image is "+width+"x"+height+"  "+bitsPerPixel+" bits/pixel");		
		System.out.println("Image uses "+colors.size()+" distinct colors.");				
				
	}
	
	public void printImage(int [][] data)
	{
		System.out.println("Image is "+data.length+"x"+data[0].length);		
		for(int y=0;y<data[0].length;++y) {
			for(int x=0;x<data.length;++x) {
				System.out.print((char)('A'+data[x][y]));
			}
			System.out.print("\r\n");
		}
	}
	
	int majority(int x, int y, int cx, int cy)
	{
		int majority=0;
		int majorityCount=0;
		for(int xx=x;xx<(x+cx);++xx) {
			for(int yy=y;yy<(y+cy);++yy) {
				int cand = pixData[xx][yy];
				
				int tc = 0;
				for(int ix=x;ix<(x+cx);++ix) {
					for(int iy=y;iy<(y+cy);++iy) {
						if(pixData[ix][iy] == cand) {
							++tc;
						}
					}
				}
				
				if(tc>majorityCount) {
					majorityCount = tc;
					majority = cand;
				}
				
			}
		}
		return majority;
	}
	public int [][] compress(int cx, int cy)
	{
		int [][] ret = new int[pixData.length/cx][pixData[0].length/cy];
		for(int x=0;x<pixData.length/cx;++x) {
			for(int y=0;y<pixData[0].length/cy;++y) {
				ret[x][y] = majority(x*cx,y*cy,cx,cy);
			}
		}
		return ret;
	}
	
	public static void main(String[] args) throws Exception
	{
		
		Digitizer d = new Digitizer(args[0]);
				
		int [][] r = d.compress(2,2);
		d.printImage(r);

	}

}
