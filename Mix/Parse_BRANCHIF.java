import java.util.List;
import java.util.Map;


public class Parse_BRANCHIF implements Parser
{
	
	public Parse_BRANCHIF(int i, Class<Command_BRANCHIF_CORE> class1) {
		// TODO Auto-generated constructor stub
	}

	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("BRANCH-IF") || ss.startsWith("BRANCH-IF ")) {
            s = s.substring(9).trim();
            Parse_BRANCHIF.NCOGCommand fc = new Parse_BRANCHIF.NCOGCommand(c,cluster);
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.removeArgument("LABEL",0);
            if(a==null) {
            	return "Missing LABEL value.";
            }
            fc.label = a.value;

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
		String label;
		
		public NCOGCommand(CodeLine line, Cluster clus) {
			super(line, clus);		
		}
		
		@Override
		public int getSize() {
			return 4;
		}

		@Override
		public String toSPIN(List<Cluster> clusters) {
			
			String cluster = Command.getCluster(label);
            String offset = Command.getOffset(label);            
			
			//'' BRANCH-IF c:o
			//'' Change program counter to offset o within cluster c if last COG.
			//'' command (usually a VariableCOG command) was non-zero.
			//''   0_000_011_cccccccccccccccc_ooooooooo
			
			Cluster clus = super.cluster;
			int clusNum = 0xFFFF;
	        int ofs = 0;
	        
	        String ret = "' "+codeLine.text+"\r\n";
	        
	        if(cluster.length()>0) {
	            clusNum=Command.findClusterNumber(cluster,clusters);
	            if(clusNum<0) {
	                return "# Cluster '"+cluster+"' not found.";
	            }
	            clus = clusters.get(clusNum);
	        }
	        
	        if(offset.length()>0) {            
	            ofs = Command.findOffsetToLabel(clus,offset);            
	            if(ofs<0) {
	                return "# Label '"+offset+"' not found.";
	            }
	        }
	        
			ofs = ofs/4;
	        ret = ret+"  long %0_000_011_"+CodeLine.toBinaryString(clusNum,16)+
	          "_"+CodeLine.toBinaryString(ofs,9)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
