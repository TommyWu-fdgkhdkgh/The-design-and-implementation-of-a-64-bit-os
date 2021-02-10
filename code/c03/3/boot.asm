;/***************************************************
;		版权声明
;
;	本操作系统名为：MINE
;	该操作系统未经授权不得以盈利或非盈利为目的进行开发，
;	只允许个人学习以及公开交流使用
;
;	代码最终所有权及解释权归田宇所有；
;
;	本模块作者：	田宇
;	EMail:		345538255@qq.com
;
;
;***************************************************/

	org	0x7c00	

BaseOfStack	equ	0x7c00

BaseOfLoader	equ	0x1000
OffsetOfLoader	equ	0x00

RootDirSectors	equ	14
SectorNumOfRootDirStart	equ	19
SectorNumOfFAT1Start	equ	1
SectorBalance	equ	17	

	jmp	short Label_Start
	nop
	BS_OEMName	db	'MINEboot'
	BPB_BytesPerSec	dw	512
	BPB_SecPerClus	db	1
	BPB_RsvdSecCnt	dw	1
	BPB_NumFATs	db	2
	BPB_RootEntCnt	dw	224
	BPB_TotSec16	dw	2880
	BPB_Media	db	0xf0
	BPB_FATSz16	dw	9
	BPB_SecPerTrk	dw	18
	BPB_NumHeads	dw	2
	BPB_HiddSec	dd	0
	BPB_TotSec32	dd	0
	BS_DrvNum	db	0
	BS_Reserved1	db	0
	BS_BootSig	db	0x29
	BS_VolID	dd	0
	BS_VolLab	db	'boot loader'
	BS_FileSysType	db	'FAT12   '

Label_Start:

	mov	ax,	cs
	mov	ds,	ax
	mov	es,	ax
	mov	ss,	ax
	mov	sp,	BaseOfStack

;=======	clear screen

	mov	ax,	0600h
	mov	bx,	0700h
	mov	cx,	0
	mov	dx,	0184fh
	int	10h

;=======	set focus

	mov	ax,	0200h
	mov	bx,	0000h
	mov	dx,	0000h
	int	10h

;=======	display on screen : Start Booting......

	mov	ax,	1301h
	mov	bx,	000fh
	mov	dx,	0000h
	mov	cx,	10
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartBootMessage
	int	10h

;=======	reset floppy

	xor	ah,	ah
	xor	dl,	dl
	int	13h

;=======	search loader.bin
	mov	word	[SectorNo],	SectorNumOfRootDirStart

; 從檔案系統中載入"根目錄"的資料，每次載入一個磁區的大小
;   載入一個磁區後，開始遍尋所有 16 個 "根目錄表項" 
;   根目錄表項遍尋完後，載入下一個磁區
;   磁區遍尋完後，表示真的沒這個檔案

Lable_Search_In_Root_Dir_Begin:

	cmp	word	[RootDirSizeForLoop],	0                 ; RootDirSizeForLoop 原本的值是 14 ，
                                                                  ;   紀錄著 "根目錄" 最多為 14 個磁區
	jz	Label_No_LoaderBin                                ; 若 14 個磁區都已經遍尋完畢的話，就可以退出，
                                                                  ;   表示這個檔案系統裡面沒有我們想要的檔案。
	dec	word	[RootDirSizeForLoop]	
	mov	ax,	00h
	mov	es,	ax
	mov	bx,	8000h

	mov	ax,	[SectorNo]                                ; 一開始是指向 "根目錄" 的第一個磁區。
                                                                  ;   每讀完一個磁區，就會指向下一個磁區

	mov	cl,	1
	call	Func_ReadOneSector                                ; 讀取一個磁區的根目錄到 main memory，
                                                                  ;   方便我們進行對檔名進行字串比對

	mov	si,	LoaderFileName
	mov	di,	8000h
	cld
	mov	dx,	10h
	
Label_Search_For_LoaderBin:

	cmp	dx,	0
	jz	Label_Goto_Next_Sector_In_Root_Dir                ; 我們每一次會載入 512 bytes 的 "根目錄表" 到主記憶體
                                                                  ;   也就是 512 / 32 == 16 == 10h 個"根目錄表項"
                                                                  ;   這 16 個表項都找不到，表示我們在這個磁區都找不到
                                                                  ;   表示我們該載入下一個磁區了
	dec	dx
	mov	cx,	11                                        ; 我們想要找的檔名有 11 個字元

