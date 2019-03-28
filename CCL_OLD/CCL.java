import java.io.*;
import java.util.*;

import flow.*;
import code.*;

public class CCL
{
    
    List<Cluster> clusters;     // List of clusters
    int autoVariable = 0;       // Track variable reservations
    List<String> defineKeys;    // List of define keys
    List<String> defineValues;  // List of define values
    List<COGCommand> parsers;   // List of parsers
    
    public static boolean printSPIN = true;
    
    public CCL()
    {
        clusters = new ArrayList<Cluster>();
        defineKeys = new ArrayList<String>();
        defineValues = new ArrayList<String>();
        parsers = new ArrayList<COGCommand>();
        
        parsers.add(new FlowCOGCommand(null,null));
        parsers.add(new VariableCOGCommand(null,null));       
        parsers.add(new VideoCOGCommand(null,null));
        parsers.add(new DiskCOGCommand(null,null));
        parsers.add(new SoundCOGCommand(null,null));
        
        // DataSection
        // DataCOGCommand should be added last. It assumes everything
        // was meant for it.
        parsers.add(new DataCOGCommand(null,null));
        
    }
    
    /**
     * This method parses an entire CCL application from the root file.
     * @param file the name of the root file
     * @returns error message or null if OK
     */
    public String parse(String file)
    {
        Cluster workCluster = new Cluster("");
        clusters.add(workCluster);
        String er = parse(file,workCluster);
        if(er!=null) {
            return er;
        }
        if(workCluster.lines.size()==0) {
            clusters.remove(0);
        }
        return null;
    }
    
    /**
     * This recursive method processes the lines from a single CCL file.
     * @param file name of single file to parse
     * @param workCluster the current cluster to add commands to
     * @returns error message or null if OK
     */
    String parse(String file, Cluster workCluster)
    {
        try {            
            int lineNumber = 0;
            Reader r = new FileReader(file);
            BufferedReader br = new BufferedReader(r);            
            while(true) {
                String g = br.readLine();
                ++lineNumber;
                if(g==null) break;
                g=g.trim();
                int i = g.indexOf("//");
                if(i>=0) {
                    // Ignore comments
                    g = g.substring(0,i).trim();
                }
                String cg = g.toUpperCase();      // Case doesn't matter in keywords                
                if(cg.length()==0) continue;      // Ignore blank lines
                if(cg.startsWith("CLUSTER")) {
                    g = g.substring(7).trim();
                    if(g.length()==0) {
                        return file+":"+lineNumber+" CLUSTER must have name";
                    }
                    // Start a new cluster
                    workCluster = new Cluster(g);
                    clusters.add(workCluster);                    
                    continue;
                }                
                // Includes are recursive calls
                if(cg.startsWith("INCLUDE")) {     
                    g = g.substring(7).trim();
                    String e = parse(g,workCluster);
                    if(e!=null) return e;
                    continue;
                }
                // Variables are "DEFINE"s with auto-values
                if(cg.startsWith("VARIABLE")) {
                    cg="DEFINE "+g.substring(8).trim()+"=V"+autoVariable;
                    ++autoVariable;
                    g = cg;
                }
                if(cg.startsWith("DEFINE")) {
                    i = g.indexOf("=");
                    if(i<0) {
                        return file+":"+lineNumber+" missing '=' in define";
                    }
                    String k = g.substring(6,i).trim();
                    String v = g.substring(i+1).trim();                    
                    if(v.length()==0) {                        
                        i = defineKeys.indexOf(k);
                        if(i>=0) {
                            // Empty value means remove
                            defineKeys.remove(i);
                            defineValues.remove(i);
                        }                       
                    } else {
                        // Sort by size to prevent partial substitution matches
                        i = 0;
                        for(int x=0;x<defineKeys.size();++x) {
                            if(defineKeys.get(x).length()<k.length()) {
                                i = x;
                                break;
                            }
                        }                        
                        defineKeys.add(i,k);
                        defineValues.add(i,v);
                    }
                    continue;
                }
                CodeLine cc = new CodeLine(lineNumber,file,g);
                // Do all substitutions
                for(int x=0;x<defineKeys.size();++x) {
                    i = g.indexOf(defineKeys.get(x));
                    if(i>=0) {
                        cc.text = g.substring(0,i)+defineValues.get(x)+g.substring(i+defineKeys.get(x).length());
                        g = cc.text;
                        x = -1;
                    }
                }

                workCluster.lines.add(cc);                          
            }            
        } catch (Exception e) {
            return e.getMessage();
        }        
        return null;        
    }
    
    String convertIfElse(Cluster c)
    {
        FlowPreprocessor fp = new FlowPreprocessor();
        String er = fp.markLevels(c);
        if(er!=null) return er;
        er = fp.loopsToIfs(c);
        if(er!=null) return er;
        er = fp.breaksContinuesToGotos(c);
        if(er!=null) return er;
        er = fp.ifBlockToIfGotos(c);
        if(er!=null) return er;
        
        // Find the end of the code section and add a STOP for good measure
        
        int datsec = 0;
        for(datsec = 0;datsec<c.lines.size();++datsec) {
            if(c.lines.get(datsec).text.toUpperCase().trim().equals("--DATA--")) {
                break; // This is the end of the code section
            }
        }
        c.lines.add(datsec,new CodeLine(0,"","STOP"));
        
        fp.attachLabels(c);
        return null;
    }
    
