' -------------------------------------------------------------------------------
''DiskCOG.spin
'' 
'' Copyright (C) Chris Cantrell October 10, 2008
'' Part of the PEGS project (PEGSKIT.com)
''
''The DiskCOG manages a set of 2K clusters pulled from an SD file into
''Propeller RAM. The top 2K of RAM is reserved for system use (mailboxes,
''configuration information, etc. -- see Boot.spin for details).
''   
''2K RAM cache pages are numbered from 0 to 14 beginning at address $0000.
''2K clusters in the SD file are numbered sequentially beginning with 0. At
''startup the InterpreterCOG will attempt to load disk cluster 0 into page 14
''in RAM and begin execution.
''
''The first three pages in RAM are reserved for screen memory. The RESERVE
''command can be used to increase the reserved memory for more tile image
''resources.
''
''Each RAM page has a reference count that indicates whether the page is being
''used or not. A count of 0 means the page can be reused for other clusters.
''Pages are reused in Least Recently Used order. Code clusters loaded
''with the FLOW command are automatically reference/dereferenced. The REFERENCE
''and DEREFERENCE commands can be used to lock frequently use clusters to
''improve program performance.
''
''##### HARDWARE #####
''
''The SD card is connected to the Propeller as follows:
''
''             3.3V
''                                                  3.3V
''    220Ω R11   R10 10KΩ                             
'' P6 ───────┻────── DO   (SD card SPI signal)     └── Vdd  (SD power)              
'' P7 ──────────────── SCLK (SD card SPI signal)     ┌── Vss  (SD power)
'' P8 ──────────────── DI   (SD card SPI signal)     ┣── Vss2 (SD power)
'' P9 ──────────────── CS   (SD card SPI signal)     
''
''##### SPI AND FAT #####
''
''The SD SPI communications code was taken from Tomas Rokicki's work
''available on the Parallax Propeller Object Exchange in the object:
''"FAT16 routines with secure digital card layer"
''
''The DiskCOG parses the FAT information in a limited way. It reads enough
''to find the first file's starting point. It then assumes that sectors
''are sequential (not fragmented) on the disk from that point on. This
''requires the user to reformat the SD card before loading new code. This
''will be corrected in future releases by caching the location of the
''file's sectors in a table in reserved RAM. 
''
''Many of the DiskCOG functions described below use the "current cluster".
''All commands passed to a COG mailbox include the RAM page offset of
''the MIX code sending the command. (See InterpreterCOG.spin for details
''on mailbox communications). This "cluster offset" defines the "current
''cluster".
''
CON

''
'' DiskCOG uses mailbox 0 (bbb = 000)
DiskBoxNumber      = 0

'' DiskCOG runs in COG 3
DiskCOGNumber      = 3
 
'Cluster0          = $8000 - 2048*2
'Cluster1          = $8000 - 2048*3
Cluster2          = $8000 - 2048*4 ' Used during boot

NumberReserved    = $7810  ' Number of reserved 2K clusters  
SectorsPerCluster = $7811  ' Stored FAT information
FirstMIXSector    = $7814  ' Stored FAT information
SystemBooted      = $7812  ' System-booted flag. Non-zero when booted.
MailboxMemory     = $7E80  ' Where to find the mailboxes
   
pub start
'' Start the DiskCOG 
   coginit(DiskCOGNumber,@DiskCOG,0)
   
DAT      
         org 0

''
''DiskCOG Mailbox Commands:

DiskCOG           

stall    rdbyte    tmp,C_BOOTED wz     ' Wait for ...
  if_z   jmp       #stall              ' ... interpreter to boot

         rdbyte    t1,C_NUMRES         ' Mark the initially ...
         call      #markCacheReserved  ' ... reserved pages         

main     'call      #dumpCache          ' Write our cache table (for debugging)
main2    rdlong    tmp,boxComStat      ' Read the command
         shl       tmp,#1 nr, wc       ' If upper bit is clear ...
   if_nc jmp       #main2              ' ... keep waiting for command
   
         mov       oneway,tmp          ' Might be a oneway ... release later
         mov       tmp2,tmp            ' Get the ...
         shr       tmp2,#20            ' ... command ...
         and       tmp2,#$F            ' ... nibble
         add       tmp2,#commandTable  ' Offset into list of jumps
         jmp       tmp2                ' Take the jump to the command         

