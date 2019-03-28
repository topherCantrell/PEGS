import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics;
import java.awt.Point;
import java.awt.event.FocusAdapter;
import java.awt.event.FocusEvent;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.util.ArrayList;
import java.util.List;

import javax.swing.JComponent;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTabbedPane;
import javax.swing.JTextArea;


public class LEDGrid extends JPanel
{
	
	private static final long serialVersionUID = 1L;
	
	private static final int pixsize = 10;
	
	public int width;
	public int height;	
	public int currentScreen = 0;
	Point lastMouseLocation;
	
	List<byte []> pixelData = new ArrayList<byte []>();
	List<Integer> pauses = new ArrayList<Integer>();
		
	List<Integer> copyPasteBuffer;
	
	JTextArea soundScript;	
	JScrollPane scriptScroll;
	
	public LEDGrid(int width, int height, List<Integer> copyPasteBuffer)
	{
		super(new BorderLayout());		
		soundScript = new JTextArea();
		scriptScroll = new JScrollPane(soundScript);
		soundScript.addFocusListener(new LEDGridSoundFocus());
		add(BorderLayout.CENTER,scriptScroll);
		soundScript.setVisible(false);
		scriptScroll.setVisible(false);
		this.copyPasteBuffer = copyPasteBuffer;
		this.width = width;
		this.height = height;
		byte [] pixels = new byte[width*height];
		pixelData.add(pixels);
		this.setPreferredSize(new Dimension(width*(pixsize+2)+2,height*(pixsize+2)+2));
		this.setBackground(Color.BLACK);
		
		LEDClick click = new LEDClick();
		this.addMouseListener(click);
		this.addMouseMotionListener(click);
		this.addKeyListener(new LEDKey());
	}
	
	public void setPoint(int x, int y, byte color) 
	{
		if(x>=width || y>=height) return;
		byte [] pixels = pixelData.get(currentScreen);
		pixels[y*width+x] = color;
	}
	
	public byte getPoint(int x, int y)
	{
		if(x>=width || y>=height) return 0;
		byte [] pixels = pixelData.get(currentScreen);
		return pixels[y*width+x];
	}	
	
	public void paint(Graphics g)
	{
		byte [] pixels = pixelData.get(currentScreen);
		if(pixels[0]==-1) {
			if(!scriptScroll.isVisible()) {
				scriptScroll.setVisible(true);
				soundScript.setVisible(true);
				updateUI();
			}
			soundScript.grabFocus();			
		} else {
			soundScript.setVisible(false);
			scriptScroll.setVisible(false);
		}
		
		super.paint(g);
		
		if(pixels[0]==-1) return;
						
		g.setColor(Color.WHITE);
								
		int twidth = width*(pixsize+2)+1;
		int theight = height*(pixsize+2)+1;
		
		for(int x=0;x<width+1;++x) {
			g.drawLine(x*(pixsize+2),0,x*(pixsize+2),theight);
			g.drawLine(x*(pixsize+2)+1,0,x*(pixsize+2)+1,theight);
		}		
		for(int y=0;y<height+1;++y) {
			g.drawLine(0,y*(pixsize+2),twidth,y*(pixsize+2));
			g.drawLine(0,y*(pixsize+2)+1,twidth,y*(pixsize+2)+1);
		}
		g.setColor(Color.YELLOW);
		g.drawLine(24*(pixsize+2),0,24*(pixsize+2),theight);
		g.drawLine(0,16*(pixsize+2),twidth,16*(pixsize+2));
				
		Color [] ccs = {Color.BLACK, Color.RED, Color.GRAY, Color.PINK};
		
		int p = 0;
		for(int y=0;y<height;++y) {
			int cy = y*(pixsize+2)+2;
			int cx = 2;
			for(int x=0;x<width;++x) {
				g.setColor(ccs[pixels[p++]]);
				g.fillRect(cx,cy,pixsize,pixsize);
				cx = cx + pixsize + 2;
			}
		}		
	}
	
