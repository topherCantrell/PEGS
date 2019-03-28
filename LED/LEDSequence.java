import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.FocusAdapter;
import java.awt.event.FocusEvent;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;
import java.io.Reader;
import java.util.ArrayList;
import java.util.List;

import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTextField;

class LEDSequence extends JPanel
{	
	private static final long serialVersionUID = 1L;
	
	LEDGrid grid;
	JTextField pageNumber;
	JTextField delay;
	
	String filename;
	
	class LEDSequenceDelayFocus extends FocusAdapter
	{

		@Override
		public void focusLost(FocusEvent e) {
			int i = 0;
			try {
				i = Integer.parseInt(delay.getText().trim());
			} catch(Exception ee) {}
			grid.pauses.set(grid.currentScreen, i);
		}
		
	}
	
	class LEDSequenceFocus extends FocusAdapter
	{

		@Override
		public void focusLost(FocusEvent e) {
			int i = 0;
			try {
				i = Integer.parseInt(pageNumber.getText().trim());
			} catch(Exception ee) {}
			if(i>=grid.pixelData.size()) {
				i = grid.pixelData.size()-1;
			}
			grid.currentScreen = i;
			pageNumber.setText(""+i);
			grid.updateUI();
		}
		
	}	
	
	class LEDSequenceAction implements ActionListener
	{

