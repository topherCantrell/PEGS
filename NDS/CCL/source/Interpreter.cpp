#include "Interpreter.h"

#include "TileMgr.h"

extern unsigned char DISK_DATA [];

Interpreter::Interpreter()
{
    for(int x=0;x<8;++x) {
        cog[x] = 0;
    }

	// COGs common to both article
	cog[0] = diskMgr = new DiskMgr(this);    
    cog[3] = variableMgr = new VariableMgr(this);
	
	// First article configuration	
	//cog[1] =  new PrintMgr(this); 
	//cog[2] = new LineInputMgr(this);
	
	// Second article configuration
	cog[1] = new TileMgr(this);
	cog[4] = padMgr = new PadMgr(this);	
	//cog[5] = new SoundMgr(this);

	
    currentCluster = 0;
    currentOffset = 0;
    currentClusterBase = diskMgr->loadCluster(0);

    stackPointer = 0;

}

bool Interpreter::run()
{
    int command[4];
    int data[4];

    for(int x=0;x<4;++x) {
        command[x] = currentClusterBase[currentOffset+x];
    }

	if(command[3]>=0x80) {
        for(int x=0;x<4;++x) {
            data[x] = currentClusterBase[currentOffset+4+x];
        }
        //printf("::%02x:%02x:%02x:%02x::::%02x:%02x:%02x:%02x::\n",
        //    command[0],command[1],command[2],command[3],
        //    data[0],data[1],data[2],data[3]);
        int c = (command[3]>>4)&7;
		if(cog[c]==0) {
            //printf("Interpreter:NoCOGRegistered slot=%d\n",c);
            return false;
        }
        cogStatus = false;
        lastResult = cog[c]->processCommand(command,data,currentClusterBase);  
        if(!cogStatus) {
            //printf("Interpreter: COG reports error.\n");
            return false;
        }
        currentOffset+=8;
    } else {
        currentOffset += 4;

        //printf("::%02x:%02x:%02x:%02x::\n",command[0],command[1],command[2],command[3]);

        int com = command[3]>>4;
        int off = (command[3]&15)*256+command[2];
        int clus = command[1]*256 + command[0];

        switch(com) {

        case 2: // GOTO
            if(clus!=0xFFFF) {
                currentCluster = clus;
                currentClusterBase = diskMgr->loadCluster(currentCluster);
            }
            currentOffset = off;
            break;
        case 3: // CALL
            stack[stackPointer++] = currentCluster;
            stack[stackPointer++] = currentOffset;
            if(clus!=0xFFFF) {
                currentCluster = clus;
                currentClusterBase = diskMgr->loadCluster(currentCluster);
            }
            currentOffset = off;
            break;
        case 4: // RETURN
            currentOffset = stack[--stackPointer];
            currentCluster = stack[--stackPointer];
            currentClusterBase = diskMgr->loadCluster(currentCluster);
            break;
		case 1: // IF
			run(); // Process the VariableMgr command
			if(lastResult==0) {
				if(clus!=0xFFFF) {
					currentCluster = clus;
					currentClusterBase = diskMgr->loadCluster(currentCluster);
				}
				currentOffset = off;				
			}
			break;
        default:
            //printf("Interpreter: UnknownInterpreterCommand %02x\n",command[0]);
            return false;

        }
        
    }

    return true;
    
}