	class LEDKey extends KeyAdapter
	{		
		public void keyTyped(KeyEvent e)
		{			
			if(e.isControlDown()) {
				byte [] pixels = pixelData.get(currentScreen);
				int k = e.getKeyChar();
				if(k==3) { // COPY
					copyPasteBuffer.clear();
					for(int x=0;x<pixels.length;++x) {
						if(pixels[x]>=2) {
							copyPasteBuffer.add(x+10000*pixels[x]);
						}
					}
				} else if(k==22) { // PASTE
					int ax = lastMouseLocation.x/(pixsize+2);
					int ay = lastMouseLocation.y/(pixsize+2);
					int xx = ax;
					int lastX = -1;
					for(Integer ii : copyPasteBuffer) {
						int c = (ii/10000)&1;
						int p = ii % 10000;
						if(lastX<0) {
							lastX=p;
						} else {
							if(p!=lastX+1) {
								xx=ax;
								ay=ay+1;
							}
							lastX = p;
						}
						setPoint(xx,ay,(byte)c);
						++xx;
					}
					updateUI();
				} else if(k==24) { // CUT
					copyPasteBuffer.clear();
					for(int x=0;x<pixels.length;++x) {
						if(pixels[x]>=2) {
							copyPasteBuffer.add(x+10000*pixels[x]);
							pixels[x]=2;
						}
					}
					updateUI();
				}
			}
		}
	}
	
	class LEDGridSoundFocus extends FocusAdapter
	{
		@Override
		public void focusLost(FocusEvent e) {
			byte [] d = pixelData.get(currentScreen);
			if(d[0]==-1) {
				String t = soundScript.getText();
				d = new byte[t.length()+1];
				d[0] = -1;
				for(int x=0;x<t.length();++x) {
					d[x+1] = (byte)t.charAt(x);
				}
				pixelData.set(currentScreen,d);
			}			
		}
		
		public void focusGained(FocusEvent e) {
			byte [] d = pixelData.get(currentScreen);
			if(d[0]==-1) {
				String t = new String(d,1,d.length-1);
				soundScript.setText(t);				
			}
		}
	}
	
	class LEDClick extends MouseAdapter
	{		
		
		Point firstDrag = null;
		Point lastDrag = null;
		
		public void mouseMoved(MouseEvent e)
		{
			lastMouseLocation = e.getPoint();			
		}
		
		public void mouseEntered(MouseEvent e)
		{
			JComponent j = (JComponent)e.getSource();			
			j.requestFocusInWindow();			
		}
		
		public void mouseClicked(MouseEvent e)
		{		
			byte [] pixels = pixelData.get(currentScreen);
			for(int x=0;x<pixels.length;++x) {
				pixels[x] = (byte)(pixels[x]&1);
			}
			
			Point p = e.getPoint();
			int ax =p.x/(pixsize+2);
			int ay =p.y/(pixsize+2);
			byte c = getPoint(ax,ay);
			if(c==0) c=1;
			else c=0;
			setPoint(ax,ay,c);
			updateUI();			
		}
		
		public void mouseReleased(MouseEvent e)
		{
			if(firstDrag!=null) {
				firstDrag = null;
				lastDrag=null;				
			}
		}
		
		public void mouseDragged(MouseEvent e)
		{
			if(firstDrag==null) {
				firstDrag = new Point(e.getX()/(pixsize+2),e.getY()/(pixsize+2));
				lastDrag = firstDrag;
				return;
			} 
			lastDrag = e.getPoint();
			
			byte [] pixels = pixelData.get(currentScreen);
			for(int x=0;x<pixels.length;++x) {
				pixels[x] = (byte)(pixels[x]&1);
			}
			
			Point p = e.getPoint();
			int ax =p.x/(pixsize+2);
			int ay =p.y/(pixsize+2);
			int bx = firstDrag.x;
			int by = firstDrag.y;
			
			if(by<ay) {
				int i = by;
				by = ay;
				ay = i;
			}
			
			if(bx<ax) {
				int i = bx;
				bx = ax;
				ax = i;
			}
			
			for(int y=ay;y<=by;++y) {
				for(int x=ax;x<bx;++x) {
					pixels[y*width+x] = (byte)(pixels[y*width+x]|2);
				}
			}
						
			updateUI();
			
		}
	}
		
	public static void main(String [] args) throws Exception
	{
		
		List<Integer> copyPasteBuffer = new ArrayList<Integer>();
		
		JTabbedPane jtp = new JTabbedPane();
		
		for(String a : args) {
			LEDGrid g = new LEDGrid(48,32,copyPasteBuffer);
			g.setFocusable(true);
			LEDSequence gg = new LEDSequence(g,a);
			jtp.add(a,gg);
		}
		
		JFrame j = new JFrame("LED Matrix");
		j.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		j.getContentPane().add(BorderLayout.CENTER,jtp);
		j.pack();
		j.setVisible(true);			
		
	}
	
}
