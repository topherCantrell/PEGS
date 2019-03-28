import java.awt.event.*;

/**
 * This key listener simulates the Playstation Pad bits as returned
 * by the CCL COG.
 */
public class GCPad implements KeyListener {
    
    public int keyPadValueA = 0;
    public int keyPadValueB = 0;
    
    // 000SYXBA|1LRZudrl|joyY|joyX
    // c-X|c-Y|L-Analog|R-Analog
    
    // 15   14   13   12   11 10    9    8        7  6  5  4  3  2 1 0
    // SLCT JOYR JOYL STRT UP RIGHT DOWN LEFT     L2 R2 L1 R1 /\ O X []
    
    public void keyTyped(KeyEvent e) {}
    
    public void keyPressed(KeyEvent e) {
        // 38=up, 40=down, 37=left, 39=right
        // CNTRL = 17, ALT=18,A=65, S=83, 1=49, 2=50,
        // L=76, R=82
        // Set specific bit
        switch(e.getKeyCode()) {
            case 38: // UP
                keyPadValueA |= 0x080000;
                break;
            case 40: // DOWN
                keyPadValueA |= 0x040000;
                break;
            case 37: // LEFT
                keyPadValueA |= 0x010000;
                break;
            case 39: // RIGHT
                keyPadValueA |= 0x020000;
                break;
            case 17: // CNTRL  /\
                keyPadValueA |= 0x02000000;
                break;
            case 32: // SPACE    O
                keyPadValueA |= 0x01000000;
                break;            
            case 49: // 1      Start
                keyPadValueA |= 0x10000000;
                break;           
        }
        //System.out.println(Integer.toString(keyPadValueA,16));
    }
    public void keyReleased(KeyEvent e) {
        // Clear specific bit
        switch(e.getKeyCode()) {
            case 38: // UP
                keyPadValueA &= ~0x080000;
                break;
            case 40: // DOWN
                keyPadValueA &= ~0x040000;
                break;
            case 37: // LEFT
                keyPadValueA &= ~0x010000;
                break;
            case 39: // RIGHT
                keyPadValueA &= ~0x020000;
                break;
            case 17: // CNTRL  /\
                keyPadValueA &= ~0x02000000;
                break;
            case 32: // SPACE    O
                keyPadValueA &= ~0x01000000;
                break;            
            case 49: // 1      Start
                keyPadValueA &= ~0x10000000;
                break;
            case 50: // 2      Select
                keyPadValueA &= ~0x010000;
                break;            
        }
    }
    
    
}
