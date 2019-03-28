CON

' This include file is pasted into the top of every SPIN file

' ==================================================  
' Numeric constants
' ==================================================

DebugPin = $08_00_00_00

RandomSeedStart = $00_B4_F0_1A

DiskBoxNumber = 0
DiskCOGNumber = 3

SpriteBoxNumber = 2
SpriteCOGNumber = 5

SoundBoxNumber = 3
SoundCOGNumber = 4

VariableBoxNumber  = 1
VariableCOGNumber  = 1

VideoBoxNumber = 2
VideoCOGNumber = 2

NumSprites = 16

CursorTileA = 32             ' First tile to blink for text cursor
CursorTileB = 31             ' Second tile to blink for text cursor
CursorBlinkRate = $8000      ' Cursor blink rate (passes through readBuf before changing)

' VariableCOG command for get-variable
VariableGetCommand = %1_111_0001__00_000_111_00_10_10_00_0111_1011
' VariableCOG command for variable-set
VariableSetCommand = %1_111_0001__01_000_110_10_00_10_10_0000_1011
' VariableCOG command for reading next key
VariableGetKeyCommandA = %1_111_0001__00_000_110_00_10_10_11_0111_1011
VariableGetKeyCommandB = $0003_0000

MountCommand = %1_000__0000___0000_0000___00000000___00000000
LoadCluster  = %1_000__0000___0001_0011___00000000___00000000

' ==================================================
' Memory addresses
' ==================================================

SpriteTable = $0000

SorEvenMask  = $0100
SorOddMask   = $0140  
   
SorEvenImage = $0180
SorOddImage  = $01C0

ScreenMap  = $0200
TileMemory = $0880

Cluster0          = $8000 - 2048*2
Cluster1          = $8000 - 2048*3
Cluster2          = $8000 - 2048*4

GC1Data   = $7800
GC2Data   = $7808

NumberReserved    = $7810
SectorsPerCluster = $7811
DisplayBeamRowNumber = $7812
InputMode = $7813
CacheCopy         = $7818

KeyboardMemory     = $7E20

KeyStates = $7E2C

RetraceCounter = $7854

ScratchMemory = $7E70        ' A 16-byte scratch buffer used by "getNumber" function

MailboxMemory     = $7E80


pub start

   do  :=  6
   clk :=  7 
   di  :=  8
   cs  :=  9

   coginit(DiskCOGNumber,@DiskCOG,0)
   
DAT      
         org 0

DiskCOG           

stall    rdlong    tmp,boxComStat wz   ' On startup, wait for ...         
   if_z  jmp       #stall              ' ... the start signal

         rdbyte    t1,C_NUMRES
         call      #markCacheReserved           

main     call      #dumpCache          ' Write our cache table (for debugging)
main2    rdlong    tmp,boxComStat      ' Read the command
         shl       tmp,#1 nr, wc       ' If upper bit is clear ...
   if_nc jmp       #main2              ' ... keep waiting for command        

         mov       tmp2,tmp
         shr       tmp2,#20
         and       tmp2,#$F
         add       tmp2,#commandTable  ' Offset into list of jumps
         jmp       tmp2                ' Take the jump to the command         

commandTable
         jmp       #SD_Mount
         jmp       #doCACHE
         jmp       #doWRITE
         jmp       #doRESERVE

doRESERVE          
         rdbyte    t1,C_NUMRES
         and       tmp,#7
         add       t1,tmp                
         wrbyte    t1,C_NUMRES
         call      #markCacheReserved
         mov       tmp,#1
         jmp       #final
         
markCacheReserved
         mov       indU,#cacheTable         
res1     movs      ddoc1,indU
         movd      ddoc2,indU
ddoc1    mov       tmp,0 wz
         or        tmp,C_FF_00_0000  
ddoc2    mov       0,tmp
         add       indU,#1
         djnz      t1,#res1
markCacheReserved_ret
         ret

doCACHE_ERROR 
         mov tmp,#0

