/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public interface Parser
{
    
    /**
     * This method parses the given code line and adds the resulting COGCommand(s)
     * to the cluster.
     * @param c the CodeLine to parse
     * @param cluster the CodeLine's container
     * @param defines the argument-replacement text
     * @return null if doesn't belong to us, "" if OK, or  message if parse error
     * @throws IllegalAccessException 
     * @throws InstantiationException 
     */
    public String parse(CodeLine c, Cluster cluster, Map<String,String> subs) throws InstantiationException, IllegalAccessException;
    
    /**
     * This method adds any system defines to the map of substitutions.
     * @param subs the map of substitutions
     */
    public void addDefines(Map<String, String> subs);
    
}

