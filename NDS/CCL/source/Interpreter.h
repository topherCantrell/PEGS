#ifndef INTERPRETER_H_
#define INTERPRETER_H_

#include "DiskMgr.h"
#include "PadMgr.h"
#include "TileMgr.h"
#include "VariableMgr.h"

class Interpreter
{

	friend class DiskMgr;
	friend class PadMgr;
	friend class TileMgr;
	friend class VariableMgr;
    friend class Mgr;

    Mgr * cog[8];

	DiskMgr * diskMgr;
	VariableMgr * variableMgr;
    PadMgr * padMgr;

    int currentOffset;
    int currentCluster;
    unsigned char * currentClusterBase;

    void * lastResult;
    bool cogStatus;

    int stack[100];
    int stackPointer;
    

public:

	Interpreter();
	~Interpreter() {}

    bool run();

};

#endif