doCACHE_FFFF
         mov tmp2,C_FFFF
         wrlong tmp2,boxDat1Ret         
         jmp #final      

doCACHE
' 1_000__0000___0001_00hr___cccccccc___cccccccc 
         mov       t1,tmp       ' Requested cluster ...
         and       t1,C_FFFF    ' ... to t1
         mov       r,tmp       ' r ...
         shr       r,#16       ' ... flag ...
         and       r,#1        ' ... to t2
         mov       h,tmp        ' h ...
         shr       h,#17        ' ... flag ...
         and       h,#1         ' ... to t3
         rdlong    acca,boxOfs  ' Current cache page ...
         shr       acca,#11     ' ... number in acca
         
         call      #searchCacheTable  ' Gather cache information   

         ' If r and U decrement U->ref (floor 0)    
         cmp r,#1 wz
  if_nz  jmp #doCACHE1  
         cmp indU,C_FFFF wz
  if_z   jmp #doCACHE1  
         
doCACHE2 
         add indU,#cacheTable         
         movs doc1,indU
         movd doc2,indU
doc1     mov tmp,0 wz
         and tmp,C_FF_00_0000 nr,wz
  if_z   jmp #doCACHE1
         sub tmp,C_REFCNT
doc2     mov 0,tmp         

doCACHE1   

         ' If CCC==FFFF return FFFF
         cmp t1,C_FFFF wz
  if_z   mov tmp,#1
  if_z   jmp #doCACHE_FFFF 
         
         ' If C, move C to end of list.
         cmp indC,C_FFFF wz
   if_z  jmp #doCACHE4
         mov tmp,indC
         call #moveSlotToEnd
         jmp  #doCACHE3  
         
doCACHE4 
         ' else if F, move F to end of list. Load cluster to F.
         cmp indF,C_FFFF wz
   if_z  jmp #doCACHE5   
         mov tmp,indF

         mov tmp5,t1
         
         call #moveSlotToEnd 
                  
         ' Fill last entry with
doFILL   andn cacheTableLast,C_FFFF  ' Store new ...
         andn t2,C_FFFF              ' ... cluster number ...
         or cacheTableLast,tmp5      ' ... in entry
         mov tmp6,cacheTablelast     ' Entry's ...
         shr tmp6,#16                ' ... RAM ...
         and tmp6,#$FF               ' ... address ...
         shl tmp6,#11                ' ... to tmp6 (cluster still in tmp5)
         mov indF,#4                 ' 4 sectors to read
         shl tmp5,#2                 ' 4 sectors per cluster
         add tmp5,firstDataSector    ' tm5 is now absolute sector         
  
doCACHE41                          
         mov parptr2,tmp5       ' parptr2 = block address
         mov parptr,tmp6        ' parptr  = RAM pointer
         call #SD_Read          ' Read one sector
         add tmp6,sector        ' Bump RAM pointer by 512 bytes
         add tmp5,#1             ' Next sequential sector
         djnz indF,#doCACHE41   ' Do all sectors in cluster 
         jmp  #doCACHE3         ' Return the address
         
doCACHE5   
         ' else if Z, move Z to end of list. Load cluster to Z.
         cmp indZ,C_FFFF wz
    if_z jmp #doCACHE_ERROR  ' else return FFFF

         mov tmp,indZ
         call #moveSlotToEnd
         jmp #doFILL
         
doCACHE3  
         ' Add h to lastEntry->ref
         ' Return lastEntry->pos
         cmp h,#1 wz
  if_z   add cacheTableLast,C_REFCNT
         mov tmp,cacheTableLast
         shr tmp,#16
         and tmp,#$F
         shl tmp,#11
         wrlong tmp,boxDat1Ret   

         mov       tmp,#1
final    wrlong    tmp,boxComStat      ' tmp is status (Done)
         jmp       #main               ' Next command

