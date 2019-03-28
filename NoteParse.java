import java.util.*;

 

class Note 

{

    int voice;
    double startTime;
    int codeDelay;
	String note;
    
    Note(int voice, double startTime, int codeDelay, String note) {
        this.voice = voice;
        this.startTime = startTime;
        this.codeDelay = codeDelay;
    }  

    public String toString()
    {
	    return startTime+":"+voice+":"+codeDelay+":"+note;
    } 

}

public class NoteParse
{    

    public static NoteTable noteTable = new NoteTable(176,8);
	
    public static void main(String [] args) throws Exception
    {   
	
        String m1 = "%tempo280 %staccato80 "+
"1D5_ | 1D5 | 4r 8F4 8F4 4G4 4G4# | 4A4 4B4b 4C5 4D5 | 1D5#_  | 1D5# | "+
"4r 8F4# 8F4# 4G4# 4A4 | 4B4b 4B4 4C5# 4D5# | 1E5_ | 1E5 | "+
"1E5 | 2C5 2E5 | 2.G5 4F5# | 2.F5 4E5 | 4D5 4C5 4B4 4A4 | 4G4 4r 2G4 | "+
"%%letterA 2E5 4.C5 8G4 4A4 2.G4 4r 2C5 4A4 "+
"1C5 4B4 4B4 4A4 4G4 4B4 4B4 4A4 4G4 4r 2G4 4E4 1G4 2B4b 4.A4 8E4 4G4 "+
"2.A4 4r 2F4 4G4 2A4 2A4 4D4 4E4 4F4# 4D4 4E4 4F4# 4E4 4D4 4B4 2B4 4A4 "+
"4.G4 8A4 4B4 4G4 2E5 4.C5 8G4 4A4 2.G4 4r 2C5 4A4 2.C5 4A4 4B4 4B4 4A4 "+
"4G4 4B4 4B4 4C5 4D5 4E5 4E5 4E5 4D5# 1D5 4A4 2C5# 4A4 2E5 2A4 1F5 2.E5 "+
"4E5 4A4 2A4 4B4 4C5 2C5 4D5 1E5 4D5 4r 2G5 2E5 4.C5 8G4 4A4 2.G4 4r 2C5 "+
"4A4 2.C5 4A4 4B4 4B4 4A4 4G4 2B4 4C5 4D5 2C5 2D5 2F5 2A5 1C6_ 4C6 4r 2r";

String m2 = "%tempo280 %staccato80 "+
"1B4b_ | 1B4b | 4r 8D4 8D4 4D4# 4E4 | 4F4 4G4 4A4 4B4b | 1B4_ | 1B4 | "+
"4r 8D4# 8D4# 4E4 4F4 | 4F4# 4G4# 4B4b 4B4 | 1C5_ | 1C5  | "+
"1C5 | 2A4 2C5 | 2.G5 4F5# | 2.F5 4E5 | 4D5 4C5 4B4 4A4 | 4G4 4r 2G4 | "+
"%%letterA 2C5 4.G4 8E4 4F4 2.E4 "+
"4r 2F4# 4F4# 1F4# 4F4 4F4 4F4 4F4 4F4 4F4 4F4 4F4 4r 2E4 4E4 1E4 2F4# "+
"4.G4 8G4 4G4 2.G4 4r 2D4 4E4 2F4 2G4 4D4 4E4 4F4# 4D4 4E4 4F4# 4E4 4D4 "+
"4B4 2B4 4A4 4.G4 8A4 4B4 4G4 2C5 4.G4 8E4 4F4 2.E4 4r 2F4# 4F4# 2.F4# "+
"4F4# 4F4 4F4 4F4 4F4 4F4 4F4 4F4 4A4 4G4# 4G4# 4A4 4B4b 1B4 4A4 2C5# "+
"4A4 2E5 2A4 1F5 2.E5 4E5 4A4 2A4 4B4 4A4 2A4 4A4 1A4 4G4 4r 2D5 2C5 "+
"4.G4 8E4 4F4 2.E4 4r 2F4# 4F4# 2.F4# 4F4# 4F4 4F4 4F4 4F4 2F4 4A4 4A4 "+
"2G4 2A4 2D5 2F5 1E5_ 4E5 4r 2r";

String m3 = "%tempo280 %staccato80 "+
"2D4 4.B3b 8F3 4G3 2.F3_ 1F3 4F3 4G3 4A3 4B3b 2D4# "+
"4.B3 8F3# 4G3# 2.F3#_ 1F3# 4F3# 4G3# 4B3b 4B3 2E4 4.C4 8G3 4A3 "+
"2.G3 1D4 2D4 2D4 2.G3 4A3 2.B3 4C4 4D4 4E4 4F4 4F4# 4G4 4r 2G3 4C4 4r "+
"4G3 4r 4C4 4r 4E4 4D4# 4D4 4r 4A3 4r 4D4 4C4 4B3 4A3 4G3 4r 4D3 4r 4G3 "+
"4r 4D3 4r 4C3 4r 4G3 4r 2C4 2B3b 4A3 4r 4E3 4r 4A3 4r 4E3 4A3 4D3 4r "+
"4A3 4r 4D3 4r 2A3 4D3 4r 4D3 4r 4D3 4r 4D3 4r 4G3 4r 4G3 4r 4G3 4G3 4A3 "+ 
"4B3 4C4 4r 4G3 4r 4C4 4r 4E4 4D4# 4D4 4r 4A3 4r 4D4 4C4 4B3 4A3 4G3 4r "+
"4G3 4r 4F3 4r 4F3 4r 4E3 4r 4F3# 4G3 4G3# 4E3 4F3# 4G3 4A3 4r 4G3 4r "+
"4D3 4r 4E3 4r 4B3b 4r 4B3b 4r 4A3 4r 4A3 4r 4A3 4r 4A3 4r 4A3 4r 4A3 "+
"4r 4D2 4E2 4F3 4F3# 4G3 4r 2G3 4C4 4r 4G3 4r 4C4 4r 4E4 4D4# 4D4 4r "+
"4A3 4r 4D4 4C4 4B3 4A3 4G3 4r 4D3 4r 4G3 4r 4D3 4G3 2G3 2G3 2G3 2G3 "+
"1C4_ 4C4 4r 2r";


        ArrayList<Note> notes1 = new ArrayList<Note>();
        System.out.println(parse(m1,0,notes1)); 
		ArrayList<Note> notes2 = new ArrayList<Note>();
        System.out.println(parse(m2,1,notes2));
		ArrayList<Note> notes3 = new ArrayList<Note>();
        System.out.println(parse(m3,2,notes3));
		
		merge(notes1,notes2);
		merge(notes1,notes3);
				
        System.out.println(sequence(notes1));
    }

