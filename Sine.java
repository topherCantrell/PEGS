

public class Sine
{


public static void main(String [] args) throws Exception
{

int width = 32;
int height = 64;
double half = 31.0;

char [][] data = new char[height][width];
for(int y=0;y<data.length;++y) {
for(int x=0;x<data[y].length;++x) {
  data[y][x] = '.';
}
}

for(int x=0;x<width;++x) {
  double val = Math.cos(x*2*Math.PI/width)*half+(height/2.0);
  System.out.println(val);
  data[(int)Math.round(val)][x] = 'X';
}


for(int y=0;y<data.length;++y) {
  for(int x=0;x<data[y].length;++x) {
    System.out.print(data[y][x]);
  }
  System.out.println();
}


}


}