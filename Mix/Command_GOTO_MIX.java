import java.util.List;


public class Command_GOTO_MIX extends Command
{
	int varForm=-1;
	String label;
	
	public Command_GOTO_MIX() {}
	
	public Command_GOTO_MIX(CodeLine line, Cluster clus) {
		super(line, clus);		
	}
	
	@Override
	public int getSize() {
		return 4;
	}

	@Override
	public String toSPIN(List<Cluster> clusters) {
		
		//'' GOTO Vn
		//'' Change program counter to offset o within cluster number stored in Vn.
		//''   0_000_100_00000000_vvvvvvvv_ooooooooo
		
		//'' GOTO c:o
		//'' Change program counter to offset o within cluster c.
		//''   0_000_000_cccccccccccccccc_ooooooooo
		
		String cluster = Command.getCluster(label);
        String offset = Command.getOffset(label);            
		
		Cluster clus = super.cluster;
		int clusNum = 0xFFFF;
        int ofs = 0;
        
        String ret = "' "+codeLine.text+"\r\n";
        
        if(varForm>=0) {
        	ofs = ofs/4;
            ret = ret+"  long %0_000_100_"+CodeLine.toBinaryString(clusNum,16)+
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
        ret = ret+"  long %0_000_000_"+CodeLine.toBinaryString(clusNum,16)+
          "_"+CodeLine.toBinaryString(ofs,9)+"\r\n";
        
        return ret;
        
	}

}
