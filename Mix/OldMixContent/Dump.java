
import java.io.*;

public class Dump
{

public static void main(String [] args) throws Exception
{

InputStream is = new FileInputStream(args[0]);
while(is.available()>0) {
int a = is.read();
System.out.print(Integer.toString(a,16)+" ");
}

}

 

}