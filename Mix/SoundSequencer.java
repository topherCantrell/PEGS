
import java.util.*;

class SequencerEvent
{    
    double startTime = -1.0;
    int voice = 0;
    Object eventData = null;
}

public class SoundSequencer
{
    
    int lastOctave = 4;
    double lastLength = 1.0;
    double tieLength = 0.0; 
    
    int myVoice;
    
    int termNumber = 0;
    
    double staccatoValue = 0.80;
    boolean staccatoIsPercent = true;
    
    double currentTime = 0.0;
    
    int repeatToIndex = -1; 
    double repeatTo = -1.0;
    
    /*
    SoundCOGCommand noteOn = new SoundCOGCommand(new CodeLine(0,"",""),null);
    SoundCOGCommand noteOff = new SoundCOGCommand(new CodeLine(0,"",""),null);
    SoundCOGCommand orgNoteOff;
    */
    
    List<SequencerEvent> events = new ArrayList<SequencerEvent>();
    
    double tempo = 15.0;  // Whole-notes per minute
    
    public static double midiFrequency(int midiNote)
    {
        // A4 (our notation) is A440 on the piano (MIDI note #69)      
        double n = midiNote - 69; // Integral offset from A4
        n = n / 12.0;
        n = Math.pow(2.0,n) * 440.0;        
        //System.out.println(" midinote="+midiNote+" freq="+n);
        return n;
    }
    
    public SoundSequencer(int voice)
    {
        myVoice = voice;
        /*
        noteOff.type = 0; // Sound command 
        noteOn.type = 0;  // Sound command
        orgNoteOff = noteOff; // This is the original (default) off
        */
    }
    
    void finalPause()
    {
        SequencerEvent ev = new SequencerEvent();
        ev.startTime = currentTime;
        events.add(ev);        
    }
    
