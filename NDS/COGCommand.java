
import java.io.*;
import java.util.*;

public class COGCommand extends Command 
{
        
    String paramA;
        
    int varA;
    int varB;
    int constant;
    int op;
    int math;
    boolean constIsVariable;
    
    boolean varAIsPtr;
    boolean varBIsPtr;
        
    public COGCommand(int id,String text)
    {
        super(id,text);
    }
    
    public int getBinarySize()
    {
        return 8;
    }
    
    int findOffsetToData(Cluster c, String label)
    {
        int ofs = 0;
        int co = CCL.findLabel(c,label);
        if(co<0) {
            throw new RuntimeException("Could not find label '"+label+"' in cluster '"+c.name+"'");
        }
        for(int x=0;x<co;++x) {
            Command cc = (Command)c.commands.get(x);
            ofs = ofs + cc.getBinarySize();
        }
        return ofs;
    }
    
    //String [] mset ={"RND","<<",">>","+","-","&","|","~","PAUSE"};    
    int [] matTrans = {10,8,9,0,1,5,6,7,4};

    //String [] oset = {"!=",">=","<=","==","<",">","="};
    int [] opTrans  = {2,4,6,1,5,3,0};    
    
    
    void writeBinary(Cluster c,OutputStream os, List allClusters) throws IOException
    {
        int ofs = 0;
        switch(id) {
            case 10: // variable                
                int flags = 0;
                if(varB>=0) flags = flags | 8;
                if(!constIsVariable) flags = flags | 4;
                if(varAIsPtr) flags = flags | 2;
                if(varBIsPtr) flags = flags | 1;
                int va = varA;
                int vb = varB;
                int con = constant;
                if (va<0) va=0;
                if (vb<0) vb=0;
                if (con<0) con = 0;
                int mathN = matTrans[math];
                int opN = 7;
                if(op>=0) {
                    opN = opTrans[op];
                }
                //System.out.println(text+">"+opN+":"+mathN+":"+flags+":"+va+":"+vb+"::"+ofs);
                                
                os.write(vb);
                os.write(va);
                os.write( (mathN<<4)|flags);
                os.write(0xB0 | opN);
                ofs = con;
                break;
            case 11: // print
                if(varA>=0) {
                                    
                    os.write(varA);
                    os.write(0);
                    os.write(0);
                    os.write(0x91);
                } else {
                                   
                    os.write(0);
                    os.write(0); 
                    os.write(0);
                    os.write(0x90); 
                }       
                ofs = findOffsetToData(c,paramA);
                break;
            case 12: // tokeninit
                               
                os.write(0);
                os.write(0); 
                os.write(0);
                os.write(0xA1); 
                ofs = findOffsetToData(c,paramA);
                break;
            case 13: // input
                //System.out.println(":"+paramA+":");
                StringTokenizer st= new StringTokenizer(paramA,",");
                int ff = Integer.parseInt(st.nextToken().trim().substring(1));
                int mt = Integer.parseInt(st.nextToken().trim());
                String lab = st.nextToken().trim();
                ofs = findOffsetToData(c,lab);
                int si = Integer.parseInt(st.nextToken().trim());
                
                os.write(mt);
                os.write(ff);
                os.write(0);
                os.write(0xA0); 
                ofs = ofs + (si<<16);
                break;
            case 14: // printvar
                                
                os.write(0);
                os.write(0);
                os.write(0);
                os.write(0x92);
                ofs = Integer.parseInt(paramA.substring(1));                
                break;
            case 20: // Stick
                                
                os.write(0);
                os.write(0);
                os.write(0);
                os.write(0x81);
                break;
                
            case 30: // readpad
                st= new StringTokenizer(paramA,",");
                int ms = Integer.parseInt(st.nextToken().trim());
                int ml = Integer.parseInt(st.nextToken().trim());
                ff = Integer.parseInt(st.nextToken().trim().substring(1));  
                               
                os.write(ff);
                os.write(ml); 
                os.write(ms);
                os.write(0xC0);
                break;    
                
            case 21: // SetTileData
                st= new StringTokenizer(paramA,",");
                int slo = Integer.parseInt(st.nextToken().trim());
                int num = Integer.parseInt(st.nextToken().trim());                
                int cmv = 0x98; //0x 1001 1000   
                
                os.write(num);
                os.write(slo);
                os.write(0);
                os.write(cmv);
                ofs = findOffsetToData(c,st.nextToken().trim());
                break;
                
            case 22: // SetTile
                st= new StringTokenizer(paramA,",");
                String vs = st.nextToken().trim();
                cmv = 0x99; //0x 1001 1001                
                if(vs.startsWith("V")) {                    
                    os.write(0);
                    os.write(0);
                    os.write(0x80 | Integer.parseInt(vs.trim().substring(1)));
                    os.write(cmv);
                } else {
                    int tx = Integer.parseInt(vs);
                    int ty = Integer.parseInt(st.nextToken().trim());
                    os.write(0);
                    os.write(ty);
                    os.write(tx);
                    os.write(cmv);
                    ofs = Integer.parseInt(st.nextToken().trim());
                }
                break;
                
            case 23: // TileBlock
                cmv = 0x9A; //0x 1001 1010
                st= new StringTokenizer(paramA,",");
                vs = st.nextToken().trim();
                if(vs.startsWith("V")) {
                    os.write(0);
                    os.write(0);
                    os.write(0x80 | Integer.parseInt(vs.trim().substring(1)));
                    os.write(cmv);
                } else {
                    int tx = Integer.parseInt(vs);
                    int ty = Integer.parseInt(st.nextToken().trim());
                    int wid = Integer.parseInt(st.nextToken().trim());
                    int hei = Integer.parseInt(st.nextToken().trim());
                    slo = Integer.parseInt(st.nextToken().trim());
                    os.write(0);
                    os.write(ty);
                    os.write(tx);
                    os.write(cmv); 
                    ofs = hei<<24 | wid << 16 | slo;
                }
                break;                
                
            case 24: // GetTile
                cmv = 0x9B; //0x 1001 1011
                st = new StringTokenizer(paramA,",");
                vs = st.nextToken().trim();
                if(vs.startsWith("V")) {
                    os.write(0);
                    os.write(0);
                    os.write(0x80 | Integer.parseInt(vs.trim().substring(1)));
                    os.write(cmv);
                } else {
                    int tx = Integer.parseInt(vs);
                    int ty = Integer.parseInt(st.nextToken().trim());   
                    os.write(0); 
                    os.write(ty);
                    os.write(tx);
                    os.write(cmv); 
                    ofs = Integer.parseInt(st.nextToken().substring(1));                  
                }
                break;                            
                
            case 25: // text
                cmv = 0x9C; //0x 1001 1100                
                st = new StringTokenizer(paramA,",");
                int tx = Integer.parseInt(st.nextToken().trim());
                int ty = Integer.parseInt(st.nextToken().trim());
                os.write(0); 
                os.write(ty);
                os.write(tx);
                os.write(cmv);
                ofs = findOffsetToData(c,st.nextToken().trim());
                break;      
                        
                
        }               
        
        os.write( (ofs) & 0xFF );
        os.write( (ofs>>8) & 0xFF );
        os.write( (ofs>>16) & 0xFF );
        os.write( (ofs>>24) & 0xFF );
    }

    public String toString()
    {
      String g = ":"+varA+":"+varB+":"+constant+":"+op+":"+math+":"+constIsVariable+":"+varAIsPtr+":"+varBIsPtr+":";
      return g;
    }
    
}
