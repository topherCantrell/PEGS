/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class SoundDataStructureCommand implements DataStructureCommand 
{
    
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
    
    String processSpecialDataSEQUENCE(List<CodeLine> code, DataCOGCommand data, SoundCOGCommand global) 
    {
        SoundSequencer [] seq = new SoundSequencer[7];
        int seqIndex = 6;
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
            if(//c.startsWith("SOUND ") || c.startsWith("PAUSE ") || c.startsWith("TEMPO ") || 
               //c.startsWith("NOTESTARTSTYLE ") || c.startsWith("NOTESTOPSTYLE ") || 
                c.startsWith("TEMPO ") || c.startsWith("REGISTER ") || c.startsWith("STACCATO ") ||
                c.startsWith("VARSET ")) {  
            	/*
                if(seqIndex<0) {
                    data.setCodeLine(code.get(x));
                    return "Must give VOICE number first.";
                }
                */
                String er = seq[seqIndex].parseSequenceTerm(c);
                if(er!=null) {
                    data.setCodeLine(code.get(x));
                    return er;
                }
                continue;
            } 
            
            /*
            // Timing is a whole line and changes the global timing
            if(c.startsWith("TIMING ")) {   
                String a = c.substring(7).trim();
                SoundCOGParser.lastF = false; SoundCOGParser.lastV = false; SoundCOGParser.lastS = false; 
                SoundCOGParser.lastN = false; SoundCOGParser.lastcycles=16;
                for(int y=0;y<a.length();++y) {
                    if(a.charAt(y)=='F') {
                        SoundCOGParser.lastF = true;
                    } else if(a.charAt(y)=='V') {
                        SoundCOGParser.lastV = true;
                    } else if(a.charAt(y)=='S') {
                        SoundCOGParser.lastS = true;
                    } else if(a.charAt(y)=='N') {
                        SoundCOGParser.lastN = true;
                    } else if(a.charAt(y)>='0' && a.charAt(y)<='9') {
                        try {
                            SoundCOGParser.lastcycles = Integer.parseInt(a.substring(y));
                        } catch (Exception e) {
                            return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(y)+")";
                        }
                        if(SoundCOGParser.lastcycles!=2 && SoundCOGParser.lastcycles!=4 && 
                           SoundCOGParser.lastcycles!=8 && SoundCOGParser.lastcycles!=16 && SoundCOGParser.lastcycles!=1) {
                            return "Waveform cycles must be 1,2,4,8, or 16 (Not "+a.substring(y)+")";
                        }
                        y=a.length();
                    } else {
                        return "Unknown sound configuration <"+a+">";
                    } 
                }                
                continue;
            }
            */
            
            // A "VOICE" command consumes the whole line, and we'll take it here.
            if(c.startsWith("VOICE")) {                
                try {
                    seqIndex = Integer.parseInt(c.substring(5));
                    if(seqIndex<0 || seqIndex>6) {
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
        for(int xx=0;xx<seq.length;++xx) {
        	int x = xx-1;
        	if(x<0) x = 6;
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
        
        /*int [] freqOnVoice = {0,0,0};*/
        
        for(int x=0;x<events.size();++x) {
            SequencerEvent a = events.get(x);
            if(a.startTime == repeatToTime) {
                repeatToOffset = data.data.size();
            }
            if(a.startTime>currentTime) {
                // Insert a pause
            	double pt = a.startTime - simTime;
            	pt = pt / 0.0003072;
            	int mm = (int)pt;
            	// 1_ppppppppppppppp            	
            	currentTime = a.startTime;
            	System.out.println("::"+mm+":"+a.startTime+":"+simTime);
                simTime += (mm)*0.0003072;
                if(mm<0 || mm>0x7FFF) {
                	return "Invalid pause: "+mm;
                }
                mm = mm | 0x8000;
                data.data.add(new Integer(mm&255));
                data.data.add(new Integer((mm>>8)&255));
                
            	/*
                int mm = (int)SoundCOGParser.getSequencerPause(a.startTime-simTime);
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
                    simTime += SoundCOGParser.getSequencerTime(mm);
                }
                */
            }
            
            // If this was a voice's final pause then there is no
            // event to follow.
            //if(a.scc==null) continue;
            if(a.eventData==null) continue;
            
            /*
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
            */
            
            /*
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
            */
            
            if(a.eventData instanceof List) {
            	// chip, reg, value
            	List<Integer> ii = (List<Integer>)a.eventData;
            	if(ii.size()==2) {
            		data.data.add(ii.get(0));
                    data.data.add(ii.get(1));            		
            	} else {
            		int chip = ii.get(0);
            		int reg = ii.get(1);
            		int val = ii.get(2);
            		if(chip==1) chip=7;            	
            		//0_111_rrrr_vvvvvvvv            	
            		chip = chip << 12;
            		reg = reg << 8;
            		chip = chip | reg | val;
            		data.data.add(new Integer(chip%256));
            		data.data.add(new Integer(chip/256)); 
            	}
            } else {	            
	            // ADD NOTE    0_001_0c_vv_nnnnnnnn
	            int n = ((Integer)a.eventData).intValue();
	            if(n!=0) {
	            	n=n-23; // Our note table
	            }
	            if(n<0) n = 0;            
	            int c = a.voice/3;
	            int v = a.voice%3;
	            data.data.add(new Integer(n&255));
	            c=c<<2 | v;
	            data.data.add(new Integer(0x10 | c));
            }
            
        }
        
        if(repeatToTime>=0.0) {
        	// REPEAT
        	/*
            if(repeatToOffset<0) {
                return "Internal Error.Could not find RepeatToHere target event.";
            }
            repeatToOffset = repeatToOffset | 0x9000;
            data.data.add(new Integer(repeatToOffset%256));
            data.data.add(new Integer(repeatToOffset/256));
            */
        	throw new RuntimeException("REPEAT not implemented");
        } else {
        	// STOP
        	/*
            data.data.add(new Integer(0xFF));
            data.data.add(new Integer(0xFF));
            */
        	data.data.add(new Integer(0x00));
        	data.data.add(new Integer(0x30));
        }       
       
        return "";
    }
    
    public String processSpecialData(String type, List<CodeLine> code, DataCOGCommand data, Map<String,String> defines)
    {   
                
        //if(type.equals("WAVEFORM")) {
        //    return processSpecialDataWAVEFORM(code,data);            
       // }
        
        if(type.equals("SEQUENCE")) {
            return processSpecialDataSEQUENCE(code,data,null);
        }
        
        // Not ours
        
        return null;

    }  
    
}
