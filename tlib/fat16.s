;tatOS/tlib/fat16.s
;rev May 2015



;fatloadvbrfatrootdir, fatsavefat, fatsaveroot
;fatreadfile, fatwritefile, fatdeletefile, fatrenamefile
;fatmakeSubDir, fatsavesub, fatloadSubDirEntries
;fatFindAvailableCluster, fatFindAvailableDirEntry, fatfindfile 
;fatreadDirEntry, fatFillinDirEntry, fatWriteDirEntry, 
;fatGenerateDEStrings, fatbuildtatOSdirString
;fatreadVBR, fatgetfilename, fatprocessfilename, fatcluster2LBA, 
;fatSetAttributes, fatCopyFilename,  fatsetCWDasRoot
;fatformatdrive

;for quick jump to the code frequently accessed:
;FATFINDFILE
;FATREADFILE
;FATWRITEFILE
;FATDELETEFILE
;FATGETFILENAME
;FATSAVESUB
;FATREADDIRENTRY
;FATSETCWDASROOT
;FATFINDAVAILABLEDIRENTRY
;FATGENERTATEDESTRINGS
;FATWRITEDIRENTRY
;FATSAVEFAT
;FATSAVEROOT
;FATMAKESUBDIR
;FATRENAMEFILE


;code to provide basic FAT16 filesystem functionality for tatOS
;to read/write between tatOS and your tatOS fat16 formatted flash drive



;**********************************************************
;Where are things on a tatOS formatted FAT16 flash drive:
;**********************************************************
;1 sector = 1 block = 512 (0x200) bytes
;64 (0x40) sectors or blocks = 1 cluster = 32,768 (0x8000) bytes
;File_LBAstart = 519 + (FirstCluster-2)*64
;**********************************************************
;                    offset     LBAstart    size,qtyblocks  size,qtybytes
;VBR  starts at:     0          0           1               0x200
;FAT1 starts at:     0x200      1           0xf3            0x1e600
;FAT2 starts at:     0x1e800    0xf4        0xf3            0x1e600
;root dir starts at: 0x3ce00    0x1e7       0x20            0x4000
;filedata starts at: 0x40e00    0x207       ?




;***********************************************************
;where is the tatOS file system data stored in memory ?
;***********************************************************
;0x1900000=STARTVBR  
;0x1900200=STARTFAT1
;0x191e800=STARTFAT2
;0x193ce00=STARTROOTDIR



;Current Sub Directory
;*************************
;new for tatOS as of March 2013 is the concept of the
;Current Sub Directory
;0x40 blocks of memory starting at 0x1960000 is reserved
;to store all the directory entries of the CSD
;STARTSUBDIR is defined as 0x1960000
;the starting cluster number of these subdirectory entries
;is stored as [CSDstartingcluster]

;the reason for this change is to completely seperate root directory entries
;in memory from sub directory entries and to prevent one from overwritting the other.

;the dword [CurrentWorkingDirectory] keeps track of 
;which directory entries are to be operated on currently
;i.e. are file operations (save/delete/rename etc) to be operated on 
;in the root directory entries or in the current sub directory entries
;[CurrentWorkingDirectory] = 0 use root directory entries
;[CurrentWorkingDirectory] = 1 use currently loaded sub directory entries






;Root Directory & Sub Directory Size
;**************************************
;The root directory on a tatOS formatted flash is 0x20 blocks which allows for
;(512) 32 byte directory entries. The sub directories are a full cluster or
;0x40 blocks which permits twice as many directory entries. I would normally save
;the root directory for nothing but sub directory names and then save all your 
;files within each subdirectory, but if you want to save files directly to the 
;root directory, thats ok too.





;FILE NAME
;************
;a tatOS filename is an ascii string of 11 bytes
;this is exactly what is stored in the first 11 bytes 
;of the FAT16 directory entry
;0xbbbbbbbbeee 
;the first 8 bytes are the base name
;the last 3 bytes are the extension
;these are merged by tatOS  and treated as a single string
;tatOS does not recognized the dot '.' as an extension seperator
;if you save a filename like "ttasm.s", tatOS will
;treat this as a string of 7 chars with the dot included
;this is differant than linux or windows which will ignore the dot
;and place whats after the dot as the bbb extension
;e.g. on linux the following filename "ttasm.s" is stored in 
;the file directory as "TTASM   S  "  (note upper case)
;so to retrieve this file under tatOS you must type 3 spaces after
;the 'M' and 2 more spaces after the 'S'
;note tatOS does not support the LFN 
;tatOS only supports the 8.3 "dos" filename entry
;do not use tatOS file delete or renaming utilities on files with LFN
;do not use any code in this file unless your flash drive was formatted by tatOS
;the tatOS filename may be upper or lower case
;Linux can also handle upper or lower case
;you can save a file with a name like "test1" as lower case without extension
;and Linux can open this file just fine
;if you intend to copy files between windows and tatOS however, 
;then the filename must be all UPPER case
;if you have a lower case filename, windows can display the file in explorer
;but windows programs can not open the file unless the name is upper case
;this upper case dependency is an artifact of msdos
;note you will also have problems with end-of-line markers if copying files from 
;tatOS to windows because tatOS/tedit uses the Linux convention of 0xa for end-of-line
;while windows requires 0xd 0xa for end-of-line
;windows Wordpad can handle the 0xa end-of-line, notepad can not. 
;also do not copy a directory of files from linux or windows to your tatOS
;formatted flash and then later rename the directory in tatOS because 
;when you copy the directory a LFN entry is created after the 8.3 entry 
;and they must match. tatOS will change the 8.3 filename for you but leave
;the LFN untouched, and this will render the files in that directory inaccessible 
;to windows.
;as a final note, Windows has a patent for FAT16 with LFN but the 8.3 dos style
;entry is not patented. See tatOS/doc references.






;FILE SAVE
;***********
;if fatfindfile returns that a file with the same name exists then we abort
;this means you can not over write an existing files data (no FileSave)
;each time you save you must give it a new name (FileSaveAs).
;try names like myfile01, myfile02...  
;for now you should not use any functions that write to your flash
;unless your flash was formatted using fatformatdrive() under tatOS
;this is because of the underlying assumptions in the code


;FILE DELETE
;************
;tatOS will overwrite the first byte of the directory entry with 0xe5
;to indicate a deleted file, but the FATs are left marked and are not modified
;and neither is the file data. This is for possible retrieval of the data at 
;a later date. to reclaim all this space on your flash drive you must reformat the disc.
;If you run the dosfsck it will identify and reclaim these unused clusters.




;SUBDIRECTORY
;**************
;tatOS only supports subdirectories of root
;there is no support for subdirectories within subdirectories
;the subdir is just a file with contents that look like the root dir
;nothing but a list of 32byte dos DIRENTRY structures
;the first entry is always the dot entry [.]
;the [.] entry gives the starting cluster of this directory
;the [.] entry looks like this:
;".   0  4 11 2010   D,   22"
;the 2nd entry is always the dotdot entry [..]
;the [..] dotdot entry looks like this:
;"..  0  4 11 2010   D,   0"
;the [..] entry gives the starting cluster of the directory one level up
;in our case this will always point to the root dir
;each subdirectory is 1 cluster or 0x40 blocks or 0x8000 bytes
;since each directory entry in FAT16 is 32 bytes
;this permits 1024 directory entries per subdirectory





;FAT16: tatOS vs Linux or Windows
;**********************************
;some differances to note :
;	* we only support 11 char filenames, the extension is appended to base
;	* LFN is not supported
;	* we only support the last modified date, other dates/times unsupported
;	* we only support adding archives and subdir to the root dir
;   * tatOS & Linux supports upper or lower case, windows upper case only


;a Flash drive can be formatted like a floppy as a single volume
;or it can be split/partitioned like a hard drive
;tatOS supports a simple disk format with no partition information

;case [1]  NO Partition
;flash drive formatted with FAT16 like a floppy:
;a tatOS formatted flash drive follows this convention
;Boot sector contains a Volume Boot Record
;the partition starts at offset=0  with the 3 byte jmp
;FAT1 begins offset=0x200
;FAT2 begins after FAT1 
;root directory table begins after FAT2
;then the data clusters starting with cluster2, cluster3, cluster4...

;case [2] Partition
;flash drive formatted like a FAT16 hard drive
;this is unsupported by tatOS
;partition table begins at offset 0x1be
;partition table tells where each partition starts
;each partition starts with its own Volume Boot Record 
;FAT1 begins after VBR
;FAT2 begins after FAT2  and so forth....





;Linux Format Flash
;*********************
;on Linux you can reformat your pen drive to have a FAT16 filesystem
;with the following command:
;./mkfs.vfat -v -I -F 16 -n NONAME /dev/sda 
;on my linux mkfs is located in /sbin  (use "whereis mkfs")
;partition information are 16 byte records starting at
;offsets 0x1be, 0x1ce, 0x1de and 0x1ee 
;but mkfs.vat will write all 00000000's (no partition information)

;Here is what the boot sector looks like after mkfs.vfat has done its thing:
;offset
;00  jmp instr 3 bytes         = eb 3c 90 
;03  oem name 8 bytes          = mkdosfs 00  
;0b  bytespersector word       = 0200
;0d  sectorspercluster byte    = 0x40 = 64  (must be a power of 2)
;0e  reservedsectorcount word  = 01
;10  numberofFATS byte         = 02
;11  maxnumrootdirentries word = 0200
;13  totalsectors word         = 00 (if 0 use 4 byte value at offset 0x20)
;15  mediadescriptor byte      = f8 = fixed disc
;16  sectorsperFAT word        = 00f3 = 243
;18  sectorspertrack word      = 003e = 62
;1a  numberofheads word        = 003f = 63
;1c  hiddensectors dword       = 00000000
;20  totalsectors dword        = 003c8800

;extended bios parameter block:
;24  physicaldrivenumber byte  = 00
;25  reserved byte             = 00
;26  extendedbootsig byte      = 29
;27  ID seriel#  dword         = 46b0dbf7
;2b  volumelabel 11 bytes      = NONAME followed by (5) 0x20 space bytes
;36  fatfilesystemtype 8 bytes = FAT16  followed by (2) 0x20 space bytes

;starting at offset 0x3e can be operating system boot code
;from offset 0xc0 -> the 55aa bytes at end of boot sector we see all 000000000

;the first entry in the Linux root directory is a Volume label, firstcluster=0
;Linux will create an LFN entry for every file copied to the flash
;whether it fits in the 8.3 filename or not
;cluster=0  is f8 ff 
;cluster=1  is ff ff
;cluster=2  is 0000  and not used ever
;cluster=3  is 0000
;cluster=4  becomes the first available cluster when a file is copied to root
;I created 3 files with vi and saved to the drive and got this:
;name     FirstCluster    Offset2FileData
;File1    4               0x50e00
;File2    6               0x60e00
;File3    8               0x70e00
;vi created and deleted SWP files in clusters 5,7,9
;clusters 5,7,9 were left 0000 in the FAT not used
;I deleted these 3 files and created 3 new files and they still occupied clusters 4,6,8
;tatOS is actually able to write to and read files to a flash disk that has been
;formatted by Linux as noted above

;dosfsck
;on Linux you can use dosfsck to check the integrity of the tatOS fat16 file system
;to run dosfsck you must first "su root" (do not mount)
;assuming your flash drive is recognized as /dev/sda, then issue the following command:
;dosfsck -l -n -v  /dev/sda > myfscheck.txt 
;these switch options will check but not make changes to your flash
;if for example you had a bad write10 and didnt immediately reinit the flash and 
;then backup FAT2->FAT1 then dosfsck may give you something like this:
;"FATS differ but appear to be intact. Using first FAT."
;"/TCAD02/tcad747 and /TCAD02/tcad800 share clusters. Truncating second to 0 bytes."


