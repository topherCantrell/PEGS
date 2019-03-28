
import java.io.*;

public class MakeBlankData
{


public static void main(String [] args) throws Exception
{

  System.out.println("unsigned char DISK_DATA[] = {");
  int cnt = 0;
  for(int y=1;y<=10;++y) {
    for(int r=0;r<128;++r) {
      for(int x=0;x<16;++x) {
        System.out.print(y);
        System.out.print(",");
      }
      System.out.println();
    }
  }  
  System.out.println("};");

}


}