Label_Cmp_FileName:

	cmp	cx,	0
	jz	Label_FileName_Found                              ; 檔名有 11 個字元相同，就代表我們找到這個檔案了
	dec	cx
	lodsb	
	cmp	al,	byte	[es:di]
	jz	Label_Go_On
	jmp	Label_Different

Label_Go_On:
	
	inc	di                                                ; 往下個 "根目錄表項" 尋找我們想要的檔名
	jmp	Label_Cmp_FileName

Label_Different:

	and	di,	0ffe0h
	add	di,	20h
	mov	si,	LoaderFileName
	jmp	Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir:
	
	add	word	[SectorNo],	1
	jmp	Lable_Search_In_Root_Dir_Begin
	
;=======	display on screen : ERROR:No LOADER Found

Label_No_LoaderBin:

	mov	ax,	1301h
	mov	bx,	008ch
	mov	dx,	0100h
	mov	cx,	21
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	NoLoaderMessage
	int	10h
	jmp	$

; bl : 字元屬性，這邊設置成 字元閃爍，黑背景色，高亮，紅色字體

;=======	found loader.bin name in root director struct

Label_FileName_Found:

; 當我們找到了 loader bin ， di 會指向該根目錄的 DIR_NAME 的後一個 bit

	mov	ax,	RootDirSectors                         ; RootDirSectors : 根目錄佔用的佔用的磁區數

	and	di,	0ffe0h                                 ; 把前 5 bits 清成 0
	add	di,	01ah                                   ; DIR_FstClus 的偏移為 0x1a
	mov	cx,	word	[es:di]                        ; 拿到了起始叢集的編號
	push	cx
	add	cx,	ax
	add	cx,	SectorBalance                          ; 起始叢集編號 + RootDirSectors + SectorBalance 
                                                               ;   == 我們想要資料所在的磁區

	mov	ax,	BaseOfLoader                           ; 我猜：要把 Loader.bin 放到 Main Memory 的哪裡
	mov	es,	ax
	mov	bx,	OffsetOfLoader
	mov	ax,	cx

Label_Go_On_Loading_File:

; 到此為止的 register 意義
;   ax : 我們想要的資料所在的磁區
;   bx : position of buffer

	push	ax
	push	bx

	mov	ah,	0eh
	mov	al,	'.'
	mov	bl,	0fh
	int	10h
	; int 0x10 + ah 0xe : BIOS 中斷，用以顯示一個字元   
        ; al : 待顯示的字元
        ; bl : 前景色

	pop	bx
	pop	ax

	mov	cl,	1
	call	Func_ReadOneSector
	pop	ax
	call	Func_GetFATEntry

; input  : ax，這一輪的 FAT 表項編號
; output : ax, 下一輪的 FAT 表項編號 

	cmp	ax,	0fffh
	jz	Label_File_Loaded
	push	ax
	mov	dx,	RootDirSectors
	add	ax,	dx
	add	ax,	SectorBalance
	add	bx,	[BPB_BytesPerSec]			; 這一個磁區被填滿了，所以目標轉向下一個磁區
	jmp	Label_Go_On_Loading_File

Label_File_Loaded:
	
	jmp	BaseOfLoader:OffsetOfLoader

; BaseOfLoader   == 0x1000
; OffsetOfLoader == 0x00
; 實模式下的定址 : physical memory == segment register << 4 + offset register
;   0x1000 << 4 + 0x00 = 0x10000 + 0x00

;=======	read one sector from floppy

; AX    : 待讀取的磁盤的起始扇區編號
; CL    : 需要讀入的扇區數量
; ES:BX : 目標緩衝區起始位置
; 這個 function 是對原本 BIOS 讀取軟碟的中斷進行封裝。
; 將 LBA ( logic block address) 轉成 BIOS : int 13h : ah 2h 中斷所需的 CHS (Cylinder 柱面/Head 柱頭/Sector 扇區)

