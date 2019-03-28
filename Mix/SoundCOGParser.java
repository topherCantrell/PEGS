/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class SoundCOGParser implements Parser 
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
    
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
    
    
    static String lookupValue(String key, List<String> keys, List<String> values)
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
    
    public static String parseSound(CodeLine c,SoundCOGCommand com) {
        if(com.codeLine==null) com.codeLine = c;
        String s = c.text;
        String ss = s.toUpperCase();  
        com.F = lastF; 
        com.V = lastV; 
        com.S = lastS; 
        com.N = lastN; 
        com.cycles=lastcycles;        
       
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
            com.F = false; com.V = false; com.S = false; com.N = false;
            for(int x=0;x<a.length();++x) {
                if(a.charAt(x)=='F') {
                    com.F = true;
                } else if(a.charAt(x)=='V') {
                    com.V = true;
                } else if(a.charAt(x)=='S') {
                    com.S = true;
                } else if(a.charAt(x)=='N') {
                    com.N = true;
                } else if(a.charAt(x)>='0' && a.charAt(x)<='9') {
                    try {
                        com.cycles = Integer.parseInt(a.substring(x));
                    } catch (Exception e) {
                        return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(x)+")";
                    }
                    if(com.cycles!=2 && com.cycles!=4 && com.cycles!=8 && com.cycles!=16 && com.cycles!=1) {
                        return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(x)+")";
                    }
                    x=a.length();
                } else {
                    return "Unknown sound configuration <"+a+">";
                }
                lastF=com.F;
                lastV=com.V;
                lastS=com.S;
                lastN=com.N;
                lastcycles=com.cycles;
            }
        }
        
        //System.out.println(lastF+" "+lastV+" "+lastN+" "+lastS+" "+lastcycles);
        // Channel=
        g = lookupValue("C",sNames,sValues);
        if(g!=null) {
            try {
                com.channel = Integer.parseInt(g);
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
                        com.freq = (int)Math.round(getM(com.F,com.V,com.S,com.N,com.cycles,a));
                        c.text = c.text + " // Desired:"+a+" Actual:"+getFrequency(com.F,com.V,com.S,com.N,com.cycles,com.freq);                        
                    } else {
                        com.freq = (int)CodeLine.parseNumber(g);
                    }
                } catch (Exception e) {
                    return "Invalid frequency '"+g+"'";
                }
            }
        }

        // Volume=
        g = lookupValue("V",sNames,sValues);
        if(g!=null) {
            com.eGiven = true;
            try {
                com.volume = Integer.parseInt(g);
            } catch (Exception e) {
                return "Invalid volume '"+g+"'";
            }
        }
        
        // Waveform=
        g = lookupValue("W",sNames,sValues);
        if(g!=null) {
            com.eGiven = true;
            try {
                com.waveform = Integer.parseInt(g);
            } catch (Exception e) {
                return "Invalid waveform '"+g+"'";
            }
        }
        
        // EDelta=
        g = lookupValue("ED",sNames,sValues);
        if(g!=null) {
            try {
                com.eDelta = Integer.parseInt(g);
                if(com.eDelta<0) {
                    com.eDelta = (16+com.eDelta)&0xF;
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
                    com.eDur = (int)Math.round(getEnvelopeM(com.F,com.V,com.S,com.N,com.cycles,a));
                    if(com.eDur>255) {
                        return "Envelope period is too large '"+g+"'";
                    }
                    c.text = c.text + " // Desired:"+a+" Actual:"+getEnvelopePeriod(com.F,com.V,com.S,com.N,com.cycles,com.eDur);
                } else {
                    com.eDur = Integer.parseInt(g);
                }
            } catch (Exception e) {
                return "Invalid envelope period '"+g+"'";
            }
        }
        
        // ELength=
        g = lookupValue("EL",sNames,sValues);
        if(g!=null) {
            if(com.eDur == 0) {
                return "EPeriod must be specified before ELength.";
            }
            try {
                if(g.endsWith("MS")) {
                    double b = Double.parseDouble(g.substring(0,g.length()-2));
                    b = b / 1000.0;
                    double a = getEnvelopePeriod(com.F,com.V,com.S,com.N,com.cycles,com.eDur);
                    com.eLength = (int)Math.round(b/a);
                    c.text = c.text + " // Desired:"+b+" Actual:"+(com.eLength *a);
                } else {
                    com.eLength = Integer.parseInt(g);
                }
            } catch (Exception e) {
                return "Invalid envelope length '"+g+"'";
            }
        }
        
        // ERepeat=
        g = lookupValue("ER",sNames,sValues);
        if(g!=null) {
            if(g.equals("TRUE")) {
                com.eRepeat = true;
            }
        }
        
        // Make sure nothing else was given
        if(sNames.size()>0) {
            return "Invalid SOUND parameter '"+sNames.get(0)+"="+sValues.get(0)+"'";
        }
        
        // Make sure we have all of the envelope params if we have any of them
        int ecnt=0;
        if(com.eLength!=0) ++ecnt;
        if(com.eDur!=0) ++ecnt;
        if(com.eDelta!=0) ++ecnt;
        if(ecnt>0 && ecnt!=3) {
            return "All parts of the envelope must be given: EDelta, EPeriod, and ELength";
        }
        com.type = 0;
        return "";
    }
    
    public String parse(CodeLine c, Cluster cluster, Map<String,String> defines) 
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
        
        if(ss.startsWith("SCRIPT ")) {
        	sc.waveform = (int)CodeLine.parseNumber(s.substring(7).trim());  
        	sc.waveform = sc.waveform*4;
        	sc.type = 4;
        	cluster.commands.add(sc);
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
            String er = parseSound(c,sc);
            if(er.length()>0) return er;
            cluster.commands.add(sc);            
            return "";
        } 
            
        return null; // Not us
    }  
    
}
