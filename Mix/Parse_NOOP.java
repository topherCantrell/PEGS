import java.util.List;
import java.util.Map;


public class Parse_NOOP implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("NOOP") || ss.startsWith("NOOP ")) {
			s=s.substring(4).trim();
			ArgumentList aList = new ArgumentList(s,subs);			        
			String rem = aList.reportUnremovedValues();
			if(rem.length()!=0) {
				return "Unexpected: '"+rem+"'";
			}
			Parse_NOOP.NCOGCommand fc = new Parse_NOOP.NCOGCommand(c,cluster);
			cluster.commands.add(fc);            
            return "";
        }
		
		return null;
	}

	static class NCOGCommand extends Command
	{
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' NOOP
			//'' Do nothing .
			//''   0_000_110_0000000000000000000000000
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_000_110_0000000000000000000000000\r\n";
	        
	        return ret;
	        
		}
		
	}

}