commandTable
         jmp       #SD_Mount
         jmp       #doFLOW
         jmp       #doWRITE
         jmp       #doRESERVE

''
'' RESERVE n
'' Adds n to the number of reserved cache clusters (for tile memory).
''   1o_bbb_001_000000000000000000000nnn
''     Memory $7810 (byte) contains new reserved count
doRESERVE          
         rdbyte    t1,C_NUMRES         ' Currently reserved
         and       tmp,#7              ' Can only reserve up to 7 at a time
         add       t1,tmp              ' New ...  
         wrbyte    t1,C_NUMRES         ' ... number of reserved
         call      #markCacheReserved  ' Mark reserved in our cache table
         mov       tmp,#1              ' Return ...
         jmp       #final              ' ... OK

' t1 contains number of entries to mark reserved
markCacheReserved
         mov       indU,#cacheTable    ' Address of first cache entry     
res1     movs      ddoc1,indU          ' Set two ...
         movd      ddoc2,indU          ' ... pointers
ddoc1    mov       tmp,0 wz            ' Read cache-entry
         or        tmp,C_FF_00_0000    ' Mark it reserved
ddoc2    mov       0,tmp               ' Write cache-entry
         add       indU,#1             ' Next entry
         djnz      t1,#res1            ' Mark all entries
markCacheReserved_ret
         ret

''
'' REFERENCE
'' Increase the cache lock reference on the current cluster. 
''   1o_bbb_000_0001_0010_cccccccccccccccc
''     The current cluster number c is resolved at compile time.
''
'' DEREFERENCE
'' Decrease the cache lock reference on the current cluster.
''   1o_bbb_000_0001_0001_1111111111111111
''
'' CACHE_HINT c
'' Load a cluster for future use -- if there are available cache slots.
''   1o_bbb_000_0001_0000_cccccccccccccccc
''
'' FLOW c
'' Called by the interpreter to move program flow out of current cluster.
'' and into a new cluster. The old cluster is dereferenced and the new
'' cluster is referenced.
''   1o_bbb_000_0001_0011_cccccccccccccccc

doFLOW
' 1o_001__0000_0001_00hr___cccccccc___cccccccc
' h = hint (0 means don't reference)
' r = release current (1 means release)
         mov       t1,tmp              ' Requested cluster ...
         and       t1,C_FFFF           ' ... to t1
         mov       r,tmp               ' r ...
         shr       r,#16               ' ... flag ...
         and       r,#1                ' ... to t2
         mov       h,tmp               ' h ...
         shr       h,#17               ' ... flag ...
         and       h,#1                ' ... to t3
         rdlong    acca,boxOfs         ' Current cache page ...
         shr       acca,#11            ' ... number in acca
         
         call      #searchCacheTable   ' Gather cache information   

         ' If "release" and we found the current-cluster then decrement
         ' the reference count (floor 0)    
         cmp       r,#1 wz             ' Skip if ...
  if_nz  jmp       #doCACHE1           ' ... not release
         cmp       indU,C_FFFF wz      ' Skip if ...
  if_z   jmp       #doCACHE1           ' ... current-cluster not found
         
doCACHE2 
         add       indU,#cacheTable    ' Offset to current-cluster entry         
         movs      doc1,indU           ' Set two ...
         movd      doc2,indU           ' ... pointers
doc1     mov       tmp,0 wz            ' Get the cache-table-entry
         and       tmp,C_FF_00_0000 nr,wz ' Skip decrement ...
  if_z   jmp       #doCACHE1           ' ... if already 0
         sub       tmp,C_REFCNT        ' Decrement the ref count
doc2     mov       0,tmp               ' Update the entry

doCACHE1
         ' If requested cluster (CCC)==FFFF then return FFFF (OK)
         cmp       t1,C_FFFF wz        ' If there is no ...
  if_z   mov       tmp,#1              ' ... requested cluster ...
  if_z   jmp       #doCACHE_FFFF       ' ... stop here (OK return)
         
         ' If requested is already loaded, move C to end of
         ' the list (it is most recently used) and use it
         cmp       indC,C_FFFF wz      ' No index ...
   if_z  jmp       #doCACHE4           ' ... move on to load
         mov       tmp,indC            ' Requested slot
         call      #moveSlotToEnd      ' Move to end of table
         jmp       #doCACHE3           ' Skip loading
         
