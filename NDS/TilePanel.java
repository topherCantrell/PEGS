import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

public class TilePanel extends JPanel 
{
    
    int [] data = new int[8*8];
    
    public TilePanel()
    {
        super(null);
        setPreferredSize(new Dimension(16,16));
    }
    
    public void setData(int [] data) {            
        for(int y=0;y<8;++y) {            
                int val = data[y*2];
                this.data[y*8+3] = (val&0xC0)>>6;
                this.data[y*8+2] = (val&0x30)>>4;
                this.data[y*8+1] = (val&0x0C)>>2;
                this.data[y*8] = val&0x03;
                val = data[y*2 + 1];
                this.data[y*8+7] = (val&0xC0)>>6;
                this.data[y*8+6] = (val&0x30)>>4;
                this.data[y*8+5] = (val&0x0C)>>2;
                this.data[y*8+4] = val&0x03;
        }        
        updateUI();
    }
    
    public void paint(Graphics g)
    {
        super.paint(g);
        for(int y=0;y<8;++y) {
            for(int x=0;x<8;++x) {
                switch(data[y*8+x]) {
                    case 2:
                        g.setColor(Color.green);
                        break;
                    case 3:
                        g.setColor(Color.red);
                        break;
                    case 1:
                        g.setColor(Color.white);
                        break;
                    default:
                        g.setColor(Color.black);
                }
                g.fillRect(x*2,y*2,2,2);
            }
        }
        
    }
    
}
