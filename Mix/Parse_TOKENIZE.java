import java.util.List;
import java.util.Map;


public class Parse_TOKENIZE implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
		String ss = s.toUpperCase();

		if(ss.equals("TOKENIZE") || ss.startsWith("TOKENIZE ")) {
			s=s.substring(8).trim();
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("BUFFER",0);
            if(a==null) {
                return "Missing BUFFER value. Must be label in data section.";
            }
            Parse_TOKENIZE.NCOGCommand fc = new Parse_TOKENIZE.NCOGCommand(c,cluster);
			fc.buffer = a.value;
            a = aList.removeArgument("DICTIONARY",1);
            if(a==null) {
                return "Missing DICTIONARY value. Must be label in data section.";
            }
            fc.dictionary = a.value;
            a = aList.removeArgument("MAXTOKENS",2);
            if(a==null) {
                return "Missing MAXTOKENS value. Must be 1-15.";
            }
            if(!a.longValueOK || a.longValue<1 || a.longValue>15) {
                return "Invalid MAXTOKENS value '"+a.value+"'. Must be 1-15.";
            }
            fc.maxtokens = (int)a.longValue;
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
		String buffer;
		String dictionary;
		int maxtokens; 
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			//'' TOKENIZE buffer-input, dictionary, max-tokens
			//''   0_100_mmmm_bbbbbbbbbbbb_dddddddddddd
			
			int b = Command.findOffsetToLabel(super.cluster,buffer);
            if(b<0) {
                return "# Label '"+buffer+"' not found.";
            }
            int d = Command.findOffsetToLabel(super.cluster,dictionary);
            if(d<0) {
                return "# Label '"+dictionary+"' not found.";
            }
			
			String ret = "' "+codeLine.text+"\r\n";
	        
	        ret = ret+"  long %0_100_"+CodeLine.toBinaryString(maxtokens,4)+"_"+
	        CodeLine.toBinaryString(b,12)+"_"+
	        CodeLine.toBinaryString(d,12)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
