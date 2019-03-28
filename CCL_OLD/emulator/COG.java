
public abstract class COG {
    
    Emulator emu;
    
    public COG(Emulator emu) {this.emu = emu;}
    
    public abstract long [] execute(long [] data);
    
}