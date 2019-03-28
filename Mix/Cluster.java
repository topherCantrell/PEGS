/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

/**
 * This class wraps all the information about a single CCL cluster.
 */
public class Cluster
{
    
    public String name;                // The name of the cluster
    public List<CodeLine> lines;       // The text code lines of the cluster
    public List<Command> commands;  // The binary commands of the cluster
    
    /**
     * This constructs a new Cluster.
     * @param name the name of the cluster
     */
    public Cluster(String name)
    {
        this.name = name;
        this.lines = new ArrayList<CodeLine>();
        this.commands = new ArrayList<Command>();
    }    
    
}