doWRITE

         rdlong    acca,boxOfs        ' Current cache page ...
         shr       acca,#11           ' ... number in acca         
         call      #searchCacheTable  ' Gather cache information
         cmp       indU,C_FFFF wz     ' Make sure ...
    if_z jmp       #doCACHE_ERROR     ' ... we can find this cluster
         mov       tmp,indU           ' Move the entry ...
         call      #moveSlotToEnd     ' ... to LRU

         mov tmp5,cacheTableLast     ' Get cluster ...
         and tmp5,C_FFFF             ' ... from entry
         mov tmp6,cacheTableLast     ' Entry's ...
         shr tmp6,#16                ' ... RAM ...
         and tmp6,#$FF               ' ... address ...
         shl tmp6,#11                ' ... to tmp6 (cluster still in tmp5)
         mov indF,#4                 ' 4 sectors to write
         shl tmp5,#2                 ' 4 sectors per cluster
         add tmp5,firstDataSector    ' tm5 is now absolute sector         
  
doCACHEF1                          
         mov parptr2,tmp5       ' parptr2 = block address
         mov parptr,tmp6        ' parptr  = RAM pointer
         call #SD_Write         ' Write one sector
         add tmp6,sector        ' Bump RAM pointer by 512 bytes
         add tmp5,#1            ' Next sequential sector
         djnz indF,#doCACHE41   ' Do all sectors in cluster 
         jmp  #doCACHE3         ' Return the address
         

' --------------------------------
' tmp  = offset in sector
' acca = two-byte-value from offset
readTwoByteValue
         add       tmp,C_CLUS2
         rdbyte    acca,tmp
         add       tmp,#1
         rdbyte    accb,tmp
         shl       accb,#8
         add       acca,accb
readTwoByteValue_ret
         ret

moveSlotToEnd
' tmp is the index of the slot to move
       add     tmp,#cacheTable           ' Address of slot
       cmp     tmp,#cacheTableLast wz    ' If this is last ...
  if_z jmp     #moveSlotToEnd_ret        ' ... slot just ignore
       movs    msl1,tmp                  ' Prepare to read from slot
       mov     tmp2,tmp                  ' Source ...
       add     tmp2,#1                   ' ... of move
msl1   mov     t1,0                      ' Get value from slot 
msl3   movs    msl2,tmp2                 ' From source ...
       movd    msl2,tmp                  ' ... up one slot
       add     tmp,#1                    ' Next destination
       add     tmp2,#1                   ' Next source
msl2   mov     0,0                       ' Move the entry
       cmp     tmp,#cacheTableLast wz    ' Loop until ...
 if_nz jmp     #msl3                     ' ... at end of table
       mov     cacheTableLast,t1         ' Store the original entry
moveSlotToEnd_ret
       ret

searchCacheTable
' Search through the table
' U = index of entry containing current cluster (acca)
'
' C = index of entry already containing cccccccc___cccccccc (t1)
' F = index of entry containing last free if any
' Z = index of entry containing last zero ref-cnt          
         mov       indC,C_FFFF      ' Initialize ...
         mov       indU,C_FFFF      ' ...
         mov       indF,C_FFFF      ' ...
         mov       indZ,C_FFFF      ' ... indexes          
         movs      rd1,#cacheTable  ' rd1 = start of table
         mov       tmp,#0           ' tmp = current index  
rd1      mov       tmp2,0           ' Read the current entry
         shl       tmp2,#1 nr,wc    ' Test upper bit
  if_c   jmp       #rd2             ' Ignore any reserved     
         mov       tmp3,tmp2        ' Get disk cluster ...
         and       tmp3,C_FFFF      ' ... of entry                  
         cmp       tmp3,t1 wz       ' Set indC if ...
  if_z   mov       indC,tmp         ' ... requested cluster  
         mov       accb,tmp2        ' Set indU if ...
         shr       accb,#16         ' ... current offset ...
         and       accb,#$FF        ' ... is the offset ...
         cmp       accb,acca wz     ' ... in this ...
  if_z   mov       indU,tmp         ' ... entry              
         cmp       tmp3,C_FFFF wz   ' Set indF if ...
  if_z   mov       indF,tmp         ' ... empty cluster      
         shr       tmp2,#24 wz      ' Set indZ if ...
  if_z   mov       indZ,tmp         ' ... ref-count is zero   
