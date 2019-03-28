package code;
import java.util.*;
import java.io.*;

public class SoundCOGCommand extends COGCommand implements Cloneable
{
    
    static boolean lastF=true;
    static boolean lastV=false;
    static boolean lastS=true;
    static boolean lastN=true;
    static int lastcycles = 16;   // 16 Cycle in the default wave
    
    static final int [] PROCESS_CLOCKS = { 
        176,
        272,
        192,
        288,
        224,
        320,
        240,
        336,
        224,
        320,
        240,
        336        
    };
    
    static final double CLOCK = 80000000.0;
    
    private static int getQ(boolean f, boolean v, boolean s, boolean n)
    {
        int a = 0;
        if(f) a=a|8;
        if(v) a=a|4;
        if(s) a=a|2;
        if(n) a=a|1;
        return PROCESS_CLOCKS[a];
    }
    
    public static double getSequencerPause(double time)
    {
        
        double pause = CLOCK / getQ(lastF,lastV,lastS,lastN);
        pause = pause * time / 256.0;
        //System.out.println("<>"+time+"<>"+pause);
        return pause;
        
        //System.out.println("<>"+time+"<>");
        // Sequencer delay values get shifted left 8 bits
        // (multiplied by 256)
        //return getM(lastF,lastV,lastS,lastN,lastcycles,1.0/time)/256.0;
    }
    
    public static double getSequencerTime(double pause)
    {
        return pause*getQ(lastF,lastV,lastS,lastN)*256.0 / CLOCK;
        //return 1.0/getFrequency(lastF,lastV,lastS,lastN,lastcycles,256*pause);
    }
    
    public static double getFrequency(double m)
    {
        return getFrequency(lastF,lastV,lastS,lastN,lastcycles,m);
    }
    
    public static double getFrequency(boolean f, boolean v, boolean s, boolean n, int cycles, double m)
    {
        double q = getQ(f,v,s,n);     
        double nn = 32/cycles;
        return CLOCK / (q * m * nn);        
    }
    
    public static double getM(double freq)
    {
        return getM(lastF,lastV,lastS,lastN,lastcycles,freq);
    }
    
    public static double getM(boolean f, boolean v, boolean s, boolean n, int cycles, double freq)
    {
        double q = getQ(f,v,s,n); 
        double nn = 32/cycles;
        double m = CLOCK / (q * freq * nn);
        return m;
    }
    
    public static double getEnvelopeM(double period)
    {
        return getEnvelopeM(lastF,lastV,lastS,lastN,lastcycles,period);
    }
    
    public static double getEnvelopeM(boolean f, boolean v, boolean s, boolean n, int cycles, double period)
    {
        period = 1.0/period; // Get frequency        
        period = getM(f,v,s,n,cycles,period);
        period = period / 64.0;  // This value gets multiplied by 16 (4 bits) by the COG
        return period;
    }
    
    public static double getEnvelopePeriod(double dur)
    {
        return getEnvelopePeriod(lastF,lastV,lastS,lastN,lastcycles,dur);       
    }
    
    public static double getEnvelopePeriod(boolean f, boolean v, boolean s, boolean n, int cycles, double dur)
    {
        dur = dur * 64.0;        
        dur = 1.0 / getFrequency(f,v,s,n,cycles,dur);
        return dur;        
    }
    
        
    
    // 0 SOUND CHAN, FREQ, [Volume, WAVE], [EDelta, EDuration, ELength, [ERepeat]]
    // 0 SOUND OFF    
    
    // 1 SEQUENCER ptr
    // 1 SEQUENCER OFF
    // 1 SEQUENCER n,ptr
    // 1 SEQUENCER n,OFF
    
    // 2 SOUNDCFG Noise, Sequencer, FrequencySweeper, VolumeSweeper
    
    // 3 WAVEFORM N, ptr
    
    int type=-1;
    int waveform=0;
    String label;
    boolean F=true;
    boolean V;
    boolean S=true;
    boolean N=true;
    int cycles = 16;
    int seqID = 0;
    
    int channel = 0;
    int freq = 0;
    boolean eGiven = false;
    int volume = 0;
    int eDelta = 0;
    int eDur = 0;
    int eLength = 0;
    boolean eRepeat = false;
    
    public Object clone() throws CloneNotSupportedException
    {        
        // All our data is simple ... shallow copy will suffice
        return super.clone();
    }
    
