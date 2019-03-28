#include "DiskMgr.h"
#include "Interpreter.h"
//#include <stdio.h>

extern unsigned char DISK_DATA [];

DiskMgr::DiskMgr(Interpreter * interpreter) : Mgr(interpreter) 
{

	data = DISK_DATA;

	/*
    data = new unsigned char[2048];
    FILE * infile = fopen("f:\\article\\project\\DS.bin","rb");
    numClusters = 0;
    while(true) {
        int i = fread(data,2048,1,infile);
        if(i!=1) break;
        ++numClusters;
    }    

    data = new unsigned char[2048*numClusters];
    fclose(infile);
    infile = fopen("f:\\article\\project\\DS.bin","rb");
    fread(data,2048,numClusters,infile);
    fclose(infile);

    printf("DiskMgr: Loaded %d clusters from DS.bin\n",numClusters);
	*/

}

void * DiskMgr::processCommand(int command[4], int data[4], unsigned char * ofs)
{
	if( (command[3]&15) == 0) {
		interpreter->cogStatus = true;
		return loadCluster(data[2]*256+data[3]);
	} else if( (command[3]&15) == 1) {
		stick(ofs);
		interpreter->cogStatus = true;
		return 0;
	}

	//printf("DiskMgr: Unknown command %02x\n",command[0]);
	return 0;
}

unsigned char * DiskMgr::loadCluster(long number)
{
	unsigned char * ret = data;
	ret = ret + number * 2048;
	return ret;
}

void DiskMgr::stick(void * base)
{
	// Ignore this because everything is in memory
}
