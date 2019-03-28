#ifndef MGR_H_
#define MGR_H_

class Interpreter;

class Mgr
{

protected:

	Interpreter * interpreter;

public:

	Mgr(Interpreter * interpreter) {this->interpreter = interpreter;}
	virtual ~Mgr() {}

	virtual void * processCommand(int command[4], int data[4], unsigned char * ofs);

};

#endif