    public SoundCOGCommand(CodeLine line,Cluster clus) {
      super(line,clus);
      F = lastF;
      V = lastV;
      S = lastS;
      N = lastN;
      cycles = lastcycles;
    }     
    
    public int getSize() 
    {
        if(type == 0) return 8; // SOUND commands are long
        return 4; // Everything else is short
    }
    
    String lookupValue(String key, List<String> keys, List<String> values)
    {
        for(int x=0;x<keys.size();++x) {
            //System.out.println("::"+keys.get(x)+"="+values.get(x));
            if(keys.get(x).startsWith(key)) {
                String ret = values.get(x);
                keys.remove(x);
                values.remove(x);
                return ret;
            }
        }
        return null;
    }
    
    public String parseSound(CodeLine c) {
        if(codeLine==null) codeLine = c;
        String s = c.text;
        String ss = s.toUpperCase();  
        F = lastF; V = lastV; S = lastS; N = lastN; cycles=lastcycles;        
       
        // Skip the "SOUND" word
        StringTokenizer st = new StringTokenizer(ss.substring(6),",");        
        
        // Get name=value pairs
        List<String> sNames = new ArrayList<String>();
        List<String> sValues = new ArrayList<String>();
        while(st.hasMoreTokens()) {
            
            String g = st.nextToken().trim().toUpperCase();
            //System.out.println(">>"+g);
            int jj = g.indexOf("=");
            if(jj<0) {
                return "Expected 'name=value' and not '"+g+"'";
            }
            String a = g.substring(0,jj).trim();
            String b = g.substring(jj+1).trim();
            if(a.length()==0 || b.length()==0) {
                return "Expected 'name=value' and not '"+g+"'";
            }
            sNames.add(a);
            sValues.add(b);
        }
        
        String g = lookupValue("T",sNames,sValues);
        if(g!=null) {
            String a = g;
            F = false; V = false; S = false; N = false;
            for(int x=0;x<a.length();++x) {
                if(a.charAt(x)=='F') {
                    F = true;
                } else if(a.charAt(x)=='V') {
                    V = true;
                } else if(a.charAt(x)=='S') {
                    S = true;
                } else if(a.charAt(x)=='N') {
                    N = true;
                } else if(a.charAt(x)>='0' && a.charAt(x)<='9') {
                    try {
                        cycles = Integer.parseInt(a.substring(x));
                    } catch (Exception e) {
                        return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(x)+")";
                    }
                    if(cycles!=2 && cycles!=4 && cycles!=8 && cycles!=16 && cycles!=1) {
                        return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(x)+")";
                    }
                    x=a.length();
                } else {
                    return "Unknown sound configuration <"+a+">";
                }
                lastF=F;lastV=V;lastS=S;lastN=N;lastcycles=cycles;
            }
        }
        
        System.out.println(lastF+" "+lastV+" "+lastN+" "+lastS+" "+lastcycles);
        // Channel=
        g = lookupValue("C",sNames,sValues);
        if(g!=null) {
            try {
                channel = Integer.parseInt(g);
            } catch (Exception e) {
                return "Invalid channel '"+g+"'";
            }
        }
        
        // Frequency=
        g = lookupValue("F",sNames,sValues);
        if(g!=null) {
            if(!g.equals("OFF")) {
                // TOPHER ... can use note names here
                try {
                    if(g.endsWith("HZ")) {
                        double a = Double.parseDouble(g.substring(0,g.length()-2));
                        freq = (int)Math.round(getM(F,V,S,N,cycles,a));
                        c.text = c.text + " // Desired:"+a+" Actual:"+getFrequency(F,V,S,N,cycles,freq);                        
                    } else {
                        freq = (int)CodeLine.parseNumber(g);
                    }
                } catch (Exception e) {
                    return "Invalid frequency '"+g+"'";
                }
            }
        }

        // Volume=
        g = lookupValue("V",sNames,sValues);
        if(g!=null) {
            eGiven = true;
            try {
                volume = Integer.parseInt(g);
            } catch (Exception e) {
                return "Invalid volume '"+g+"'";
            }
        }
        
        // Waveform=
        g = lookupValue("W",sNames,sValues);
        if(g!=null) {
            eGiven = true;
            try {
                waveform = Integer.parseInt(g);
            } catch (Exception e) {
                return "Invalid waveform '"+g+"'";
            }
        }
        
        // EDelta=
        g = lookupValue("ED",sNames,sValues);
        if(g!=null) {
            try {
                eDelta = Integer.parseInt(g);
                if(eDelta<0) {
                    eDelta = (16+eDelta)&0xF;
                }
            } catch (Exception e) {
                return "Invalid envelope delta '"+g+"'";
            }
        }
        
        // EPeriod=
        g = lookupValue("EP",sNames,sValues);
        if(g!=null) {
            try {
                if(g.endsWith("MS")) {
                    double a = Double.parseDouble(g.substring(0,g.length()-2));
                    a = a / 1000.0;
                    eDur = (int)Math.round(getEnvelopeM(F,V,S,N,cycles,a));
                    if(eDur>255) {
                        return "Envelope period is too large '"+g+"'";
                    }
                    c.text = c.text + " // Desired:"+a+" Actual:"+getEnvelopePeriod(F,V,S,N,cycles,eDur);
                } else {
                    eDur = Integer.parseInt(g);
                }
            } catch (Exception e) {
                return "Invalid envelope period '"+g+"'";
            }
        }
        
        // ELength=
        g = lookupValue("EL",sNames,sValues);
        if(g!=null) {
            if(eDur == 0) {
                return "EPeriod must be specified before ELength.";
            }
            try {
                if(g.endsWith("MS")) {
                    double b = Double.parseDouble(g.substring(0,g.length()-2));
                    b = b / 1000.0;
                    double a = getEnvelopePeriod(F,V,S,N,cycles,eDur);
                    eLength = (int)Math.round(b/a);
                    c.text = c.text + " // Desired:"+b+" Actual:"+(eLength *a);
                } else {
                    eLength = Integer.parseInt(g);
                }
            } catch (Exception e) {
                return "Invalid envelope length '"+g+"'";
            }
        }
        
        // ERepeat=
        g = lookupValue("ER",sNames,sValues);
        if(g!=null) {
            if(g.equals("TRUE")) {
                eRepeat = true;
            }
        }
        
        // Make sure nothing else was given
        if(sNames.size()>0) {
            return "Invalid SOUND parameter '"+sNames.get(0)+"="+sValues.get(0)+"'";
        }
        
        // Make sure we have all of the envelope params if we have any of them
        int ecnt=0;
        if(eLength!=0) ++ecnt;
        if(eDur!=0) ++ecnt;
        if(eDelta!=0) ++ecnt;
        if(ecnt>0 && ecnt!=3) {
            return "All parts of the envelope must be given: EDelta, EPeriod, and ELength";
        }
        type = 0;
        return "";
    }
    