;Windows Format Flash Drive
;****************************
;I formatted my flash drive on a WinXP machine and got this:
;you will notice that the values are very similar to what Linux does
;oem name = MSDOS5.0
;bytespersector = 0x0200
;sectorspercluster = 0x40
;reservedsectorcount = 02
;numberofFATS = 02
;maxnumrootdirentries = 0x0200
;totalsectors = 00
;mediadescriptor = f8
;sectorsperFAT = 00f3
;sectorspertrack = 003f
;numberofheads = 00ff
;hiddensectors = 00000000
;totalsectors = 003c8800  (* 512 bytes/block = capacity of flash drive)
;extended bios parameter block:
;physicaldrivenumber = 00
;reserved = 00
;extendedbootsig = 29
;ID = 6cdbe83c
;volumelabel = NO NAME
;fatfilesystemtype = FAT16
;I copied 3 files to the drive and got this:
;name     FirstCluster    Offset2FileData
;File1    2               0x41000
;File2    3               0x49000
;File3    4               0x51000
;Windows will also create a RECYCLER with attributes RO,H,S,D
;and AUTORUN INF with attributes RO,H,S
;I once copied a bunch of files to my tatOS formatted flash in Windows
;the files were copied to a subdir and the first file copied to this subdir
;was assigned by windows the same firstcluster as the subdir itself which is an error
;also windows marked the FAT as f8 ff ff 7f ....
;Q1: why did windows mark cluster(1) of the FAT as ff 7f ?
;Q2: why did windows mark a file to have the same firstcluster as the subdir ?
;the result was the files were not accessible in Linux 
;I could cd to the subdir but when I tried to ls the files I got garbage
;and had to reformat the flash






;What is the offset to the start of FAT1 ?
;*******************************************
;FAT1 starts immediately after "qtyreservedsectors"
;if qtyreservedsectors = 01 and bytespersector = 0x200 then FAT1 starts at 0x200
;if qtyreservedsectors = 02 and bytespersector = 0x200 then FAT1 starts at 0x400




;What is the offset to start of ROOT directory ?
;*************************************************
;the root directory starts immediately after FAT2
;so first you need offset to start of FAT1
;then compute sizeofFAT = sectorsperFAT * bytespersector
;for tatOS this is 0xf3 * 0x200 = 0x1e600
;so now if offset to start of FAT1 = 0x200 then add 0x1e600 + 0x1e600 = 0x3ce00
;0x3ce00 is the offset to the start of root directory




;Where is the file data stored on the tatOS flash disc ?
;How do I convert the cluster number to LBA ?
;*********************************************************
;Your basic formula to compute LBA start of the file data
;the FirstCluster must be known by reading the directory entry
;on tatos we have 512 bytes/block and 64 blocks/cluster

;File LBAstart = NumReservedSectors + NumFATS*SectorsPerFAT + 
;                MaxQtyRootDirEntries*32/BytesPerSector     +
;                (FirstClusterNumOfFile-2)*SectorsPerCluster

;for a tatOS formatted flash drive the above formula reduces to:
;	File_LBAstart = 1 + 0x1e6 + 0x20 + (FirstCluster-2)*0x40

;which can be further reduced to:  
;	File_LBAstart = 0x207 + (FirstCluster-2)*0x40

;or in all decimal notation:
;	File_LBAstart = 519 + (FirstCluster-2)*64

;or to look at it in terms of bytes:
;offset-to-start-of-file = offset-to-start-of-data-region + 
;		                   bytespercluster * (FirstCluster - 2)
;offset-to-start-of-file = 0x40e00 + 0x8000 * (FirstCluster - 2) for tatOS

;FirstClusterNum  File_LBAstart   ByteOffset
;2                0x207           0x40e00
;3                0x247           0x48e00
;4                0x287           0x50e00           
;5                0x2c7           0x58e00
;and so forth



;Fat Marking
;*************
;An example of how the FAT is marked for a file of size 109,000 bytes
;assuming a tatOS formatted flash drive with 32,768 bytes/cluster
;cluster 0 always holds f8ff
;cluster 1 is marked ffff as used even though we dont use it
;the first file starts at cluster=2
;the file requires 4 clusters to store all the bytes
;cluster=2 is the starting cluster that points to 3
;cluster=3 points to 4
;cluster=4 points to 5
;cluster=5 is marked as the last cluster in the chain
;Fat marking: f8ff ffff 0300 0400 0500 ffff 0000 0000 0000 0000
;cluster #:   0    1    2    3    4    5    and so on ...
;the reason we mark cluster=1 as used is because we search thru the entire fat
;for an available cluster marked 0000



;NAMEOFCWD CurrentWorkingDirectory
;**********************************
;NAMEOFCWD is the address of a buffer defined in tatos.inc to hold the 
;name of the current working directory. This is a 11 byte 0 terminated string.
;this will either be "root       ",0  or the name of a subdir in root



;DIRENTRY Structure
;***********************
;The FAT16 root directory and each sub directory are arrays of DIRENTRY structures
;each directory entry structure consists of 32 bytes as follows:
;first line of 16 bytes:
;8 byte DOS filename
;3 byte extension  (8+3=11 byte filename in tatOS)
;1 byte File Attributes (0x10=subdir, 0x20=archive, 0x0f=long file name...)
;1 byte reserved
;1 byte create time fine resolution (special encoding)
;2 byte create time hour/min/sec
;next line of 16 bytes:
;2 byte create date (year/month/day are encoded)
;2 byte last access date
;2 byte EA-Index
;2 byte last modified time
;2 byte last modified date
;2 byte first cluster in FAT
;4 bytes filesize
;total bytes = 32



;Copy Your Files off the Flash drive in Linux first (Dont create holes)
;**************************************************************************
;dont delete files off your flash in linux, just copy
;you should not delete any files off your flash drive in Linux.
;Because this driver saves files as continguous blocks, I suggest to avoid
;deleting files from your tatOS flash drive in linux because this will create holes
;in your fat and Im not sure how the tatOS driver will respond to that.
;I also suggested not using vi to view/edit a file on your tatOS flash drive 
;because this will create a new swap file and delete the old again causing holes.
;In short with Linux just list your files using "ls" or just copy them off.
;vmware on a mac also creates "trash" folders and holes in the fat so you
;should reformat your tatOS flash after using vmware 

;we store the root directory entries seperately from sub directory entries 
;and use a variable [CurrentWorkingDirectory] 
;to distinguish which entries represent the current working directory.

;The code in filemanager.s is closely linked to this file. The filemanager allows
;interactive use of the functions in this file.

;FAT16 allows for a max of 2GB addressible flash
;you may format flash drives larger than 2GB but only the first 2GB can be used
;there is no code to partition the volume (someday perhaps)
;I save all my developed asm code to a 2GB Toshiba flash drive
;the Max Logical Block = 0x003c87ff
;with 64 sectors or blocks per cluster on a tatOS formatted flash drive
;we have max cluster number = 61983
;I mostly write asm source to my flash drive and after a couple months
;Im only up to cluster numbers in the hundreds (actually cl=2388 as of Nov 2013)

;you should not use this code unless your flash was formatted by tatOS
;your files can be interchanged to Linux or Windows with restrictions see below

;Stability  
;have used this code for all of 2015 without any failed usb transactions
;still BACKUP !


;fixme:
;we have the ability to create a duplicate directory entry which references the
;same file data but we should copy the file data and have the directory entry
;point to this new data instead. dosfsck does not like what we are doing currently.









fatstr0 db 'Read Fat16',0
fatstr1 db 'unknown format on flash drive-exiting',0
fatstr2 db 'jmp byte1',0
fatstr3 db 'jmp byte2',0
fatstr4 db 'OEM name:',0
fatstr5 db 'bytes per sector',0
fatstr6 db 'sectors per cluster',0
fatstr7 db 'reserved sectors',0
fatstr8 db 'qty FATS',0
fatstr9 db 'Max qty root directory entries',0
fatstr10 db 'total sectors, small',0
fatstr11 db 'media descriptor',0
fatstr12 db 'sectors per FAT',0
fatstr13 db 'sectors per track',0
fatstr14 db 'qty heads',0
fatstr15 db 'qty hidden sectors',0
fatstr16 db 'total sectors, large (sizeof partition)',0
fatstr17 db 'physical drive number',0
fatstr18 db 'reserved (current head)',0
fatstr19 db 'extended boot signature',0
fatstr20 db 'ID seriel number',0
fatstr21 db 'volume label:',0
fatstr22 db 'filesystem ID:',0
fatstr23 db 'boot signature',0
fatstr24 db 'offset to FAT1',0
fatstr25 db 'sizeof FAT, bytes',0
fatstr26 db 'offset to FAT2',0
fatstr27 db 'offset to Root Dir Table',0
fatstr28 db 'sizeof Root Directory',0
fatstr29 db 'Long filename entry',0
fatstr30 db 'dos 8.3 entry',0
fatstr31 db '8.3 filename',0
fatstr32 db 'file attributes',0
fatstr33 db 'filesize, bytes',0
fatstr34 db 'first available cluster',0
fatstr35 db 'FAT read subdirectory',0
fatstr36 db 'hidden.',0
fatstr37 db 'system.',0
fatstr38 db 'LFN entry',0
fatstr39 db 'Found partiton table - 1st Partition active',0
fatstr40 db 'Failed to find 0xeb jmp at start of partition-exiting',0
fatstr41 db 'offset to start of partition',0
fatstr42 db 'offset to file data region, cluster=2',0
fatstr43 db 'bytes per cluster',0
fatstr44 db 'fatWriteDirEntry',0
fatstr45 db 'fatmakeSubDir',0
fatstr46 db 'fatCopyFilename',0
fatstr47 db 'fatfindfile',0
fatstr48 db 'fatgetfilename',0
fatstr49 db 'remaining clusters:',0
fatstr50 db 'View FAT16 subdir: Enter starting cluster number (0=rootdir)',0
fatstr51 db 'FAT16 subdirectory',0
fatstr52 db 'subdir offset',0
fatstr53 db 'Last modified date:',0
fatstr54 db 'WARNING-Format Flash Drive w/FAT16 - Do you wish to continue ? (ESC=quit)',0
fatstr55 db 'fatreadfile:',0
fatstr56 db 'fatcluster2LBA: computed LBAstart',0
fatstr57 db 'fatreadfile: next cluster in FAT',0
fatstr58 db 'failed to find available cluster',0
fatstr59 db 'failed to find available entry in Root dir',0
fatstr60 db 'fatwritefile: qty clusters needed',0
fatstr61 db '...',0
fatstr62 db 'fatfindfile: direntry does not exist in CWD, returning 0',0
fatstr63 db 'fatloadvbrfatrootdir:Loading VBR,FAT1,FAT2,ROOTDIR',0
fatstr64 db 'FAT read dir entry return value',0
fatstr66 db 'fatrenamefile',0
fatstr67 db 'fatwritefile: file size is zero bytes',0
fatstr68 db 'fatcluster2LBA: input cluster number',0
fatstr69 db 'fatreadfile return value',0
fatstr70 db 'fatwritefile',0
fatstr71 db 'Next Available Cluster',0
fatstr72 db 'marking FAT single cluster ffff',0
fatstr73 db 'fatwritefile: marking FAT multi-cluster file',0
fatstr74 db 'Next Available Cluster',0
fatstr75 db 'First Available Cluster',0
fatstr76 db 'fatwritefile: preparing to write file data',0
fatstr77 db 'fatwritefile: illegal attempt to write cluster=0',0
fatstr78 db 'fatreadfile failed: file not in CWD or not archive or invalid clusternum',0
fatstr79 db 'filename entered:',0
fatstr80 db 'fatfindfile returns nonzero, filename already exists',0
fatstr81 db 'fatwritefile: failed to find Next Available cluster',0
fatstr82 db 'erased entry',0
fatstr83 db 'entry is available and no more entries',0
fatstr84 db 'fatdeletefile',0
fatstr86 db 'building file string',0
fatstr87 db 'overwrite existing filename',0
fatstr89 db 'marking entry 0xe5 for delete',0
fatstr90 db 'fatSetAttributes',0
fatstr91 db 'fatFindAvailableCluster',0
fatstr92 db 'fatFillinDirEntry',0
fatstr93 db '.          ',0   ;11 char dot name
fatstr94 db '..         ',0   ;11 char dotdot name
fatstr95 db 'Format Flash Drive',0
fatstr95a db 'tatOS fat16 format success',0
fatstr95b db 'tatOS fat16 format failed',0
fatstr96 db 'fatGenerateDEStrings',0
fatstr97 db 'fatdeletefile failed: failed to find or not an archive',0 
fatstr98 db 'fatreadVBR',0
fatstr99 db 'fatwritefile: writting data to cluster number ...',0
fatstr100 db 'fatloadSubDirEntries',0
fatstr101 db 'fatsetCWDasRoot',0
fatstr104 db 'fatcopydirentry',0
fatstr105 db 'fatFindAvailableDirEntry',0
fatstr108 db 'fatfindfile:  found direntry in CWD, returning filesize',0
fatstr109 db 'fatloadSubDirEntries failed',0
fatstr110 db 'Warning/Error:fatFindAvailableCluster return value is < 2 (Is CWD set ?)',0
fatstr112 db 'fatwritefile: write10 failed',0
fatstr113 db 'fatcluster2LBA: invalid cluster number',0
fatstr114 db 'fatmakeSubDir failed',0
fatstr116 db 'saving FAT1',0
fatstr117 db 'saving FAT2',0
fatstr118 db 'saving ROOTDIR',0
fatstr120 db 'fat format Flash drive',0
fatstr121 db 'fatwritefile: bad cluster number out of range',0
fatstr122 db 'fatWriteDirEntry: failed',0
fatstr123 db 'fatsavefat: saving FAT1+FAT2',0
fatstr124 db 'fatsavesub',0
fatstr125 db 'current working directory index',0
fatstr126 db 'fatsaveroot',0
fatstr127 db 'fatrestorefat:done',0
fatstr128 db 'fatsavevbrfatrootdir: Saving VBR,FAT1,FAT2,ROOTDIR',0
fatstr129 db 'fatsavevbrfatrootdir: success',0
fatstr130 db 'fatsavevbrfatrootdir: failed',0







