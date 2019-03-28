import java.util.List;
import java.util.Map;


public class Parse_STOP implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("STOP") || ss.startsWith("STOP ")) {
            s = s.substring(4).trim();
            Parse_STOP.NCOGCommand fc = new Parse_STOP.NCOGCommand(c,cluster);
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
			
			//'' STOP
			//'' Halt the program with an infinite loop.
			//''   0_000_111_0000000000000000000000000
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_000_111_0000000000000000000000000\r\n";
	        
	        return ret;
	        
		}
		
	}

}