		@Override
		public void actionPerformed(ActionEvent e) 
		{
			Object o = e.getSource();
			if(o==pageNumber) {
				int i = 0;
				try {
					i = Integer.parseInt(pageNumber.getText().trim());
				} catch(Exception ee) {}
				if(i>=grid.pixelData.size()) {
					i = grid.pixelData.size()-1;
				}
				grid.currentScreen = i;
				pageNumber.setText(""+i);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			
			if(o==delay) {
				int i = 0;
				try {
					i = Integer.parseInt(pageNumber.getText().trim());
				} catch(Exception ee) {}
				grid.pauses.set(grid.currentScreen, i);
				return;
			}
			
			JButton j = (JButton)e.getSource();
			String t = j.getText();
			
			if(t.equals("<ND")) {		
				int od = grid.pauses.get(grid.currentScreen);
				byte [] newPixDat = grid.pixelData.get(grid.currentScreen).clone();
				grid.pixelData.add(grid.currentScreen,newPixDat);
				grid.pauses.add(grid.currentScreen, od);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals("ND>")) {
				int od = grid.pauses.get(grid.currentScreen);
				byte [] newPixDat = grid.pixelData.get(grid.currentScreen).clone();
				grid.pixelData.add(grid.currentScreen+1,newPixDat);
				grid.pauses.add(grid.currentScreen+1, od);
				++grid.currentScreen;
				pageNumber.setText(""+grid.currentScreen);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals("<NB")) {
				int od = grid.pauses.get(grid.currentScreen);
				byte [] newPixDat = new byte[grid.width*grid.height];
				grid.pixelData.add(grid.currentScreen,newPixDat);
				grid.pauses.add(grid.currentScreen, od);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals("NB>")) {
				int od = grid.pauses.get(grid.currentScreen);
				byte [] newPixDat = new byte[grid.width*grid.height];
				grid.pixelData.add(grid.currentScreen+1,newPixDat);
				grid.pauses.add(grid.currentScreen+1, od);
				++grid.currentScreen;
				pageNumber.setText(""+grid.currentScreen);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals("X")) {
				if(grid.pixelData.size()==1) {
					grid.pixelData.set(0,new byte[grid.pixelData.get(grid.currentScreen).length]);
					delay.setText(""+grid.pauses.get(grid.currentScreen));
					grid.updateUI();
				} else {
					grid.pixelData.remove(grid.currentScreen);
					if(grid.currentScreen==grid.pixelData.size()) {
						--grid.currentScreen;
						pageNumber.setText(""+grid.currentScreen);
					}					
					delay.setText(""+grid.pauses.get(grid.currentScreen));
					grid.updateUI();
				}
				return;
			}
			
			if(t.equals("<")) {
				--grid.currentScreen;
				if(grid.currentScreen<0) {
					++grid.currentScreen;
				}
				pageNumber.setText(""+grid.currentScreen);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals(">")) {
				++grid.currentScreen;
				if(grid.currentScreen==grid.pixelData.size()) {					
					--grid.currentScreen;
				}
				pageNumber.setText(""+grid.currentScreen);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals("<<")) {
				grid.currentScreen = 0;
				pageNumber.setText(""+grid.currentScreen);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			if(t.equals(">>")) {
				grid.currentScreen = grid.pixelData.size()-1;
				pageNumber.setText(""+grid.currentScreen);
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				grid.updateUI();
				return;
			}
			
			if(t.equals("Save")) {
				try {
					saveFile(grid.pixelData,grid.pauses);
				} catch (Exception ex) {
					ex.printStackTrace();
				}
				return;
			}
			
			if(t.equals("Reload")) {
				try {
					grid.pixelData = new ArrayList<byte []>();
					grid.pauses = new ArrayList<Integer>();
					loadFile(grid.pixelData,grid.pauses);
					delay.setText(""+grid.pauses.get(grid.currentScreen));
					updateUI();
				} catch (Exception ex) {
					ex.printStackTrace();
				}
				return;
			}
			
			if(t.equals("Sound")) {				
				byte [] b = new byte[1];
				b[0] = -1;
				grid.soundScript.setVisible(true);
				grid.scriptScroll.setVisible(true);
				grid.pixelData.set(grid.currentScreen,b);				
				grid.soundScript.grabFocus();
				delay.setText(""+grid.pauses.get(grid.currentScreen));
				updateUI();
				return;
			}
			
			System.out.println("UNKNOWN ACTION:"+t);
		}
		
	}
	
	public LEDSequence(LEDGrid grid, String filename) throws IOException
	{
		super(new BorderLayout());
		this.grid = grid;		
		add(BorderLayout.CENTER,grid);
		
		this.filename = filename;
		
		grid.pixelData = new ArrayList<byte []>();
		grid.pauses = new ArrayList<Integer>();
		loadFile(grid.pixelData,grid.pauses);
		
		LEDSequenceAction action = new LEDSequenceAction();
		
		delay = new JTextField("0",6);
		delay.addActionListener(action);
		delay.addFocusListener(new LEDSequenceDelayFocus());
				
		pageNumber = new JTextField("0",6);
		pageNumber.addActionListener(action);
		pageNumber.addFocusListener(new LEDSequenceFocus());
		
		JPanel ja = new JPanel(new FlowLayout());
		JButton b = new JButton("<<");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton("<"); 
		b.addActionListener(action);
		ja.add(b);
		ja.add(pageNumber);
		b = new JButton(">");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton(">>");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton("<ND");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton("<NB");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton("X");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton("NB>");
		b.addActionListener(action);
		ja.add(b);
		b = new JButton("ND>");
		b.addActionListener(action);
		ja.add(b);
		
		JPanel jb = new JPanel(new FlowLayout());
		b = new JButton("Sound");
		b.addActionListener(action);
		jb.add(b);
		b = new JButton("Save");
		b.addActionListener(action);
		jb.add(b);
		b = new JButton("Reload");
		b.addActionListener(action);
		jb.add(b);
		b = new JButton("SD");
		b.addActionListener(action);
		jb.add(b);
		jb.add(new JLabel("     Pause (ms):"));
		jb.add(delay);
	
		
		JPanel jc = new JPanel(new BorderLayout());
		jc.add(BorderLayout.NORTH,ja);
		jc.add(BorderLayout.SOUTH,jb);
		add(BorderLayout.SOUTH,jc);
		
		delay.setText(""+grid.pauses.get(grid.currentScreen));
	}

	private void loadFile(List<byte[]> ret, List<Integer> pauses) throws IOException
	{
		File f = new File(filename);
		if(!f.exists() || !f.isFile()) {
			OutputStream os = new FileOutputStream(filename);
			os.close();
		}
		
		Reader is = new FileReader(filename);
		BufferedReader br = new BufferedReader(is);
		while(true) {
			byte[] b = new byte[grid.width*grid.height];
			ret.add(b);
			pauses.add(0);
			int pos = 0;
			while(true) {
				String g = br.readLine();
				if(g==null) {
					is.close();
					return;				
				}
				g=g.trim();
				if(g.startsWith("%")) {
					g=g.substring(1);
					int ii = Integer.parseInt(g);
					pauses.set(pauses.size()-1,ii);
					continue;
				}
				if(g.equals("#####")) {
					String ss = "";
					while(true) {
						g = br.readLine();
						if(g.equals("#####")) {
							break;
						}
						ss = ss+g+"\n";
					}
					ss=ss.trim();
					b = new byte[ss.length()+1];					
					b[0] = -1;
					for(int zz=0;zz<ss.length();++zz) {
						b[zz+1] = (byte)ss.charAt(zz);
					}
					ret.set(ret.size()-1,b);
					break;
				}
				if(g.length()<grid.width) {
					break;
				}
				for(int x=0;x<g.length();++x) {
					if(g.charAt(x)!='.') {
						b[pos]=1;
					}
					++pos;
				}
			}
		}
		
	}
	
	private void saveBinary(List<byte []> data,List<Integer> pauses) throws IOException
	{
		OutputStream os = new FileOutputStream("a.bin");
		
		os.flush();
		os.close();		
	}
	
	private void saveSpin(List<byte[]> data,List<Integer> pauses) throws IOException
	{
		
		OutputStream oss = new FileOutputStream(filename+".spin");
		PrintStream pss = new PrintStream(oss);		
		
		pss.print("define REFRESH=32620\r\n");
		int nc = 0;
		
		for(int z=0;z<data.size();++z) {
			if(z%9 == 0) {
				pss.print("CLUSTER clus"+(z/9)+"\r\n");
				int mx = z+9;
				if(mx>data.size()) {
					mx=data.size();
				}
				nc = (z/9)+1;
				pss.print("CACHEHINT clus"+nc+"\r\n");
				for(int xx=z;xx<mx;++xx) {
					pss.print("MEMCOPY frame"+xx+",0,48\r\n");
					pss.print("mem(REFRESH)=1\r\n");
					pss.print("pause "+pauses.get(xx)+"ms\r\n");
				}
				pss.print("GOTO clus"+nc+":\r\n");
				pss.print("----------\r\n");
			}
			pss.print("frame"+z+":\r\n");
			byte [] i = data.get(z);
			if(i[0]==-1) {
				pss.print("SEQUENCE {\r\n");
				String t = new String(i,1,i.length-1);
				for(int x=0;x<t.length();++x) {
					char cc = t.charAt(x);
					if(cc=='\n') {
						pss.print("\r");
					}
					pss.print(cc);
				}	
				pss.print("\r\n}\r\n\r\n");
			} else {				
				int [] spinDat = new int[192];
				// Lower right quadrant
				int pos = 0;
				for(int col=24;col<48;col=col+1) {
					for(int row=16;row<32;row=row+8) {				
						int da = 0;
						da = da | ((i[(row+0)*grid.width+col]&1)<<0);
						da = da | ((i[(row+1)*grid.width+col]&1)<<1);
						da = da | ((i[(row+2)*grid.width+col]&1)<<2);
						da = da | ((i[(row+3)*grid.width+col]&1)<<3);
						da = da | ((i[(row+4)*grid.width+col]&1)<<4);
						da = da | ((i[(row+5)*grid.width+col]&1)<<5);
						da = da | ((i[(row+6)*grid.width+col]&1)<<6);
						da = da | ((i[(row+7)*grid.width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}
				// Lower left quadrant
				for(int col=0;col<24;col=col+1) {
					for(int row=16;row<32;row=row+8) {				
						int da = 0;
						da = da | ((i[(row+0)*grid.width+col]&1)<<0);
						da = da | ((i[(row+1)*grid.width+col]&1)<<1);
						da = da | ((i[(row+2)*grid.width+col]&1)<<2);
						da = da | ((i[(row+3)*grid.width+col]&1)<<3);
						da = da | ((i[(row+4)*grid.width+col]&1)<<4);
						da = da | ((i[(row+5)*grid.width+col]&1)<<5);
						da = da | ((i[(row+6)*grid.width+col]&1)<<6);
						da = da | ((i[(row+7)*grid.width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}
				// Upper right quadrant
				for(int col=47;col>=24;col=col-1) {
					for(int row=15;row>0;row=row-8) {				
						int da = 0;
						da = da | ((i[(row-0)*grid.width+col]&1)<<0);
						da = da | ((i[(row-1)*grid.width+col]&1)<<1);
						da = da | ((i[(row-2)*grid.width+col]&1)<<2);
						da = da | ((i[(row-3)*grid.width+col]&1)<<3);
						da = da | ((i[(row-4)*grid.width+col]&1)<<4);
						da = da | ((i[(row-5)*grid.width+col]&1)<<5);
						da = da | ((i[(row-6)*grid.width+col]&1)<<6);
						da = da | ((i[(row-7)*grid.width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}
				// Upper left quadrant
				for(int col=23;col>=0;col=col-1) {
					for(int row=15;row>0;row=row-8) {				
						int da = 0;
						da = da | ((i[(row-0)*grid.width+col]&1)<<0);
						da = da | ((i[(row-1)*grid.width+col]&1)<<1);
						da = da | ((i[(row-2)*grid.width+col]&1)<<2);
						da = da | ((i[(row-3)*grid.width+col]&1)<<3);
						da = da | ((i[(row-4)*grid.width+col]&1)<<4);
						da = da | ((i[(row-5)*grid.width+col]&1)<<5);
						da = da | ((i[(row-6)*grid.width+col]&1)<<6);
						da = da | ((i[(row-7)*grid.width+col]&1)<<7);
						spinDat[pos++] = da;
					}
				}

				for(int zz=0;zz<spinDat.length;++zz) {
					pss.print(spinDat[zz]);
					if(zz!=(spinDat.length-1)) {
						pss.print(",");
					}				
				}
				pss.print("\r\n\r\n");
			}
			
		}		
		pss.print("CLUSTER clus"+nc+"\r\n");
		pss.print("GOTO clus0:\r\n");
		
		pss.flush();
		pss.close();
		
	}
	
	private void saveFile(List<byte[]> data,List<Integer> pauses) throws IOException
	{
		OutputStream os = new FileOutputStream(filename);
		PrintStream ps = new PrintStream(os);

		for(int z=0;z<data.size();++z) {
			byte [] i = data.get(z);						
			if(i[0]==-1) {
				ps.print("#####\r\n");
				String t = new String(i,1,i.length-1);
				for(int x=0;x<t.length();++x) {
					char cc = t.charAt(x);
					if(cc=='\n') {
						ps.print("\r");
					}
					ps.print(cc);
				}				
				ps.print("\r\n#####");
			} else {
				ps.print("%"+pauses.get(z)+"\r\n");
				for(int y=0;y<grid.height;++y) {
					for(int x=0;x<grid.width;++x) {
						if( (i[y*grid.width+x]&1)==1 ) {
							ps.print("O");
						} else {
							ps.print(".");
						}
					}
					ps.print("\r\n");
				}		
			}
			if(z!=(data.size()-1)) {
				ps.print("\r\n");
			}
			
		}
		ps.flush();
		ps.close();
		
		saveSpin(data,pauses);
		saveBinary(data,pauses);
				
	}
	
}