;fatloadvbrfatrootdir loads the VBR+FAT1+FAT2+ROOTDIR=0x40e00 to 0x1900000
STARTVBR     equ  0x1900000 
STARTFAT1    equ  0x1900200
STARTFAT2    equ  0x191e800
STARTROOTDIR equ  0x193ce00
STARTSUBDIR  equ  0x1960000   ;the current sub directory entries are loaded here



;fatbuildtatOSdirString builds a 76 byte string at FATDIRSTRING
FATDIRSTRING equ  0x198fc00

;fatSetAttributes, fatFindAvailableCluster and fatCopyFilename 
;write a new 32byte DIRENTRY structure here
FATDIRENTRY  equ  0x198fd00


;dwords
bytespersector    dd 0
sectorspercluster dd 0
sectorsperFAT     dd 0
sizeofFAT         dd 0
offsetFAT1        dd 0
offsetFAT2        dd 0
qtyreservedsect   dd 0
qtyrootdirentry   dd 0
sizeofrootdir     dd 0
offsetrootdir     dd 0
offsetfiledata    dd 0
foundLFN          dd 0
bytespercluster   dd 0
offsetsubdir      dd 0
clusternum        dd 0
CurrentCluster    dd 0
FirstAvailCluster dd 0
NextAvailCluster  dd 0
qtyclusters       dd 0
direntryaddress   dd 0
direntryaddress_old   dd 0
qtyVBRstrings     dd 0
qtydirentrystrings        dd 0
offsetStartOfPartition    dd 0
CurrentWorkingDirectory   dd 0
CSDstartingcluster        dd 0



%define ROOTDIRECTORY 0
%define SUBDIRECTORY  1


;holds the cluster number of the cwd
currentworkingdir dd 0

;bytes
mediadescriptor   db 0
ROOTSTR db 'root       ',0   ;11 bytes
old_direntry times 50 db 0


;fatreadDirEntry fills in these fields
direntry.filename times 12 db 0    ;1 extra 0 for terminator
direntry.lastmodifieddate  dd 0
direntry.attributes        dd 0
direntry.filesize          dd 0
direntry.startingcluster   dd 0


;for parsing LFN - currently not used
;these numbers represent offset to the ascii byte of a utf-16 sequence
;for example the ascii string "Sled" would be represented in utf-16 as:
;53 00 6c 00 65 00 64 00
UTFarray:
db 1,3,5,7,9
db 14,16,18,20,22,24
db 28,30




;***************************************************************************
;Volume Boot Record VBR for tatOS FAT16 flash drive
;the first sector of an unpartitioned device is a VBR
;if partitioned, the first sector is then called an MBR
;fatformatdrive will write this to the first sector of your flash
;all code in /tlib/fat16.s depends on these values
;this is a non-bootable VBR, we have no boot code here (someday maybe)
;***************************************************************************

tatOSFlashVolumeBootRecord:

	;2 byte jump to operating system boot code
	jmp short .Start

	nop

	;8 byte OEM ID
	db 'tatOS   '

	;BIOS parameter block

	;offset11 tatos used 0x200=512 bytes per sector/block
	dw 0x200

	;offset13 tatos used 0x40=64 sectors or blocks per cluster
	;64 sectors times 512 bytes per sector = 32,768 bytes per cluster = 0x8000 bpc
	db 0x40

	;qty reserved sectors
	;the FAT1 appears immediately after the first sector VBR
	dw 1

	;qty FATS (File Allocation Table)
	db 2

	;offset17 max qty root directory entries
	;since each dir entry is 0x20=32 bytes this means
	;sizeof rootdir = 0x200 * 0x20 = 0x4000 or 32 blocks/sectors
	dw 0x200

	;offset19 total sectors small (used for Floppy Disk Drive size of volume)
	dw 0

	;offset21 media descriptor (0xf0=floppy, 0xf8=hard/pen drive)
	db 0xf8

	;offset22 sectors per FAT 
	;(ToshibaFlashDrive=0xf3, BlueFlashDrive=0xf7, SledDrive=0xff)
	;0xf3*0x200 = 0x1e600 bytes/FAT = 0xf300 words/FAT
	dw 0xf3

	;offset24 sectors per track
	;These next two values are needed for cylinder/sector/head addressing
	;if we ever make tatOS to boot from its own FAT16 formatted flash drive
	;or if we decide to partition the volume
	;the sector is encoded in 6 bits so max value is 0x3f, see /doc/CHS
	dw 0x3e

	;offset26 qty heads
	;the head is encoded in 8 bits but max value allowed is 0xfe, see /doc/CHS
	dw 0x3f

	;qty hidden sectors
	dd 0

	;offset32 total sectors large (Hard drive size of partition)
	;best to use returned data from  usb/SCSI readcapacity
	;my toshiba flash drive has a capacity of 2GB = 0x3c8800 * 0x200 bytes/block
	dd 0x3c8800   

	;36 bytes so far

	;Extended Bios Parameter Block for Fat12 and Fat16


	;offset36 physical drive number (hard drives us 0x80, floppys use 00)
	db 0

	;reserved ("Current Head")
	db 0

	;offset38 extended boot signature
	db 0x29

	;id seriel number
	;we just made this up
	dd 0x3b8fa221

	;offset43 volume label, 11 byte, "NO NAME    " is common
	;the last two bytes allow us to identify changes for future versions
	db 'tatOSdisc01'

	;offset54 file system type, 8 byte
	db 'FAT16   '

	;62 bytes VBR so far

.Start:
	;here is allowed 448 bytes of operating system boot code
	;Linux mkdosfs utility will put some code here to switch the video mode
	;to text using in10h then get a keystroke using int16h, then issue int 19h
	;someday we may add our own custom boot loader code here 
	;so we can boot tatOS from our own FAT16 formatted flash drive
	db 0xeb,0xfe   ;this is jump short $

	;64 bytes so far

	times 446 db 0

	;if we were to partition the flash drive into 2gb blocks
	;we would set up the 4 partition entries here
	;each entry is 16 bytes at offset 0x1be, 0x1ce, 0x1de, 0x1ee
	;for now we just write all 000000 so we have an unpartitioned flash drive

	;the so called "executable marker" is at offset 0x1fe=510
	db 0x55, 0xaa   
	
	;************ end tatOS-VBR/Boot Sector  ***************************








;**********************************************************************
;fatreadVBR
;code to read the fat16 VBR off a tatOS formatted flash drive
;the file manager invokes this function directly

;input:none

;output:
;up to 32 strings describing your FAT VBR are written to LISTCTRLBUF
;each string is 0 terminated and spaced 0x100 bytes apart

;return:
;global variable [qtyVBRstrings] is set
;*********************************************************************

fatreadVBR:

	STDCALL fatstr98,dumpstr	

	;read off pen drive to STARTOFEXE
	mov ecx,1000        ;qtyblocks
	mov ebx,0           ;LBAstart
	mov edi,STARTOFEXE  ;destination
	call read10  


	mov esi,STARTOFEXE
	mov dword [qtydirentrystrings],0
	mov dword [qtyVBRstrings],0


	;a flash drive formated with a FAT16 having a partition table
	;should have an 0x80 byte at offset=0x1be+8
	;this indicates an active partition
	cmp byte [esi+0x1be],0x80
	jnz .noPartitionTable 

	;flash drive has partition info
	;this is unsupported
	;linux calls your drive /dev/sda1
	;we will generate 1 VBR string and quit
	;I suggest formating the flash using the tatOS utility
	STDCALL fatstr39,LISTCTRLBUF,strcpy2
	add dword [qtyVBRstrings],1
	jmp .done


.noPartitionTable:
	;flash drive formatted like floppy
	;linux calls your drive /dev/sda
	;partition starts at offset=0
	;and no partition table


	;test for jmp
	cmp byte [STARTOFEXE],0xeb
	jz .continueJMP

	;we failed to find the eb at start of partition-bail
	STDCALL fatstr40,LISTCTRLBUF,strcpy2
	add dword [qtyVBRstrings],1
	jmp .done


	;start of a normal VBR at offset=0
	;**********************************