doCACHE4 
         ' If there is a free cluster, move it to the of list (most
         ' recently used) and load it.
         mov       tmp5,t1             ' Requested cluster to tmp5
         cmp       indF,C_FFFF wz      ' If there was no free ...
   if_z  jmp       #doCACHE5           ' ... move on to eject one
         mov       tmp,indF            ' Free slot                                         
         call      #moveSlotToEnd      ' Move free slot to end
                  
         ' Fill last entry with
doFILL   andn      cacheTableLast,C_FFFF ' Store new ...
         andn      t2,C_FFFF           ' ... cluster number ...
         or        cacheTableLast,tmp5 ' ... in entry
         mov       tmp6,cacheTablelast ' Entry's ...
         shr       tmp6,#16            ' ... RAM ...
         and       tmp6,#$FF           ' ... address ...
         shl       tmp6,#11            ' ... to tmp6 (cluster still in tmp5)
         mov       indF,#4             ' 4 sectors to read
         shl       tmp5,#2             ' 4 sectors per cluster
         add       tmp5,firstDataSector ' tm5 is now absolute sector         
  
doCACHE41                          
         mov       parptr2,tmp5        ' parptr2 = block address
         mov       parptr,tmp6         ' parptr  = RAM pointer
         call      #SD_Read            ' Read one sector
         add       tmp6,sector         ' Bump RAM pointer by 512 bytes
         add       tmp5,#1             ' Next sequential sector
         djnz      indF,#doCACHE41     ' Do all sectors in cluster 
         jmp       #doCACHE3           ' Return the address
         
doCACHE5

         ' If there is a zero-referenced cluster, we will move it to the end
         ' of the list and load it with a new cluster.
         cmp       indZ,C_FFFF wz      ' We were unable ...
    if_z jmp       #doCACHE_ERROR      ' ... to find a page to use

         mov       tmp,indZ            ' Page to eject
         call      #moveSlotToEnd      ' Make it most recently used
         jmp       #doFILL             ' Go load it
         
doCACHE3
         ' Now the cluster is loaded and the entry is moved to the bottom
         ' of the table. If this is not a hint, reference the newly loaded.
         ' Return lastEntry->pos
         cmp       h,#1 wz             ' If not a hint ...
  if_z   add       cacheTableLast,C_REFCNT ' ... bump the reference count
         mov       tmp,cacheTableLast  ' Return ...
         shr       tmp,#16             ' ... the ...
         and       tmp,#$F             ' ... memory address ...
         shl       tmp,#11             ' ... of the ...
         wrlong    tmp,boxDat1Ret      ' ... requested cluster's page

         mov       tmp,#1              ' Return-status code OK
final    wrlong    tmp,boxComStat      ' tmp is status (Done)
         and       oneway,C_ONEWAY wz  ' Check one-way request
  if_nz  mov       tmp,#DiskBoxNumber  ' If oneway, release lock ...
  if_nz  lockclr   tmp                 ' ... on behalf of the caller
         jmp       #main               ' Next command

doCACHE_ERROR 
         mov       tmp,#0              ' Return-status code FAIL
doCACHE_FFFF
         mov       tmp2,C_FFFF         ' FFFF as ...
         wrlong    tmp2,boxDat1Ret     ' ... return value 
         jmp       #final              ' Done

''
'' WRITE
'' The current cluster is written to disk whether it needs it or not.
''   1o_bbb_000__0010_0000__00000000__00000000
doWRITE

         rdlong    acca,boxOfs         ' Current cache page ...
         shr       acca,#11            ' ... number in acca         
         call      #searchCacheTable   ' Gather cache information
         cmp       indU,C_FFFF wz      ' Make sure ...
    if_z jmp       #doCACHE_ERROR      ' ... we can find this cluster
         mov       tmp,indU            ' Move the entry ...
         call      #moveSlotToEnd      ' ... to LRU

         mov       tmp5,cacheTableLast ' Get cluster ...
         and       tmp5,C_FFFF         ' ... from entry
         mov       tmp6,cacheTableLast ' Entry's ...
         shr       tmp6,#16            ' ... RAM ...
         and       tmp6,#$FF           ' ... address ...
         shl       tmp6,#11            ' ... to tmp6 (cluster still in tmp5)
         mov       indF,#4             ' 4 sectors to write
         shl       tmp5,#2             ' 4 sectors per cluster
         add       tmp5,firstDataSector ' tm5 is now absolute sector         
  
