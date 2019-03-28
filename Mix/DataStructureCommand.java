/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public interface DataStructureCommand
{
    
    /**
     * Processes any special data structure (Sprites, Waveforms, Sequences).
     * @param type the type from the structure
     * @param code the list of lines from the cluster
     * @param data the data command to fill out
     * @param defines the argument-replacement text
     */
    public String processSpecialData(String type, List<CodeLine> code, DataCOGCommand data, Map<String,String> defines);
    
}
