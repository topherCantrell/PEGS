#include "PadMgr.h"
#include "Interpreter.h"


#define BASE_IO       0x04000000

PadMgr::PadMgr(Interpreter * interpreter) : Mgr(interpreter)
{
}

void * PadMgr::processCommand(int command[4], int data[4], unsigned char * ofs)
{

	unsigned long valA, valB;

	if((command[3]&15)==0) {
		getPadValues(&valA,&valB);
		interpreter->variableMgr->setVariable(command[0],false,valA);
		interpreter->variableMgr->setVariable(command[0]+1,false,valB);        
		interpreter->cogStatus = true;
		return 0;
	}

	//printf("PadMgr: Unknown command %02x\n",command[0]);
	return 0;
}

void PadMgr::getPadValues(unsigned long * a, unsigned long * b)
{

	//  0 A       0x01000000
	//  1 B       0x02000000
	//  2 Select  ?
	//  3 Start   0x10000000
	//  4 Right   0x00020000
	//  5 Left    0x00010000
	//  6 Up      0x00080000
	//  7 Down    0x00040000
	//  8 R       0x00200000
	//  9 L       0x00400000
	//printf("PadMgr: getPadValues\n");
	volatile unsigned short * p = (volatile unsigned short *)BASE_IO;
	p = p + 0x130/2;
	unsigned long tmp = ~(*p);
	*a = 0;
	*b = 0;
	if( (tmp&1) )   *a=*a | 0x01000000;
	if( (tmp&2) )   *a=*a | 0x02000000;
	if( (tmp&3) )   *a=*a |   0x0;
	if( (tmp&8) )   *a=*a | 0x10000000;
	if( (tmp&16) )  *a=*a | 0x00020000;
	if( (tmp&32) )  *a=*a | 0x00010000;
	if( (tmp&64) )  *a=*a | 0x00080000;
	if( (tmp&128) ) *a=*a | 0x00040000;
	if( (tmp&256) ) *a=*a | 0x00200000;
	if( (tmp&512) ) *a=*a | 0x00400000;	
}
