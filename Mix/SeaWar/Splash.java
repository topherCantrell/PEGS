import java.util.ArrayList;
import java.util.Random;

class Segment 
{
	int x;
	int ship;
	int direction;
	int speed;
	int flipCount;
	int sequenceCount;
	boolean shipUpdated;
	int startDirection;
	
	Random rand = new Random();
	
	ArrayList<String> data = new ArrayList<String>();
	
	Segment(int direct)
	{
		// Random ship (0-4)	
		ship = rand.nextInt(5);
		shipUpdated = true;
		
		// Random direction (0 or 1) and set x (286, 0)
		//direction = rand.nextInt(2);
		direction = direct;
		startDirection = direction;
		if(direction==0) {			
			x = 286;
		} else {
			x = 0;
		}
		
		// Random speed (0,1,2 ... slow, medium, fast)
		speed = rand.nextInt(3);
	}
	
}

public class Splash {
	
	static int [] shipsRight = {314,346,378,394,410};
	static int [] shipsLeft =  {330,362,386,402,418};
	static int [] widths = {32,32,16,16,16};
	static int [] delays = {1,2,2,3,3};	
	static int [] speedXDelta = {1,1,2};
	static int [] speedXDelay = {2,1,1};
	
	static int [] initDirect = {1,0,1,1,0};	
	
	static int [] MIN_RUN_LENGTH     = {32,40,60};
	static int [] MAX_RUN_LENGTH     = {40,80,120};	
	static int MIN_RUNS_PER_SCRIPT   = 3;
	static int MAX_RUNS_PER_SCRIPT   = 8;
	static int MAX_FLIP_COUNT        = 2;	
	static int SCRIPTS_PER_SEQUENCE  = 8;	
	static int MIN_DELAY             = 20;
	static int MAX_DELAY             = 60;
	
	
	/**
	 * A "run" is a constant line of motion on the given segment.
	 * @param s the segment to make a run on
	 * @param b 
	 * @return true if the segment runs completely off the screen
	 */
	static boolean makeRun(Segment s, boolean b)
	{
		boolean ret = false;
		int xDelta = Splash.speedXDelta[s.speed];
		int xDelay = Splash.speedXDelay[s.speed];
		if(s.direction==0) {
			xDelta = -xDelta;
		}
		int count = s.rand.nextInt(MAX_RUN_LENGTH[s.speed]-MIN_RUN_LENGTH[s.speed]) + MIN_RUN_LENGTH[s.speed];
		count = count >> 1;
		count = count << 1;
		if(b) count = 286;
		if((s.x+count*xDelta)>=286) {
			count = (286-s.x)/xDelta;
			ret = true;
		}
		if((s.x+count*xDelta)<=0) {
			count = s.x/(-xDelta);
			ret = true;
		}
		
		String data = "count="+count+", deltaX="+xDelta+", delayX="+xDelay;
		if(s.shipUpdated) {
			int sn = shipsRight[s.ship];
			if(s.direction == 0) {
				sn = shipsLeft[s.ship];
			}
			data = data +", width="+widths[s.ship]+", height=8, image="+sn+", numPics=2, flipDelay="+delays[s.ship];
			s.shipUpdated = false;
		}
		s.data.add(data);
		
		s.x = s.x + count*xDelta;
		if(s.x<0 || s.x>286) {
			throw new RuntimeException("X out of range:"+s.x);
		}
		if(ret && (s.x!=0 && s.x!=286)) {
			throw new RuntimeException("Ending sequence but not on edge:"+s.x);
		}
		return ret;
	}
	
	static void printSeguence(Segment s) {
		for(String g : s.data)
		{
			System.out.print(g+"\r\n");
		}
	}