.continueJMP:
	;jmp byte1 and byte2 
	xor eax,eax
	mov al,[STARTOFEXE+1]
	STDCALL fatstr2,LISTCTRLBUF,eaxstr
	add dword [qtyVBRstrings],1
	mov al,[STARTOFEXE+2]
	STDCALL fatstr3,LISTCTRLBUF+0x100,eaxstr


	;OEM name  offset=3 bytes=8
	;8 byte ascii padded with 0x20 
	;we bound the name with quotes
	STDCALL fatstr4,LISTCTRLBUF+0x200,strcpy2
	mov byte [LISTCTRLBUF+0x300],'"'
	lea esi,[STARTOFEXE+3]
	mov edi,LISTCTRLBUF+0x301
	mov ecx,8
	call strncpy
	mov byte [LISTCTRLBUF+0x309],'"'
	mov byte [LISTCTRLBUF+0x30a],0


	;bytes per sector offset=11 bytes=2
	mov ax,[STARTOFEXE+11]
	mov [bytespersector],eax
	STDCALL fatstr5,LISTCTRLBUF+0x400,eaxstr
	
	;sectors per cluster offset=13 bytes=1
	xor eax,eax
	mov al,[STARTOFEXE+13]
	mov [sectorspercluster],eax
	STDCALL fatstr6,LISTCTRLBUF+0x500,eaxstr

	;bytespercluster = bytespersector * sectorspercluster
	mov ebx,[bytespersector]
	mul ebx
	mov [bytespercluster],eax
	STDCALL fatstr43,LISTCTRLBUF+0x600,eaxstr


	;qty reserved sectors  offset=14 bytes=2
	xor eax,eax
	mov ax,[STARTOFEXE+14]
	mov [qtyreservedsect],eax
	STDCALL fatstr7,LISTCTRLBUF+0x700,eaxstr

	;qty FATS  offset=16 bytes=1
	xor eax,eax
	mov al,[STARTOFEXE+16]
	STDCALL fatstr8,LISTCTRLBUF+0x800,eaxstr

	;qty root directory entries offset=17 bytes=2
	mov ax,[STARTOFEXE+17]
	mov [qtyrootdirentry],eax
	STDCALL fatstr9,LISTCTRLBUF+0x900,eaxstr

	;qty sectors, small offset=19 bytes=2
	;if 0 use 4 byte value at offset 32
	mov ax,[STARTOFEXE+19]
	STDCALL fatstr10,LISTCTRLBUF+0xa00,eaxstr
	
	;media descriptor offset=21 bytes=1
	;f0=floppy, f8=fixed disk
	xor eax,eax
	mov al,[STARTOFEXE+21]
	mov [mediadescriptor],al
	STDCALL fatstr11,LISTCTRLBUF+0xb00,eaxstr

	;sectors per fat offset=22 bytes=2
	;for FAT12 or FAT16
	mov ax,[STARTOFEXE+22]
	mov [sectorsperFAT],eax
	STDCALL fatstr12,LISTCTRLBUF+0xc00,eaxstr

	;sectors per track offset=24 bytes=2
	mov ax,[STARTOFEXE+24]
	STDCALL fatstr13,LISTCTRLBUF+0xd00,eaxstr

	;qty heads offset=26 bytes=2
	mov ax,[STARTOFEXE+26]
	STDCALL fatstr14,LISTCTRLBUF+0xe00,eaxstr

	;qty hidden sectors offset=28 bytes=4
	mov eax,[STARTOFEXE+28]
	STDCALL fatstr15,LISTCTRLBUF+0xf00,eaxstr

	;qty sectors, large offset=32 bytes=4
	mov eax,[STARTOFEXE+32]
	STDCALL fatstr16,LISTCTRLBUF+0x1000,eaxstr

	;physical drive number offset=36 bytes=1
	xor eax,eax
	mov al,[STARTOFEXE+36]
	STDCALL fatstr17,LISTCTRLBUF+0x1100,eaxstr

	;reserved (current head) offset=37 bytes=1
	mov al,[STARTOFEXE+37]
	STDCALL fatstr18,LISTCTRLBUF+0x1200,eaxstr

	;extended boot signature offset=38 bytes=1
	;0x28 or 0x29 for Windows NT
	mov al,[STARTOFEXE+38]
	STDCALL fatstr19,LISTCTRLBUF+0x1300,eaxstr

	;seriel number ID offset=39 bytes=4
	mov eax,[STARTOFEXE+39]
	STDCALL fatstr20,LISTCTRLBUF+0x1400,eaxstr

	;volume label offset=43 bytes=11
	;11 byte ascii padded with 0x20 
	;"NO NAME    " is common
	;a tatOS formatted flash uses 'tatOSdisc01'
	STDCALL fatstr21,LISTCTRLBUF+0x1500,strcpy2
	mov byte [LISTCTRLBUF+0x1600],'"'
	lea esi,[STARTOFEXE+43]
	mov edi,LISTCTRLBUF+0x1601
	mov ecx,11
	call strncpy
	mov byte [LISTCTRLBUF+0x160c],'"'
	mov byte [LISTCTRLBUF+0x160d],0



	;filesystem ID offset=54 bytes=8
	;8 byte ascii padded with 0x20 
	;"FAT16   " or "FAT12   " ... 
	STDCALL fatstr22,LISTCTRLBUF+0x1700,strcpy2
	mov byte [LISTCTRLBUF+0x1800],'"'
	lea esi,[STARTOFEXE+54]
	mov edi,LISTCTRLBUF+0x1801
	mov ecx,8
	call strncpy
	mov byte [LISTCTRLBUF+0x1809],'"'
	mov byte [LISTCTRLBUF+0x180a],0



	;tom we should at this point check for FAT16 and bail if not


	;boot signature offset=0x1fe bytes=2
	xor eax,eax
	mov ax,[STARTOFEXE+0x1fe]
	STDCALL fatstr23,LISTCTRLBUF+0x1900,eaxstr


	;***************************************
	;end of parsing the Volume Boot Record
	;now dump some VBR derived parameters
	;***************************************


	;offsetFAT1 = offsetStartOfPartition + qtyreservedsect*bytespersector 
	mov eax,[qtyreservedsect]
	mul dword [bytespersector]
	add eax,[offsetStartOfPartition]
	mov [offsetFAT1],eax
	STDCALL fatstr24,LISTCTRLBUF+0x1a00,eaxstr

	;sizeofFAT = bytespersector * sectorsperFAT
	mov eax,[bytespersector]
	mul dword [sectorsperFAT]
	mov [sizeofFAT],eax
	STDCALL fatstr25,LISTCTRLBUF+0x1b00,eaxstr

	;offsetFAT2 = offsetFAT1 + sizeofFAT
	mov eax,[offsetFAT1]
	add eax,[sizeofFAT]
	mov [offsetFAT2],eax
	STDCALL fatstr26,LISTCTRLBUF+0x1c00,eaxstr

	;offset to root directory table
	mov eax,[offsetFAT2]
	add eax,[sizeofFAT]
	mov [offsetrootdir],eax
	STDCALL fatstr27,LISTCTRLBUF+0x1d00,eaxstr

	;compute size of root directory table
	;each directory entry is 32 bytes
	mov eax,[qtyrootdirentry]
	mov ebx,32
	mul ebx
	mov [sizeofrootdir],eax
	STDCALL fatstr28,LISTCTRLBUF+0x1e00,eaxstr

	;offset to start of file data region
	;file data starts immediately after the root directory
	add eax,[offsetrootdir]
	mov [offsetfiledata],eax
	STDCALL fatstr42,LISTCTRLBUF+0x1f00,eaxstr


	;for a normal tatOS VBR we generate 32 strings
	mov dword [qtyVBRstrings],32

.done:

	;values for the ListControl
	mov eax,[qtyVBRstrings]
	mov dword [list_QtyStrings],eax
	call ListControlDoHome
	ret





;********************************************************************
;fatcluster2LBA
;this function takes as input the starting cluster number of a file
;and outputs the LBAstart of the file data for read10/write10
;see formulas for this above
;for example if the firstcluster=2 then file data begins at LBA=0x207

;input
;eax=starting cluster number of file
;return
;on success eax=LBAstart and ZF is clear
;on error eax=0 and ZF is set if bad cluster number out of range

;for a tatOS formatted flash drive we have:
;offsetfiledata = 0x40e00
;bytespercluster= 0x8000
;********************************************************************

fatcluster2LBA:

	push ebx
	push edx
	STDCALL fatstr68,0,dumpeax

	;test for valid cluster
	;this may catch a previous write error to the fat
	;valid cluster number must be in the range of 2-0xee00
	;for a tatOS FAT16 2gig accessible flash drive
	cmp eax,2
	jb .error
	cmp eax,0xee00
	ja .error

	sub eax,2        ;the file data starts with clusternum=2
	shl eax,15       ;multiply eax by 0x8000 bytes per cluster
	add eax,0x40e00  ;add offset to start of file data
	shr eax,9        ;divide by 512 bytes per sector
	;eax=LBA

	jmp .success

.error:
	STDCALL fatstr113,dumpstr
	xor eax,eax  ;ZF is set and eax=0 on error
	jmp .done
.success:
	STDCALL fatstr56,0,dumpeax
	or edx,1   ;ZF is clear
.done:
	;return LBA in eax
	pop edx
	pop ebx
	ret







;****************************************************************
;fatformatdrive
;formats your flash drive by writting:
;	a new VolumeBootRecord to the first block
;	a new FAT1 starting immediately after the VBR
;	a new FAT2 starting immediately after FAT1
;	clearing the root dir.  
;   loads the vbr, fats and rootdir into memory

;Warning: make sure your flash drive has no files on it !!!!
;note you may not store your tatOS.img on this flash drive
;this function formats your flash as non-bootable
;we assume you keep a seperate drive for tatOS.img
;run this utility on a flash drive for storing FAT16 files only

;input:none
;return:none

;assumptions:
;bytespersector=0x200
;sectorsperfat=0xf3
;bytesperfat=0xf3*0x200=0x1e600
;sectorspercluster=0x40
;bytespercluster=0x40*0x200=0x8000
;maxnumrootdirentries=0x200
;sizeofrootdir=0x200*32bytesperentry=0x4000
;mediadescriptorbyte=0xf8
;***************************************************************

fatformatdrive:

	;give the user a Warning and chance to quit
	STDCALL fatstr54,COMPROMPTBUF,comprompt
	jnz near .done  ;user ESC

	STDCALL fatstr120,dumpstr


	;allocate some scratch memory for building the VBR,FAT1,FAT2,ROOTDIR
	mov ecx,0x40e00
	call alloc
	jz .done
	;esi=address of our memory block, must preserve this reg


	;zero out memory where we will copy the VBR, FAT1, FAT2 and root dir
	;the total qty zero bytes we are writting is
	;0x200 for VBR + 0x1e600 for FAT1 + 0x1e600 for FAT2 + 0x4000 for rootdir
	cld
	mov al,0
	mov edi,esi
	mov ecx,0x40e00
	rep stosb


	;copy the VBR 
	push esi
	mov edi,esi   
	mov esi,tatOSFlashVolumeBootRecord
	mov ecx,512
	rep movsb
	pop esi ;esi=start of scratch memory


	;cluster=0
	;FAT1 starts at offset 0x200
	;the first word of FAT1 is (ff + mediadescriptorbyte)
	mov word [esi+0x200],0xfff8

	;cluster=1
	;the second word of FAT1 is 0xffff reserved
	;we dont use it but mark ffff 
	mov word [esi+0x202],0xffff

	
	;now mark FAT2 same as FAT1
	;FAT2 starts at 0x200 + 0x1e600
	mov word [esi+0x1e800],0xfff8
	mov word [esi+0x1e802],0xffff


	;now write to flash drive
	;the total qty bytes we are writting is 0x40e00 bytes or 0x207 blocks
	;esi = start of scratch memory
	mov ebx,0          ;destination LBAstart
	mov ecx,0x207      ;qty blocks to write
	call write10  
	cmp eax,1
	jz .fail


	;now reload the vbr,fat1,fat2,and rootdir to memory
	;the only other place this is done is at the end of initflash
	call fatloadvbrfatrootdir


	STDCALL fatstr95,fatstr95a,popupmessage
	jmp .done

