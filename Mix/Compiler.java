import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.PrintStream;
import java.io.Reader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.StringTokenizer;

public class Compiler 
{
	
	List<Cluster> clusters;     // List of clusters
    Map<String,String> subs;    // Map of define values
    List<Parser> codeParsers;   // List of code-section parsers
    List<Parser> dataParsers;   // List of data-section parsers
    List<DataStructureCommand> structureParsers;  // Special data structures
    
    boolean inCommentBlock; // True if ignoring lines
    String commentBlockStartFile;
    int commentBlockStartLineNumber;
    int autoVariable = 0;       // Track variable reservations  
    
    boolean multiClusters;
    boolean dataAllowed;    
    
    public Compiler(boolean multiClusters, boolean dataAllowed)
    {
    	this.multiClusters = multiClusters;
    	this.dataAllowed = dataAllowed;
    	
    	clusters = new ArrayList<Cluster>();
        subs = new HashMap<String,String>();
        structureParsers = new ArrayList<DataStructureCommand>();
        codeParsers = new ArrayList<Parser>();
        dataParsers = new ArrayList<Parser>();
    }
    
    public void addParser(Parser parser)
    {
    	codeParsers.add(parser);
    	parser.addDefines(subs);
    }
    
    public void addDataParser(Parser parser)
    {
    	dataParsers.add(parser);
    	parser.addDefines(subs);
    }
    
    public void addStructureParser(DataStructureCommand parser)
    {
    	structureParsers.add(parser);
    }
    
    static String convertIfElse(Cluster c)
    {
        // Flow processing ... the if/else/while/do magic
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
            if(c.lines.get(datsec).text.trim().startsWith("---")) {
                break; // This is the end of the code section
            }
        }
        c.lines.add(datsec,new CodeLine(0,"","STOP"));                
        fp.attachLabels(c);
        
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
                