    public String parse(CodeLine c, Cluster cluster) 
    {
        
        String s = c.text;
        String ss = s.toUpperCase();          
        
        SoundCOGCommand sc = new SoundCOGCommand(c,cluster);
        if(ss.startsWith("WAVEFORM ")) {
            StringTokenizer st=new StringTokenizer(s.substring(9).trim(),",");
            if(st.countTokens()!=3) {
                return "Expected WAVEFORM N,PTR,CYCLES";
            }
            String g = st.nextToken();            
            if(g.toUpperCase().equals("TONE")) sc.waveform = 0;
            else if(g.toUpperCase().equals("NOISE")) sc.waveform = 1;
            else if(g.equals("0")) sc.waveform = 0;
            else if(g.equals("1")) sc.waveform = 1;
            else return "Invalid waveform '"+g+"'";            
            sc.label = st.nextToken();            
            sc.type = 3;
            cluster.commands.add(sc);
            g = st.nextToken();
            try {
                lastcycles = Integer.parseInt(g);
                if(lastcycles!=2 && lastcycles!=4 && lastcycles!=8 && lastcycles!=16 && lastcycles!=1) {
                    throw new Exception("Invalid cycles");
                }
            } catch (Exception e) {
                return "Waveform cycles must be 1,2,4,8, or 16 (Not '"+g+"')";                
            }
            return ""; 
        }
        
        if(ss.startsWith("SEQUENCER ")) {
            sc.label = s.substring(10).trim();
            if(sc.label.toUpperCase().equals("STOP")) {
              sc.label = "";
            }
            sc.type = 1;
            cluster.commands.add(sc);
            return "";
        }
        
        if(ss.startsWith("SOUNDCFG ")) {
            sc.F = false; sc.V = false; sc.S = false; sc.N = false;
            StringTokenizer st=new StringTokenizer(s.substring(9).trim(),",");
            while(st.hasMoreTokens()) {
                String g = st.nextToken().toUpperCase();
                if(g.equals("NONE")) {
                } else if(g.equals("NOISE")) {
                    sc.N = true;
                } else if(g.equals("SEQUENCER")) {
                    sc.S = true;
                } else if(g.equals("VOLUMESWEEPER")) {
                    sc.V = true;
                } else if(g.equals("FREQUENCYSWEEPER")) {
                    sc.F = true;
                } else {
                    return "Unknown sound configuration '"+g+"'";
                }
            }            
            sc.type = 2;
            cluster.commands.add(sc);
            lastN = sc.N;
            lastS = sc.S;
            lastV = sc.V;
            lastF = sc.F;
            return "";
        }
        
        if(ss.startsWith("SOUND ") || ss.startsWith("SOUND<")) {
            String er = sc.parseSound(c);
            if(er.length()>0) return er;
            cluster.commands.add(sc);            
            return "";
        } 
            
        return null; // Not us
    }
    
