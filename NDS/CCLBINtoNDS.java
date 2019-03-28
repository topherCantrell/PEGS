import java.io.*;

public class CCLBINtoNDS
{

public static void main(String [] args) throws Exception
{

InputStream is = new FileInputStream("CCL.nds");
byte [] b = new byte[is.available()];
is.read(b);
is.close();

int ofs = -1;
for(int x=0;x<b.length;++x) {
  if(b[x]!=1) continue;
  boolean fnd = true;
  for(int y=x;y<x+2048;++y) {
    if(b[y]!=1) {
      fnd = false;
      break;
    }
  }
  for(int y=x+2048;y<x+4096;++y) {
    if(b[y]!=2) {
      fnd = false;
      break;
    }
  }
  if(fnd) {
    ofs = x;
    break;
  }
}

System.out.println(":: DiskData in NDS starts at 0x"+Integer.toString(ofs,16));

is = new FileInputStream(args[0]);
is.read(b,ofs,is.available());
is.close();

OutputStream os = new FileOutputStream(args[1]);
os.write(b);
os.flush();
os.close();

}

}