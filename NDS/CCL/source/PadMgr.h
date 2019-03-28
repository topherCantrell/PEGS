#ifndef PADMGR_H_
#define PADMGR_H_

#include "Mgr.h"

class PadMgr : public Mgr
{

public:

	PadMgr(Interpreter * interpreter);

	virtual void * processCommand(int command[4], int data[4], unsigned char * ofs);

	void getPadValues(unsigned long * a, unsigned long * b);

};

#endif
