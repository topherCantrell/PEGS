import java.util.*;

public class MusicParser
{

    // 4.C3#_
    static String mus = "C4 D4 E4 F4 G4 A4 B4 C5";
	
	NoteTable noteTable;
	
	public MusicParser(NoteTable noteTable)
	{
	  this.noteTable = noteTable;
	}
	
	public String parseMusic(String mus, List<Note> notes)
	{
	  int lastOctave = 4;
	  int lastLength = 4;
	  
	  StringTokenizer p = new StringTokenizer(mus," ");
	  while(p.hasMoreTokens()) {
	    String g = p.nextToken();
		System.out.println(noteTable.getCodeDelay(g));
	  }
	  return "";
	}	
	
	public static void main(String [] args) throws Exception
	{
	    MusicParser par = new MusicParser(new NoteTable(208,4));
		List<Note> notes = new ArrayList<Note>();
		par.parseMusic(mus,notes);
		
	}

}
