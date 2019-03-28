#ifndef VARIABLEMGR_H_
#define VARIABLEMGR_H_

#include "Mgr.h"

class VariableMgr : public Mgr
{

	unsigned long variables[128];

public:

	VariableMgr(Interpreter * interpreter);

	virtual void * processCommand(int command[4], int data[4], unsigned char * ofs);

	void setVariable(int variable, bool indirect, unsigned long value);

	unsigned long getVariable(int variable, bool indirect);

};


#endif