doCACHEF1                          
         mov       parptr2,tmp5        ' parptr2 = block address
         mov       parptr,tmp6         ' parptr  = RAM pointer
         call      #SD_Write           ' Write one sector
         add       tmp6,sector         ' Bump RAM pointer by 512 bytes
         add       tmp5,#1             ' Next sequential sector
         djnz      indF,#doCACHE41     ' Do all sectors in cluster 
         jmp       #doCACHE3           ' Return the address   

moveSlotToEnd
' tmp is the index of the slot to move
       add     tmp,#cacheTable         ' Address of slot
       cmp     tmp,#cacheTableLast wz  ' If this is last ...
  if_z jmp     #moveSlotToEnd_ret      ' ... slot just ignore
       movs    msl1,tmp                ' Prepare to read from slot
       mov     tmp2,tmp                ' Source ...
       add     tmp2,#1                 ' ... of move
msl1   mov     t1,0                    ' Get value from slot 
msl3   movs    msl2,tmp2               ' From source ...
       movd    msl2,tmp                ' ... up one slot
       add     tmp,#1                  ' Next destination
       add     tmp2,#1                 ' Next source
msl2   mov     0,0                     ' Move the entry
       cmp     tmp,#cacheTableLast wz  ' Loop until ...
 if_nz jmp     #msl3                   ' ... at end of table
       mov     cacheTableLast,t1       ' Store the original entry
moveSlotToEnd_ret
       ret

searchCacheTable
' Search through the table
' U = index of entry containing current cluster (acca)
'
' C = index of entry already containing cccccccc___cccccccc (t1)
' F = index of entry containing last free if any
' Z = index of entry containing last zero ref-cnt          
         mov       indC,C_FFFF         ' Initialize ...
         mov       indU,C_FFFF         ' ...
         mov       indF,C_FFFF         ' ...
         mov       indZ,C_FFFF         ' ... indexes          
         movs      rd1,#cacheTable     ' rd1 = start of table
         mov       tmp,#0              ' tmp = current index  
rd1      mov       tmp2,0              ' Read the current entry
         shl       tmp2,#1 nr,wc       ' Test upper bit
  if_c   jmp       #rd2                ' Ignore any reserved     
         mov       tmp3,tmp2           ' Get disk cluster ...
         and       tmp3,C_FFFF         ' ... of entry                  
         cmp       tmp3,t1 wz          ' Set indC if ...
  if_z   mov       indC,tmp            ' ... requested cluster  
         mov       accb,tmp2           ' Set indU if ...
         shr       accb,#16            ' ... current offset ...
         and       accb,#$FF           ' ... is the offset ...
         cmp       accb,acca wz        ' ... in this ...
  if_z   mov       indU,tmp            ' ... entry              
         cmp       tmp3,C_FFFF wz      ' Set indF if ...
  if_z   mov       indF,tmp            ' ... empty cluster      
         shr       tmp2,#24 wz         ' Set indZ if ...
  if_z   mov       indZ,tmp            ' ... ref-count is zero   
rd2      add       rd1,#1              ' Point to next in table
         add       tmp,#1              ' Bump current index
         cmp       tmp,#15 wz          ' Loop over ...
   if_nz jmp       #rd1                ' ... entire table     
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
oneway long    0

firstDataSector  long  FirstMIXSector
C_BOOTED         long  SystemBooted
C_ONEWAY         long  %01000000_00000000_00000000_00000000

' DiskCOG uses box 0
boxComStat long   MailboxMemory+DiskBoxNumber*32
boxDat1Ret long   MailboxMemory+DiskBoxNumber*32+4
boxOfs     long   MailboxMemory+DiskBoxNumber*32+28 

cacheTable
 long $00_00_FFFF  ' Format of entry is: RR_PP_CCCC
 long $00_01_FFFF  '   RR is reference count. 0=available. FF=reserved.
 long $00_02_FFFF  '   PP is 2K page in local RAM. (What would be the 16th page is reserved)
 long $00_03_FFFF  '   CCCC is the cluster mapped to the page. FFFF is empty.
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