.fail:
	STDCALL fatstr95,fatstr95b,popupmessage
.done:
	;esi=memory address to free
	call free  
	ret



;***************************************************
;FATSETCWDASROOT
;fatsetCWDasRoot
;sets the current working directory as root
;input:none
;return:none
;****************************************************

fatsetCWDasRoot:
	STDCALL fatstr101,dumpstr
	STDCALL ROOTSTR,NAMEOFCWD,strcpy2
	mov dword [CurrentWorkingDirectory],0  ;1=root
	ret





;****************************************************************************
;fatloadvbrfatrootdir
;this function loads 0x207 blocks or 0x40e00 bytes of data off the flash drive
;into memory, this is the VBR, FAT1, FAT2 and ROOTDIR 
;does not change the current working directory to root
;this function is customized for a tatOS formatted flash drive
;as tatOS file operations now modify the fats and rootdir in memory only
;there are only two places where this function can be called
;1=end of initflash
;2=end of fatformatflash

;input:none
;return:none

;for a tatOS formatted FAT16 flash drive:
;0x1900000=STARTVBR  
;0x1900200=STARTFAT1
;0x191e800=STARTFAT2
;0x193ce00=STARTROOTDIR
;****************************************************************************

fatloadvbrfatrootdir:
	pushad	
	STDCALL fatstr63,dumpstr

	;VBR is 1 block
	;each FAT is 0xf3 blocks = 0x1e600 bytes
	;the root dir is 0x20 blocks  (0x200entries * 32bytesper=0x8000 bytes)
	;1+0xf3+0xf3+0x20=0x207 
	mov ecx,0x207       ;qtyblocks  
	mov ebx,0           ;LBAstart
	mov edi,STARTVBR    ;destination
	call read10  

	;set some globals needed by fatcluster2LBA
	mov dword [bytespercluster],0x8000
	mov dword [offsetfiledata], 0x40e00

	popad
	ret






;**********************************************************************
;FATREADFILE
;fatreadfile
;searches the DIRENTRIES in the CWD by filename
;loads the filedata clusters off flash to destination memory 
;ehci likes memory addresses on 32 byte boundrys so make sure your
;destination address ends in at least 2 zeros hex (e.g. 0x125400)

;this function requires a previous call to filemanager
;which stores the filename at FILENAME in kernel memory
;or kernel may copy 11 byte filename to FILENAME directly

;input
;push destination memory address         [ebp+8]

;return:
;eax=filesize,bytes else 0 if file not found

;there is no check to make sure the memory block is big enough
;*********************************************************************

fatreadfile:

	STDCALL fatstr55,dumpstr

	push ebp
	mov ebp,esp

	push ebx
	push ecx
	push edx
	push esi
	push edi


	STDCALL FILENAME,fatfindfile  ;only searches the CWD
	;returns address of DIRENTRY in esi
	cmp eax,0
	jz near .error


	call fatbuildtatOSdirString
	STDCALL FATDIRSTRING,dumpstr


	;is this an archive ?
	cmp dword [direntry.attributes],0x20
	jnz .error


	;now prepare to read the file data
	mov eax,[direntry.startingcluster]
	mov [clusternum],eax
	STDCALL fatstr57,0,dumpeax
	mov edi,[ebp+8]  ;destination 

.clusterToLBA:
	;convert starting cluster number to LBAstart
	mov eax,[clusternum]
	call fatcluster2LBA  
	;on success eax=LBAstart and ZF is clear
	;on error eax=0 and ZF is set
	jz .error


	;read the cluster off pen drive to edi
	mov ecx,0x40    ;qtyblocks (we read 1 cluster)
	mov ebx,eax     ;LBAstart
	call read10     ;edi=destination memory address

	;increment destination memory address
	add edi,0x8000  ;bytes/cluster

	;here would be a good place to check if we might exceed our memory limit

	;get the number of the next cluster from the FAT
	mov eax,[clusternum]
	;get address of cluster num in FAT1
	lea ebx,[STARTVBR+0x200+eax*2]  
	xor eax,eax
	mov ax,[ebx]   ;read FAT1 
	mov [clusternum],eax
	STDCALL fatstr57,0,dumpeax

	;test for last cluster in chain
	cmp eax,0xffff 
	jnz .clusterToLBA
	jmp .success


.error:
	;there are 3 ways to get here
	;1) fatfindfile did not find file in CWD
	;2) found direntry but its not an archive 0x20
	;3) fatcluster2LBA returned error, invalid cluster number, corrupt FAT
	STDCALL fatstr78,dumpstr
	xor eax,eax  ;return 0
	jmp .done

.success:
	mov eax,[direntry.filesize]  ;return value

.done:
	STDCALL fatstr69,0,dumpeax
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop ebp
	retn 4







;********************************************************************************
;FATWRITEFILE
;fatwritefile
;this is your general purpose file save routine for a tatOS FAT16 flashdrive
;  * create a DIRENTRY structure for the file 
;  * mark the appropriate clusters in the FAT as used
;  * save the CWD to flash
;  * save the FATs to flash
;  * save the file data to flash

;if the filename already exists in the CWD, then we abort
;this forces you to save backup copies with names like file1, file2...
;you must manually delete all these copies

;this function requires a previous call to fatgetfilename
;which stores the filename at COMPROMPTBUF in kernel memory

;input
;push address of file data                         [ebp+12]
;push filesize,bytes                               [ebp+8]

;return: eax=0 if successful 
;        eax=1 if filesize is 0 
;        eax=1 if failed to find available cluster
;        eax=1 if failed to find available entry in directory
;        eax=1 if invalid LBA
;        eax=1 if subroutine failure
;        eax=2 if file already exists
;*******************************************************************************

fatwritefile:

	push ebp
	mov ebp,esp

	push ebx
	push ecx
	push edx
	push esi
	push edi

	STDCALL fatstr70,dumpstr


	;abort if filesize=0
	;tatOS treats filesize=0 as a subdir
	;and fatwritefile is not to be used for subdir
	cmp dword [ebp+8],0
	jz near .filesizezero



	;first check if this same filename already exists in the CWD
	;tatOS does not permit over write or saving duplicate filenames
	STDCALL COMPROMPTBUF,fatfindfile
	cmp esi,0   ;if esi=0 then filename is not in CWD
	jnz near .badfilename


	;now lets build a new 32 byte directory entry 
	push dword COMPROMPTBUF ;filename
	push dword [ebp+8]      ;filesize
	push dword 0x20         ;archive
	call fatWriteDirEntry   
	jz near .subroutinefailure



	;how many clusters do we need for the file ?
	mov eax,[ebp+8]  ;filesize
	mov ebx,0x8000   ;bytespercluster with tatOS formatted flash drive
	xor edx,edx
	div ebx
	add eax,1
	mov [qtyclusters],eax  ;save qty clusters needed for file
	STDCALL fatstr60,0,dumpeax
	


	;Mark the FAT
	;***************
	
	;single cluster file
	;if your fat contains lots of ffff entries these are small 1 cluster files
	cmp eax,1
	ja .markmultipleclusters

	;mark FAT single cluster only
	STDCALL fatstr72,dumpstr
	mov eax,[direntry.startingcluster]
	;get address of startingcluster
	lea edi,[STARTFAT1+eax*2]
	mov word [edi],0xffff   ;mark as terminate 
	jmp .saveCWD




.markmultipleclusters:

	;routine to find and mark multiple entries in fat 
	;as belonging to this large multi-cluster file
	;if your file is larger than 0x8000 bytes = 32,768
	;then we need to mark multiple clusters as used
	;each word in the FAT gets marked with the index of 
	;the next available entry in the FAT
	STDCALL fatstr73,dumpstr

	;set CurrentCluster equal to the startingcluster
	mov eax,[direntry.startingcluster]
	mov [CurrentCluster],eax

	;set esi to address of cluster after startingcluster
	add eax,1
	lea esi,[STARTFAT1+eax*2]   

	;loop counter is 1 less than qty clusters reqd
	mov edx,[qtyclusters]
	sub edx,1        ;edx=loop counter

.findNextAvailableCluster:
	mov ax,[esi]     ;get cluster num

	cmp ax,0         ;test for 00
	jz .markCluster

	cmp esi,STARTFAT2 ;test for STARTFAT2 which means we reached the end of FAT
	jae near .NoClusterAvailable

.incrementClusterNum:
	add esi,2  ;increment address of cluster to check by 1 word
	jmp .findNextAvailableCluster


.markCluster:

	;esi holds address of NextAvailableCluster

	;compute ax = index of NextAvailableCluster 
	mov eax,esi
	sub eax,STARTFAT1         
	shr eax,1   ;divide by 2 because FAT16 clusters are words

	;save number of NextAvailableCluster at the CurrentCluster position	
	mov ebx,[CurrentCluster]
	lea edi,[STARTFAT1+ebx*2]    ;get address of current cluster 

	;mark the FAT CurrentCluster with number of NextAvailableCluster
	mov [edi],ax                 

	;save CurrentCluster as NextAvailableCluster
	mov [CurrentCluster],eax

	;decrement qtyclusters marked
	sub edx,1
	jnz .incrementClusterNum

	;mark the last cluster as terminate
	lea edi,[STARTFAT1+eax*2]    ;get address of last cluster 
	mov word [edi],0xffff        ;mark the FAT as terminate

	;done marking the FAT



.saveCWD:

	;save the CWD entries

	cmp dword [CurrentWorkingDirectory],SUBDIRECTORY
	jz .saveSUB
	cmp dword [CurrentWorkingDirectory],ROOTDIRECTORY
	jz .saveROOT

	jmp .writefail ;we should never make this jump

.saveSUB:

	;CWD is sub so save the sub directory entries
	call fatsavesub
	jz near .writefail
	jmp .saveFAT


.saveROOT:

	;CWD is root so save the root
	call fatsaveroot  ;sets ZF on write10 error
	jz near .writefail
	;fall thru

	
.saveFAT:
	;no matter if we are in a subdir or rootdir, we must save the fats
	call fatsavefat
	jz near .writefail



.writeFlashData:

	;Write File Data to flash
	;*************************

	STDCALL fatstr76,dumpstr
	mov eax,[direntry.startingcluster]
	mov [clusternum],eax
	mov esi,[ebp+12]  ;source file data 


.WriteFileDataLoop:

	;in this loop esi must be preserved

	;convert starting cluster number to LBAstart
	mov eax,[clusternum]
	call fatcluster2LBA  ;return value in eax
	;on success eax=LBAstart and ZF is clear
	;on error eax=0 and ZF is set if bad cluster number out of range
	jz near .badClusterNumber

	;write the file data to cluster
	mov ecx,0x40    ;qtyblocks (we write 1 cluster)
	mov ebx,eax     ;LBAstart
	;esi=source memory address
	call write10    
	jz near .writefail

	;increment source memory address
	add esi,0x8000  ;bytes/cluster

	;decrement the qty clusters written
	sub dword [qtyclusters],1
	jz near .success

	;get the number of the next cluster from the FAT
	mov eax,[clusternum]
	;get address of cluster num in FAT1
	lea ebx,[STARTFAT1+eax*2]  
	xor eax,eax
	mov ax,[ebx]   ;read FAT1 
	mov [clusternum],eax
	STDCALL fatstr99,0,dumpeax
	cmp eax,0
	jnz .WriteFileDataLoop


	;if we got here we read a 0000 cluster value which is illegal
	;somehow our FAT is not marked correctly
	STDCALL fatstr77,dumpstr
	mov eax,1
	jmp .done


