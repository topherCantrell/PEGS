
import java.io.*;

public class MakeData
{


public static void main(String [] args) throws Exception
{

  InputStream is = new FileInputStream(args[0]);
  byte [] b = new byte[is.available()];
  is.read(b);
  is.close();

  System.out.println("unsigned char DISK_DATA[] = {");
  int cnt = 0;
  for(int x=0;x<b.length;++x) {

    int a = b[x];
    if(a<0) a=a+256;
    System.out.print("0x");
    System.out.print(Integer.toString(a,16));
    if(x!=(b.length-1)) {
      System.out.print(", ");
    }
    cnt = cnt + 1;
    if(cnt==8) {
      cnt = 0;
      System.out.println();
    }
  }
  System.out.println("};");

}


}