{
' For debugging ... copies the contents of the cache table to
' RAM after every operation
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
}
 
' ----------------------------------------------
' Modified from sdspiqasm  "FAT16 routines with secure digital card layer"

''
'' MOUNT_CARD
'' Called by Interpreter during boot.
''   1o_bbb_000_000000000000000000000000
''     Memory $7811 (byte) contains number of sectors per FAT cluster (0 if no card).
''     Memory $7814 (long) contains sector number of 1st MIX program data sector.
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

' In the future, all this needs to be done in Boot.spin filling out a table
' of sector numbers. That makes the solution more flexible and takes all
' this math out of DiskCOG's code space

' 1st data sector = bootSectorNum + reserved + rootEnt + fatSize*numFats

         mov       parptr,C_CLUS2      ' Cluster2 should be free at boot
         mov       parptr2,#0          ' Read ...
         call      #SD_Read            ' ... Master Boot Record

         mov       parptr,C_CLUS2      ' Look ...
         add       parptr,#510         ' ...
         rdword    tmp,parptr          ' ... for ...
         cmp       tmp,C_AA55 wz       ' ...
  if_nz  jmp       #mountError         ' AA55 end

         mov       parptr,C_CLUS2      ' Get ...
         add       parptr,#$1C6        ' ... boot ...
         rdbyte    parptr2,parptr      ' ... sector ...
         mov       firstDataSector,parptr2      ' ...  
         mov       parptr,C_CLUS2      ' ... of first ...
         call      #SD_Read            ' ... partition

         mov       parptr,C_CLUS2      ' Look ...
         add       parptr,#510         ' ... 
         rdword    tmp,parptr          ' ... for ...
         cmp       tmp,C_AA55 wz       ' ...
  if_nz  jmp       #mountError         ' AA55 end

         mov       parptr,C_CLUS2
         add       parptr,#13
         rdbyte    tmp6,parptr         ' tmp6 = sectorsPerCluster

         mov       tmp,#14
         call      #readTwoByteValue
         add       firstDataSector,acca ' firstDataSector = boot sector + numberOfReserved

         mov       tmp,#22
         call      #readTwoByteValue
         mov       tmp4,acca wz        ' tmp4 = sectors per fat                 
  if_nz  jmp       #mount1

         mov       tmp,#36
         call      #readTwoByteValue
         mov       tmp4,acca
         mov       tmp,#38
         call      #readTwoByteValue
         shl       acca,#16
         add       tmp4,acca           ' tmp4 = sectors per fat (large for FAT32)
         mov       tmp5,tmp6           ' tmp5 = 1 cluster (root directory)
         jmp       #mount2             

mount1   mov       tmp,#17
         call      #readTwoByteValue
         mov       tmp5,acca
         shr       tmp5,#4        

mount2   add       firstDataSector,tmp5 ' account for root directory

         ' firstDataSector = firstDataSector + numFats*fatsize
         mov       tmp,C_CLUS2
         add       tmp,#16
         rdword    t1,tmp
         mov       t2,tmp4
         call      #multiply
         add       firstDataSector,t1

         ' Store the mount results. C_FATSPC will be 0 if not mounted
         ' or sectorsPerClusters if OK.
         ' C_FATSPC+3 is a long firstDataSector

         mov       tmp,C_FATSPC
         wrbyte    tmp6,tmp            ' Store sectorsPerCluster  
         add       tmp,#3
         wrlong    firstDataSector,tmp ' Store firstDataSector
         mov       tmp,#0              ' 0=OK (otherwise lots of error codes)
         wrlong    tmp,boxDat1Ret      ' Return(0) 

         mov       tmp,#1              ' Return ...
         jmp       #final              ' ... success        

mountError
         mov       tmp,C_FFFF          ' FFFF is error code for mount-failure
         wrlong    tmp,boxDat1Ret      ' Return($FFFF)        
         mov       tmp,#0              ' Return ...
         jmp       #final              ' ... failure

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

multiply mov       t3,#16
         shl       t2,#16
         shr       t1,#1 wc
mloop
  if_c   add       t1,t2 wc
         rcr       t1,#1 wc
         djnz      t3,#mloop         
multiply_ret
         ret       

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
do        long   6
clk       long   7
di        long   8
cs        long   9
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
        