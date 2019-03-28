import java.util.List;
import java.util.Map;


public class Parse_RETURN implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("RETURN") || ss.startsWith("RETURN ")) {
            s = s.substring(6).trim();
            Parse_RETURN.NCOGCommand fc = new Parse_RETURN.NCOGCommand(c,cluster);
            ArgumentList aList = new ArgumentList(s,subs);
            
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
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
			
			//'' RETURN
			//'' Pop the cluster/offset from the call stack.
			//''   0_001_0000000000000000000000000000
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_001_0000000000000000000000000000\r\n";
	        
	        return ret;
	        
		}
		
	}

}
