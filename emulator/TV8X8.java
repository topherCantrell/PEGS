
import javax.swing.*;
import java.awt.*;


public class TV8X8 extends JPanel {
    
    Color [][] colors = new Color[16][4];
    int [] memory;
    
    public TV8X8(int [] memory) {
        
        this.memory = memory;
        
        for(int x=0;x<colors.length;++x) {
            colors[x][0] = Color.black;
            colors[x][1] = Color.red;
            colors[x][2] = Color.green;
            colors[x][3] = Color.white;
        }
        
        setPreferredSize(new Dimension(256*2,208*2));
        
    }
    
    
    public void paint(Graphics g) {
        
        g.drawLine(10,10,20,20);
        
    }
    
    
    
    public static void main(String [] args) throws Exception {
        
        JFrame jf = new JFrame("TV8X8");
        int [] memory = new int[65536];
        TV8X8 tv = new TV8X8(memory);
        jf.getContentPane().add(BorderLayout.CENTER,tv);
        jf.pack();
        jf.setResizable(false);
        jf.setVisible(true);
        
    }
    
    
    
    
}