	/**
	 * A "script" is a sequence of runs that takes the current segment
	 * on and back off the screen.
	 * @param s the segment to script
	 */
	static void makeScript(Segment s)
	{
		int nrs = s.rand.nextInt((MAX_RUNS_PER_SCRIPT-MIN_RUNS_PER_SCRIPT))+MIN_RUNS_PER_SCRIPT;
		for(int nr=0;nr<nrs;++nr) {
			// Make a run
		    boolean r = makeRun(s,false);
		    if(r) return;
		    
		    // Now one of the following can happen on the segment:
		    // 1) Slow down (one or two steps)
		    // 2) Speed up (one or two steps)
		    // 3) Flip directions (slow to a stop, flip, then speed up one to three steps
		    
		    int action = 0;
		    while(true) {
		    	action = s.rand.nextInt(3);
		    	if(action==0) { // Slow down
		    		if(s.speed>0) break; // We can
		    	} else if(action==1) { // Speed up
		    		if(s.speed<2) break; // We can		    		
		    	} else { // Flip directions
		    		if(s.flipCount<MAX_FLIP_COUNT) break; // We can		    		
		    	}		    	
		    }
		    		    
		    int numSteps = s.rand.nextInt(2)+1;  // One step or two
		    if(s.speed==1) numSteps = 1;         // Limit to all we can do
		    
		    switch(action) {
		    case 0:
		    	s.data.add("// Slow down from "+s.speed+" to "+(s.speed-numSteps));
		    	s.speed = s.speed - numSteps;
		    	break;
		    case 1:
		    	s.data.add("// Speed up from "+s.speed+" to "+(s.speed+numSteps));
		    	s.speed = s.speed + numSteps;
		    	break;
		    case 2:
		    	// Flips are rare.		    	
		    	if(s.rand.nextInt(2)==0 && s.x>96 && s.x<224) {
			    	s.data.add("// Flip direction from "+s.direction);
			    	if(s.direction==0) {
			    		s.direction = 1;
			    		s.shipUpdated = true;
			    	} else {
			    		s.direction = 0;
			    		s.shipUpdated = true;
			    	}
		    	}
		    	break;
		    }
		    
		}	
		// If we ended on the screen then just continue off (even if we
		// are moving slowly).
		s.data.add("// Continuing off the screen");
		makeRun(s,true);		
	}
	
	public static void main(String [] args) 
	{
		
		for(int x=0;x<5;++x) {
			System.out.print((char)('a'+x)+"Script:\r\n");
			System.out.print("ActionScript {\r\n");
			doOne(initDirect[x]);
			System.out.print("}\r\n\r\n");
		}
	
	}
	
	public static void doOne(int direct) {	
		
		// Start with a random ship, direction, speed
		Segment s = new Segment(direct);
		if(s.direction==0) {
			s.data.add("// sequence starts at x=286");
		} else {
			s.data.add("// sequence starts at x=0");
		}

		int x = 0;
		while(x<SCRIPTS_PER_SEQUENCE || s.direction!=s.startDirection) {
			
		    // On and off screen
			makeScript(s);
		    
			// Delay
		    int delay = s.rand.nextInt(MAX_DELAY-MIN_DELAY)+MIN_DELAY;
		    delay = delay / 2;
		    s.data.add("// Delay "+(delay*2));
		    if(s.x==0) {
		    	s.data.add("count=1, deltaX=-1, delayX="+delay);
		    	s.data.add("count=1, deltaX=1, delayX="+delay);
		    } else {
		    	s.data.add("count=1, deltaX=1, delayX="+delay);
		    	s.data.add("count=1, deltaX=-1, delayX="+delay);
		    }
		    
		    // Pick new ship
		    s.ship = s.rand.nextInt(5);
		    s.data.add("//");
		    s.data.add("// Changing ship to "+s.ship);
		    s.shipUpdated = true;
		    
		    // Flip direction
		    if(s.direction==0) {
		    	s.direction = 1;
		    } else {
		    	s.direction = 0;
		    }	
		    
		    s.data.add("// Starting run at x="+s.x);
		    
		    ++x;
		    
		}
		
		s.data.add("REPEAT");
						
		printSeguence(s);	

	}


}