Func_ReadOneSector:
	
	push	bp
	mov	bp,	sp
	sub	esp,	2
	mov	byte	[bp - 2],	cl
	push	bx
	mov	bl,	[BPB_SecPerTrk]
	div	bl                                       ; 餘數 : ah
                                                         ; 商數 : al
	inc	ah
	mov	cl,	ah
	mov	dh,	al
	shr	al,	1
	mov	ch,	al
	and	dh,	1
	pop	bx
	mov	dl,	[BS_DrvNum]
Label_Go_On_Reading:
	mov	ah,	2
	mov	al,	byte	[bp - 2]
	int	13h
	jc	Label_Go_On_Reading                      ; Q: 不太懂這一行的意義
                                                         ;   是怕讀取失敗，就重讀是嗎？
	add	esp,	2
	pop	bp
	ret

; int 13h + ah == 2 : BIOS 中斷，用以讀取軟碟上的磁區
; ah : 讀入的磁區數
; CH : 磁軌號
; CL : 磁區號
; DH : 磁頭號
; DL : 驅動器號
; ES:BX : 資料緩存區

;=======	get FAT Entry

; AX : FAT 表項號
; return value : 那 1.5 bytes 的值。( 下一個 FAT 表項號, 0xff8~0xfff 就表示到此為止了)


Func_GetFATEntry:

	push	es
	push	bx
	push	ax
	mov	ax,	00
	mov	es,	ax
	pop	ax
	mov	byte	[Odd],	0
	mov	bx,	3
	mul	bx
	mov	bx,	2

	div	bx				; ax 是商， dx 是餘數

	cmp	dx,	0 			; 餘數是 0 的話，就表示該" FAT 表項"的起始位置是是偶數

; 這個 function 的 input 是 FAT 表項編號 ( 0 --> 第 0 個 FAT 表項， 1 --> 第 1 個 FAT 表項 )
;   將 input * 3 / 2 == 該 FAT 表項編號是 FAT 的第幾個 bytes ( 每個 FAT 表項佔了 1.5 Byte ) ， 也就是下面
;   所說的偏移量

	jz	Label_Even
	mov	byte	[Odd],	1

Label_Even:

	xor	dx,	dx
	mov	bx,	[BPB_BytesPerSec]
	div	bx				; 商 : ax, 餘 : dx

	push	dx
	mov	bx,	8000h
	add	ax,	SectorNumOfFAT1Start
	mov	cl,	2
	call	Func_ReadOneSector

; AX    : 待讀取的磁盤的起始扇區編號 --> 這裡是 FAT1 的起始磁區 + 偏移量 / 512
; CL    : 需要讀入的扇區數量         --> 因為可能出現 1.5 bytes ， 有可能會橫跨兩的磁區 
; ES:BX : 目標緩衝區起始位置         --> es == 0, bx == 0x8000

; ax 代表是哪一個磁區
; dx 代表在該磁區上的偏移
	
	pop	dx
	add	bx,	dx
	mov	ax,	[es:bx]				; 會從指定位址搬 32 bits 過來
	cmp	byte	[Odd],	1
	jnz	Label_Even_2
	shr	ax,	4

; 例如我現在想要拿取第一個 FAT 表項 ( 0-indexed ) ， 1 * 3 / 2 ==> 起始位址是 1.5 bytes
;   於是我們會從 1 byte 的地方拿取，變成低位的 4 bits 會是我們不想要的資料。
;   所以這邊才會往右偏移 4 bits

Label_Even_2:
	and	ax,	0fffh
	pop	bx
	pop	es
	ret

;=======	tmp variable

RootDirSizeForLoop	dw	RootDirSectors
SectorNo		dw	0
Odd			db	0

;=======	display messages

StartBootMessage:	db	"Start Boot"
NoLoaderMessage:	db	"ERROR:No LOADER Found"
LoaderFileName:		db	"LOADER  BIN",0

;=======	fill zero until whole sector

	times	510 - ($ - $$)	db	0
	dw	0xaa55


; P.S 0-indexed 在這邊是使 index 從 0 開始，跟 C 一樣，這個是從 leetcode 的題目敘述學來的。