                int sb = g.indexOf("/*");
                int eb = g.indexOf("*/");                
                if(sb>0) {
                    return file+":"+lineNumber+" '/*' must be the first thing on the line";
                }
                if(eb>0) {
                    return file+":"+lineNumber+" and '*/' must be the first thing on the line";
                }
                if(inCommentBlock && sb==0) {
                    return file+":"+lineNumber+" '/*' not allowed ... already inside a comment block "+commentBlockStartFile+":"+commentBlockStartLineNumber;
                }
                if(!inCommentBlock && eb==0) {
                    return file+":"+lineNumber+" '*/' not allowed ... not inside a comment block";
                }
                if(inCommentBlock) {
                    if(eb==0) {
                        inCommentBlock = false;
                        if(g.substring(2).trim().length()>0) {
                            return file+":"+lineNumber+" '*/' must be the only thing on the line";
                        }
                    }
                    continue;
                }
                if(sb==0) {
                    inCommentBlock = true;
                    commentBlockStartFile = file;
                    commentBlockStartLineNumber = lineNumber;
                    continue;
                }
                
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
                    g = g.substring(8).trim();
                    StringTokenizer st = new StringTokenizer(g,",");
                    while(st.hasMoreElements()) {
                        String k = st.nextToken().trim().toUpperCase();                        
                        String v = "V"+autoVariable;
                        ++autoVariable;
                        subs.put(k,v);
                    }
                    continue;
                }                
                
                // We'll manage defines here
                if(cg.startsWith("DEFINE")) {
                    i = g.indexOf("=");
                    if(i<0) {
                        return file+":"+lineNumber+" missing '=' in define";
                    }
                    String k = g.substring(6,i).trim().toUpperCase();
                    String v = g.substring(i+1).trim();                    
                    if(v.length()==0) {     
                    	subs.remove(k);                                         
                    } else {                        
                    	subs.put(k,v);  
                        //System.out.println("#"+k+"#"+v+"#");
                    }                     
                    continue;
                }
                 
                CodeLine cc = new CodeLine(lineNumber,file,g);
                
                workCluster.lines.add(cc);                          
            }            
        } catch (Exception e) {
            return e.getMessage();
        }        
        return null;        
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
        if(inCommentBlock) {
            return "Missing '*/' ... reached end of file inside a comment block "+commentBlockStartFile+":"+commentBlockStartLineNumber;
        }    
        
        /*
        if(clusters.size()>0 && clusters.get(0).lines.size()>0) {
            CodeLine g = clusters.get(0).lines.get(0);
            if(!g.text.toUpperCase().equals("INPUTDRIVER") && !g.text.toUpperCase().startsWith("INPUTDRIVER ")) {
                clusters.get(0).lines.add(0,new CodeLine(0,g.file,"INPUTDRIVER MODE=KEYBOARD"));
            }
        }
        */
        
        // Lines ending with "," are merged with the next line. Allows for
        // long parameter lists (like sprites) to span several lines.
        for(int y=0;y<clusters.size();++y) {
            for(int x=0;x<clusters.get(y).lines.size()-1;++x) {
                CodeLine c = clusters.get(y).lines.get(x);
                if(c.text.endsWith(",")) {
                    CodeLine cc = clusters.get(y).lines.get(x+1);
                    c.text = c.text + cc.text;
                    clusters.get(y).lines.remove(x+1);
                    --x;
                }
            }
        }
        
        return null;
    }
    
    
    String compile() 
    {
                       
        // - Convert the if/else constructs within each cluster        
        for(int x=0;x<clusters.size();++x) {
            String er = convertIfElse(clusters.get(x));
            if(er!=null) {
                return er;
            }
        }        
               
        // Process the individual lines in the code and data sections        
        for(int x=0;x<clusters.size();++x) {
            Cluster clus = clusters.get(x);
            boolean inData = false;
            for(int y=0;y<clus.lines.size();++y) {                
                CodeLine c = clus.lines.get(y);
                String ccom = c.text.toUpperCase().trim();
                if(ccom.startsWith("---")) {
                	if(!dataAllowed) {
                		return "Data sections not allowed";
                	}
                    inData = true;
                    continue;
                }
                
                String e = null;
                if(inData) {
                    if(ccom.endsWith("{") ) {
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
                                for(int z=0;z<structureParsers.size();++z) {
                                    DataStructureCommand par = structureParsers.get(z);
                                    e = par.processSpecialData(type,struct,dcc,subs);
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
                    } else {
                        for(int z=0;z<dataParsers.size();++z) {
                            Parser par = dataParsers.get(z);
                            try {
								e = par.parse(c,clus,subs);
							} catch (InstantiationException e1) {
								throw new RuntimeException(e1);
							} catch (IllegalAccessException e1) {
								throw new RuntimeException(e1);
							}
                            if(e!=null) break;                            
                        }
                    }
                    
                } else {
                    for(int z=0;z<codeParsers.size();++z) {
                        Parser par = codeParsers.get(z);                        
                        try {
							e = par.parse(c,clus,subs);
						} catch (InstantiationException e1) {
							throw new RuntimeException(e1);
						} catch (IllegalAccessException e1) {
							throw new RuntimeException(e1);
						}
                        if(e!=null) break;                        
                    }
                }
                if(e==null) {
                    e = "Unknown Command";
                }
                if(e.length()>0) {
                    if(inData) {
                        return "## "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.text;
                    } else {
                        return "## "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.text;
                    }                    
                }
            }
        }
         
        return null;
    }
    
    public String writeSPIN(PrintStream ps) throws IOException
    {   
        for(int x=0;x<clusters.size();++x) {
            ps.println("' Cluster '"+clusters.get(x).name+"'");     
            int ofs = 0;
            for(int y=0;y<clusters.get(x).commands.size();++y) {
               // ps.println("' @"+ofs+"    ("+(ofs/4)+")");                
                Command cc = clusters.get(x).commands.get(y);
                ofs = ofs + cc.getSize();
                CodeLine c = cc.getCodeLine();       
                String e = cc.toSPIN(clusters);
                if(e.startsWith("#")) {                    
                    return "## "+e+"\r\n"+c.file+":"+c.lineNumber+"\r\n"+c.text.trim();                    
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
    
    public String writeIntermediate(PrintStream ps,Compiler compiler) throws IOException
    {
        for(int x=0;x<compiler.clusters.size();++x) {
            ps.println("CLUSTER "+compiler.clusters.get(x).name);
            for(int y=0;y<compiler.clusters.get(x).lines.size();++y) {
                CodeLine c = compiler.clusters.get(x).lines.get(y);
                for(int z=0;z<c.labels.size();++z) {
                    ps.println(c.labels.get(z)+":");
                }
                ps.println(c.text);
            }
        }
        
        ps.flush();
        return null;
    }    

}