    String compile() {
        // - Convert the if/else constructs within each cluster
        
        for(int x=0;x<clusters.size();++x) {
            String er = convertIfElse(clusters.get(x));
            if(er!=null) {
                return er;
            }
        }        
                
        for(int x=0;x<clusters.size();++x) {
            Cluster clus = clusters.get(x);
            boolean inData = false;
            for(int y=0;y<clus.lines.size();++y) {
                CodeLine c = clus.lines.get(y);
                String ccom = c.text.toUpperCase().trim();
                if(ccom.equals("--DATA--")) {
                    inData = true;
                    continue;
                }
                String e = null;
                if(inData) {
                    if(ccom.endsWith("{")) {
                        List<CodeLine> struct = new ArrayList<CodeLine>();
                        ++y;
                        String type = ccom.substring(0,ccom.length()-1).trim();                        
                        DataCOGCommand dcc = new DataCOGCommand(c,clus);
                        while(true) {
                            if(y>=clus.lines.size()) {
                                e = "Missing '}' to close data structure '"+type+"'";
                                break;
                            }
                            c = clus.lines.get(y);
                            if(c.text.trim().equals("}")) {                                
                                for(int z=0;z<parsers.size();++z) {
                                    COGCommand par = parsers.get(z);
                                    e = par.processSpecialData(type,struct,dcc);
                                    if(e!=null) {
                                        c = dcc.getCodeLine();
                                        break;                                    
                                    }
                                }  
                                if(e==null) {
                                    e = "Unknown data structure '"+type+"'";  
                                    c = dcc.getCodeLine();
                                }
                                break;
                            }
                            struct.add(c);  
                            
                            ++y;
                        }                        
                        if(e!=null && e.length()==0) {
                            clus.commands.add(dcc);
                        }
                    }
                } else {
                    for(int z=0;z<parsers.size();++z) {
                        COGCommand par = parsers.get(z);
                        if(par.isData() == inData) {
                            e = par.parse(c,clus);
                            if(e!=null) break;
                        }
                    }
                }
                if(e==null) {
                    e = "Unknown Command";
                }
                if(e.length()>0) {
                    if(inData) {
                        return "## DataSection "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.orgText.trim();
                    } else {
                        return "## CodeSection "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.orgText.trim();
                    }                    
                }
            }
        }
        return null;
    }
    
    public String writeCCL(OutputStream os) throws IOException
    {
        PrintStream ps = new PrintStream(os);
        
        for(int x=0;x<defineKeys.size();++x) {
            ps.println("// :"+defineKeys.get(x)+":"+defineValues.get(x)+":");
        }
        
        for(int x=0;x<clusters.size();++x) {
            ps.println("CLUSTER "+clusters.get(x).name);
            for(int y=0;y<clusters.get(x).lines.size();++y) {
                CodeLine c = clusters.get(x).lines.get(y);
                for(int z=0;z<c.labels.size();++z) {
                    ps.println(c.labels.get(z)+":");
                }
                ps.println(c.text);
            }
        }
        
        ps.flush();
        
        return null;
    }
    
    public String writeSPIN(OutputStream os) throws IOException
    {
        PrintStream ps = new PrintStream(os);
        
        for(int x=0;x<clusters.size();++x) {
            ps.println("' Cluster '"+clusters.get(x).name+"'");            
            for(int y=0;y<clusters.get(x).commands.size();++y) {
                COGCommand cc = clusters.get(x).commands.get(y);
                CodeLine c = cc.getCodeLine();       
                String e = cc.toSPIN(clusters);
                if(e.startsWith("#")) {                    
                    return "## "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.orgText.trim();                    
                }
                for(int z=0;z<c.labels.size();++z) {
                    ps.println("' "+c.labels.get(z)+":");
                }                
                ps.println(e);
            }
        }
        ps.flush();
        return null;
    }
    
    public String writeBinary(OutputStream os) throws IOException
    {
        
        for(int x=0;x<clusters.size();++x) {
            int clusSize = 0;
            for(int y=0;y<clusters.get(x).commands.size();++y) {
                COGCommand cc = clusters.get(x).commands.get(y);
                CodeLine c = cc.getCodeLine();  
                int siz = cc.getSize();
                byte [] b = new byte[siz];
                String e = cc.toBinary(clusters,b);
                if(e!=null) {                    
                    return "## "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.orgText.trim();                    
                }
                os.write(b,0,siz);
                clusSize+=siz;
            }
            System.out.println("CLUSTER '"+clusters.get(x).name+"' "+clusSize+" bytes.");
            if(clusSize>2048) {
                return "# CLUSTER '"+clusters.get(x).name+"' exceeds 2048 bytes.";
            }
            while(clusSize<2048) {
                os.write(0);
                ++clusSize;
            }
        }
        return null;
    }
    
    public static void main(String [] args) throws Exception
    {
        
        // Make a parser object
        CCL ccl = new CCL();
        
        // Parse the root file
        String er = ccl.parse(args[0]);
        if(er!=null) {
            System.out.println(er);
            return;
        }
        
        er = ccl.compile();
        if(er!=null) {
            System.out.println(er);
            return;
        }
        
        if(args.length>2) {
            OutputStream oos = new FileOutputStream(args[2]);
            er = ccl.writeCCL(oos); 
            if(er!=null) {
                System.out.println(er);
                return;
            }            
        }
        
        if(args.length>3) {
            OutputStream oos = new FileOutputStream(args[3]);
            er = ccl.writeSPIN(oos);
            if(er!=null) {
                System.out.println(er);
                return;
            }            
        }        
         
        OutputStream os = new FileOutputStream(args[1]);
        er = ccl.writeBinary(os);
        os.flush();
        os.close();
        if(er!=null) {
            System.out.println(er);
            return;
        }        
        
    }
    
}