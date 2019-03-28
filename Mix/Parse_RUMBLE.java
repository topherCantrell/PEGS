import java.util.Map;


public class Parse_RUMBLE implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("RUMBLE") || ss.startsWith("RUMBLE ")) {
			s = s.substring(6).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("PLAYER1",0);
            Argument b = aList.removeArgument("PLAYER2",1);
            if(a==null && b==null) {
                return "Missing PLAYER1 and/or PLAYER2 values. Must be TRUE or FALSE (1 or 0).";
            }
            if(a!=null) {                
                if(!a.longValueOK || a.longValue<0 || a.longValue>1) {
                    return "Invalid PLAYER1 value '"+a.value+"'. Must be TRUE or FALSE (1 or 0).";
                }
            }
            if(b!=null) {
                if(!b.longValueOK || b.longValue<0 || b.longValue>1) {
                    return "Invalid PLAYER2 value '"+b.value+"'. Must be TRUE or FALSE (1 or 0).";
                }
            }
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            
            int i = cluster.lines.indexOf(c);
            if(a!=null && b!=null) {
                int val = (int)(a.longValue | (b.longValue>>8));
                CodeLine cc = new CodeLine(c.lineNumber,c.file,"MEM(M_RUMBLE1,WORD)="+val);                
                cluster.lines.add(i+1,cc);
                return "";
            }                    
            if(a!=null) {
                int val = (int)(a.longValue);
                CodeLine cc = new CodeLine(c.lineNumber,c.file,"MEM(M_RUMBLE1)="+val);                
                cluster.lines.add(i+1,cc);
                return "";
            }
            if(b!=null) {
                int val = (int)(b.longValue);
                CodeLine cc = new CodeLine(c.lineNumber,c.file,"MEM(M_RUMBLE2)="+val);                
                cluster.lines.add(i+1,cc);
                return "";
            }
            
        }
		
		return null;
	}
	
}
