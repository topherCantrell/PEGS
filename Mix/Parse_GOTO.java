import java.util.Map;


public class Parse_GOTO implements Parser
{
	
	Class<?> impl;
	
	public Parse_GOTO(int i, Class<?> impl)
	{
		this.impl = impl;
	}
	
	@Override
	public void addDefines(Map<String, String> subs) {}

	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs) throws InstantiationException, IllegalAccessException
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("GOTO") || ss.startsWith("GOTO ")) {
            s = s.substring(4).trim();
            Command_GOTO_MIX fc = (Command_GOTO_MIX)impl.newInstance();
            fc.setCodeLine(c);
            fc.setCluster(cluster);
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                if(!a.isVariableOK) {
                    return "Invalid VARIABLE value '"+a.value+". Must be "+Argument.validVariableForm+".";
                } 
                fc.varForm = (int)a.longValue; 
            } else {
                a = aList.removeArgument("LABEL",0);
                if(a==null) {
                    return "Missing LABEL value.";
                }
                fc.label = a.value;
            }
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            cluster.commands.add(fc);
            return "";
        }
		
		return null;
	}
	
}
