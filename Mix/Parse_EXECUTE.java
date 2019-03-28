import java.util.List;
import java.util.Map;


public class Parse_EXECUTE implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("EXECUTE") || ss.startsWith("EXECUTE ")) {
			
			s = s.substring(7).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            
            Argument a = aList.removeArgument("COG",0);
            if(a==null) {
                return "Missing COG value. Must be 0-7.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>7) {
            	return "Invalid COG value '"+a.value+". Must be 0-7.";
            }
            Parse_EXECUTE.NCOGCommand fc = new Parse_EXECUTE.NCOGCommand(c,cluster);
            fc.cog = (int)a.longValue;
            a = aList.removeArgument("PAR",1);
            if(a==null) {
                return "Missing PAR value. Must be 0-0xFFFF.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>65535) {
            	return "Invalid PAR value '"+a.value+". Must be 0-0xFFFF.";
            }           
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            fc.par = (int)a.longValue;
            cluster.commands.add(fc);            
            return "";
        }
		
		return null;
	}

	static class NCOGCommand extends Command
	{
		
		int cog; 
		int par;
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' EXECUTE COG=c, PAR=p
			//'' Load the following binary data into COG c and execute it with
			//'' given PAR value. The binary code must follow the EXECUTE
			//'' command with a 4 byte gap between (usually an added STOP command).
			//'' An implicit RETURN is made after the EXECUTE command.
			//''   0_111_0000_00000ccc_pppppppp_pppppppp
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_111_0000_"+CodeLine.toBinaryString(cog,8)+"_"+
	            CodeLine.toBinaryString(par,16)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
