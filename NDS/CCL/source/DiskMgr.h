#ifndef DISKMGR_H_
#define DISKMGR_H_

#include "Mgr.h"

class DiskMgr : public Mgr
{

    int numClusters;
    unsigned char * data;
	
public:

	DiskMgr(Interpreter * interpreter);

	virtual void * processCommand(int command[4], int data[4], unsigned char * ofs);

	unsigned char * loadCluster(long number);

	void stick(void * base);

};

#endif
