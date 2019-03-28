package flow;

import java.util.*;
import code.*;

/**
 * This class holds all the information about a node in the expression
 * tree.
 */
class ExpressionNode {
    
    int id;                   // Used to make labels
    String expression;        // The expression at this node (term or operator)
    boolean connectedToLeft;  // True if connected to the left side of parent
    ExpressionNode parent;    // This node's parent
    ExpressionNode left;      // The child to the left (if any)
    ExpressionNode right;     // The child to the right (if any)    
    
    // These methods are used to navigate the expression tree for complex
    // expressions.
    
    int getStartBlockID() {
        if(!expression.equals("&&") && !expression.equals("||")) {
            return id;
        }
        return left.getStartBlockID();
    }
    
    int getTrueBlockID(ExpressionNode asker) {
        if(expression.equals("&&")) {
            if(asker==left) {
                return right.getStartBlockID();
            } else if(asker==right) {
                if(parent==null) return -1;
                return parent.getTrueBlockID(this);
            } else {
                throw new RuntimeException("Unknown asker for && TrueBlockID");
            }
        } else if(expression.equals("||")) {    
            if(asker==left || asker==right) {
                if(parent==null) return -1;
                return parent.getTrueBlockID(this);
            } else {
                throw new RuntimeException("Unknown asker for || TrueBlockID");
            }
        } else {
            if(parent==null) return -1;
            return parent.getTrueBlockID(this);
        }       
    } 
    
    int getFalseBlockID(ExpressionNode asker) {
        if(expression.equals("&&")) {
            if(asker==left || asker==right) {
                if(parent==null) return -2;
                return parent.getFalseBlockID(this);
            }  else {
                throw new RuntimeException("Unknown asker for && FalseBlockID");
            }
        } else if(expression.equals("||")) {    
            if(asker==left) {
                return right.getStartBlockID();
            } else if(asker==right) {
                if(parent==null) return -2;
                return parent.getFalseBlockID(this);
            } else {
                throw new RuntimeException("Unknown asker for || FalseBlockID");
            }
        } else {
            if(parent==null) return -2;
            return parent.getFalseBlockID(this);
        }       
    }
    
    String getLabel(int constructID)
    {
        return "_if_"+constructID+"_"+id;
    }
    
    void getCode(boolean polarity, int constructID, List<CodeLine> ret)
    {
        int tid = getTrueBlockID(this);
        int fid = getFalseBlockID(this);
        String tids = "_if_"+constructID+"_";
        String fids = tids;
        if(tid==-1) tids = tids+"true";
        else if(tid==-2) tids = tids+"false";
        else tids = tids+""+tid;
        
        if(fid==-1) fids = fids+"true";
        else if(fid==-2) fids = fids+"false";
        else fids = fids+""+fid;
        ret.add(new CodeLine(0,null,"_if_"+constructID+"_"+id+":"));
        if(polarity) {
            ret.add(new CodeLine(0,null,expression));
            ret.add(new CodeLine(0,null,"BRANCH-IF "+tids));
            ret.add(new CodeLine(0,null,"GOTO "+fids));
        } else {
            ret.add(new CodeLine(0,null,expression));
            ret.add(new CodeLine(0,null,"BRANCH-IFNOT "+fids));
            ret.add(new CodeLine(0,null,"GOTO "+tids));
        }
    }
}

/**
 * This class holds parsed strings from two terms separated by a
 * logic operation.
 */
class ExpressionLeftRightOpInfo
{
    String left;       // The string to the left of the operator
    String right;      // The string to the right of the operator
    String operator;   // The logic operator
}

/**
 * These static methods are used to parse a String logic expression into
 * a tree of terms and operators.
 */
public final class ExpressionParser
{
    