    String processSpecialDataWAVEFORM(List<CodeLine> code, DataCOGCommand data) {
        if(code.size()<2) {
            return "# Waveforms must have at least 2 rows.";
        }
        for(int x=0;x<code.size();++x) {
            code.get(x).text = code.get(x).text.trim().toUpperCase();
            int a = code.get(x).text.length();
            if(a!=2 && a!=4 && a!=8 && a!=16 && a!=32) {
                data.setCodeLine(code.get(x));
                return "# Waveform rows must be 2, 4, 8, 16, or 32 characters long.";
            }
            if(code.get(x).text.length() != code.get(0).text.length()) {
                return "# All the rows of a waveform must be the same length.";
            }
        }
        
        // Repeat the rows out to 32 characters
        for(int x=0;x<code.size();++x) {
            while(code.get(x).text.length()!=32) {
                code.get(x).text+=code.get(x).text;
            }
        }
        // Get the height of each column from the picture
        double[] height = new double[32];
        for(int x=code.size()-1;x>=0;--x) {
            String s = code.get(x).text;
            for(int y=0;y<32;++y) {
                if(s.charAt(y)!='.' && s.charAt(y)!=' ') {
                    height[y] = code.size()-x-1;
                }
            }
        }
        double cnv = 64.0/(code.size()-1);
        
        for(int x=0;x<32;++x) {
            int v = (int)Math.round(height[x]*cnv)-1;
            if(v<0) v=0;
            //System.out.println("::"+v);
            data.data.add(new Integer(v));
        }
        //System.out.println("\n\n");
        
        return "";
    }
    