.subroutinefailure:
	mov eax,1
	jmp .done
.NoClusterAvailable:
	STDCALL fatstr81,putspause
	mov eax,1
	jmp .done
.badClusterNumber:
	STDCALL fatstr121,putspause	
	mov eax,1
	jmp .done
.badfilename:
	STDCALL fatstr80,putspause
	mov eax,2
	jmp .done
.filesizezero:
	STDCALL fatstr67,putspause
	mov eax,1
	jmp .done
.writefail:
	mov eax,1
	STDCALL fatstr112,putspause
	jmp .done
.success:
	mov eax,0
.done:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop ebp
	retn 8  ;clean up what user pushed onto the stack






;****************************************************************************
;fatFillinDirEntry
;fills in most of the fields of a 32byte msdos FATDIRENTRY structure 
;the flash drive is not updated
;does not look for the first available cluster because
;this action is not wanted for creating dot and dotdot entries
;input
;push address of 11 char ascii filename base+ext   [ebp+16]
;push filesize,bytes                               [ebp+12]
;push 0x10 for SubDir or 0x20 for Archive          [ebp+8]
;return:none
;*****************************************************************************

fatFillinDirEntry:

	push ebp
	mov ebp,esp
	pushad

	STDCALL fatstr92,dumpstr

	mov esi,[ebp+16]
	call fatCopyFilename

	STDCALL [ebp+8],[ebp+12],fatSetAttributes

.done:
	popad
	pop ebp
	retn 12




;****************************************************************************
;FATWRITEDIRENTRY
;fatWriteDirEntry
;calls fatFillinDirEntry to fill in the fields of a FATDIRENTRY structure
;finds a place for the FATDIRENTRY structure in rootdir or CWD and writes 
;input
;push address of 11 char ascii filename base+ext   [ebp+16]
;push filesize,bytes                               [ebp+12]
;push 0x10 for SubDir or 0x20 for Archive          [ebp+8]
;return
;ZF is set on failure, clear on success
;*****************************************************************************

fatWriteDirEntry:

	push ebp
	mov ebp,esp
	pushad

	STDCALL fatstr44,dumpstr


	;most of the work is done here
	;fills in the fields of the FATDIRENTRY structure
	STDCALL [ebp+16],[ebp+12],[ebp+8],fatFillinDirEntry


	call fatFindAvailableCluster  
	;returns cluster num in [startingcluster]
	jz .fail


	;find a place for our FATDIRENTRY struct in rootdir or subdir
	call fatFindAvailableDirEntry
	cmp edi,0
	jz .fail


	;copy our new 32byte FATDIRENTRY structure 
	cld
	mov esi,FATDIRENTRY  
	;edi is set by fatFindAvailableDirEntry 
	mov ecx,32
	rep movsb


	;if we got here we succeeded
	or eax,1  ;clear ZF
	jmp .done

.fail:
	STDCALL fatstr122,dumpstr
	xor eax,eax  ;set ZF on fail	
.done:
	popad
	pop ebp
	retn 12





;**************************************************************************
;fatCopyFilename
;copies the 11 byte filename to the FATDIRENTRY structure
;input
;esi=address of filename
;*************************************************************************

fatCopyFilename:

	STDCALL fatstr46,dumpstr

	cld
	;esi is set by calling function
	mov edi,FATDIRENTRY
	mov ecx,11
	rep movsb

	ret






;**************************************************************************
;fatSetAttributes
;sets 0x10 for SubDir or 0x20 for archive
;sets the reserved byte
;sets the various dates (most are just zeroed out)
;sets the filesize
;bytes are written to the FATDIRENTRY structure in memory
;input
;push 0x10 for SubDir or 0x20 for Archive  [ebp+12]
;push the filesize in bytes                [ebp+8]
;return:none
;**************************************************************************

fatSetAttributes:

	push ebp
	mov ebp,esp

	STDCALL fatstr90,dumpstr

	;set the file attributes
	mov al,[ebp+12]
	mov [FATDIRENTRY+11],al

	;reserved byte is not used
	mov byte [FATDIRENTRY+12],0

	;create time not used
	mov byte [FATDIRENTRY+13],0
	mov byte [FATDIRENTRY+14],0
	mov byte [FATDIRENTRY+15],0

	;EA-Index not used
	mov byte [FATDIRENTRY+20],0
	mov byte [FATDIRENTRY+21],0

	;last modified time is not used
	mov byte [FATDIRENTRY+22],0
	mov byte [FATDIRENTRY+23],0


	;last modified date 
	;bios gave us BCD values to convert
	;we save byte year at 0x512, day at 0x511 and month at 0x510
	xor ecx,ecx

	mov al,[0x512]      ;get year
	call bcd2bin        ;returns al=binary equiv
	mov cl,al
	add ecx,20          ;need num years since 1980
	shl ecx,9           ;year occupies bits 9-16

	mov al,[0x510]      ;get month
	call bcd2bin
	shl eax,5           ;month occupies bits 5-8 
	or ecx,eax          ;add month to year

	mov al,[0x511]      ;get day
	call bcd2bin        ;day occupies bits 0-4
	or ecx,eax          ;add day to month,year

	;set the last modified date
	mov [FATDIRENTRY+24],cx
	;set the last access date to same
	mov [FATDIRENTRY+18],cx
	;set the create date to same
	mov [FATDIRENTRY+16],cx


	;write the filesize to the DIRENTRY
	mov eax,[ebp+8]
	mov [FATDIRENTRY+28],eax

	pop ebp
	retn 8



;**************************************************************************
;fatFindAvailableCluster
;searches FAT1 for the first available 00
;assumes a previous call to fatfindfile
;input:none
;return
;ZF is set on error, clear on success
;eax=[startingcluster]=cluster number found on success
;**************************************************************************

fatFindAvailableCluster:

	STDCALL fatstr91,dumpstr

	;scan FAT1 looking for 00
	;ff entries or non-zero entries are taken by another file
	cld
	mov ecx,0xf300   ;qty words in tatOS FAT
	mov edi,STARTFAT1
	mov ax,0
	repne scasw      ;repeat while ax is != 0

	cmp ecx,0        ;if this got to zero we failed to find
	jz .fail

	;if we got here we found an available cluster
	;ecx decrements down til scasw finds ax=0
	;now we compute the cluster number 
	add ecx,1    ;the scan functions always over shoot 
	mov eax,0xf300
	sub eax,ecx


	;save first available cluster num found
	mov [FATDIRENTRY+26],ax
	mov [direntry.startingcluster],eax  
	STDCALL fatstr34,0,dumpeax

	;check that this number is greater than 2
	;since the first 2 clusters are always reserved
	cmp dword [direntry.startingcluster],2
	jae .success
	STDCALL fatstr110,putspause
	jmp .fail

.success:
	or eax,1 ;clear ZF on success
	jmp .done

.fail:
	STDCALL fatstr58,dumpstr
	xor eax,eax

.done:
	ret







;***************************************************************************
;FATFINDAVAILABLEDIRENTRY
;fatFindAvailableDirEntry
;searches an array of DIRENTRY structures for the first 00 entry
;input:
;global dword [CurrentWorkingDirectory] must be set to 0 for root
;or set to 1 for sub
;return:
;edi=address of available 32byte dir entry
;edi=0 if failed to find
;***************************************************************************

fatFindAvailableDirEntry:

	STDCALL fatstr105,dumpstr


	;are we searching root dir entries or sub dir entries ?
	cmp dword [CurrentWorkingDirectory],0
	jz .searchRootDir
	cmp dword [CurrentWorkingDirectory],1
	jz .searchSubDir
	jmp .error      ;invalid dir ID
.searchRootDir:
	mov ecx,0x200  ;max qty entries
	mov edi,STARTROOTDIR 
	jmp .doneWorkingDirectory
.searchSubDir:
	mov ecx,0x400  
	mov edi,STARTSUBDIR
.doneWorkingDirectory:



.topofloop:
	mov al,[edi]

	;we ignore the e5 deleted entries in tact 
	;this is for possible file recovery

	cmp al,0  ;entry is available and no subsequent entry in use
	jz .done

	add edi,32   ;next entry in dir is 32 bytes away
	loop .topofloop

.error:
	;if we got here we failed to find available entry in dir
	STDCALL fatstr59,dumpstr
	xor edi,edi  ;edi=0, fail
.done:
	;return value in edi
	ret








;******************************************************************
;FATREADDIRENTRY
;fatreadDirEntry
;this function reads and picks apart a 32byte FATDIRENTRY structure 
;from the rootdir or any subdir
;and stores the various fields for our convience in global memory
;the address of the particular direntry being examined 
;is stored at dword [direntryaddress]

;the following global values are filled in:
;1)  direntry.filename   (11 char 0 terminated string)
;    (bbbbbbbbeee0, bbbbbbbb=8 char basename, eee=3 char extension)
;2)  dword direntry.attribute (0x10=sub, 0x20=archive...)
;3)  dword direntry.startingcluster   
;4)  dword direntry.filesize          
;5)  dword direntry.lastmodifieddate  

;input
;	esi=starting address in memory of directory entry 

;return: value in eax
;global dword [direntryaddress] is saved
;eax = 0 entry is available and no more entries in directory
;      1 0xe5 erased entry
;      2 LFN entry
;      3 archive 
;      4 subdirectory
;      5 other combinations of attributes are set
;*****************************************************************

fatreadDirEntry:

	push ecx
	push esi
	push edi


	;store the address of the dir entry
	;this is for the benefit of tatOS file utilities
	;that want to modify this dir entry 
	mov [direntryaddress],esi


	;entry is available and no more entries in dir
	cmp byte [esi],0
	jz .done0 

	;erased entry 
	cmp byte [esi],0xe5
	jz .done1

	;LFN entry 
	cmp byte [esi+11],0x0f
	jz .done2

	

	;8.3 filename
	push esi
	cld
	mov edi,direntry.filename
	mov ecx,11
	rep movsb
	pop esi

	;attributes 
	xor eax,eax
	mov al,[esi+11]
	mov [direntry.attributes],eax

	;last modified date 
	;bits[15:9] = numyears since 1980
	;bits[8:5]  = month
	;bits[4:0]  = day
	xor eax,eax
	mov ax,[esi+24]
	mov [direntry.lastmodifieddate],eax

	;starting cluster
	or eax,eax
	mov ax,[esi+26]
	mov [direntry.startingcluster],eax

	;filesize
	mov eax,[esi+28]
	mov [direntry.filesize],eax


	cmp byte [esi+11],0x20  ;archive
	jz .done3
	cmp byte [esi+11],0x10  ;subdir
	jz .done4

	jmp .done5

.done0:
	xor eax,eax
	jmp .done
.done1:
	mov eax,1
	jmp .done
.done2:
	mov eax,2
	jmp .done
.done3:
	mov eax,3
	jmp .done
.done4:
	mov eax,4
	jmp .done
.done5:
	mov eax,5

.done:
	;STDCALL fatstr64,0,dumpeax  ;for debug
	pop edi
	pop esi
	pop ecx
	ret





;******************************************************************
;fatbuildtatOSdirString
;this function builds a formatted 0 terminated ascii string 
;describing a single directory entry
;the ascii string is 76 bytes long
;tatOS displays this string in its filemanager

;the string looks like this:

	;"filenametxt   filesize  mm dd yyyy   attributes    startcluster",0

