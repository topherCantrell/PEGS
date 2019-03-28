#include "TileMgr.h"
#include "Interpreter.h"

// Tiles come in from storage as bytes like this:
// DCBA 
// Where A,B,C,D are the pixels from left to right.

#define BASE_IO       0x04000000
#define BASE_COLORS   0x05000000
#define BASE_MAP      0x06004000
#define BASE_TILE     0x06000000

extern unsigned char DISK_DATA [];

TileMgr::TileMgr(Interpreter * interpreter) : Mgr(interpreter)
{
	int x;	
	volatile unsigned short * p;

	// Color map like the propeller scheme
	p = (volatile unsigned short *)BASE_COLORS;
	p[0]=0;	
	p[1]=0x7FFF; // White
    p[2]=0x03E0; // Green
	p[3]=0x001F; // Red	

	// Set tile 0 to blank
	p = (volatile unsigned short *)BASE_TILE;
	for(x=0;x<32;++x) {
		p[x]=0;		
	}	

	// Map all tiles to blank
	p = (volatile unsigned short *)BASE_MAP;	
	for(x=0;x<32*32;++x) {
		p[x] = 0;
	}
	
	// Configure the LCD and background 2
	p = (volatile unsigned short *)BASE_IO;	
	p[0] = 0x0400; // LCD
	p[6] = 0xA880; // BG2

}

void * TileMgr::processCommand(int command[4], int data[4], unsigned char * ofs)
{

	int t;
	int x,y,width,height;
			
	switch(command[3]&15) {

	case 8:
		x = command[1];
		y = command[0];		
		// NO INDIRECT MODE FOR SETTILEDATA
		ofs = ofs + data[1]*256;
		ofs = ofs + data[0];
		setTileData(x,y,ofs);
		interpreter->cogStatus = true;
		return 0;
	case 9:
		x = command[2];
		y = command[1];
		t = data[1]*256+data[0];
		if(x>=128) {			
			y = interpreter->variableMgr->getVariable((x+1)&127,false);
			t = interpreter->variableMgr->getVariable((x+2)&127,false);
			x = interpreter->variableMgr->getVariable(x&127,false);			
		}		
		setTile(x,y,t);
		interpreter->cogStatus = true;
		return 0;
	case 10:
		x = command[2];
		y = command[1];
		t = data[1]*256+data[0];
		width = data[2];
		height = data[3];
		if(x>=128) {			
			y = interpreter->variableMgr->getVariable((x+1)&127,false);
			width = interpreter->variableMgr->getVariable((x+2)&127,false);
			height = interpreter->variableMgr->getVariable((x+3)&127,false);
			t = interpreter->variableMgr->getVariable((x+4)&127,false);
			x = interpreter->variableMgr->getVariable(x&127,false);			
		}	
		tileBlock(x,y,width,height,t);		
		interpreter->cogStatus = true;
		return 0;
	case 11:
		x = command[2];
		y = command[1];
		width = data[0];
		if(x>=128) {
			y = interpreter->variableMgr->getVariable((x+1)&127,false);
			width = ((x+2)&127);
			x = interpreter->variableMgr->getVariable(x&127,false);					
		}
		t = getTile(x,y);
		interpreter->variableMgr->setVariable(width,false,t);
		interpreter->cogStatus = true;
		return 0;
	case 12:
		x = command[2];
		y = command[1];
		if(x>=128) {			
			y = interpreter->variableMgr->getVariable((x+1)&127,false);
			x = interpreter->variableMgr->getVariable(x&127,false);			
		}
		ofs = ofs + data[1]*256;
		ofs = ofs + data[0];
		tileText(x,y,ofs);
		interpreter->cogStatus = true;
		return 0;

	default:
		//printf("TileMgr: Unknown command %02x\n",command[0]);
		return 0;
	}	
	
	
}

// Read one byte then call this ... do 16 times (returns 2 unsigned shorts = 32 shorts or 64 bytes)
void TileMgr::convertTileData(unsigned char b, unsigned short * d1, unsigned short *d2)
{
   int p1 = b&0x03;
   int p2 = (b>>2)&0x03;
   int p3 = (b>>4)&0x03;
   int p4 = (b>>6)&0x03;
   (*d1) = (p2<<8) | p1;
   (*d2) = (p4<<8) | p3;
}

void TileMgr::setTileData(int slot, int num, unsigned char * data)
{
	// One byte per pixel = 64 bytes (32 shorts)
	unsigned short d1,d2;
	volatile unsigned short * base = (volatile unsigned short *)BASE_TILE;
	base = base + 32*slot;	
	for(int x=0;x<num*16;++x) {
		convertTileData(data[x],&d1,&d2); // 4 bit-pairs to 4 bytes
		base[x*2] = d1;
		base[x*2+1] = d2;
	}
}

void TileMgr::setTile(int x, int y, unsigned short tile)
{
	volatile unsigned short * base = (volatile unsigned short *)BASE_MAP;
	base[y*32+x] = tile;
}

unsigned short TileMgr::getTile(int x, int y)
{
	volatile unsigned short * base = (volatile unsigned short *)BASE_MAP;
	return base[y*32+x];
}

void TileMgr::tileBlock(int x, int y, int width, int height, unsigned short tile)
{
	for(int yy=0;yy<height;++yy) {
		for(int xx=0;xx<width;++xx) {
			setTile(x+xx,y+yy,tile);
		}
	}
}

void TileMgr::tileText(int x, int y, unsigned char * data)
{
	while( (*data) !=0 ) {
		setTile(x,y,*data);
		++data;
		++x;
		if(x>32) {
			x=0;
			y=y+1;
		}
	}
}



