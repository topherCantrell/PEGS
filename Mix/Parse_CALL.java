import java.util.List;
import java.util.Map;


public class Parse_CALL implements Parser
{
	
	@Override
	public void addDefines(Map<String, String> subs) {}
	
	public String parse(CodeLine c, Cluster cluster, Map<String,String> subs)
	{
		
		String s = c.text;
        String ss = s.toUpperCase();
        
        if(ss.equals("CALL") || ss.startsWith("CALL ")) {
            s = s.substring(4).trim();
            Parse_CALL.NCOGCommand fc = new Parse_CALL.NCOGCommand(c,cluster);
            ArgumentList aList = new ArgumentList(s,subs);
            Argument a = aList.getArgument("VARIABLE",0);
            if(a!=null && a.isVariable) {
                if(!a.isVariableOK) {
                    return "Invalid VARIABLE value '"+a.value+". Must be "+Argument.validVariableForm+".";
                } 
                fc.varForm = (int)a.longValue; 
            } else {
                a = aList.removeArgument("LABEL",0);
                if(a==null) {
                    return "Missing LABEL value.";
                }
                fc.label = a.value;
            }
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
		int varForm=-1;
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
			
			//'' CALL Vn
			//'' Change program counter to offset o within cluster number stored in Vn.
			//'' The return cluster/offset is pushed onto call stack.
			//''   0_000_101_00000000_vvvvvvvv_ooooooooo
			
			//'' CALL c:o
			//'' Change program counter to offset o within cluster c.
			//'' The return cluster/offset is pushed onto call stack.
			//''   0_000_001_cccccccccccccccc_ooooooooo
			
			String cluster = Command.getCluster(label);
            String offset = Command.getOffset(label);             
			
			Cluster clus = super.cluster;
			int clusNum = 0xFFFF;
	        int ofs = 0;
	        
	        String ret = "' "+codeLine.text+"\r\n";
	        
	        if(varForm>=0) {
	        	ofs = ofs/4;
	            ret = ret+"  long %0_000_101_"+CodeLine.toBinaryString(clusNum,16)+
	              "_"+CodeLine.toBinaryString(ofs,9)+"\r\n";
	            return ret;
	        }
	        
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
	        ret = ret+"  long %0_000_001_"+CodeLine.toBinaryString(clusNum,16)+
	          "_"+CodeLine.toBinaryString(ofs,9)+"\r\n";
	        
	        return ret;
	        
		}
		
	}

}