;8 byte base filename w/ 3 byte extension appended
;filesize in decimal
;month last modified
;day last modified
;year last modified
;attributes string: F=file, D=directory, R=readonly, S=system, H=hidden
;Starting Cluster number

;input: a previous read to fatreadDirEntry is required
;       the directory entry should not be LFN, 00 or e5

;return:
;	the string is written to FATDIRSTRING and is 0 terminated
;*****************************************************************

fatbuildtatOSdirString:

	pushad

	;first fill the string with 75 spaces
	cld
	mov ecx,75
	mov al,SPACE
	mov edi,FATDIRSTRING
	rep stosb


	;copy the 11 byte filename
	mov edi,FATDIRSTRING
	mov esi,direntry.filename
	mov ecx,11
	rep movsb


	;filesize
	mov eax,[direntry.filesize]
	lea esi,[FATDIRSTRING+14]  ;col 14
	STDCALL esi,0,1,eax2dec


	;last modified date
	mov eax,[direntry.lastmodifieddate]
	mov ebx,eax  ;copy

	;month last modified
	mov eax,ebx
	shr eax,5
	and eax,1111b
	lea esi,[FATDIRSTRING+25]
	STDCALL esi,0,1,eax2dec

	;day last modified
	mov eax,ebx
	and eax,11111b
	lea esi,[FATDIRSTRING+28]
	STDCALL esi,0,1,eax2dec

	;year last modified
	mov eax,ebx
	shr eax,9
	and eax,1111111b ;mask off numyears since 1980
	add eax,1980
	lea esi,[FATDIRSTRING+31]
	STDCALL esi,0,1,eax2dec



	;attributes
	;R=read only
	;H=hidden
	;S=sysetm
	;V=volume label
	;D=directory (sub)
	;F=file (archive)
	mov eax,[direntry.attributes]
	lea edi,[FATDIRSTRING+40]

	;readonly
	bt eax,0
	jnc .notR
	mov byte [edi],'R'
	inc edi
	mov byte [edi],','
	inc edi
.notR:

	;hidden
	bt eax,1
	jnc .notH
	mov byte [edi],'H'
	inc edi
	mov byte [edi],','
	inc edi
.notH:

	;system
	bt eax,2
	jnc .notS
	mov byte [edi],'S',
	inc edi
	mov byte [edi],','
	inc edi
.notS:

	;volumelabel
	bt eax,3
	jnc .notV
	mov byte [edi],'V',
	inc edi
	mov byte [edi],','
	inc edi
.notV:

	;subdirectory
	bt eax,4
	jnc .notD
	mov byte [edi],'D',
	inc edi
	mov byte [edi],','
	inc edi
.notD:

	;archive/file
	bt eax,5
	jnc .notF
	mov byte [edi],'F',
	inc edi
	mov byte [edi],','
	inc edi
.notF:

	;bit6 is device (internal use only never found on disc)
	;and bit7 is unused



	;starting cluster number
	mov eax,[direntry.startingcluster]
	lea esi,[FATDIRSTRING+55]  
	STDCALL esi,0,1,eax2dec

	
	;0 terminator 
	mov byte [FATDIRSTRING+75],0

	popad
	ret



;**************************************************************************
;FATRENAMEFILE
;fatrenamefile
;change the 11 char name of a file or subdir in the CWD
;input
;push address of existing 11 char filename   [ebp+12]
;push address of new 11 char filename        [ebp+8]
;return:
;**************************************************************************

fatrenamefile:

	push ebp
	mov ebp,esp

	STDCALL fatstr66,dumpstr

	;search the CWD by filename
	STDCALL [ebp+12],fatfindfile
	;returns esi=address of DIRENTRY and eax=filesize if successful

	cmp esi,0  ;failed
	jz .done


	;dump the dir entry strings  
	call fatbuildtatOSdirString
	STDCALL FATDIRSTRING,dumpstr


	;overwrite the existing filename 
	cld 
	mov esi,[ebp+8]
	;the 11 char filename occupies the first 11 bytes
	;of any dir entry
	mov edi,[direntryaddress]  ;fatreaddirentry gives us this
	mov ecx,11
	rep movsb


	;save changes made to flash
	cmp dword [CurrentWorkingDirectory],ROOTDIRECTORY
	jz .saveroot
	cmp dword [CurrentWorkingDirectory],SUBDIRECTORY
	jz .savesub
	jmp .failed

.saveroot:
	call fatsaveroot ;zf set on error
	jz .failed
	jmp .done
.savesub:
	call fatsavesub  ;zf set on error
	jnz .done


.failed:
.done:
	pop ebp
	retn 8





;********************************************************************
;FATDELETEFILE
;fatdeletefile
;delete a file off your tatOS formatted flash drive in the CWD
;this function will not delete a subdir
;actually a better name for this function is "fat_delete_direntry"
;all this function does is mark the first byte of the directory entry 
;as 0xe5 meaning "erased".  The FAT is not touched and neither is the
;file data.  To recover this file at a later date you can always dump 
;the ROOTDIR and raw FAT later and read the clusters making up the file
;eventually you must reformat the drive to regain the storage space

;input: 
;eax = address of 11 char filename to delete    [ebp+8]
;return:eax=nonzero if file was found 
;       eax=0 if failed to find
;********************************************************************

fatdeletefile:

	STDCALL fatstr84,dumpstr

	STDCALL eax,fatfindfile
	;success if eax=nonzero, failed if eax=0, esi=address of dir entry 

	cmp eax,0
	jz .failed

	;are we deleting an archive ?
	cmp dword [direntry.attributes],0x20
	jnz .failed


.setDeleteByte:
	;overwrite the first byte of the filename with e5
	;this signifies a deleted file
	mov byte [esi],0xe5

	
	;save changes made to flash
	cmp dword [CurrentWorkingDirectory],ROOTDIRECTORY
	jz .saveroot
	cmp dword [CurrentWorkingDirectory],SUBDIRECTORY
	jz .savesub
	jmp .failed

.saveroot:
	call fatsaveroot ;zf set on error
	jz .failed
	jmp .done
.savesub:
	call fatsavesub  ;zf set on error
	jnz .done



.failed:
	STDCALL fatstr97,dumpstr

.done:
	ret 


;*************************************************************
;FATGETFILENAME
;fatgetfilename
;this function presents an 11 char "gets" edit control
;for the user to enter a filename
;it does not actually check for a valid filename on your flash
;prompts the user for a 11 char ascii FAT16 filename string
;if the user enters less than 11 char, spaces are appended
;the string is stored starting at COMPROMPTBUF
;the 0 terminated string is exactly 11 characters long always
;typical usage is getting filename from user prior to fatwritefile

;input:
;push address of 0 terminated prompt string   [ebp+8]
;return:ZF is set on success else clear on failure (user hit ESC)

;the prompt string varies by application
;tedit has its own prompt string for saving files
;the filemanager has its own prompt string for delete and rename files
;************************************************************

fatgetfilename:

	push ebp
	mov ebp,esp
	pushad

	STDCALL fatstr48,dumpstr

	;we want this dialog to always appear at bottom of screen
	push dword [YORIENT]  ;save calling programs Yorientation
	mov dword [YORIENT],1 ;set Yorientation to top down


	;this code is copied from comprompt
	;we only want gets to offer a 11 char edit control

	;background for prompt string
	STDCALL 0,570,800,15,BLA,fillrect


	;we do not want "gets" to display whats in the destination buffer
	;this presents a blank edit box with every invocation
	mov byte [COMPROMPTBUF],0


	;prompt string
	STDCALL FONT01,0,570,[ebp+8],0xfdef,puts  


	;display the gets editbox along the bottom of screen
	;the user may only enter up to 11 chars
	;red caret, black text on yellow
	;edi=buffer to store string
	mov ebx,0             ;x
	mov eax,585           ;y
	mov ecx,11            ;edit control will collect max 11 chars
	mov edi,COMPROMPTBUF  ;destination buffer
	mov edx,LRE           ;colors 00ccbbtt
	shl edx,16            ;caret
	mov dh,YEL            ;background
	mov dl,BLA            ;text
	call gets             ;gets has its own paint loop
	jnz .done    
	;zf is clear if user ESCaped


	;mess-age the filename string to make it exactly 11 char
	;with appended spaces and 0 terminated
	mov eax,COMPROMPTBUF
	call fatprocessfilename


	STDCALL fatstr79,dumpstr  ;'filename entered:'

	;dump the filename string (eax=address of)
	mov eax,COMPROMPTBUF
	STDCALL eax,dumpstrquote 

	xor eax,eax  ;set ZF on success, comprompt clears on error

.done:
	pop dword [YORIENT]  ;restore calling programs Yorientation
	popad
	pop ebp
	retn 4



;**************************************************
;fatprocessfilename
;this code mess-ages a filename string making
;it exactly 11 chars long with appended spaces
;and 0 terminated
;input: eax=address of unprocessed filename string
;return:none
;**************************************************

fatprocessfilename:

	mov edx,eax  ;save copy of string address for later

	;is the filename string less than 11 char ?
	call strlen   
	;return value in ecx

	cmp ecx,11
	jae .terminate

	;the string is shorter than 11 chars
	;then append spaces to make it 11 char long
	cld
	;edx=address of string
	;ecx=strlen
	lea edi,[edx+ecx]
	mov ebx,11
	sub ebx,ecx
	xchg ebx,ecx  ;ecx=num spaces to append
	mov al,SPACE
	rep stosb

.terminate:
	mov byte [edx+11],0  ;terminate the 12th byte
	ret






;*************************************************************
;FATMAKESUBDIR
;fatmakeSubDir
;this function will change the CWD to root
;it will check to see if a subdir of the same name exists
;if not it will create a new subdir in root with the given name
;only 1 cluster is reserved for the subdir entries
;input
;push address of 11 char ascii Directory name   [ebp+8]
;return:
;eax=0 on success, nonzero on failure
;************************************************************

fatmakeSubDir:

	push ebp
	mov ebp,esp

	STDCALL fatstr45,dumpstr

	;we assume the root dir has been previously loaded to memory 

	;does this same dir name exist ?
	STDCALL [ebp+8],fatfindfile
	cmp esi,0   ;esi=0 if file does not exist
	jz .donecheckexist
	STDCALL fatstr80,dumpstr
	mov eax,2
	jmp .done
.donecheckexist:



	;now lets build a new 32 byte directory entry for root
	;it will look like this:
	;"MyDirectory  0   4 11 2010   D,   23"
	;the filesize=0
	;attributes=0x10 for subdirectory

	push dword [ebp+8]   ;filename
	push dword 0         ;filesize=0 for sub
	push dword 0x10      ;subdir
	call fatWriteDirEntry
	jz near .failNoFree

	;and save root to flash
	call fatsaveroot


	
	;mark cluster in FAT1 as reserved for this subdir
	STDCALL fatstr72,dumpstr
	mov eax,[direntry.startingcluster] 
	;get address of startingcluster
	lea edi,[STARTFAT1+eax*2]
	;mark the cluster in FAT1 as terminate
	mov word [edi],0xffff  

	;and save the FATs to flash
	call fatsavefat

	

	;alloc some scratch memory for creating sub DIRENTRIES
	mov ecx,0x8000
	call alloc  ;returns esi=address of memory block
	jz near .failNoFree
	mov edx,esi  ;edx must be preserved to ret
	

	;zero out 1 cluster for sub DIRENTRIES 
	;we write our dot and dotdot entries as the first 2 entries in the subdir
	cld
	mov ecx,0x8000
	mov al,0
	mov edi,edx
	rep stosb


	;create a FATDIRENTRY structure for our dot entry
	STDCALL fatstr93,0,0x10,fatFillinDirEntry
	jz near .fail


	;copy dot entry 
	cld
	mov esi,FATDIRENTRY  
	mov edi,edx
	mov ecx,32
	rep movsb

	;and just copy it again for the dotdot entry
	mov esi,FATDIRENTRY  
	lea edi,[edx+32]
	mov ecx,32
	rep movsb


	;now modify the dotdot entry
	;we need to fix the filename and firstcluster fields
	lea edi,[edx+32]
	mov esi,fatstr94    ;dotdot
	call strcpy  
	;set the firstcluster to 0 
	;since a subdir in root always points up to root
	mov word [edx+58],0  ;zero out firstcluster


	;copy 1 cluster to flash
	;this cluster will hold the DIRENTRIES of files within the subdir
	;for now all it holds are the [.] and [..] DIRENTRIES 
	mov eax,[direntry.startingcluster]
	call fatcluster2LBA
	;on success eax=LBAstart and ZF is clear
	;on error eax=0 and ZF is set
	jz .fail

	mov ebx,eax    ;destination LBAstart
	mov ecx,0x40   ;we write 1 cluster
	mov esi,edx    ;source address of memory
	call write10
	jz .fail