    String processSpecialDataSEQUENCE(List<CodeLine> code, DataCOGCommand data) 
    {
        SoundSequencer [] seq = new SoundSequencer[3];
        int seqIndex = -1;
        for(int x=0;x<code.size();++x) {
            String c = code.get(x).text.toUpperCase();
            while(true) {
                int j = c.indexOf("|");
                if(j<0) break;
                String cc = c.substring(0,j)+" "+c.substring(j+1);
                c = cc;
            }
            c=c.trim();
            
            // These commands consume the whole line
            if(c.startsWith("SOUND ") || c.startsWith("PAUSE ") || c.startsWith("TEMPO ") || 
               c.startsWith("NOTESTARTSTYLE ") || c.startsWith("NOTESTOPSTYLE ") || 
               c.startsWith("STACCATO ") ) {                   
                if(seqIndex<0) {
                    data.setCodeLine(code.get(x));
                    return "Must give VOICE number first.";
                }
                String er = seq[seqIndex].parseSequenceTerm(c);
                if(er!=null) {
                    data.setCodeLine(code.get(x));
                    return er;
                }
                continue;
            } 
            
            // Timing is a whole line and changes the global timing
            if(c.startsWith("TIMING ")) {   
                String a = c.substring(7).trim();
                lastF = false; lastV = false; lastS = false; lastN = false;lastcycles=16;
                for(int y=0;y<a.length();++y) {
                    if(a.charAt(y)=='F') {
                        lastF = true;
                    } else if(a.charAt(y)=='V') {
                        lastV = true;
                    } else if(a.charAt(y)=='S') {
                        lastS = true;
                    } else if(a.charAt(y)=='N') {
                        lastN = true;
                    } else if(a.charAt(y)>='0' && a.charAt(y)<='9') {
                        try {
                            lastcycles = Integer.parseInt(a.substring(y));
                        } catch (Exception e) {
                            return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(y)+")";
                        }
                        if(lastcycles!=2 && lastcycles!=4 && lastcycles!=8 && lastcycles!=16 && lastcycles!=1) {
                            return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(y)+")";
                        }
                        y=a.length();
                    } else {
                        return "Unknown sound configuration <"+a+">";
                    } 
                }                
                continue;
            }
            
            // A "VOICE" command consumes the whole line, and we'll take it here.
            if(c.startsWith("VOICE")) {                
                try {
                    seqIndex = Integer.parseInt(c.substring(5));
                    if(seqIndex<0 || seqIndex>2) {
                        data.setCodeLine(code.get(x));
                        return "Invalid voice number '"+c+"'";
                    }
                    if(seq[seqIndex]!=null) {
                        data.setCodeLine(code.get(x));
                        return "Multiple '"+c+"' not allowed in same sequence.";
                    }
                    seq[seqIndex] = new SoundSequencer(seqIndex);                    
                } catch (Exception e) {
                    data.setCodeLine(code.get(x));
                    return "Invalid voice number '"+c+"'";
                }
                continue;
            }
            
            // Must be musical notes ... they are space-separated
            StringTokenizer st = new StringTokenizer(c," ");
            while(st.hasMoreTokens()) {
                String cc = st.nextToken().trim();                
                if(seqIndex<0) {
                    data.setCodeLine(code.get(x));
                    return "Must give VOICE number first.";
                }
                String er = seq[seqIndex].parseSequenceTerm(cc);
                if(er!=null) {
                    data.setCodeLine(code.get(x));
                    return er;
                }
            }
        }
        
        // If there are some dangling pauses we need to add those now. Otherwise
        // the RepeatToHere will be out of sequence
        for(int x=0;x<seq.length;++x) {
            if(seq[x]!=null) {
                seq[x].finalPause();
            }
        }
        
        // Check for repeats        
        double repeatToTime = -1.0;    
        double lastTime = -1.0;
        int repeatToOffset = -1;
        
        // Pull all events into one big list
        List<SequencerEvent> events = new ArrayList<SequencerEvent>();
        for(int x=0;x<seq.length;++x) {
            if(seq[x]!=null) {                     
                if(lastTime<0.0) {
                    lastTime = seq[x].events.get(seq[x].events.size()-1).startTime;
                }
                if(seq[x].repeatTo>=0.0) {
                    repeatToTime = seq[x].repeatTo;
                }
                for(int y=0;y<seq[x].events.size();++y) {
                    events.add(seq[x].events.get(y));
                }
            }
        }
        
        for(int x=0;x<seq.length;++x) {
            if(seq[x]!=null) {
                if(seq[x].repeatTo!=repeatToTime) {
                    return "All voices RepeatToHere must be the same point in time.";
                }           
                if(repeatToTime>=0.0) {
                    if(seq[x].events.get(seq[x].events.size()-1).startTime != lastTime) {
                        return "All voices must be the same time length in order to use RepeatToHere.";
                    }
                }
            }
        }
        
        // Now bubble sort the list
        boolean changed = true;
        while(changed) {
            changed = false;
            for(int x=0;x<events.size()-1;++x) {
                SequencerEvent a = events.get(x);
                SequencerEvent b = events.get(x+1);
                if(a.startTime>b.startTime) {
                    changed = true;
                    events.set(x,b);
                    events.set(x+1,a);
                }
            }
        }
        
        // Lay out the events and pauses. We use "simTime" to track the
        // round-off errors in pause loop-counts.
        double currentTime = 0.0;
        double simTime = 0.0;
        
        int [] freqOnVoice = {0,0,0};
        
        for(int x=0;x<events.size();++x) {
            SequencerEvent a = events.get(x);
            if(a.startTime == repeatToTime) {
                repeatToOffset = data.data.size();
            }
            if(a.startTime>currentTime) {
                // Insert a pause
                int mm = (int)getSequencerPause(a.startTime-simTime);
                if(mm>0xFFF) {
                    // TOPHER ... can combine multiple pauses for longer times
                    return "Pause is too long. TOPHER ... break these up!";
                }
                if(mm>0) { // If M<=0 just skip pausing
                    //System.out.println("PAUSING FOR "+(a.startTime-simTime)+":"+mm+":"+getSequencerTime(mm));
                    int yy = 0x8000+mm;
                    data.data.add(new Integer(yy&255));
                    data.data.add(new Integer((yy>>8)&255));
                    currentTime = a.startTime;
                    simTime += getSequencerTime(mm);
                }
            }
            
            // If this was a voice's final pause then there is no
            // event to follow.
            if(a.scc==null) continue;
            
            // Warn about duplicates
            if(a.scc.freq!=0) {
                for(int y=0;y<freqOnVoice.length;++y) {
                    if(freqOnVoice[y]==0) continue;
                    if(y==a.scc.channel) continue;
                    if(a.scc.freq == freqOnVoice[y]) {
                        System.out.println("WARNING. Frequency starting on channel "+
                          a.scc.channel+" already playing on channel "+y+" : '"+a.scc.getCodeLine().text+"'");
                    }
                }
            }
            freqOnVoice[a.scc.channel] = a.scc.freq;
            
            byte [] sdat = new byte[8];
            a.scc.toBinary(null,sdat);           
            
            if(a.scc.eGiven) {
                int aa = sdat[0]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
                aa = sdat[1]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
                aa = sdat[6]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
                aa = sdat[7]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
                aa = sdat[4]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
                aa = sdat[5]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
            } else {
                int aa = sdat[4]; if(aa<0) aa=aa+256;
                data.data.add(new Integer(aa));
                aa = sdat[5]; if(aa<0) aa=aa+256;
                int bb = sdat[1];if(bb<0) bb=bb+256;
                bb=bb&0xF0;
                aa=aa&0x0F;
                aa=aa|bb;
                data.data.add(new Integer(aa));
            }            
            
        }
        
        if(repeatToTime>=0.0) {
            if(repeatToOffset<0) {
                return "Internal Error.Could not find RepeatToHere target event.";
            }
            repeatToOffset = repeatToOffset | 0x9000;
            data.data.add(new Integer(repeatToOffset%256));
            data.data.add(new Integer(repeatToOffset/256));
        } else {
            data.data.add(new Integer(0xFF));
            data.data.add(new Integer(0xFF));
        }       
       
        return "";
    }
    
