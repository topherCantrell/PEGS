import java.util.List;
import java.util.Map;


public class Parse_DEBUG implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("DEBUG") || ss.startsWith("DEBUG ")) {
			s=s.substring(5).trim();
			ArgumentList aList = new ArgumentList(s,subs);
			Argument a = aList.removeArgument("LED",0);
			if(a==null) {
				return "Missing LED value. Must be TRUE or FALSE (1 or 0).";
			}      
			if(!a.longValueOK || a.longValue<0 || a.longValue>1) {
				return "Invalid LED value '"+a.value+"'. Must be TRUE or FALSE (1 or 0).";
			}            
			String rem = aList.reportUnremovedValues();
			if(rem.length()!=0) {
				return "Unexpected: '"+rem+"'";
			}
			Parse_DEBUG.NCOGCommand fc = new Parse_DEBUG.NCOGCommand(c,cluster);
			fc.value = (int)a.longValue;              
            cluster.commands.add(fc);            
            return "";
        }
		
		return null;
	}

	static class NCOGCommand extends Command
	{
		int value; 
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' DEBUG b
			//'' Turn debug light on (b=1) or off (b=0)
			//''   0_011_000000000000000000000000000b
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_010_"+CodeLine.toBinaryString(value,28)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
