#include "VariableMgr.h"
#include "Interpreter.h"
#include <stdlib.h>

VariableMgr::VariableMgr(Interpreter * interpreter) : Mgr(interpreter) 
{
	for(int x=0;x<128;++x) variables[x]=0;
	srand(0);
}

void * VariableMgr::processCommand(int command[4], int data[4], unsigned char * ofs)
{

	// 1011:oooo MF AA BB

// Math:                  Ops:            Flags:
// 0000 +                 0000 =          ----abcd
// 0001 -                 0001 ==         a : 1 if B is used
// 0010 *   (FUTURE)      0010 !=         b : 1 if C is constant (0=var)
// 0011 /   (FUTURE)      0011 >          c : 1 if A is indirect
// 0100 PAU               0100 >=         d : 1 if B is indirect
// 0101 AND               0101 <
// 0110 OR                0110 <=
// 0111 NOT               0111 no-op
// 1000 <<
// 1001 >>
// 1010 RND

	int op = command[3] & 0x0F;
	int math = command[2]>>4;
	int flags = command[2]&0x0F;

	unsigned long con = (data[3]<<24) | (data[2]<<16) | (data[1]<<8) | data[0];

	int vnA = command[1];
	if( (flags&2)!=0 ) vnA = getVariable(vnA,false);
	unsigned long valA = getVariable(vnA,false);
	unsigned long valB = 0;
	if( (flags&8) !=0 ) {	
		int vnB = command[0];
		if( (flags&1)!=0 ) vnB = getVariable(vnB,false);
		valB = getVariable(vnB,false);
	}
	if( (flags&4) == 0) {
		con = getVariable(con,false);
	}

	switch(math) {
	case 0:
		valB = valB + con;
		break;
	case 1:
		valB = valB - con;
		break;
	case 4: 
		for(long x=0;x<con/120;++x) {
                  rand();
                }
		//printf("VariableMgr: PAUSE");
		break;
	case 5:
		valB = valB & con;
		break;
	case 6:
		valB = valB | con;
		break;
	case 7:
		valB = ~con;
		break;
	case 8:
		valB = valB << con;
		break;
	case 9:
		valB = valB >> con;
		break;
	case 10:
		valB = rand() & con;
		break;
	default:
		//printf("VariableMgr: Unknown math=%d\n",math);
		return 0;		
	}

	switch(op) {
	case 0:
		valA = valB;
		setVariable(vnA,false,valA);
		break;
	case 1:
		if(valA==valB) {
			valA = 1;
		} else {
			valA = 0;
		}
		break;
	case 2:
		if(valA!=valB) {
			valA = 1;
		} else {
			valA = 0;
		}
		break;
	case 3:
		if(valA>valB) {
			valA = 1;
		} else {
			valA = 0;
		}
		break;
	case 4:
		if(valA>=valB) {
			valA = 1;
		} else {
			valA = 0;
		}
		break;
	case 5:
		if(valA<valB) {
			valA = 1;
		} else {
			valA = 0;
		}
		break;
	case 6:
		if(valA<=valB) {
			valA = 1;
		} else {
			valA = 0;
		}
		break;
	case 7:
		valA = valB;
		break;
	default:
		//printf("VariableMgr: Unknown op=%d\n",op);
		return 0;
	}

	interpreter->cogStatus = 1;
	return (void *)valA;
}

void VariableMgr::setVariable(int variable, bool indirect, unsigned long value)
{
	if(indirect) {
		variables[variables[variable]] = value;
	}
	variables[variable] = value;
}

unsigned long VariableMgr::getVariable(int variable, bool indirect)
{
    interpreter->padMgr->getPadValues(&variables[126],&variables[127]);
	if(indirect) {
		return variables[variables[variable]];
	}
	return variables[variable];
}
