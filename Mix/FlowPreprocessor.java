/**
 * Copyright (c) Chris Cantrell 2008
 * All rights reserved.
 * Part of the MIX compiler project for PEGSKIT. See http://www.pegskit.com. 
 */

import java.util.*;

public class FlowPreprocessor
{
    
    public void debugFlow(Cluster c)
    {
        for(int x=0;x<c.lines.size();++x) {
            CodeLine a = c.lines.get(x);
            System.out.println("::"+a.bracketType+":"+a.bracketLevel+":"+a.file+":"+a.lineNumber+":"+a.text+"::");
        }
    }
    
    public void attachLabels(Cluster c)
    {
        CodeLine current = null;
        for(int x=c.lines.size()-1;x>=0;--x) {
            CodeLine a = c.lines.get(x);
            if(a.text.endsWith(":") && a.text.indexOf(" ")<0 ) {
                c.lines.remove(x);
                String t = a.text.substring(0,a.text.length()-1).trim();
                if(current!=null) {
                    // Any pointless labels on the end get ignored
                    current.labels.add(t);
                }                                 
            } else {
                current = a;
            }
        }
    }
    
    public String ifBlockToIfGotos(Cluster c)
    {      
        int ifNumber = 1;        
        for(int x=0;x<c.lines.size();++x) {
            CodeLine co=c.lines.get(x);
            if(co.bracketType!=2) continue;            
            String ccom = co.text.toUpperCase();  
            String coorg = co.text;
            if(ccom.startsWith("---")) {
                break; // No code in t"+co.file+":"+co.lineNumber+"\r\n"+coorg;
            }
            ccom = co.text.substring(2,co.text.length()-1).trim();
            if(!ccom.startsWith("(")) {
                return "## Expected 'IF(exp) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;
            }
            if(!ccom.endsWith(")")) {
               return "## Expected 'IF(exp) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;
            }
            ccom = ccom.substring(1,ccom.length()-1).trim();
            
            // Find the ending bracket for the WHILE
            int j = x;
            while(j<c.lines.size()) {
              if((c.lines.get(j).bracketType==1) && (c.lines.get(j).bracketLevel==(co.bracketLevel+1))) break;
              ++j;
            }
            if(j==c.lines.size()) {
                return "## IF must be closed with a lone '}' line or '} else {'\r\n"+co.file+":"+
                    co.lineNumber+"\r\n"+coorg;                
            }
            CodeLine cj = c.lines.get(j);
            
            // If this is an ELSE, find the closing bracket.
            int jj=-1;
            if(cj.text.toUpperCase().indexOf("ELSE")>=0) {
                jj = j+1;
                while(jj<c.lines.size()) {
                    if((c.lines.get(jj).bracketType==1) && (c.lines.get(jj).bracketLevel==(co.bracketLevel+1))) break;
                    ++jj;
                }
                if(jj==c.lines.size()) {
                    return "## '} ELSE {' must be closed with a lone '}' line\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;                    
                }                
            }
                      
            // At this point:
            // - x is the IF line number (co)
            // - j is the close of the IF (cj)
            // - jj is the ELSE-IF close line (or -1 if none)
            
            if(jj>=0) {
                CodeLine cjj = c.lines.get(jj);
                cjj.text = "_if_"+ifNumber+"_end:"; 
                cjj.bracketLevel = -1;
                cjj.bracketType = 0;
                c.lines.add(j+1,new CodeLine(cj.lineNumber,cj.file,"_if_"+ifNumber+"_false:"));
                cj.text = "GOTO _if_"+ifNumber+"_end";
                cj.bracketLevel = -1;
                cj.bracketType = 0;
            } else {
                c.lines.add(j,new CodeLine(cj.lineNumber,cj.file,"_if_"+ifNumber+"_false:"));
                cj.text = "_if_"+ifNumber+"_end:";  
                cj.bracketLevel = -1;
                cj.bracketType = 0;
            }
            
            // Add the "true" block label
            co.text = "_if_"+ifNumber+"_true:";
            co.bracketLevel = -1;
            co.bracketType = 0;
            
            // Evaluate the expression
            List<CodeLine> expn = new ArrayList<CodeLine>();
            String er = resolveExpression(ccom,expn,ifNumber);
            if(er!=null) {
                return "## "+er+"\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;                                    
            }
            
            // Add the expression lines
            for(int y=expn.size()-1;y>=0;--y) {
                CodeLine cc = expn.get(y);
                cc.lineNumber = co.lineNumber;
                cc.file = co.file;
                c.lines.add(x,cc);
            }          
            
            // Add the "expression" label at the very top
            c.lines.add(x,new CodeLine(cj.lineNumber,cj.file,"_if_"+ifNumber+"_expression:")); 
            
            ++ifNumber;            
        }         
        
        //return "IfBlockToIfGotos Not Implemented";
        return null;
    }
    
