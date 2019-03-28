import java.util.List;
import java.util.Map;


public class Parse_GETINPUTS implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) 
	{
		subs.put("M_KEYSTATES",  "0x7E2C");
		subs.put("M_GC1",        "0x7800");
		subs.put("M_GC2",        "0x7808");        
		subs.put("M_RUMBLE1",    "0x7E6C");
		subs.put("M_RUMBLE2",    "0x7E6D");
		subs.put("IN_LEFT",  "1");
		subs.put("IN_RIGHT", "2");
		subs.put("IN_DOWN",  "4");
		subs.put("IN_UP",    "8");
		subs.put("IN_Z",     "16");
		subs.put("IN_R",     "32");
		subs.put("IN_L",     "64");
		subs.put("IN_A",     "256");
		subs.put("IN_B",     "512");
		subs.put("IN_X",     "1024");
		subs.put("IN_Y",     "2048");
		subs.put("IN_START", "4096");
	}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("GETINPUTS") || ss.startsWith("GETINPUTS ")) {
			Parse_GETINPUTS.NCOGCommand fc = new Parse_GETINPUTS.NCOGCommand(c,cluster);
			s = s.substring(9).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            fc.player = 0;
            Argument a = aList.removeArgument("PLAYER",0);
            if(a!=null) {                
                if(!a.longValueOK || a.longValue<1 || a.longValue>2) {
                    return "Invalid PLAYER value '"+a.value+". Must be 1 or 2.";
                }
                fc.player = (int)a.longValue-1;
            }
            a = aList.removeArgument("VARIABLE",1);
            if(a==null) {
                return "Missing VARIABLE value. Must be "+Argument.validVariableForm+".";
            }
            if(!a.isVariable || !a.isVariableOK) {
                return "Invalid VARIABLE value '"+a.value+"'. Must be "+Argument.validVariableForm+".";
            }
            fc.variable = (int)a.longValue;						       
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
		int player;
		int variable;
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' GETINPUTS p,var
			//'' Get input for players based on input mode (keyboard or pads)
			//'' Return 16 bit format is: 000SYXBA0LRZudrl
			//''   0_110_p_000_00000000_00000000_vvvvvvvv
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_110_"+CodeLine.toBinaryString(player,1)+
	            "_000_00000000_00000000_"+CodeLine.toBinaryString(variable,8)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
