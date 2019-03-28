import java.util.List;
import java.util.Map;


public class Parse_MEMCOPY implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("MEMCOPY") || ss.startsWith("MEMCOPY ")) {
        	
        	s=s.substring(7).trim();
        	ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("SOURCE",0);
            if(a==null) {
            	return "Missing SOURCE value.";
            }            
            Parse_MEMCOPY.NCOGCommand fc = new Parse_MEMCOPY.NCOGCommand(c,cluster);
            fc.source = a.value;
            a = aList.removeArgument("DESTINATION",1);            
            if(!a.longValueOK || a.longValue<0 || a.longValue>511) {
                return "Invalid DESTINATION long address value '"+a.value+"'. Must be 0-511.";
            }
            fc.destination = (int)a.longValue;
            a = aList.removeArgument("LENGTH",2);
            if(a==null) {
            	return "Missing LENGTH value.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>511) {
                return "Invalid LENGTH (number of longs) value '"+a.value+"'. Must be 0-511.";
            }            
            fc.length = (int)a.longValue;
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
		String source;
		int destination;
		int length;
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' MEMCOPY SRC, DST, LEN
			//'' 0_110_0_nnnnnnnnn_sssssssss_ddddddddd
			
			int i = Command.findOffsetToLabel(super.cluster,source);
            if(i<0) {
                return "# Label '"+source+"' not found.";
            }
            if( (i%4)>0) {
            	return "# Label '"+source+"' not LONG aligned.";
            }
            i=i>>2;
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_110_0_"+CodeLine.toBinaryString(length,9)+"_"+
	          CodeLine.toBinaryString(i,9)+"_"+
	          CodeLine.toBinaryString(destination,9)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