    String parseSequenceTerm(String term)
    {
        ++termNumber;
        //System.out.println("::::"+termNumber+"::"+term+"::::");          
        
        // Pause ... just advance the currentTime
        if(term.startsWith("PAUSE ")) {            
            term = term.substring(6);
            try {
                double i = Double.parseDouble(term);
                i = i / 1000.0;
                currentTime = currentTime + i;
                return null;
            } catch (Exception e) {
                return "Invalid pause value '"+term+"'";
            }                        
        }
        
        // RepeatToHere ... remember where we are in time
        if(term.equals("REPEATTOHERE")) {
            if(repeatTo>=0.0) {
                return "Only one RepeatToHere allowed per voice.";
            }
            repeatTo = currentTime;
            repeatToIndex = events.size();
            return null;
        }
        
        // Staccato<...> ... either percent or time
        if(term.startsWith("STACCATO ")) {            
            term = term.substring(9).trim();
            if(term.endsWith("%")) {
                try {
                    staccatoValue = Double.parseDouble(term.substring(0,term.length()-1));
                    if(staccatoValue<0 || staccatoValue>100) {
                        return "Staccato percentage must be between 0 and 100.";
                    }
                    staccatoValue = staccatoValue/100.0;
                    staccatoIsPercent = true;
                    return null; 
                } catch (Exception e) {
                    return "Invalid staccato percentage '"+term+"'";
                }
            }
            if(!term.endsWith("MS")) {
                return "Staccato value must end with '%' or 'MS'.";
            }
            term = term.substring(0,term.length()-2);
            try {
                staccatoValue = Double.parseDouble(term);
                if(staccatoValue<0 || staccatoValue>100) {
                    return "Staccato time must be greater than 0.";
                }
                staccatoValue = staccatoValue/1000.0;
                staccatoIsPercent = false;
                return null; 
            } catch (Exception e) {
                return "Invalid staccato time '"+term+"'";
            }                       
        }
        
        if(term.startsWith("TEMPO ")) {            
            term = term.substring(6).trim();            
            try {
                tempo = Double.parseDouble(term);
                if(tempo<=0) {
                    return "Invalid tempoo '"+term+"'";
                }                
            } catch (Exception e) {
                return "Invalid tempo '"+term+"'";
            }
            return null;
        }
        
        // VARINC rr
        // VARDEC rr
        
        if(term.startsWith("VARSET ")) { // VARSET r,v
        	
        	//  0_100_rrrr_vvvvvvvv              ' Set variable R to V 
        	
        	SequencerEvent ev = new SequencerEvent();
            ev.startTime = currentTime;
            List<Integer> regs = new ArrayList<Integer>();
            ev.eventData = regs;
        	term = term.substring(7).trim();            
            ArgumentList aList = new ArgumentList(term,null); 
            
            Argument a = aList.removeArgument("REG ",0);
            if(a==null) {
            	return "Missing REG value. Must be 0-15.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>15) {
                return "Invalid REG value '"+a.value+"'. Must be 0-15.";
            }
            int rr = 0x40 | (int)a.longValue;            
            
            a = aList.removeArgument("VALUE ",1);
            if(a==null) {
            	return "Missing VALUE value. Must be 0-255.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                return "Invalid VALUE value '"+a.value+"'. Must be 0-255.";
            }
            regs.add(new Integer((int)a.longValue));
            regs.add(rr);
                       
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            events.add(ev);
            return null; 
        	
        }
        
        if(term.startsWith("REGISTER ")) {
        	SequencerEvent ev = new SequencerEvent();
            ev.startTime = currentTime;
            List<Integer> regs = new ArrayList<Integer>();
            ev.eventData = regs;
        	term = term.substring(9).trim();            
            ArgumentList aList = new ArgumentList(term,null); 
            Argument a = aList.removeArgument("CHIP",0);
            if(a==null) {
            	return "Missing CHIP value. Must be 0 or 1.";
            }            
            if(!a.longValueOK || a.longValue<0 || a.longValue>1) {
                return "Invalid CHIP value '"+a.value+"'. Must be 0 or 1.";
            }
            regs.add(new Integer((int)a.longValue));
            
            a = aList.removeArgument("REG ",1);
            if(a==null) {
            	return "Missing REG value. Must be 0-15.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>15) {
                return "Invalid REG value '"+a.value+"'. Must be 0-15.";
            }
            regs.add(new Integer((int)a.longValue));
            
            a = aList.removeArgument("VALUE ",2);
            if(a==null) {
            	return "Missing VALUE value. Must be 0-255.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>255) {
                return "Invalid VALUE value '"+a.value+"'. Must be 0-255.";
            }
            regs.add(new Integer((int)a.longValue));
                       
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            events.add(ev);
            return null; 
        }
        
        /*
        if(term.startsWith("NOTESTARTSTYLE ")) {             
            SoundCOGCommand scc = new SoundCOGCommand(null,null);
            CodeLine co = new CodeLine(0,null,"SOUND "+term.substring(15));
            String er = SoundCOGParser.parseSound(co,scc);
            if(er==null) {
                return "Internal error";
            }
            if(er.length()>0) {
                return er;
            }      
            if(scc.freq!=0) {
                return "Frequency may not be given in a NoteStartStyle";
            }
            scc.channel = myVoice;
            noteOn = scc;
            return null;
        }
        
        if(term.startsWith("NOTESTOPSTYLE ")) {            
            SoundCOGCommand scc = new SoundCOGCommand(null,null);
            CodeLine co = new CodeLine(0,null,"SOUND "+term.substring(14));
            String er = SoundCOGParser.parseSound(co,scc);
            if(er==null) {
                return "Internal error";
            }
            if(er.length()>0) {
                return er;
            }      
            if(scc.freq!=0) {
                return "Frequency may not be given in a NoteStopStyle";
            }
            scc.channel = myVoice;
            noteOff = scc;
            return null;
        }        
        
        // Sound ... parse a regular sound event
        if(term.startsWith("SOUND ")) {                        
            SoundCOGCommand scc = new SoundCOGCommand(null,null);
            CodeLine co = new CodeLine(0,null,term);            
            String er = SoundCOGParser.parseSound(co,scc);
            if(er==null) {
                return "Internal error";
            }
            if(er.length()>0) {
                return er;
            }      
            scc.channel = myVoice; // Whatever ... override it
            SequencerEvent ev = new SequencerEvent();
            ev.startTime = currentTime;
            ev.scc = scc;
            events.add(ev);
            return null;
        }
        */
        
        int i = 0;
        char cc = 0;
        // Get note length
        while(true) {
            if(i==term.length()) {
                return "Excpected an A,B,C,D,E,F,G, or R";
            }
            cc = term.charAt(i);
            if(cc=='R' || (cc>='A' && cc<='G')) break;
            ++i;
        }
        if(cc=='D') { // It is a 'double' note length if another note name follows
            if((i+1)<term.length()) {
                if(term.charAt(i+1)=='R' || (term.charAt(i+1)>='A' && term.charAt(i+1)<='G')) {                    
                    ++i;
                    cc = term.charAt(i);
                }
            }
        }
        String noteLengthS = term.substring(0,i);        
        
        double noteLength = lastLength;
        if(i>0) {
            int j = 0;
            while(j!=noteLengthS.length()) {
                if(noteLengthS.charAt(j)<'0' || noteLengthS.charAt(j)>'9') {
                    break;
                }      
                ++j;
            }
            if(j==0) {
                return "Invalid note length '"+noteLengthS+"'";
            }
            noteLength = 1.0 / Double.parseDouble(noteLengthS.substring(0,j));
            if(j!=noteLengthS.length()) {
                if(noteLengthS.charAt(j)=='.') {
                    // Only single dots for now
                    noteLength = noteLength + noteLength/2.0;
                    ++j;
                }
            }
            if(j!=noteLengthS.length()) {
                if(noteLengthS.charAt(j)=='T') {
                    noteLength = noteLength*2.0/3.0;
                    ++j;
                } else if(noteLengthS.charAt(j)=='D') {
                    noteLength = noteLength*3.0/2.0;
                    ++j;
                }
            }
            
            if(j!=noteLengthS.length()) {
                return "Extra characters in note length '"+noteLengthS+"'";
            }
            
        }
        
        // Note value (key of C)
        int noteVal = 0;
        switch(cc) {
            case 'C': noteVal = -9; break;                
            case 'D': noteVal = -7; break;
            case 'E': noteVal = -5; break;
            case 'F': noteVal = -4; break;
            case 'G': noteVal = -2; break;
            case 'A': noteVal = 0; break;
            case 'B': noteVal = 2; break;
        }    
        
        ++i;
        
        // Get absolute octave (or use last)        
        int noteOctave = lastOctave;
        
        if(cc!='R') { // Only notes have accidentals and octaves
            
            // Absolute octave
            if(i!=term.length()) {
                if(term.charAt(i)>='0' && term.charAt(i)<='9') {
                    noteOctave = term.charAt(i)-'0';
                    ++i;
                }
            }
            
            // Octave offsets
            while(i!=term.length()) {
                if(term.charAt(i)=='+') {
                    ++noteOctave;
                } else if(term.charAt(i)=='-') {
                    --noteOctave;
                } else {
                    break;
                }
                ++i;
            }
            
            // Accidentals
            while(i!=term.length()) {
                if(term.charAt(i)=='#') {
                    ++noteVal;
                } else if(term.charAt(i)=='B') {
                    --noteVal;
                } else {
                    break;
                }
                ++i;
            }
            
        }
        
        // Tie
        boolean tie = false;
        if(i!=term.length()) {
            if(term.charAt(i)=='_') {
                tie = true;
                ++i;
            }
        }
        
        // Make sure that's all
        if(i!=term.length()) {
            return "Extra note characters '"+term.substring(i)+"'";
        }
        
        // Remember length and octave for next note if not specified
        lastLength = noteLength;
        lastOctave = noteOctave;
        
        // Note length now in seconds
        noteLength = noteLength * 60.0/tempo;        
        
        // Actual midi note number
        if(cc!='R') {
            noteVal += noteOctave*12+21;  // A4+21 = 4*12+21 = 69 (MIDI #) 
            if(noteVal<0 || noteVal>127) {
                return "Invalid note number '"+noteVal+"'";
            }
        }
        
        // If we are tieing to the next note, just remember the length
        // and move on.
        if(tie) {
            tieLength += noteLength;
            return null;
        }
        
        // Here is what we have ...        
        // noteLength   -- in seconds        
        // noteVal      -- midi note number or -1 for rest   
        // tieLength    -- amount of tie from last note(s) in seconds
        
        //System.out.println(":"+noteVal);
                
        double totalTime = noteLength+tieLength;
        tieLength = 0.0;
        
        if(cc!='R') { // Rests just advance the time
            // Find where note's sound ends (maybe some silence a little after)
            double onTime = totalTime;            
            if(staccatoIsPercent) {
                // Staccato percent only applies to the current noteLength and
                // not the tieLength coming in.
                onTime = onTime - noteLength*(1.0-staccatoValue);
            } else {
                if(staccatoValue < onTime) {
                    onTime = onTime - staccatoValue;
                }
            }
            
            /*
            SoundCOGCommand son = null;
            SoundCOGCommand soff = null;            
            try {            
                // Duplicate the note on/off styles
                son = (SoundCOGCommand)noteOn.clone();
                soff = (SoundCOGCommand)noteOff.clone();
            } catch (CloneNotSupportedException cnse) {
                cnse.printStackTrace();
            }            
            son.setCodeLine(new CodeLine(0,null,"Number "+termNumber+" term in sequence '"+term+"'"));            
              
            // Set this note's frequency
            //System.out.println(":: "+son.F+" "+son.V+" "+son.S+" "+son.N+" "+son.cycles);
            son.freq = (int)Math.round(SoundCOGParser.getM(son.F,son.V,son.S,son.N,son.cycles,
            midiFrequency(noteVal)));
            
            if(noteOff == orgNoteOff) {
                // If we are using the original simple note-off style, set
                // the freq to 0 to make a short-command for OFF.
                soff.freq = 0;
            } else {
                // If the user has given a note-off style, set the freq to
                // the note freq so the sweeper can run it off. This won't
                // be a short-command anyway.
                soff.freq = son.freq;
            }  
                        
            // Override the voice
            soff.channel = myVoice; // Whatever ... override it
            son.channel = myVoice; // Whatever ... override it
            
            // Note on event at the current time
            SequencerEvent ev = new SequencerEvent();
            ev.startTime = currentTime;
            ev.scc = son;
            events.add(ev);            
            
            // Note off at the right time in the future
            ev = new SequencerEvent();
            ev.startTime = currentTime+onTime;
            ev.scc = soff;
            events.add(ev);
            */
            
            if(myVoice==6) {
            	return "VOICE7 is reserved for non-voice commands.";
            }
            
            // Note on
            SequencerEvent ev = new SequencerEvent();
            ev.startTime = currentTime;            
            ev.eventData = new Integer(noteVal);            
            ev.voice = myVoice;
            events.add(ev);
            
            // Note off
            ev = new SequencerEvent();
            ev.startTime = currentTime+onTime;
            ev.eventData = new Integer(0);
            ev.voice = myVoice;
            events.add(ev);
            
            //System.out.println("AT "+currentTime+" NOTE ON:"+noteVal+"="+midiFrequency(noteVal)+":"+noteLength);
            //System.out.println("PAUSE :"+onTime);
            //System.out.println("AT "+(currentTime+onTime)+" NOTE OFF");
        }
        
        // Advance time past note (or rest) duration
        currentTime = currentTime + totalTime;    
        return null;       
        
    }  
    
}
