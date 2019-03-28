import java.util.List;
import java.util.Map;


public class Parse_PAUSE implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("PAUSE") || ss.startsWith("PAUSE ")) {
            s = s.substring(5).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("TIME",0);
            if(a==null) {
                return "Missing TIME value.";
            }            
            if(!a.doubleValueOK || a.doubleValue<0.0) {
                return "Invalid TIME value '"+a.value+"'.";
            }
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            a.convertToStandardUnits();   
            // TODO this is MIX specific
            while(a.doubleValue>3.3554432) {
            	Parse_PAUSE.NCOGCommand fc = new Parse_PAUSE.NCOGCommand(c,cluster);
                fc.value = 0x0FFFFFFF;
                cluster.commands.add(fc);
                a.doubleValue = a.doubleValue - 3.3554432;
            }   
            Parse_PAUSE.NCOGCommand fc = new Parse_PAUSE.NCOGCommand(c,cluster);
            a.doubleValue = a.doubleValue * 80000000.0;
            fc.value = (int)Math.round(a.doubleValue);            
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
			
			//'' PAUSE t
			//'' Pause for t clock ticks. At 80MHz all ones is 3.3554432 seconds.
			//''   0_010_tttttttttttttttttttttttttttt
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_010_"+CodeLine.toBinaryString(value,28)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
