import java.util.List;
import java.util.Map;


public class Parse_SAVEVARIABLES implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("SAVEVARIABLES") || ss.startsWith("SAVEVARIABLES ")) {
			Parse_SAVEVARIABLES.NCOGCommand fc = new Parse_SAVEVARIABLES.NCOGCommand(c,cluster);
			s=s.substring(13).trim();
            ArgumentList aList = new ArgumentList(s,null);
            Argument a = aList.removeArgument("BUFFER",0);
            if(a==null) {
                return "Missing BUFFER value. Must be label in data section.";
            }
            fc.buffer = a.value;
            a = aList.removeArgument("START",1);
            if(a==null) {
                return "Missing START value. Must be "+Argument.validVariableForm+".";
            }
            if(!a.isVariable || !a.isVariableOK) {
                return "Invalid START value '"+a.value+"'. Must be "+Argument.validVariableForm+".";
            }
            fc.start = (int)a.longValue;
            a = aList.removeArgument("COUNT",2);
            if(a==null) {
                return "Missing COUNT value. Must be 0-127.";
            }
            if(!a.longValueOK || a.longValue<0 || a.longValue>127) {
                return "Invalid COUNT value '"+a.value+"'. Must be 0-127.";
            }
            fc.count = (int)a.longValue;
            String rem = aList.reportUnremovedValues();
            if(rem.length()!=0) {
                return "Unexpected: '"+rem+"'";
            }
            int i = cluster.lines.indexOf(c);
            CodeLine cc = new CodeLine(c.lineNumber,c.file,"WRITE");
            cluster.lines.add(i+1,cc);            
            cluster.commands.add(fc);
            return "";
        }
		
		return null;
	}

	static class NCOGCommand extends Command
	{
		String buffer;
		int start;
		int count;
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' SAVEVARIABLES BUFFER=b, START=Vs, COUNT=n
			//'' Write n variables, starting with Vs, to the current cluster at offset b.
			//'' This command is usually followed by a DiskCOG WRITE. 
			//''   0_101_1_nnnnnnnn_ssssssss_bbbbbbbbbbb
			
			String ret = "' "+codeLine.text+"\r\n";
			
			int b = Command.findOffsetToLabel(super.cluster,buffer);
            if(b<0) {
                return "# Label '"+buffer+"' not found.";
            }
	        
	        ret = ret+"  long %0_101_1"+CodeLine.toBinaryString(count,8)+"_"+
	        CodeLine.toBinaryString(start,8)+"_"+
	        CodeLine.toBinaryString(b,12)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