.success:
	mov esi,edx
	call free
	mov eax,0  ;return value
	jmp .done
.fail:
	STDCALL fatstr114,dumpstr
	mov esi,edx
	call free
.failNoFree:
	mov eax,1
	jmp .done
.done:
	pop ebp
	retn 4





;********************************************************************
;FATGENERTATEDESTRINGS
;fatGenerateDEStrings
;generates ascii strings describing the DIRENTRY structures 
;that have been loaded to STARTROOTDIR or STARTSUBDIR 
;strings are written directly to the ListControl buffer
;and spaced 0x100 bytes apart and 0 terminated 
;LFN, e5 or 00 directory entries are excluded
;Linux dot and dotdot entry strings are also included for subs

;input:none 
;requires global dword [CurrentWorkingDirectory] to set to 
;0 for root or 1 for sub 

;return: 
;ecx=qty directory entry strings generated
;ecx=0 if no strings or if fatfindfile failed
;*****************************************************************

fatGenerateDEStrings:

	STDCALL fatstr96,dumpstr
	mov dword [qtydirentrystrings],0
	
	;init the destination address of list control buffer
	mov edi,0x2950000   


	;are we searching root dir entries or sub dir entries ?
	cmp dword [CurrentWorkingDirectory],0
	jz .searchRootDir
	cmp dword [CurrentWorkingDirectory],1
	jz .searchSubDir
	jmp .error   ;invalid dir ID
.searchRootDir:
	mov esi,STARTROOTDIR
	jmp .doneSetWorkingDirectoryAddress
.searchSubDir:
	mov esi,STARTSUBDIR
.doneSetWorkingDirectoryAddress:


	;as a protection we will only parse up to 1000 dir entries and no more
	;appx 32000 bytes per cluster / 32 bytes per dir entry
	xor ebp,ebp

.topofloop:

	;esi=address of DIRENTRY structure
	call fatreadDirEntry  
	;returns eax=0,1,2,3,4,5 indicating type of entry 

	;we skip over LFN, e5 or 00 entries
	cmp eax,0  ;entry is available and no more in dir
	jz .done
	cmp eax,1  ;erased entry
	jz .increment
	cmp eax,2  ;LFN entry
	jz .increment

	;if we got here eax=3 Archive or eax=4 SubDir or eax=5 something else
	;this includes the "." and ".." entries typically found at the beginning
	;of a linux subdirectory
	;build a string to represent a single DIRENTRY structure
	call fatbuildtatOSdirString

	;increment qty of directory entry strings generated
	add dword [qtydirentrystrings],1
	
	;copy string to list control buffer 0x2950000+n*0x100
	STDCALL FATDIRSTRING,edi,strcpy2

	;increment edi address to store next string
	add edi,0x100

.increment:
	;in this loop esi and ebp must be preserved
	add esi,32    ;inc to address of next entry
	add ebp,1     ;inc qty of entries parsed
	cmp ebp,1000  ;max qty entries parsed
	jb .topofloop


.done:
	mov ecx,[qtydirentrystrings] ;return value 

	;values for the ListControl
	mov dword [list_QtyStrings],ecx
	call ListControlDoHome


.error:
	ret




;***********************************************************************
;fatloadSubDirEntries 
;this function searches for a valid subdirectory name in root
;if the name exists, it will load all directory entires to STARTSUBDIR
;it will set a new current working directory as this sub dir
;if the name string does not exist in root we exit with error
;input:
;push address of 11 byte name of subdir in root  [ebp+8]
;return:
;ZF is set on error (subdir name does not exist in root)
;note:
;[1] this function assumes the rootdir is at STARTROOTDIR
;[2] this function has to set the current working directory to root
;**********************************************************************

fatloadSubDirEntries:

	push ebp
	mov ebp,esp
	
	STDCALL fatstr100,dumpstr

	;dump the subdir name string
	STDCALL [ebp+8],dumpstrquote


	;search for sub dir filename in root
	mov dword [CurrentWorkingDirectory],0  ;0=root 
	STDCALL [ebp+8],fatfindfile
	;returns esi=address of DIRENTRY or 0 not found
	cmp esi,0
	jz .invalid


	;if we got here the user has entered a valid string
	;that is the name of a subdir in root 
	;now save this string to NAMEOFCWD
	STDCALL [ebp+8],NAMEOFCWD,strcpy2

	;and indicate that the current working directory is now a sub
	mov dword [CurrentWorkingDirectory],1  ;1=sub


	;save the starting cluster number 
	xor eax,eax
	mov ax,[esi+26]               ;the dir entry byte offset 26 is FirstCluster
	mov [CSDstartingcluster],eax  ;save for the benefit of fatwritefile


	;and convert the starting cluster number to LBA
	call fatcluster2LBA
	jz .invalid              ;error LBA out of range


	;now load the subdir cluster of DIRENTRIES off flash 
	mov ebx,eax           ;LBAstart
	mov ecx,0x40          ;qty blocks
	mov edi,STARTSUBDIR   ;memory address
	call read10  


.success:
	or eax,1   ;ZF is clear on success
	jmp .done
.invalid:
	STDCALL fatstr109,dumpstr
	xor eax,eax  ;ZF is set on error
.done:
	pop ebp
	retn 4






;*************************************************************************
;FATFINDFILE
;fatfindfile
;this function is used all over the place
;it searches the DIRENTRY structures 
;that have been previous loaded to STARTROOTDIR or STARTSUBDIR 
;it looks for an archive file (0x20) or subdirectory (0x10) by filename
;if the file attributes are not one of these two this function will fail
;the various fields of the directory entry are stored in global memory 

;input:
;push address of 11 char filename    [ebp+8]
;global dword [CurrentWorkingDirectory] =  0 for root dir read
;                                       =  1 for sub dir read

;return
;success: esi=starting address of dir entry
;         if archive, eax=filesize
;         if subdir,  eax=0
;         global dword [direntryaddress] is saved
;failed:  eax=esi=0 and file or dirname does not exist in CWD
;***********************************************************************

fatfindfile:

	push ebp
	mov ebp,esp
	push ecx
	push edi

	STDCALL fatstr47,dumpstr

	;dump the filename
	STDCALL [ebp+8],dumpstrquote


	;are we searching root dir entries or sub dir entries ?
	cmp dword [CurrentWorkingDirectory],0
	jz .searchRootDir
	cmp dword [CurrentWorkingDirectory],1
	jz .searchSubDir
	jmp .failed   ;invalid dir ID
.searchRootDir:
	;set esi to address of first DIRENTRY 
	mov esi,STARTROOTDIR
	jmp .doneSetAddress
.searchSubDir:
	mov esi,STARTSUBDIR
.doneSetAddress:



.topofloop:
	;grab a directory entry
	;search for the file or subdir name 
	;esi=starting address of dir entry
	call fatreadDirEntry
	;returns eax=0,1,2,3,4,5 for type of entry
	;fills in the following fields:
	;direntry.filename 
	;direntry.lastmodifieddate  
	;direntry.attributes       
	;direntry.filesize        
	;direntry.startingcluster

	cmp eax,0   ;no more entries
	jz near .failed
	
	cmp eax,1  ;erased entry
	jz .increment

	cmp eax,2  ;LFN
	jz .increment

	cmp eax,3  ;archive
	jz .checkFileName

	cmp eax,4  ;sub
	jz .checkFileName

	;5=other combinations of attributes are set
	;the dir entry is something else
	;for example linux may create a dir entry for RECYCLER
	;which is subdir:hidden:system:readonly attributes
	jmp .increment
	 

.checkFileName:
	;heres where we do byte by byte check for string equality using cmpsb
	cld   
	push esi
	mov esi,[ebp+8]
	mov edi,direntry.filename  ;fatreadDirEntry stores the 11char filename address here
	mov ecx,11                 ;we treat the filename as 11 ascii char
	repe cmpsb                 ;compare string byte while equal
	pop esi
	;if strings are same zf is set
	jz .success  
	
.increment:
	;get next dir entry address
	add esi,32
	jmp .topofloop




	;if we got here we looped thru the entire root dir
	;and failed to find the file 

.failed:
	STDCALL fatstr62,dumpstr
	xor eax,eax  ;return 0
	xor esi,esi
	jmp .done

.success:
	mov eax,[direntry.filesize]
	;also esi=starting address of directory entry
	;a subdir will return eax=0 bytes but esi=nonzero
	STDCALL fatstr108,0,dumpeax  ;dump the filesize

.done:
	pop edi
	pop ecx
	pop ebp
	retn 4










;****************************************************
;FATSAVESUB
;fatsavesub
;save the 32 byte directory entries stored in memory 
;representing the current sub directory 
;to flash at the appropriate LBA 
;input: dword [CSDstartingcluster] 
;       is the starting cluster number of the sub directory
;       this global is saved by fatloadSubDirEntries
;return:sets ZF on error
;***************************************************

fatsavesub:

	STDCALL fatstr124,dumpstr

	mov eax,[CSDstartingcluster]
	call fatcluster2LBA
	jz .done              ;error LBA out of range

	mov ebx,eax           ;LBAstart
	mov ecx,0x40          ;qty blocks
	mov esi,STARTSUBDIR   ;memory address
	call write10          ;sets ZF on error

.done:
	ret





;*******************************************
;FATSAVEFAT
;fatsavefat
;writes fat1 and fat2 to flash
;input:none
;return:none
;*******************************************

fatsavefat:

	pushad

	STDCALL fatstr123,dumpstr

	;copy FAT1->FAT2 so they match
	mov esi,STARTFAT1
	mov edi,STARTFAT2
	mov ecx,0x1e600   ;qtybytes
	call memcpy


	;write FAT1+FAT2 to flash
	mov ebx,1           ;LBAstart
	mov ecx,0xf3+0xf3   ;qtyblocks  
	mov esi,STARTFAT1   ;source memory
	call write10        ;sets ZF on error

	popad
	ret




;*******************************************
;FATSAVEROOT
;fatsaveroot
;writes the root directory to flash
;input:none
;return:zf set on error
;*******************************************

fatsaveroot:

	pushad

	STDCALL fatstr126,dumpstr

	;write rootdir to flash
	mov ebx,0x1e7         ;LBAstart
	mov ecx,0x20          ;qtyblocks  
	mov esi,STARTROOTDIR  ;source memory
	call write10          ;sets ZF on error

	popad
	ret