    public static String merge(List<Note> notesA, List<Note> notesB)
    {       
		 
		 for(int x=0;x<notesB.size();++x) {
		   notesA.add(notesB.get(x));
		 }
		 
		 boolean changed = true;
		 while(changed) {
		   changed = false;
		   for(int x=0;x<notesA.size()-1;++x) {
		     Note na = notesA.get(x);
			 Note nb = notesA.get(x+1);
			 if(nb.startTime < na.startTime) {
			   notesA.set(x,nb);
			   notesA.set(x+1,na);
			   changed = true;
			 }
		   }
 	    }
	
        return "";
    }
    
    public static String sequence(List<Note> notes)
    {
	/*
	    for(int x=0;x<notes.size();++x) {
		  System.out.println(notes.get(x));
		}
*/
	
	
	    double tickMult = 1.0/noteTable.tickTime;
        double totalTime = 0.0;
		double lastTime = 0.0;
		
        for(int x=0;x<notes.size();++x) {
            Note n = notes.get(x);
			int vn = (8 + n.voice)<<12;            
			double delta = n.startTime - lastTime;
			totalTime += delta;			
			lastTime = n.startTime;
            int musicDelay = (int)Math.round(delta*tickMult);
			if(musicDelay>0) {
                System.out.println("word $"+Integer.toString(musicDelay,16)+" ' PAUSE "+musicDelay);			
            }

            if(n.codeDelay>=0) {                
                System.out.println("  word   $"+Integer.toString(vn,16)+"+"+n.codeDelay+" ' Voice "+n.voice+" ON  "+n.codeDelay);
            } else {
                System.out.println("    word $"+Integer.toString(vn,16)+" ' Voice "+n.voice+" OFF");
            }
        }

        System.out.println("' Total time (seconds): "+totalTime);
		
        return "";
    }