rd2      add       rd1,#1           ' Point to next in table
         add       tmp,#1           ' Bump current index
         cmp       tmp,#15 wz       ' Loop over ...
   if_nz jmp       #rd1             ' ... entire table     
searchCacheTable_ret
         ret 

indU  long     0
indC  long     0
indF  long     0
indZ  long     0

tmp   long     0
tmp2  long     0
tmp3  long     0
tmp4  long     0
tmp5  long     0
tmp6  long     0
t1    long     0
t2    long     0
t3    long     0
h     long     0
r     long     0

firstDataSector  long      0 

' DiskCOG uses box 0
boxComStat long   MailboxMemory+DiskBoxNumber*32
boxDat1Ret long   MailboxMemory+DiskBoxNumber*32+4
boxOfs     long   MailboxMemory+DiskBoxNumber*32+28 

cacheTable
 long $00_00_FFFF  ' RR_PP_CCCC
 long $00_01_FFFF  ' RR is reference count. 0=available. FF=reserved.
 long $00_02_FFFF  ' PP is 2K page in local RAM. (What would be the 16th page is reserved)
 long $00_03_FFFF  ' CCCC is the cluster mapped to the page. FFFF is empty.
 long $00_04_FFFF
 long $00_05_FFFF
 long $00_06_FFFF
 long $00_07_FFFF
 long $00_08_FFFF
 long $00_09_FFFF
 long $00_0A_FFFF
 long $00_0B_FFFF
 long $00_0C_FFFF
 long $00_0D_FFFF
cacheTableLast
 long $00_0E_FFFF
cacheTableEnd

C_NUMRES   long   NumberReserved
C_FATSPC   long   SectorsPerCluster
C_FF_00_0000 long $FF000000

' Cluster2 should be empty during boot ... we can use it
C_CLUS2    long   Cluster2                       
C_AA55     long   $AA55
C_FFFF     long   $FFFF
C_REFCNT   long   %00000001_00000000__00000000_00000000 

dumpCache
          mov       tmp,C_DUMP
          mov       tmp2,#15
          mov       tmp3,#cacheTable
dumpC1    movd      dumpC2,tmp3
          add       tmp3,#1
dumpC2    wrlong    0,tmp
          add       tmp,#4
          djnz      tmp2,#dumpC1
dumpCache_ret
          ret

C_DUMP    long  CacheCopy

' ----------------------------------------------
' Modified from sdspiqasm

SD_Mount

        mov acca,#0           ' Initially ...
        wrbyte acca,C_FATSPC  ' ... not mounted 

        mov acca,#1
        shl acca,di        
        or dira,acca
        mov acca,#1
        shl acca,clk
        or dira,acca
        mov acca,#1
        shl acca,do
        mov domask,acca
        mov acca,#1
        shl acca,cs
        or dira,acca
        mov csmask,acca
        neg phsb,#1
        mov frqb,#0
        mov acca,nco
        add acca,clk
        mov ctra,acca
        mov acca,nco
        add acca,di
        mov ctrb,acca
        mov ctr2,onek
oneloop
        call #sendiohi
        djnz ctr2,#oneloop
        mov starttime,cnt
        mov cmdo,#0
        mov cmdp,#0        
        call #cmd
        or outa,csmask
        call #sendiohi
initloop
        mov cmdo,#55
        call #cmd
        mov cmdo,#41
        call #cmd
        or outa,csmask
        cmp accb,#1 wz
   if_z jmp #initloop                   
         
' reset frqa and the clock
'finished
        mov frqa,#0
        or outa,csmask
        neg phsb,#1
        call #sendiohi
'pause
        mov acca,#511
        add acca,cnt
        waitcnt acca,#0 

' Find the first FAT data sector on the disk ...
' We have to go through the MasterBootRecord, and
' account for FAT and FAT32