    public String processSpecialData(String type, List<CodeLine> code, DataCOGCommand data)
    {   
        
        if(type.equals("WAVEFORM")) {
            return processSpecialDataWAVEFORM(code,data);            
        }
        
        if(type.equals("SEQUENCE")) {
            return processSpecialDataSEQUENCE(code,data);
        }
        
        // Not ours
        
        return null;

    }
    
    
    public String toSPIN(List<Cluster> clusters) 
    {
        
        String tt = "' "+codeLine.text+"\r\n";        
        int i;
        int s = 0;
        int er = 0;
        switch(type) {
            case 0:  
                //1_111_0011 | 00__0000_00 || 0scc_0vvvvvv_iiii_r
                //dddddddd_llllllll_ww00ffff_ffffffff
                if(eGiven)s=1;
                if(eRepeat)er=1;
                tt = tt + "  long %1_111_0011____00__0000_00____0"+CodeLine.toBinaryString(s,1)+CodeLine.toBinaryString(channel,2)+
                  "_0"+CodeLine.toBinaryString(volume,6)+"_"+CodeLine.toBinaryString(eDelta,4)+"_"+CodeLine.toBinaryString(er,1)+"\r\n";
                
                tt = tt + "  long %"+CodeLine.toBinaryString(eDur,8)+"_"+CodeLine.toBinaryString(eLength,8)+CodeLine.toBinaryString(waveform,2)+
                  "00"+CodeLine.toBinaryString(freq,12)+"\r\n";
                return tt;
            case 1: // Sequencer
                i = 0;
                if(label.length()!=0) {
                    i = COGCommand.findOffsetToLabel(cluster,label);
                    if(i<0) {
                        return "Could not find label '"+label+"'";
                    }
                }
                tt = tt + "  long %1_011_000"+CodeLine.toBinaryString(seqID,1)+"___00__0001_00_"+CodeLine.toBinaryString(i,16)+"\r\n";
                return tt;
            case 2: // SoundCfg
                i = 0;
                if(F) i = i | 8;
                if(V) i = i | 4;
                if(S) i = i | 2;
                if(N) i = i | 1;
                tt = tt + "  long %1_011_0000___00_0010_00000000000000_"+CodeLine.toBinaryString(i,4)+"\r\n";
                return tt;
            case 3: // Waveform
                i = COGCommand.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "Could not find label '"+label+"'";
                }
                tt = tt+"  long %1_0_11_0000____00_0011_"+CodeLine.toBinaryString(waveform,2)+"_"+CodeLine.toBinaryString(i,16)+"\r\n";
                return tt;
        }
        return "#Unrecognized SoundCOGCommand type '"+type+"'";
    } 
    
}