    public static String parse(String mus, int voice, List<Note> notes)
    {
     
        String lastLength = "32";  // Keep up with last note length
        char lastOctave = '4';     // Keep up with last note octave
        int measure = 1;           // Count measures for error messages
        double staccato = 0.90;    // Percent of note "on" in length
        double tempo = 4.0;        // Seconds per whole-note
        
        double nextDelay = 0.0;    // Where we are in time
        double runningTie = 0.0;   // Multiple running tied notes
		double absoluteTime = 0.0;
        
        StringTokenizer st = new StringTokenizer(mus," ");        
        while(st.hasMoreTokens()) {
            
            // Count measures
            String m = st.nextToken();
            String org = m;
            if(m.equals("|")) {
                ++measure;
                continue;
            }           
            
            if(m.startsWith("%%")) {
                // Comment ... ignore
				System.out.println("' "+m+" on measure "+measure);				
                continue;
            }
            
            if(m.startsWith("%staccato")) {
                m=m.substring(9);
                staccato = Double.parseDouble(m)/100.0;
                continue;
            }
            
            if(m.startsWith("%tempo")) {
                m=m.substring(6);
                tempo = Double.parseDouble(m)/4; // Wholes/min
                tempo = tempo/60.0; // Wholes/sec
                tempo = 1.0/tempo; // seconds/whole
                continue;
            }
            
            // Skip over numbers, dots, and T (duration characters)
            int p = 0;
            while(p<m.length()) {
                char c = m.charAt(p++);
                if(c>='0' && c<='9') continue;
                if(c=='.') continue;
                if(c=='T') continue;
                break;
            }
            --p;            
                        
            // If we didn't specify a length, use the last length
            // Otherwise change the last length
            String len = m.substring(0,p);
            if(len.length()==0) len=lastLength;
            else lastLength = len;
            
            // Strip off the length
            m = m.substring(p);
            
            // Parse length modifiers T (tripplet) and dot.
            boolean tripplet = false;
            boolean dotted = false;            
            if(len.endsWith("T")) {
                tripplet = true;
                len = len.substring(0,len.length()-1);
            }
            if(len.endsWith(".")) {
                dotted = true;
                len = len.substring(0,len.length()-1);
            }       
            
            // Calculate the length (in whole-notes) of the note
            double nl = 1.0 / Double.parseDouble(len);            
            if(dotted) {
                nl = nl + nl/2.0;
            }
            if(tripplet) {
                nl = nl * 2.0 / 3.0;
            } 
            
            // Convert wholes to seconds
            nl = nl * tempo;
            
            // Check for tie flag
            boolean tie = false;
            if(m.endsWith("_")) {
                tie = true;
                m = m.substring(0,m.length()-1);
            }             
            
            // Make sure note has valid name (no defaults here)
            char c = m.charAt(0);
            if(! ((c>='A' && c<='G') || c=='r' || c=='R')) {
                return "Measure "+measure+":Invalid note in '"+org+"'";
            }
            m = m.substring(1);                       
            
            // Parse the absolute octave (or use the last octave)
            char o = ' ';
            if(m.length()>0) {
                o = m.charAt(0);
            }             
            if(o>='0' && o<='9') {                
                m = m.substring(1);
            } else {
                o = lastOctave;
            }
            
            // Parse relative octaves
            while(m.length()>0 && m.charAt(0)=='+') {
                ++o;
                m=m.substring(1);
            }
            while(m.length()>0 && m.charAt(0)=='-') {
                --o;
                m=m.substring(1);
            }
            
            // Rests just advance the nextDelay. Notes are added
            // to the list as "on note" and "off note" pairs.
            if(c!='r' && c!='R') {
                lastOctave = o;
                if(tie) {
                    runningTie += nl;                    
                    continue;
                }                
                int del = noteTable.getCodeDelay(""+c+""+o+""+m);
				absoluteTime += nextDelay;
                Note nn = new Note(voice,absoluteTime,del,org);                
                notes.add(nn);
				absoluteTime += runningTie+nl*staccato;
                nn = new Note(voice,absoluteTime,-1,org);
                notes.add(nn);
                nextDelay = nl*(1.0-staccato);
                runningTie = 0;
            } else {
                nextDelay = nextDelay + nl;
            }                  
            
        }
        
        if(nextDelay>0) {
            Note nn = new Note(voice,absoluteTime+nextDelay,-1,"END");
            notes.add(nn);
        }
        
        return "";
        
    }
    
}