' For FAT32, the 2-byte fatSize is 0 and:
'   fatSize is the 4-byte value
'   rootEnt is sectorsPerCluster

' 1st data sector = bootSectorNum + reserved + rootEnt + fatSize*numFats

        mov      parptr,C_CLUS2   ' Cluster2 should be free at boot
        mov      parptr2,#0       ' Read ...
        call     #SD_Read         ' ... Master Boot Record

        mov     parptr,C_CLUS2    ' Look ...
        add     parptr,#510       ' ...
        rdword  tmp,parptr        ' ... for ...
        cmp     tmp,C_AA55 wz     ' ...
  if_nz jmp     #mountError       ' AA55 end

        mov     parptr,C_CLUS2    ' Get ...
        add     parptr,#$1C6      ' ... boot ...
        rdbyte  parptr2,parptr    ' ... sector ...
        mov     firstDataSector,parptr2      ' ...  
        mov     parptr,C_CLUS2    ' ... of first ...
        call    #SD_Read          ' ... partition

        mov     parptr,C_CLUS2    ' Look ...
        add     parptr,#510       ' ... 
        rdword  tmp,parptr        ' ... for ...
        cmp     tmp,C_AA55 wz     ' ...
  if_nz jmp     #mountError       ' AA55 end

        mov     parptr,C_CLUS2
        add     parptr,#13
        rdbyte  tmp6,parptr       ' tmp6 = sectorsPerCluster

        mov     tmp,#14
        call    #readTwoByteValue
        add     firstDataSector,acca         ' firstDataSector = boot sector + numberOfReserved

        mov     tmp,#22
        call    #readTwoByteValue
        mov     tmp4,acca wz      ' tmp4 = sectors per fat                 
  if_nz jmp     #mount1

        mov     tmp,#36
        call    #readTwoByteValue
        mov     tmp4,acca
        mov     tmp,#38
        call    #readTwoByteValue
        shl     acca,#16
        add     tmp4,acca         ' tmp4 = sectors per fat (large for FAT32)
        mov     tmp5,tmp6         ' tmp5 = 1 cluster (root directory)
        jmp     #mount2             

mount1  mov     tmp,#17
        call    #readTwoByteValue
        mov     tmp5,acca
        shr     tmp5,#4        

mount2  add     firstDataSector,tmp5          ' account for root directory

        ' firstDataSector = firstDataSector + numFats*fatsize
        mov     tmp,C_CLUS2
        add     tmp,#16
        rdword  t1,tmp
        mov     t2,tmp4
        call    #multiply
        add     firstDataSector,t1

        ' Store the mount results. C_FATSPC will be 0 if not mounted
        ' or sectorsPerClusters if OK.
        ' C_FATSPC+3 is a long firstDataSector

        mov     tmp,C_FATSPC
        wrbyte  tmp6,tmp           ' Store sectorsPerCluster  
        add     tmp,#3
        wrlong  firstDataSector,tmp           ' Store firstDataSector
        mov     tmp,#0            ' 0=OK (otherwise lots of error codes)
        wrlong  tmp,boxDat1Ret    ' Return(0) 

        mov     tmp,#1             ' Return ...
        jmp     #final             ' ... success        

mountError
        mov      tmp,C_FFFF       ' FFFF is error code for mount-failure
        wrlong   tmp,boxDat1Ret    ' Return($FFFF)        
        mov      tmp,#0            ' Return ...
        jmp      #final            ' ... failure

multiply                mov     t3,#16
                        shl     t2,#16
                        shr     t1,#1           wc
mloop   if_c            add     t1,t2           wc
                        rcr     t1,#1           wc
                        djnz    t3,#mloop         
multiply_ret            ret       

SD_Write
' parptr2   = block address
' parptr    = RAM pointer
        mov starttime,cnt
        mov cmdo,#24
        mov cmdp,parptr2
        call #cmd
        mov phsb,#$fe
        call #sendio
        mov accb,parptr
        neg frqa,#1
        mov ctr2,sector
