import java.util.Map;


public class Parse_PADMODE implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) 
	{
		subs.put("M_INPUTMODE","0x7813");
	}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("PADMODE") || ss.startsWith("PADMODE ")) {
			s=s.substring(7).trim();
			ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("MODE",0);
            if(a==null) {
                return "Missing MODE value. Must be ONEPAD or TWOPADS.";
            }            
            int val=0;
            if(a.value.equals("ONEPAD")) {
                val = 1;
            } else if(a.value.equals("TWOPADS")) {
                val = 2;
            }
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"MEM(M_INPUTMODE)="+val);
            int i = cluster.lines.indexOf(c);
            cluster.lines.add(i+1,cc);
            return ""; 
        }
		
		return null;
	}
	
}