    ExpressionNode findNodeByID(List<ExpressionNode> exp, int id)
    {  
        for(int x=0;x<exp.size();++x) {
            if(exp.get(x).id == id) {
                return exp.get(x);
            }
        }
        return null;
    }
        
    public String resolveExpression(String expression, List<CodeLine> result, int constructID)
    {
        // Convert the expression into a tree
        List<ExpressionNode> exp = new ArrayList<ExpressionNode>();
        String er = ExpressionParser.processExpression(exp,expression);
        if(er!=null) {
            return er;
        }
        
        // Count the terminal blocks and give them unique IDs for labels
        int numTerms = 0;
        for(int x=0;x<exp.size();++x) {
            ExpressionNode n = exp.get(x);            
            if(n.expression!="&&" && n.expression!="||") {
                n.id = numTerms+1;
                ++numTerms;            
            }
        }  
        
        // The first thing we do is the start block of the root node. Find
        // the root node.
        int rootID =exp.get(0).getStartBlockID();
        ExpressionNode rootNode = findNodeByID(exp,rootID);
        
        // All possible polarities of code blocks
        boolean [] pols = new boolean[numTerms];
        
        // This is the best we've done
        List<CodeLine> best = null;
                
        // while(true) ... We can try different orders of code blocks
        while(true) {
            
            // This is our current attempt
            List<CodeLine> tmp = new ArrayList<CodeLine>();
            // Goto the first block (probably get optimized out shortly)
            tmp.add(new CodeLine(0,null,"GOTO "+rootNode.getLabel(constructID)));
            
            // Run all code blocks
            int polCur = 0;
            for(int x=0;x<exp.size();++x) {
                if(exp.get(x).id<1) continue;
                exp.get(x).getCode(pols[polCur++],constructID,tmp);
            }
            
            // Remove any GOTO NEXT LINE
            for(int x=0;x<tmp.size()-1;++x) {
                CodeLine a = tmp.get(x);
                CodeLine b = tmp.get(x+1);
                if(a.text.startsWith("GOTO ")) {
                    String t = a.text.substring(5);
                    if(b.text.equals(t+":")) {
                        tmp.remove(x);
                    }
                }
            }
            
            // We know the TRUE block follows the expression so optimize out 
            // any GOTO to that on the end
            if(tmp.get(tmp.size()-1).text.equals("GOTO _if_"+constructID+"_true")) {
                tmp.remove(tmp.size()-1);
            }
            
            // If we did better this pass than the best, keep this
            if(best==null) {
                best = tmp;
            } 
            if(tmp.size()<best.size()) {
                    best = tmp;
            }            
            
            // Try next combination of polarities
            for(polCur=0;polCur<pols.length;++polCur) {
                if(!pols[polCur]) {
                    pols[polCur] = true;
                    break;
                }
                pols[polCur] = false;
            }
            
            // If we've tried them all, break out with the best
            if(polCur==pols.length) {
                break;
            }              
            
        }
        
        // Copy the best into the return result
        for(int x=0;x<best.size();++x) {
            result.add(best.get(x));
        }
        
        return null;
    }
    