wbyte
        rdbyte phsb,accb
        shl phsb,#23
        add accb,#1
        mov ctr,#8
wbit    mov phsa,#8
        shl phsb,#1
        djnz ctr,#wbit
        djnz ctr2,#wbyte        
        neg phsb,#1
        call #sendiohi
        call #sendiohi
        call #readresp
        and accb,#$1f
        sub accb,#5
        mov rw_status,accb
        call #busy 
        mov frqa,#0 
        or outa,csmask
        neg phsb,#1
        call #sendiohi
'pause
        mov acca,#511
        add acca,cnt
        waitcnt acca,#0
SD_Write_ret
        ret     
        
SD_Read
' parptr2 = block address
' parptr  = RAM pointer
        mov starttime,cnt
        mov cmdo,#17
        mov cmdp,parptr2
        call #cmd
        call #readresp
        mov accb,parptr
        sub accb,#1
        mov ctr2,sector
rbyte
        mov phsa,hifreq
        mov frqa,freq
        add accb,#1
        test domask,ina wc
        addx acca,acca
        test domask,ina wc
        addx acca,acca
        test domask,ina wc
        addx acca,acca
        test domask,ina wc
        addx acca,acca
        test domask,ina wc
        addx acca,acca
        test domask,ina wc
        addx acca,acca
        test domask,ina wc
        addx acca,acca
        mov frqa,#0
        test domask,ina wc
        addx acca,acca
        wrbyte acca,accb
        djnz ctr2,#rbyte        
        mov frqa,#0
        neg phsb,#1
        call #sendiohi
        call #sendiohi
        or outa,csmask
        mov rw_status,ctr2        
        mov frqa,#0 
        or outa,csmask
        neg phsb,#1
        call #sendiohi
'pause
        mov acca,#511
        add acca,cnt
        waitcnt acca,#0
SD_Read_ret
        ret          

sendio
        rol phsb,#24
sendiohi
        mov ctr,#8
        neg frqa,#1
        mov accb,#0
bit     mov phsa,#8
        test domask,ina wc
        addx accb,accb        
        rol phsb,#1
        djnz ctr,#bit
sendio_ret
sendiohi_ret
        ret
checktime
        mov duration,cnt
        sub duration,starttime
        cmp duration,clockfreq wc
checktime_ret
  if_c  ret             
        neg duration,#13
        and duration,C_FFFF
        or  duration,#1
        wrlong duration,boxDat1Ret         
        
        mov frqa,#0        
        or outa,csmask
        neg phsb,#1
        call #sendiohi
'pause
        mov acca,#511
        add acca,cnt
        waitcnt acca,#0
        mov  tmp,#0       ' Failure 
        jmp  #final       ' (boxDat1Ret contains error code)
        
cmd
        andn outa,csmask
        neg phsb,#1
        call #sendiohi
        mov phsb,cmdo
        add phsb,#$40
        call #sendio
        mov phsb,cmdp
        shl phsb,#9
        call #sendiohi
        call #sendiohi
        call #sendiohi
        call #sendiohi
        mov phsb,#$95
        call #sendio
readresp
        neg phsb,#1
        call #sendiohi
        call #checktime
        cmp accb,#$ff wz
   if_z jmp #readresp 
cmd_ret
readresp_ret
        ret
busy
        neg phsb,#1
        call #sendiohi
        call #checktime
        cmp accb,#$0 wz
   if_z jmp #busy
busy_ret
        ret
                  
rw_status long   0
di        long   0
do        long   0
clk       long   0
cs        long   0
nco       long   $1000_0000
hifreq    long   $e0_00_00_00
freq      long   $20_00_00_00
clockfreq long   80_000_000
onek      long   1000
sector    long   512
domask    long   0
csmask    long   0
acca      long   0
accb      long   0
cmdo      long   0
cmdp      long   0
parptr    long   0
parptr2   long   0
ctr       long   0
ctr2      long   0
starttime long   0
duration  long   0 

  fit
        