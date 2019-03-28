/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class VideoDataStructureCommand implements DataStructureCommand 
{
    
    String decodeASCIIGraphics(String text, char [] map)
    {
        StringBuffer sb = new StringBuffer();
        for(int x=0;x<text.length();++x) {
            char g = text.charAt(x);
            if(g==' ') continue;            
            int y;            
            for(y=0;y<map.length;++y) {
                if(map[y]==g) break;
            }
            if(y==map.length) {
                String ret = "" + g;                
                return ret.toString();
            }
            sb.append((char)(y+'0'));
        }
        
        return sb.toString();
    }  
    
    public char[] DEFAULTSPRITECHARS = {'.','R','G','W'};
    public char[] DEFAULTSPRITECHARSCOMPLEX = {'B','R','G','W','.'};
    
    String processASCIIGraphics(List<CodeLine> code, DataCOGCommand data, boolean tile, boolean simple)
    {
        if(code.size()<8) {
            return "Structure must contain an optional INFO line followed by at least 8 data rows.";
        }
        
        int width = -1;
        int height = -1;        
        if(tile) {
            simple = true;
            width = 8;
            height = 8;
        }
        char [] transMap = DEFAULTSPRITECHARS;        
        if(!simple) {
            transMap = DEFAULTSPRITECHARSCOMPLEX;
        }        
        
        String tt = code.get(0).text.toUpperCase();
        if(tt.equals("INFO") || tt.startsWith("INFO ")) {
            tt = code.get(0).text.substring(4).trim(); // The MAP is case sensitive
            code.remove(0);
            ArgumentList aList = new ArgumentList(tt,null); // No substitutes allowed
            Argument a = aList.removeArgument("WIDTH",0);
            if(a!=null) {
                if(tile) {
                    if(!a.longValueOK || a.longValue!=8) {
                        return "Invalid WIDTH value '"+a.value+"'. Tile width must be '8' pixels.";
                    }
                } else {
                    if(!a.longValueOK || (a.longValue!=8 && a.longValue!=16 && a.longValue!=32 && a.longValue!=64)) {
                        return "Invalid WIDTH value '"+a.value+"'. Sprite width must be 8, 16, 32, or 64.";
                    }
                    width = (int)a.longValue;
                }
            }
            a = aList.removeArgument("HEIGHT",1);
            if(a!=null) {
                if(tile) {
                    if(!a.longValueOK || a.longValue!=8) {
                        return "Invalid HEIGHT value '"+a.value+"'. Tile height must be '8' pixels.";
                    }
                } else {
                    if(!a.longValueOK || (a.longValue!=8 && a.longValue!=16 && a.longValue!=32 && a.longValue!=64)) {
                        return "Invalid HEIGHT value '"+a.value+"'. Sprite height must be 8, 16, 32, or 64.";
                    }
                    height = (int)a.longValue;
                }
            }
            a = aList.removeArgument("MAP",2);
            if(a!=null) {
                tt = a.orgCase;
                if(simple) {
                    if(tt.length()!=4) {
                        return "Simple image maps must be 4 characters ... one for each color value in order: 0, 1, 2 and 3.";
                    }
                    transMap[0]=tt.charAt(0);transMap[1]=tt.charAt(1);
                    transMap[2]=tt.charAt(2);transMap[3]=tt.charAt(3);
                } else {
                    if(tt.length()!=5) {
                        return "Complex image maps must be 5 characters ... one for each color value in order: transparent, 0, 1, 2 and 3.";
                    }
                    transMap[0]=tt.charAt(1);transMap[1]=tt.charAt(2);
                    transMap[2]=tt.charAt(3);transMap[3]=tt.charAt(4);
                    transMap[4]=tt.charAt(0);
                }
            }   
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
        }
         
        if(width<0) {
            return "Missing WIDTH value. Sprite width must be 8, 16, 32, or 64.";
        }
        if(height<0) {
            return "Missing HEIGHT value. Sprite height must be 8, 16, 32, or 64.";
        }
        
        if(code.size()%height !=0) {
            data.setCodeLine(code.get(0));
            return "Number of data rows ("+code.size()+") is not a multiple of the image height ("+height+").";
        } 
        
        int sp = 0;
        while(code.size()>0) {
            String [] spriteRow = new String[height];                        
            for(int x=0;x<height;++x) {
                spriteRow[x] = decodeASCIIGraphics(code.get(0).text,transMap);
                if(spriteRow[x].length()==1) {
                    data.setCodeLine(code.get(0));
                    return "Unknown ASCII art pixel mapping for character '"+spriteRow[x]+"'.";
                }
                if(spriteRow[x].length()%width != 0) {
                    data.setCodeLine(code.get(0));
                    return "ASCII art lines must be multiple of 'width' characters.";
                }
                if(spriteRow[x].length()!=spriteRow[0].length()) {
                    data.setCodeLine(code.get(0));
                    return "All lines in a row must be the same length.";
                }
                code.remove(0);
            }   
            
            if(!simple) {
                sp = storeImageRow(data,sp,spriteRow,width,height,true);
            }
            sp = storeImageRow(data,sp,spriteRow,width,height,false);
        }              

        return "";
        
    } 
    
    int storeImageRow(DataCOGCommand data, int sp, String[] spriteRows, 
        int width, int height, boolean maskOnly)
    {  
        
        // If this is a mask, we convert everything but '4' to '3', but
        // we must leave the original intact.
        if(maskOnly) {
            String [] a = new String[spriteRows.length];
            for(int x=0;x<a.length;++x) {
                byte [] bb = spriteRows[x].getBytes();
                for(int y=0;y<bb.length;++y) {
                    if(bb[y]!='4') bb[y]='3';
                }
                a[x] = new String(bb);
            }
            spriteRows = a;
        }
        
        // Add space for the row of sprite data
        int rowDataSize = spriteRows[0].length()/4; // 4 pixels per byte
        for(int x=0;x<rowDataSize*height;++x) {
            data.data.add(new Integer(0));
        }
        
        // Some names to make the math more readable
        int pixelRowLength = spriteRows[0].length();
        int pixelsPerImageRow = width;
        int bytesPerImageRow = pixelsPerImageRow/4;
        int bytesPerImage = bytesPerImageRow * height;
        
        for(int y=0;y<height;++y) {
            String row = spriteRows[y];
            for(int x=0;x<pixelRowLength;x=x+pixelsPerImageRow) {
                for(int z=0;z<pixelsPerImageRow;z=z+8) {
                    
                    int po = x+z; // Index of 8 pixels  
                    
                    // Arrange the 8 pixels into the bits of two bytes
                    // (We AND with 3 to turn transparent into 0 in image bits)
                    int a = ((row.charAt(po+4)-'0')&3)    | 
                            ((row.charAt(po+5)-'0')&3)<<2 | 
                            ((row.charAt(po+6)-'0')&3)<<4 | 
                            ((row.charAt(po+7)-'0')&3)<<6;
                    
                    int b = ((row.charAt(po+0)-'0')&3)    | 
                            ((row.charAt(po+1)-'0')&3)<<2 | 
                            ((row.charAt(po+2)-'0')&3)<<4 | 
                            ((row.charAt(po+3)-'0')&3)<<6;
                    
                    //           group         image                            row
                    int ii = sp + (z/8)*2 + (x/pixelsPerImageRow)*bytesPerImage + y*bytesPerImageRow;
                    
                    data.data.set(ii,new Integer(b));
                    data.data.set(ii+1,new Integer(a));
                    
                }
            }
        }
        
        return sp+rowDataSize*height;        
        
    }
    
    String processSpecialACTIONSCRIPT(List<CodeLine> code, DataCOGCommand data, Map<String,String> subs)
    {
        
        for(int x=0;x<code.size();++x) {
            String a = code.get(x).text;
            if(a.toUpperCase().trim().equals("REPEAT")) {
                if(x!=(code.size()-1)) {
                    data.setCodeLine(code.get(x));
                    return "REPEAT must be last line of ACTIONSCRIPT.";                    
                }
                int dist = data.data.size()+3;
                dist = 65536 - dist;                
                data.data.add(new Integer(2));         
                data.data.add(new Integer(dist%256));
                data.data.add(new Integer(dist/256));                
                continue;
            }
            
            if(a.toUpperCase().trim().equals("HALT")) {
            	data.data.add(new Integer(0x4)); // Set motion to zero and quit
            	continue;
            }
            
            if(a.toUpperCase().trim().equals("POKE")) {
            	// POKE location,value
            	// Fix this in the future
            	int j = a.indexOf(",");
            	String aa = a.substring(4,j).trim();
            	String bb = a.substring(j+1).trim();
            	int av = Integer.parseInt(aa);
            	int bv = Integer.parseInt(bb);
            	data.data.add(new Integer(3));
            	data.data.add(new Integer(av%256));
                data.data.add(new Integer(av/256));        
                data.data.add(new Integer(bv%256));
                data.data.add(new Integer(bv/256));            	
            	continue;
            }
            
            ArgumentList aList = new ArgumentList(a,subs);
            int is = 0;
            if(aList.getArgument("IMAGE",0)!=null ||
               aList.getArgument("SIMPLEIMAGE",0)!=null ||
               aList.getArgument("WIDTH",2)!=null ||
               aList.getArgument("HEIGHT",3)!=null ||
               aList.getArgument("NUMPICS",4)!=null ||
               aList.getArgument("FLIPDELAY",5)!=null ||
               aList.getArgument("FLIPTIMER",6)!=null) {
                   int image,width=0,height=0,numPics,flipDelay,flipTimer;
                   // LONG FORM
                   is = 6;
                   data.data.add(new Integer(1));
                   
                   Argument aa = aList.removeArgument("WIDTH",0);
                   if(aa==null || !aa.longValueOK || (aa.longValue!=8 && aa.longValue!=16 && aa.longValue!=32 && aa.longValue!=64)) {
                       data.setCodeLine(code.get(x));
                       return "In ACTIONSCRIPT long-form, invalid WIDTH value '"+aa.value+"'. Must be 8, 16, 32, or 64.";
                   }
                   switch((int)aa.longValue) {
                       case 8:
                           width=0;
                           break;
                       case 16:
                           width=1;
                           break;
                       case 32:
                           width=2;
                           break;
                       case 64:
                           width=3;
                           break;
                   }
                   
                   aa = aList.removeArgument("HEIGHT",1);
                   if(aa==null || !aa.longValueOK || (aa.longValue!=8 && aa.longValue!=16 && aa.longValue!=32 && aa.longValue!=64)) {
                       data.setCodeLine(code.get(x));
                       return "In ACTIONSCRIPT long-form, invalid HEIGHT value '"+aa.value+"'. Must be 8, 16, 32, or 64.";
                   }
                   switch((int)aa.longValue) {
                       case 8:
                           height=0;
                           break;
                       case 16:
                           height=1;
                           break;
                       case 32:
                           height=2;
                           break;
                       case 64:
                           height=3;
                           break;
                   }
                   
                   aa = aList.removeArgument("IMAGE",2);
                   String it = "IMAGE";
                   if(aa==null) {
                       aa = aList.removeArgument("SIMPLEIMAGE",2);
                       it = "SIMPLEIMAGE";
                   }
                   if(aa==null || !aa.longValueOK || aa.longValue<0) {
                       data.setCodeLine(code.get(x));
                       return "In ACTIONSCRIPT long-form, IMAGE or SIMPLEIMAGE must be specified.  Must be 0-4095.";
                   }
                   image = (int)aa.longValue;
                   if(it.equals("SIMPLEIMAGE")) {
                       image=image | 0x8000;
                   } 
                   
                   numPics = 0;
                   aa = aList.removeArgument("NUMPICS",3);
                   if(aa!=null) {
                       if(!aa.longValueOK || aa.longValue<1 || aa.longValue>4) {
                           data.setCodeLine(code.get(x));
                           return "In ACTIONSCRIPT long-form, invalid NUMPICS value '"+aa.value+"'. Must be 1, 2, 3, or 4.";
                       }
                       numPics = (int)aa.longValue - 1; // ONE is assumed
                   }
                   
                   flipDelay = 0;
                   aa = aList.removeArgument("FLIPDELAY",4);
                   if(aa!=null) {
                       if(numPics==0) {
                           data.setCodeLine(code.get(x));
                           return "In ACTIONSCRIPT long-form, cannot specify FLIPDELAY without NUMPICS>1.";
                       }
                       if(!aa.longValueOK || aa.longValue<0 || aa.longValue>3) {
                           data.setCodeLine(code.get(x));
                           return "In ACTIONSCRIPT long-form, invalid FLIPDELAY value '"+aa.value+"'. Must be 0, 1, 2, or 3.";
                       }
                       flipDelay = (int)aa.longValue;
                   }
                   
                   flipTimer = numPics<<4 | flipDelay<<2 | 3;                   
                   
                   aa = aList.removeArgument("FLIPTIMER",5);
                   if(aa!=null) {
                       if(numPics==0) {
                           data.setCodeLine(code.get(x));
                           return "In ACTIONSCRIPT long-form, cannot specify FLIPTIMER without NUMPICS>1.";
                       }
                       if(!aa.longValueOK || aa.longValue<0 || aa.longValue>255) {
                           data.setCodeLine(code.get(x));
                           return "In ACTIONSCRIPT long-form, invalid FLIPTIMER value '"+aa.value+"'. Must be 0-255.";
                       }
                       flipTimer = (int)aa.longValue;
                   }
                   
                   data.data.add(new Integer(image%256)); // imageLSB
                   data.data.add(new Integer(image/256)); // imageMSB
                   data.data.add(new Integer(width<<6 | height<<4 | numPics<<2 | flipDelay)); // spriteInfo
                   data.data.add(new Integer(flipTimer)); // spriteFlipTimer  
                   
            } else {
                data.data.add(new Integer(0));
            }
            
            // SHORT FORM (and end of LONG FORM)
            
            int deltaX=0,deltaY=0,delayX=0,delayY=0,count;
            Argument aa = aList.removeArgument("COUNT",is);
            if(aa==null || !aa.longValueOK || aa.longValue<=0) {
                data.setCodeLine(code.get(x));
                return "In ACTIONSCRIPT, COUNT value must be >0";
            }       
            count = (int)aa.longValue;
            
            aa=aList.removeArgument("DELTAX",is+1);
            if(aa!=null) {
                if(!aa.longValueOK || aa.longValue<-8 || aa.longValue>7) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, invalid DELATAX value '"+aa.value+"'. Must be -8 to 7.";
                }
                deltaX = (int)aa.longValue;
                if(deltaX<0) deltaX=16+deltaX;
            }
            aa=aList.removeArgument("DELTAY",is+2);
            if(aa!=null) {
                if(!aa.longValueOK || aa.longValue<-8 || aa.longValue>7) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, invalid DELATAY value '"+aa.value+"'. Must be -8 to 7.";
                }
                deltaY = (int)aa.longValue;
                if(deltaY<0) deltaY=16+deltaY;
            }
            aa=aList.removeArgument("DELAYX",is+3);
            if(aa!=null) {                
                if(deltaX==0) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, cannot specify a DELAYX without a non-zero DELTAX.";
                }
                if(!aa.longValueOK || aa.longValue<=0 || aa.longValue>255) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, invalid DELAYX value '"+aa.value+"'. Must be 1-255.";
                }
                delayX = (int)aa.longValue;
            }
            aa=aList.removeArgument("DELAYY",is+4);
            if(aa!=null) {
                if(deltaY==0) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, cannot specify a DELAYY without a non-zero DELTAY.";
                }
                if(!aa.longValueOK || aa.longValue<=0 || aa.longValue>255) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, invalid DELAYY value '"+aa.value+"'. Must be 1-255.";
                }
                delayY = (int)aa.longValue;
            }
                        
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                data.setCodeLine(code.get(x));
                return "In ACTIONSCRIPT, invalid values: '"+rem+"'";
            }
            
            data.data.add(new Integer(deltaX<<4 | deltaY)); // xyDelta
            data.data.add(new Integer(delayX)); // xDelay
            data.data.add(new Integer(delayY)); // yDelay
            data.data.add(new Integer(count)); // actionScriptTimer
            
        }       
        
        data.data.add(new Integer(0xFF)); // Forces the script to terminate
        // In the future, we don't need to do this if we repeated earlier
        
        return "";
    }
    
    
    
    public String processSpecialData(String type, List<CodeLine> code, DataCOGCommand data, Map<String,String> subs)
    {   
        
    	if(type.equals("TILE")) {
            return processASCIIGraphics(code,data,true,false);           
        }
        
        if(type.equals("SIMPLEIMAGE")) {
            return processASCIIGraphics(code,data,false,true);
        }
        
        if(type.equals("IMAGE")) {
            return processASCIIGraphics(code,data,false,false);
        }
        
        if(type.equals("ACTIONSCRIPT")) {
            return processSpecialACTIONSCRIPT(code,data,subs);
        }
        
        if(type.equals("SCROLLSCRIPT")) {
        	return processSCROLLSCRIPT(code,data,subs);        
        }
        
        // Not ours
        
        return null;

    }

	private String processSCROLLSCRIPT(List<CodeLine> code, DataCOGCommand data, Map<String, String> subs) 
	{		
				
		int currentOffset = 0;
		int repeatTo = -1;
		for(int x=0;x<code.size();++x) {
            String a = code.get(x).text;
            if(a.toUpperCase().trim().equals("REPEATTOHERE")) {
            	
            	if(repeatTo>=0) {
            		return "Only one REPEATTOHERE may be given in the SCROLLSCRIPT.";
            	}
            	repeatTo = currentOffset;            	
            } else {
            	ArgumentList aList = new ArgumentList(a,subs);
            	Argument aa = aList.removeArgument("YOFFSET", -1);
            	if(aa!=null) {    
            		if(!aa.longValueOK || aa.longValue<0) {
                        data.setCodeLine(code.get(x));
                        return "In SCROLLSCRIPT, invalid YOFFSET value '"+aa.value+"'. Must be >= 0.";
                    }
            		int c = (int)aa.longValue;
            		c = c | 0x2000;
            		data.data.add(new Integer(c%256));
            		data.data.add(new Integer(c/256));
            		++currentOffset;
            	}
            	aa = aList.removeArgument("DELTA", -1);
            	if(aa!=null) {  
            		
            		if(!aa.longValueOK || aa.longValue<-2048 || aa.longValue>2047) {
            		    data.setCodeLine(code.get(x));
            		    return "In SCROLLSCRIPT, invalid DELTA value '"+aa.value+"'. Must be -2048 to 2047.";
            		}            		
            		int c = (int)aa.longValue;
            		if(c<0) {
            			c = 0x1000 + c;
            		}
            		c = c | 0x3000;
            		data.data.add(new Integer(c%256));
            		data.data.add(new Integer(c/256));
            		++currentOffset;
            	}
            	aa = aList.removeArgument("PAUSE", -1);
            	if(aa!=null) { 
            		if(!aa.longValueOK || aa.longValue<=0 || aa.longValue>4095) {
                        data.setCodeLine(code.get(x));
                        return "In SCROLLSCRIPT, invalid PAUSE value '"+aa.value+"'. Must be 1 - 4095.";
                    }
            		int c = (int)aa.longValue;
            		c = c | 0x4000;
            		data.data.add(new Integer(c%256));
            		data.data.add(new Integer(c/256));
            		++currentOffset;
            	}
            	aa = aList.removeArgument("COUNT", -1);
            	if(aa!=null) {
            		if(!aa.longValueOK || aa.longValue<=0 || aa.longValue>4095) {
                        data.setCodeLine(code.get(x));
                        return "In SCROLLSCRIPT, invalid COUNT value '"+aa.value+"'. Must be 1 - 4095.";
                    }
            		int c = (int)aa.longValue;
            		//c = c | 0x0000;
            		data.data.add(new Integer(c%256));
            		data.data.add(new Integer(c/256));
            		++currentOffset;
            	}
            	String rem = aList.reportUnremovedValues();
                if(rem.length()!=0) {
                    data.setCodeLine(code.get(x));
                    return "In ACTIONSCRIPT, invalid values: '"+rem+"'";
                }
            }            
        }
		
		// If we are just repeating the last GOTO
		// treat it like a end-of-script
		if(repeatTo == currentOffset) {
			repeatTo = -1;
		}
		
		if(repeatTo>=0) {
			System.out.println(currentOffset+":"+repeatTo);
			int c = currentOffset-repeatTo+1; // Add another word for the GOTO itself			
			c = 0x1000 - c;
			if(c<0x800) {
				return "Can't reach REPEATTOHERE. SCROLLSCRIPT is too long.";
			}
			c = c | 0x1000;
			data.data.add(new Integer(c%256));
			data.data.add(new Integer(c/256));
		} else {
			data.data.add(new Integer(0xFF)); // Wait ... 
			data.data.add(new Integer(0x0F)); // ... 0_FFF
			data.data.add(new Integer(0xFE)); // GOTO ...
			data.data.add(new Integer(0x1F)); // ... 1_FFE (-2)
		}
		
		return "";
	}    
    
}