    /**
     * This method builds an expression tree from a complex expression.
     * @param result filled in with the resulting logic tree (first node is root)
     * @expression the complex logic expression to parse
     * @return error message or null if OK
     */
    public static String processExpression(List<ExpressionNode> result, String expression)
    {
        ExpressionNode root = new ExpressionNode();
        root.expression = expression;
        root.connectedToLeft = true;
        result.add(root);
        
        try {
            boolean changed = true;
            while(changed) {
                changed = false;
                for(int x=0;x<result.size();++x) {
                    ExpressionNode n = result.get(x);
                    boolean b = processExpressionNode(result,n);
                    if(b) {
                        changed=true;
                        break;
                    }
                }
            }
        } catch (Exception e) {
            return e.getMessage();
        }
        
        return null;
    }
    
    /**
     * This method turns the input node into a parent-and-two-children adding
     * the new children to the growing list of nodes.
     * @param master the list of nodes
     * @param node the node to expand
     */
    private static boolean processExpressionNode(List<ExpressionNode> master, ExpressionNode node) {
        
        String e = node.expression;
        
        // Don't do anything if this node has already been processed
        if(e.equals("||") || e.equals("&&")) {
            return false;
        }

        // Convert the String expression into left-operator-right form
        ExpressionLeftRightOpInfo pi = parseLogicConnector(e);        

        // Don't do anything if this node is a leaf 
        if(pi.right==null) {
            return false;
        }
                
        ExpressionNode nLeft = new ExpressionNode();
        ExpressionNode nRight = new ExpressionNode();
        
        nLeft.expression = pi.left;
        nLeft.connectedToLeft = true;
        nLeft.parent = node;
        
        nRight.expression = pi.right;
        nRight.connectedToLeft = false;
        nRight.parent = node;
        
        node.left = nLeft;
        node.right = nRight;
        
        node.expression = pi.operator;
        
        master.add(nLeft);
        master.add(nRight);
        
        return true;
        
    }
    
    /**
     * This method parses an expression of two entities separated by a
     * AND or OR connector.
     * @param expression the term to disect
     * @return the parsed information
     */
    private static ExpressionLeftRightOpInfo parseLogicConnector(String expression)
    {
        ExpressionLeftRightOpInfo ret = new ExpressionLeftRightOpInfo();
                
        String g = expression.trim();
        
        // Get the left hand term
        String a = parseTerm(g);        
        ret.left = a.trim();
        if(ret.left.startsWith("(")) {
            ret.left = ret.left.substring(1,ret.left.length()-1);
        }
        
        g = g.substring(a.length()).trim();
        
        if(g.length()==0) {
            return ret; // Just one term ... that's OK
        }
        
        // More ... it MUST be a logic connector
        if(g.startsWith("&&")) {
            ret.operator = "&&";
        } else if(g.startsWith("||")) {
            ret.operator = "||";
        } else {
            throw new RuntimeException("Expected '&&' or '||' :"+g);
        }        
        g = g.substring(2).trim();
        
        // If there was an operation, there MUST be a right-hand term
        a = parseTerm(g);
        ret.right = a.trim();
        if(ret.right.startsWith("(")) {
            ret.right = ret.right.substring(1,ret.right.length()-1);
        }
        
        // And that's all there can be
        g = g.substring(a.length()).trim();
        if(g.length()!=0) {
            throw new RuntimeException("Extra information: "+g);
        } 
        
        return ret;
        
    }          
    
     /**
     * This method parses out the expression term from the beginning
     * of the expression string. A term is either wrapped in
     * parenthesis or ends with a connector (&&, ||)
     * @param expression the expression to parse
     * @return the first term in the string
     */
    private static String parseTerm(String expression) 
    {
        if(!expression.startsWith("(")) {
            int i = expression.indexOf("&&");
            int j = expression.indexOf("||");
            if(i<0) i=j;
            if(j<0) j=i;
            if(j<i) i=j;
            if(i<0) return expression;
            return expression.substring(0,i);
        }
        int level = 0;
        for(int x=0;x<expression.length();++x) {
            if(expression.charAt(x)=='(') {
                ++level;
            } else if(expression.charAt(x)==')') {
                --level;
                if(level==0) {
                    return expression.substring(0,x+1);
                }
            }
        }
        throw new RuntimeException("Missing or extra parenthesis: "+expression);
    }        
    
}
