/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class ArgumentList {
    
    List<Argument> argList;
    
    /**
     * This constructs a new list of arguments by parsing the input string.
     * Arguments are separated by "," and we don't do string arguments. We
     * also make any text-substitutions BEFORE parsing the argument values.
     * @param text the input list of arguments
     * @param subs list of string pairs target/replace sorted with longest
     *             targets at the front of the list
     */
    public ArgumentList(String text, Map<String,String> subs) {
        argList = new ArrayList<Argument>();
        StringTokenizer st = new StringTokenizer(text,",");
        while(st.hasMoreTokens()) {                        
            argList.add(new Argument(st.nextToken().trim(),subs));
        }
    }
    
    /**
     * This function searches the list for a specific argument. It returns
     * the first argument in the list with the matching name or alternately
     * any unnamed argument at the given position. If in the alternate
     * case the requested position doesn't exist or has an argument with
     * a different name, NULL is returned.
     * @param name the desired argument's name
     * @param position alternately the unnamed argument's position
     * @return the desired argument or NULL
     */
    public Argument getArgument(String name, int position) {
        name = name.toUpperCase();
        // Search the list for a specific named argument
        for(int x=0;x<argList.size();++x) {
            Argument a = argList.get(x);
            if(a!=null && a.name.equals(name)) return a;
        }
        
        // If the position is not in the list return null
        if(position<0 || position>=argList.size()) return null;
        
        Argument a = argList.get(position);
        
        // If the argument at the requested position has a name return null
        if(a!=null && a.name.length()>0) return null;
        return a;
    }
    
    /**
     * This function duplicates the "getArgument" except that it removes the
     * argument from this list ... the argument is thus "consumed".
     */
    public Argument removeArgument(String name, int position) {
         name = name.toUpperCase();
        // Search the list for a specific named argument
        for(int x=0;x<argList.size();++x) {
            Argument a = argList.get(x);
            if(a!=null && a.name.equals(name)) {
                argList.set(x,null);
                return a;
            }
        }
        
        // If the position is not in the list return null
        if(position<0 || position>=argList.size()) return null;
        
        Argument a = argList.get(position);
        
        // If the argument at the requested position has a name return null
        if(a!=null && a.name.length()>0) return null;
        
        argList.set(position,null);
        
        return a;        
    }
    
    /**
     * This reports back any "unconsumed" arguments in the list ... those that
     * have not been "removeArgument"ed.
     * @return the report string or "" if all consumed
     */
    public String reportUnremovedValues() {
        StringBuffer sb = new StringBuffer();
        for(int x=0;x<argList.size();++x) {
            Argument a = argList.get(x);
            if(a==null) continue;
            if(!a.name.equals("")) {
                sb.append(a.name);
                sb.append("=");
            }
            sb.append(a.value);
            sb.append(",");            
        }        
        String ret = sb.toString();
        if(ret.equals("")) return ret;
        
        ret = sb.toString().substring(0,sb.length()-1);
        return ret;
    }
    
    /**
     * This returns the number of arguments in the list.
     * @return the number of arguments
     */
    public int getSize() {
        return argList.size();
    }
     
}