    public String breaksContinuesToGotos(Cluster c)
    {
        List<String> loopStack = new ArrayList<String>();
        for(int x=0;x<c.lines.size();++x) {
            CodeLine co=c.lines.get(x);
            String ccom = co.text.toUpperCase();
            if(ccom.startsWith("--")) {
                break; // No code in the data section
            }
            if(ccom.startsWith("_LOOP_") && ccom.endsWith("_START:")) {
                loopStack.add(co.text.substring(0,co.text.length()-7));
            }
            if(ccom.startsWith("_LOOP_") && ccom.endsWith("_END:")) {
                loopStack.remove(loopStack.size()-1);
            }
            if(ccom.equals("BREAK")) {
                co.text = "GOTO "+loopStack.get(loopStack.size()-1)+"_end";
            } else if(ccom.equals("CONTINUE")) {
                co.text = "GOTO "+loopStack.get(loopStack.size()-1)+"_continue";
            }
        }
        return null;
    }
    
    public String loopsToIfs(Cluster c)
    {
        int loopNumber = 1;
        for(int x=0;x<c.lines.size();++x) {
            CodeLine co = c.lines.get(x);
            String coorg = co.text;
            String ccom = co.text.toUpperCase();
            if(ccom.startsWith("--")) {
                break; // No code in the data section
            }
            if(co.bracketType==2) {
                if(ccom.startsWith("WHILE")) {
                    if(ccom.charAt(5)!=' ' && ccom.charAt(5)!='(') continue;
                    // Check the WHILE statement for syntax errors
                    if(!co.text.endsWith("{")) {
                        return "## Must in with '{' like 'WHILE(exp) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;                        
                    }
                    String exp = co.text.substring(5,co.text.length()-1).trim();  
                    if(!exp.startsWith("(")) {
                        return "## WHILE must be followed by '(' like 'WHILE(exp) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;  
                    }
                    if(!exp.endsWith(")")) {
                        return "## WHILE expression must be followed by ')' like 'WHILE(exp) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;                          
                    }
                    exp = exp.substring(1,exp.length()-1);
                    // Find the ending bracket for the WHILE
                    int j = x;
                    while(j<c.lines.size()) {
                        if((c.lines.get(j).bracketType==1) && (c.lines.get(j).bracketLevel==(co.bracketLevel+1))) break;
                        ++j;
                    }
                    if(j==c.lines.size() || !c.lines.get(j).text.equals("}")) {
                        return "## WHILE must be closed with a lone '}' line\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;                          
                    }         
                    // This is the ending bracket line
                    CodeLine cj = c.lines.get(j);
                    
                    // Starting at the bottom, add a label for the end of the loop
                    c.lines.add(j+1,new CodeLine(cj.lineNumber,cj.file,"_loop_"+loopNumber+"_end:"));
                    // Add a GOTO back to the top of the loop                    
                    c.lines.add(j,new CodeLine(cj.lineNumber,cj.file,"GOTO _loop_"+loopNumber+"_start"));
                    // Change the WHILE to an IF (preserving the bracket type/level)
                    co.text="IF("+exp+") {";
                    // At the top, add a label above the top of the loop
                    c.lines.add(x,new CodeLine(co.lineNumber,co.file,"_loop_"+loopNumber+"_start:"));
                    c.lines.add(x,new CodeLine(co.lineNumber,co.file,"_loop_"+loopNumber+"_continue:"));
                    // Next loop ID
                    ++loopNumber;
                } else if(ccom.startsWith("DO")) {
                    if(ccom.charAt(2)!=' ' && ccom.charAt(5)!='{') continue;
                    String t = ccom.substring(0,ccom.length()-1).trim();
                    if(!t.equals("DO")) {
                        return "## Expected 'DO {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg; 
                    }
                    // Find the ending bracket for the WHILE
                    int j = x;
                    while(j<c.lines.size()) {
                        if((c.lines.get(j).bracketType==1) && (c.lines.get(j).bracketLevel==(co.bracketLevel+1))) break;
                        ++j;
                    }
                    // This is the ending bracket line
                    CodeLine cj = c.lines.get(j);
                    t = cj.text.substring(1).trim();
                    // Syntax check the while part
                    String ct = t.toUpperCase();
                    if(!ct.startsWith("WHILE")) {
                        return "## Expected '} WHILE(exp)'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;
                    }
                    ct = t.substring(5).trim();
                    if(!ct.startsWith("(")) {
                        return "## Expected '(' in '} WHILE(exp)'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;
                    }
                    if(!ct.endsWith(")")) {
                        return "## Expected ')' in '} WHILE(exp)'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;  
                    }
                    ct = ct.substring(1,ct.length()-1);
                    
                    // Change the "DO" to the label
                    co.text = "_loop_"+loopNumber+"_start:";   
                    co.bracketType = 0;
                    // Add a end label
                    c.lines.add(j+1,new CodeLine(cj.lineNumber,cj.file,"_loop_"+loopNumber+"_end:"));
                    // Add the if/goto
                    CodeLine cc = new CodeLine(cj.lineNumber,cj.file,"IF("+ct+") {");
                    cc.bracketLevel = cj.bracketLevel;
                    cc.bracketType = 2;
                    c.lines.add(j,cc);
                    c.lines.add(j+1,new CodeLine(cj.lineNumber,cj.file,"GOTO _loop_"+loopNumber+"_start"));
                    //cc = new CodeLine(cj.lineNumber,cj.file,"}");
                    //cc.bracketLevel = cj.bracketLevel+1;
                    //cc.bracketType = 1;
                    //c.lines.add(j+2,cc);
                    cj.text="}";
                    ++cj.bracketLevel;
                    cj.bracketType = 1;
                    c.lines.add(x,new CodeLine(co.lineNumber,co.file,"_loop_"+loopNumber+"_continue:"));
                    ++loopNumber;                    
                } else if(ccom.startsWith("FOR")) {
                    if(ccom.charAt(3)!=' ' && ccom.charAt(3)!='(') continue;
                    String t = co.text.substring(3,co.text.length()-1).trim();  
                    if(!t.startsWith("(") || !t.endsWith(")")) {
                        return "## xpected 'FOR(init;exp;inc) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;  
                    }
                    t=t.substring(1,t.length()-1);
                    StringTokenizer st=new StringTokenizer(t,";");
                    if(st.countTokens()!=3) {
                        return "## Expected 'FOR(init;exp;inc) {'\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg;
                    }       
                    String init = st.nextToken();
                    String exp = st.nextToken();
                    String inc = st.nextToken();                   
                    
                    // Find the ending bracket for the WHILE
                    int j = x;
                    while(j<c.lines.size()) {
                        if((c.lines.get(j).bracketType==1) && (c.lines.get(j).bracketLevel==(co.bracketLevel+1))) break;
                        ++j;
                    }
                    if(j==c.lines.size() || !c.lines.get(j).text.equals("}")) {
                        return "## FOR must be closed with a lone '}' line\r\n"+co.file+":"+co.lineNumber+"\r\n"+coorg; 
                    }    
                    // This is the ending bracket line
                    CodeLine cj = c.lines.get(j);
                    c.lines.add(j+1,new CodeLine(cj.lineNumber,cj.file,"_loop_"+loopNumber+"_end:"));
                    c.lines.add(j,new CodeLine(cj.lineNumber,cj.file,"GOTO _loop_"+loopNumber+"_start"));
                    c.lines.add(j,new CodeLine(cj.lineNumber,cj.file,inc));
                    c.lines.add(j,new CodeLine(cj.lineNumber,cj.file,"_loop_"+loopNumber+"_continue:"));
                    co.text="IF("+exp+") {";
                    c.lines.add(x,new CodeLine(cj.lineNumber,cj.file,"_loop_"+loopNumber+"_start:"));
                    c.lines.add(x,new CodeLine(cj.lineNumber,cj.file,init));
                    ++loopNumber;
                }
            }
        }
        return null;
    }
    
    public String markLevels(Cluster c)
    {
        int lev = 0;
        for(int x=0;x<c.lines.size();++x) {
            CodeLine co = c.lines.get(x);
            co.bracketLevel = lev;
            if(co.text.trim().startsWith("--")) {
                break; // No code in the data section
            }
            if(co.text.indexOf("{")>=0) {
                ++lev;
                co.bracketType = 2;
            }
            if(co.text.indexOf("}")>=0) {
                --lev;
                co.bracketType = 1;                
            }
            
            if(lev<0) {
                return "## Too many close brackets\r\n"+co.file+":"+co.lineNumber+"\r\n"+co.text; 
            }            
            
        }        
        if(lev>0) {
            return "Cluster "+c.name+" in "+c.lines.get(0).file+" Too many open brackets";
        }
        return null;
    }
    
}
