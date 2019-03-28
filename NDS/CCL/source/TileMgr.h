#ifndef TILEMGR_H_
#define TILEMGR_H_

#include "Mgr.h"

class TileMgr : public Mgr
{

	
public:

	TileMgr(Interpreter * interpreter);
	
	virtual void * processCommand(int command[4], int data[4], unsigned char * ofs);

    void convertTileData(unsigned char b, unsigned short * d1, unsigned short *d2);
	void setTileData(int slot, int number, unsigned char * data);
	void setTile(int x, int y, unsigned short tile);
	unsigned short  getTile(int x, int y);
	void tileBlock(int x, int y, int width, int height, unsigned short tile);
	void tileText(int x, int y, unsigned char * data);
	
};

#endif
