import java.util.List;
import java.util.Map;


public class Parse_GETJOYSTICK implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) 
	{
		// TODO Some of these are wrong. Sort them out.
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

		if(ss.equals("GETJOYSTICK") || ss.startsWith("GETJOYSTICK ")) {
			Parse_GETJOYSTICK.NCOGCommand fc = new Parse_GETJOYSTICK.NCOGCommand(c,cluster);
			s = s.substring(9).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("VARIABLE",1);
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
			
			//'' GETJOYSTICK Vn
			//'' Read the joystick/button inputs to the given variable.
			//'' Return format in Vn: 000S000F0rsudrl
			//''   0_110_0000_00000000_0000_vvvvvvvv
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_110__0000_00000000_00000000_"+
	            CodeLine.toBinaryString(variable,8)+"\r\n";
	        
	        return ret;	        
		}
		
	}

}
