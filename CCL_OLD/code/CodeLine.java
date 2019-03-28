package code;

import java.util.*;

/**
 * This class wraps all the information about a single line of CCL code.
 */
public class CodeLine
{
    
    public int lineNumber;       // The line number
    public String file;          // The file name
    public String orgText;       // The original unaltered text
    public String text;          // The text with substitutions made
    
    public int bracketLevel=-1;  // Bracket level used in decoding flow constructs   
    public int bracketType;      // 0=none, 1=close, 2=open
    
    public List<String> labels;  // All the labels attached to this line
    
    /**
     * This helper function converts a number to a binary string.
     * @param num the number
     * @len the number of bits in the final field
     * @return the binary string
     */
    public static String toBinaryString(int num, int len)
    {
        String ret = Integer.toString(num,2);
        while(ret.length()<len) ret="0"+ret;
        return ret;
    }
    
    /**
     * This helper function converts a number to an 8-digit hex string.
     * @param num the number to convert
     * @return the hex string
     */
    public static String toLongString(long num)
    {
        String ret = Long.toString(num,16).toUpperCase();
        while(ret.length()<8) ret="0"+ret;
        return ret;
    }
    
    /**
     * This helper functions parses a string number in possibly other
     * bases.
     * @param m the string
     * @return the converted number
     */
    public static long parseNumber(String m)
    {
        while(true) {
            int i = m.indexOf("_");
            if(i<0) break;
            String t = m.substring(0,i)+m.substring(i+1);
            m = t;
        }
        if(m.startsWith("'") && m.endsWith("'")) {
            // TOPHER ... /' and /n
            return m.charAt(1);
        }
        if(m.startsWith("0x") || m.startsWith("0X")) {
            return Long.parseLong(m.substring(2),16);
        }
        if(m.startsWith("0b") || m.startsWith("0B")) {
            return Long.parseLong(m.substring(2),2);
        }
        return Long.parseLong(m);
    }
    
    /**
     * This constructs a new CodeLine.
     * @param lineNumber the line number
     * @param file the file name
     * @param text the original (unaltered) text
     */
    public CodeLine(int lineNumber, String file, String text)
    {
        this.lineNumber = lineNumber;
        this.file = file;
        this.text = text;
        this.orgText = text;
        labels = new ArrayList<String>();
    }
    
    // For debugging
    public String toString()
    {
        char bt = ' ';
        if(bracketType==1) bt='}';
        if(bracketType==2) bt='{';
        String bl = ""+bracketLevel;
        if(bracketLevel<0) bl = "-";
        return bl+" "+bt+" "+file+":"+lineNumber+" "+text;//+" ("+orgText+")";
    }
    
}
