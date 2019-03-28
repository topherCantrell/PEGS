/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class VideoCOGCommand extends Command {
    
    int type;
    boolean varForm;
    String label;
    
    int tileNumber;
    int x,y,width,height;
    int n,pic,numPics,flipDelay,deltaX,deltaY,delayX,delayY,flipTimer,actionScriptTimer;
    int xCount,yCount;
    
    public VideoCOGCommand(CodeLine line,Cluster clus) {super(line,clus);}
    
    public int getSize() {
        int size = 0;
        switch(type) {
            case 0: // CLS
                if(varForm) size= 4;
                else size= 8;
                break;
            case 1: // PRINT
                size= 4;
                break;
            case 2: // PRINTARR
                size= 8;
                break;
            case 3: // PRINTVAR
                size= 4;
                break;
            case 4: // GETNUMBER
                size = 4;
                break;
            case 5: // GETLINE
                size = 8;
                break;
            case 6: // SETCURSOR
                size = 4;
                break;
            case 7: // SETCURSORINFO
                if(varForm) size=4;
                else size=8;
                break;
            case 8: // INITTILES
                size = 8;
                break;
            case 9: // SETTILE
                if(varForm) size=4;
                else size=8;
                break;
            case 10: // GETTILE
                if(varForm) size=4;
                else size=8;
                break;
            case 11: // SETSPRITE
                if(varForm) size=8;
                else size = 20;
                break;
            case 12: // GETSPRITE
                size=4;
                break;
            case 13: // SCROLLSCRIPT
            	size=4;
            	break;
        }
        return size;
    }
    
    public String toSPIN(List<Cluster> clusters) {
                
        String tt = "' "+codeLine.text+"\r\n";
        int i;
        switch(type) {
            case 0:
                if(varForm) {
                    tt = tt+"  long  %10_010_000___00_1_00000___00000000"+
                    "___"+CodeLine.toBinaryString(tileNumber,8);
                } else {
                    tt = tt+"  long  %10_111_010___00_0_00000___"+CodeLine.toBinaryString(x,8)+
                    "___"+CodeLine.toBinaryString(y,8)+"\r\n";
                    tt = tt+"    long %"+CodeLine.toBinaryString(width,8)+"_"
                    + CodeLine.toBinaryString(height,8)+"_"
                    + CodeLine.toBinaryString(tileNumber,16);
                }
                
                return tt;
            case 1:
                i = Command.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
                tt = tt+"  long  %10_010_000___00_0_00001___"+CodeLine.toBinaryString(i,16);
                
                return tt;
            case 2:
                i = Command.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
                tt = tt+"  long  %10_111_010___00_0_00010___"+CodeLine.toBinaryString(i,16)+"\r\n";
                tt = tt+"    long %"+CodeLine.toBinaryString(y,32);
                
                return tt;
            case 3:
                tt = tt+"  long %10_010_000___00_0_00011___00000000___"+CodeLine.toBinaryString(y,8);
                
                return tt;
                
            case 4:
                tt = tt+"  long %10_010_000___00_0_00110___00000000___"+CodeLine.toBinaryString(y,8);
                return tt;
                
            case 5: // GETLINE
                i = Command.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
                tt = tt+"  long %10_111_010___00_0_00111___"+CodeLine.toBinaryString(i,16)+"\r\n";
                tt = tt+"   long %"+CodeLine.toBinaryString(y,32);
                return tt;
            case 6: // SETCURSOR
                if(varForm) {
                    tt = tt+"  long %10_010_100___00_1_00100___00000000__"+CodeLine.toBinaryString(y,8);
                    return tt;
                }
                tt = tt+"  long %10_010_010___00_0_00100___"+CodeLine.toBinaryString(x,8)+"__"+CodeLine.toBinaryString(y,8);
                return tt;
            case 7: // SETCURSORINFO
                tt = tt+"  long %10_111_010___00_0_00101___"+CodeLine.toBinaryString(width,16)+"\r\n";
                tt = tt+"  long %"+CodeLine.toBinaryString(x,16)+"__"+CodeLine.toBinaryString(y,16);
                return tt;
            case 8: // INITTILES
                i = Command.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
                tt=tt+"  long %10_111_010___00_0_01000___"+CodeLine.toBinaryString(i,16)+"\r\n";
                tt=tt+"  long %"+CodeLine.toBinaryString(x,16)+"__"+CodeLine.toBinaryString(y,16);
                return tt;
            case 9: // SETTILE
                if(varForm) {
                    tt=tt+"  long %10_010_000___00_1_01001___00000000__"+CodeLine.toBinaryString(y,8);
                    return tt;
                }
                tt = tt+"  long %10_111_010___00_0_01001___"+CodeLine.toBinaryString(x,8)+"__"+CodeLine.toBinaryString(y,8)+"\r\n";
                tt = tt+"  long %"+CodeLine.toBinaryString(width,32);
                return tt;
            case 10: // GETTILE
                if(varForm) {
                    tt=tt+"  long %10_010_000___00_1_01010___00000000__"+CodeLine.toBinaryString(y,8);
                    return tt;
                }
                tt = tt+"  long %10_111_010___00_0_01010___"+CodeLine.toBinaryString(x,8)+"__"+CodeLine.toBinaryString(y,8)+"\r\n";
                tt = tt+"  long %"+CodeLine.toBinaryString(width,32);
                return tt;
            case 11: // SETSPRITE
                i = 0;
                if(label!=null) {
                    i = Command.findOffsetToLabel(cluster,label);
                    if(i<0) {
                        return "#Could not find label '"+label+"'";
                    }                    
                }
                if(varForm) {
                    tt = tt + "  long %10_111_010___00_1_01011___00000000_"+CodeLine.toBinaryString(y,8)+"\r\n";
                    tt = tt + "  long %00000000_00000000__"+CodeLine.toBinaryString(i,16)+"\r\n";
                    return tt;
                }
                
                tt = tt + " long %10_111_010__11_0_01011___00000000__0000_"+CodeLine.toBinaryString(n,4)+"\r\n";
                
                tt = tt + " long %"+
                CodeLine.toBinaryString(x,16)+"__"+
                CodeLine.toBinaryString(y,16)+"\r\n";
                
                tt = tt + " long %"+
                CodeLine.toBinaryString(deltaX,4)+"_"+
                CodeLine.toBinaryString(deltaY,4)+"__"+
                CodeLine.toBinaryString(width,2)+"_"+
                CodeLine.toBinaryString(height,2)+"_"+
                CodeLine.toBinaryString(numPics,2)+"_"+
                CodeLine.toBinaryString(flipDelay,2)+"__"+
                CodeLine.toBinaryString(pic,16)+"\r\n";
                
                tt = tt + " long %"+
                CodeLine.toBinaryString(yCount,8)+"_"+
                CodeLine.toBinaryString(xCount,8)+"_"+
                CodeLine.toBinaryString(delayY,8)+"_"+
                CodeLine.toBinaryString(delayX,8)+"\r\n";
                
                tt = tt + " long %"+
                CodeLine.toBinaryString(i,16)+"__"+
                CodeLine.toBinaryString(actionScriptTimer,8)+"_"+
                CodeLine.toBinaryString(flipTimer,8)+"\r\n";
                
                return tt;
                
            case 12: // GETSPRITE
                tt = tt + "  long %10_010_000___00_0_01100__00000000_"+CodeLine.toBinaryString(y,8)+"\r\n";
                return tt;
                
            case 13: // AUTOSCROLL
            	i = Command.findOffsetToLabel(cluster,label);
                if(i<0) {
                    return "#Could not find label '"+label+"'";
                }
            	tt = tt + "  long %10_010_000___00_0_01101__"+CodeLine.toBinaryString(i,16)+"\r\n";
            	return tt;
            	
        }
        return "#Unrecognized VideoCOGCommand type '"+type+"'";
    }
    
}
