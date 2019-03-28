/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class SoundCOGCommand extends Command implements Cloneable
{
    
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
      F = SoundCOGParser.lastF;
      V = SoundCOGParser.lastV;
      S = SoundCOGParser.lastS;
      N = SoundCOGParser.lastN;
      cycles = SoundCOGParser.lastcycles;
    }      
    
    public int getSize() 
    {
        if(type == 0) return 8; // SOUND commands are long
        return 4; // Everything else is short
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
                tt = tt + "  long %10_111_011____00__0000_00____0"+CodeLine.toBinaryString(s,1)+CodeLine.toBinaryString(channel,2)+
                  "_0"+CodeLine.toBinaryString(volume,6)+"_"+CodeLine.toBinaryString(eDelta,4)+"_"+CodeLine.toBinaryString(er,1)+"\r\n";
                
                tt = tt + "  long %"+CodeLine.toBinaryString(eDur,8)+"_"+CodeLine.toBinaryString(eLength,8)+CodeLine.toBinaryString(waveform,2)+
                  "00"+CodeLine.toBinaryString(freq,12)+"\r\n";
                return tt;
            case 1: // Sequencer
                i = 0;
                if(label.length()!=0) {
                    i = Command.findOffsetToLabel(cluster,label);
                    if(i<0) {
                        return "Could not find label '"+label+"'";
                    }
                }
                tt = tt + "  long %10_011_00"+CodeLine.toBinaryString(seqID,1)+"___00__0001_00_"+CodeLine.toBinaryString(i,16)+"\r\n";
                return tt;
            case 2: // SoundCfg
                i = 0;
                if(F) i = i | 8;
                if(V) i = i | 4;
                if(S) i = i | 2;
                if(N) i = i | 1;
                tt = tt + "  long %10_011_000___00_0010_00000000000000_"+CodeLine.toBinaryString(i,4)+"\r\n";
                return tt;
            case 3: // Waveform
                i = Command.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "Could not find label '"+label+"'";
                }
                tt = tt+"  long %10_0_11_000____00_0011_"+CodeLine.toBinaryString(waveform,2)+"_"+CodeLine.toBinaryString(i,16)+"\r\n";
                return tt;
            case 4: // Script            	
            	tt = tt + "  long %10_011_"+CodeLine.toBinaryString(waveform,27);
            	return tt;
        }
        return "#Unrecognized SoundCOGCommand type '"+type+"'";
    }
    
}
