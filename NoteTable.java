
import java.util.*;

// tickTime is the time (in seconds) of one music tick.
// Thus a tickTime of 6.656E-4 = 0.0006656
// or 1502.4 ticks per second.

// A tempo of 120-quarters-per-minute is 120/60 = 2 quarters per second.
// A quarter gets 1502.4/2 = 751.2 ticks.

// Do the music with fractional ticks and round off at the end.

// A440 (A5) is note 69

public class NoteTable
{

    double [] theoreticalFrequency= new double[128];
	double [] actualFrequency = new double[128];
	int [] codeDelay = new int[128];
    String [] name = new String[128];
	
	int clocksPerLoop; // 208
	int loopsPerWave;  // 4
	double tickTime;
	
	public NoteTable(int clocksPerLoop, int loopsPerWave)
	{
	    this.clocksPerLoop = clocksPerLoop;
		this.loopsPerWave = loopsPerWave;
		
		tickTime = 80000000.0/clocksPerLoop; // Loops per second
        tickTime = tickTime / 256.0;         // 256 ticks per loop (cuts the frequency)
        tickTime = 1.0/tickTime;
		
		for(int x=0;x<128;++x) {
				
		    theoreticalFrequency[x] = (x-69.0)/12.0;
            theoreticalFrequency[x] = Math.pow(2,theoreticalFrequency[x])*440.0;

            double mm = 80000000.0/(clocksPerLoop*theoreticalFrequency[x]*loopsPerWave);
            codeDelay[x] = (int)(Math.round(mm));
			actualFrequency[x] = 80000000.0/(clocksPerLoop*codeDelay[x]*loopsPerWave);
			
		}
		
		String nnames = "CDEFGAB";
		int [] ndis = {2,2,1,2,2,2,1};
		int x = 0;
		int oct = 0;
		int nn = 0;
		while(x<128) {		  
		  name[x] = nnames.charAt(nn)+""+oct;		
          x=x+ndis[nn];
		  ++nn;
		  if(nn>6) {
		    nn=0;
			++oct;
		  }
		  
		}
 
	}
	
	public int getCodeDelay(String n)
	{	
	    for(int x=0;x<128;++x) {
		  if(name[x]!=null && n.startsWith(name[x])) {
		      int i = 2;
			  while(i<n.length()) {
			    if(n.charAt(i)=='#') {
				  ++x;
				} else if(n.charAt(i)=='b') {
				  --x;
				}
				++i;
			  }
			  return codeDelay[x];
		  }
		}
		return -1;
	}

public static void main(String [] args) throws Exception
{
NoteTable tab = new NoteTable(208,4);
System.out.println(tab.tickTime);
System.out.println(tab.getCodeDelay("G4#"));
}

}