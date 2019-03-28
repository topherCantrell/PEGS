import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class TileGrid extends JPanel implements KeyListener
{
    
    TilePanel [][] tilePanel;
    
    int [][] tileData = new int[512][16];
    int [][] tileSlotNumber;

    public void keyTyped(KeyEvent e) {System.out.println("woo"+e);}
    public void keyPressed(KeyEvent e) {System.out.println(e);}
    public void keyReleased(KeyEvent e) {System.out.println(e);}
    
    public TileGrid(int width, int height)
    {
        super(new GridLayout(height,width,0,0));
        addKeyListener(this);
        tilePanel = new TilePanel[height][width];
        tileSlotNumber = new int[height][width];
        for(int y=0;y<height;++y) {
            for(int x=0;x<width;++x) {
                tilePanel[y][x] = new TilePanel();
                add(tilePanel[y][x]);
            }
        }
    }

    public void redrawGrid()
    {
       for(int y=0;y<tileSlotNumber.length;++y) {
         for(int x=0;x<tileSlotNumber[y].length;++x) {
           setTile(x,y,tileSlotNumber[y][x]);
         }
       }
    }
    
    public void setTileData(int slot, int [] data)
    {
        tileData[slot] = data;        
    }
    
    public int setTile(int x, int y, int slot)
    {
        int ret = tileSlotNumber[y][x];
        tileSlotNumber[y][x] = slot;
        //System.out.println("::::"+tileSlotNumber[y][x]);
        //System.out.println(x+","+y+","+slot);
        tilePanel[y][x].setData(tileData[(slot&255)]);
        return ret;
    }  
    
    public int getTile(int x, int y)
    {
        //System.out.println(":>:"+tileSlotNumber[y][x]);
        return tileSlotNumber[y][x];
    }     
    
    
}
