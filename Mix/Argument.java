/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

/**
 * This class manages function arguments specified in multiple bases and units.
 * x=100
 * Frequency=440.5Hz
 * V120
 */
public class Argument {

    String orgCase; // For strings, we may want the original case
    String name;    // name=value ... this is the "name" part or "" if not given
    String value;   // name=value ... this is the raw "value" part, whatever
    String units;   // name=100Hz ... the is the "HZ" part if numeric and given
                    // * NOTE * Units can only be given to base 10 numbers
    
    boolean isVariable; // name=V123 ... this is TRUE if value is a variable
                        // and longValue will be "123" part
                        // * NOTE * Variables can only be specified in base 10
    boolean isVariableOK; // True if V0 - V127
    
    boolean doubleValueOK;  // True if the numeric value parses as a double
    double doubleValue;     // The parsed double value or 0.0
   
    boolean longValueOK;    // True if the numeric value parses as a long
    long longValue;         // The parsed long value or 0.0    
    
    static final String validVariableForm = "V0-V127"; // For error messages
    
    /**
     * This constructs an Argument by parsing the input string. Nothing can
     * really go wrong. An argument is acceptable no matter what it is though
     * we will decide if it is a variable or numeric here.
     */
    public Argument(String arg, Map<String,String> subs) {
        
        // We are case insensitive
        orgCase = arg;
        arg = arg.toUpperCase();
        
        // If this is a named value, peel the name
        int i = arg.indexOf("=");
        if(i>=0 && !arg.startsWith("\"")) {
            name = arg.substring(0,i).trim();
            arg = arg.substring(i+1);
            orgCase = orgCase.substring(i+1);
        } else {
            name = "";
        }
        
        // Everything else is the value
       
        if(subs!=null) {        	
            String rep = subs.get(arg.toUpperCase());
            //System.out.println("::"+arg+"::"+rep);
            if(rep!=null) {
                arg = rep.toUpperCase();
                orgCase = rep;
            }
        }
                
        value = arg;
        
        // Strip out "_" characters (spacers in numbers)
        while(true) {
            int k = arg.indexOf("_");
            if(k<0) break;
            String g = arg.substring(0,k)+arg.substring(k+1);
            arg = g;
        }
        
        // See if a base is specified (double constants are not allowed in other bases)
        int base=10;
        if(value.startsWith("0X")) {
            arg = arg.substring(2);
            base = 16;
            doubleValueOK = false;
        } else if(value.startsWith("0B")) {
            arg = arg.substring(2);
            base = 2;
            doubleValueOK = false;
        }
        
        if(value.startsWith("'") && value.endsWith("'")) {
            if(value.length()==3) {
                arg = Integer.toString(value.charAt(1));
                base = 10;
                doubleValueOK = false;
            }
        }
        
        // Decimals and units may only be used in base 10
        // Variable may only be referenced in base 10
        if(base==10) {
            // Peel off any units
            int j = arg.length();
            while(j>0) {
                if(arg.charAt(j-1)<'A' || arg.charAt(j-1)>'Z') {
                    break;
                }
                --j;
            }
            units = arg.substring(j);
            arg = arg.substring(0,j);
            
            // Variable reference
            if(units.length()==0 && arg.startsWith("V")) {
                isVariable = true;
                arg = arg.substring(1);
            }
            
            // Attempt conversion to double
            try {
                doubleValue = Double.parseDouble(arg);
                doubleValueOK = true;
            } catch (Exception e) {}
        }
        
        // Attempt conversion to long
        try {
            longValue = Long.parseLong(arg,base);
            longValueOK = true;
        } catch (Exception e) {}
        
        if(isVariable) {
            if(longValueOK && longValue>=0 && longValue<=127) {
                isVariableOK = true;
            }
        }
        
    }
    
    /**
     * This function converts numeric values from familar units back to
     * their "standard" units. If we don't recognize the units nothing
     * happens.
     */
    public void convertToStandardUnits() {
        if(units.equals("KHZ")) {
            doubleValue = doubleValue / 1000.0;
            longValue = longValue / 1000;
            units = "HZ";
        }
        if(units.equals("MHZ")) {
            doubleValue = doubleValue / 1000000.0;
            longValue = longValue / 1000000;
            units = "HZ";
        }
        if(units.equals("MS")) {
            doubleValue = doubleValue / 1000.0;
            longValue = longValue / 1000;
            units="S";
        }
    }
    
    /**
     * For testing.
     */
    public String toString() {
        return "name='"+name+"' value='"+value+"' units='"+units+
        "' longValueOK='"+longValueOK+"' longValue='"+longValue+
        "' doubleValueOK='"+doubleValueOK+"' doubleValue='"+doubleValue+
        "' isVariable='"+isVariable+"'" ;
    }
    
}
