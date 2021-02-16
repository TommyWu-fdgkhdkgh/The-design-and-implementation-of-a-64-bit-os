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

org	10000h
	jmp	Label_Start

%include	"fat12.inc"

BaseOfKernelFile	equ	0x00
OffsetOfKernelFile	equ	0x100000

BaseTmpOfKernelAddr	equ	0x00
OffsetTmpOfKernelFile	equ	0x7E00

MemoryStructBufferAddr	equ	0x7E00

[SECTION gdt]

; dd --> 4 bytes
; dw --> 2 bytes
; db --> 1 bytes ( 8 bits )

LABEL_GDT:		dd	0,0
LABEL_DESC_CODE32:	dd	0x0000FFFF,0x00CF9A00
LABEL_DESC_DATA32:	dd	0x0000FFFF,0x00CF9200

; LABEL_DESC_CODE32 
;   段基位址 == 0x0     --> 段基位址在 "線性位址" == 0 的地方
;   段長度   == 0xFFFFF
;   DPL      == 0x0
;   Type     == b1010   --> 非一致性，可讀，未訪問

GdtLen	equ	$ - LABEL_GDT
GdtPtr	dw	GdtLen - 1
	dd	LABEL_GDT	;be carefull the address(after use org)!!!!!!

; 到這裡～讀完書的 p 202 ~ 214 ， 然後整理出 "段選擇子  ( selector, 段寄存器保存的值 )"，"GDT"， "段描述符" 間的關係

; "段寄存器 ( segment register )" 所保存的值便是"段選擇子 ( segment selector )"，以及透過段選擇子所選到的 segment descriptor ( 以避免不斷的對 Main Memory 內的 GDT 進行多次 request ) 。
;  使用 segment selector 在 " Global Offset Table "

SelectorCode32	equ	LABEL_DESC_CODE32 - LABEL_GDT
SelectorData32	equ	LABEL_DESC_DATA32 - LABEL_GDT

; 在這裡， SelectorCode32 == 8 == b1000，也就是 GDT 的第一個 entry。
; Segment Selector 
;   0 ~ 1  bit : RPL
;   2      bit : TI， 0 == GDT, 1 == LDT
;   3 ~ 15 bit : 段選擇子索引 ( Index )

[SECTION gdt64]

; dq : 8 Bytes

LABEL_GDT64:		dq	0x0000000000000000
LABEL_DESC_CODE64:	dq	0x0020980000000000			; 書本 p229
LABEL_DESC_DATA64:	dq	0x0000920000000000			; 書本 p230

; Q: segment selector   在 protection mode 以及 long mode 應該相同 ?
; Q: segment descriptor 在 protection mode 以及 long mode 的長度應該相同 ( 都是 8 bytes ) ? 

GdtLen64	equ	$ - LABEL_GDT64
GdtPtr64	dw	GdtLen64 - 1
		dd	LABEL_GDT64

SelectorCode64	equ	LABEL_DESC_CODE64 - LABEL_GDT64		; 8 
SelectorData64	equ	LABEL_DESC_DATA64 - LABEL_GDT64		; 16

[SECTION .s16]
[BITS 16]

Label_Start:

; cs = 0x1000

	mov	ax,	cs
	mov	ds,	ax
	mov	es,	ax
	mov	ax,	0x00
	mov	ss,	ax
	mov	sp,	0x7c00

; ds = 0x1000
; es = 0x1000
; ss = 0x00
; sp = 0x7c00

;=======	display on screen : Start Loader......

	mov	ax,	1301h
	mov	bx,	000fh
	mov	dx,	0200h		;row 2
	mov	cx,	12
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartLoaderMessage
	int	10h

;=======	open address A20
	push	ax
	in	al,	92h				; 從 I/O 0x92 拿取資料 
	or	al,	00000010b			; 打開一個 bit
	out	92h,	al				; 輸入資料到 I/O 0x92
	pop	ax

	cli						; 關閉外部中斷

	lgdt	[GdtPtr]				; Q: 為什麼這邊需要 lgdt ?
							; A: 為了開啟 big real mode 模式，將 FS 的定址能力拉長，所以
							;      必須要暫時開啟 protected mode。而想要打開 protected mode
							;      就必須設定好 gdt

	mov	eax,	cr0				; 打開 protected mode，在這裡會暫時跳到 protected mode
	or	eax,	1
	mov	cr0,	eax

	mov	ax,	SelectorData32
	mov	fs,	ax				; 在 protected mode 下對 fs 賦值
	mov	eax,	cr0
	and	al,	11111110b
	mov	cr0,	eax				; 關掉 protected mode， 回到 real mode

; 到這裡，原本 fs 的尋址能力只有 1MB，會被拉長到 4GB，這是為了把 kernel 搬移到 1MB 以上的位置

	sti

;=======	reset floppy

	xor	ah,	ah
	xor	dl,	dl
	int	13h

;=======	search kernel.bin
	mov	word	[SectorNo],	SectorNumOfRootDirStart

Lable_Search_In_Root_Dir_Begin:

	cmp	word	[RootDirSizeForLoop],	0
	jz	Label_No_LoaderBin
	dec	word	[RootDirSizeForLoop]	
	mov	ax,	00h
	mov	es,	ax
	mov	bx,	8000h
	mov	ax,	[SectorNo]
	mov	cl,	1
	call	Func_ReadOneSector
	mov	si,	KernelFileName
	mov	di,	8000h
	cld
	mov	dx,	10h
	
Label_Search_For_LoaderBin:

	cmp	dx,	0
	jz	Label_Goto_Next_Sector_In_Root_Dir
	dec	dx
	mov	cx,	11

Label_Cmp_FileName:

	cmp	cx,	0
	jz	Label_FileName_Found
	dec	cx
	lodsb	
	cmp	al,	byte	[es:di]
	jz	Label_Go_On
	jmp	Label_Different

Label_Go_On:
	
	inc	di
	jmp	Label_Cmp_FileName

Label_Different:

	and	di,	0FFE0h
	add	di,	20h
	mov	si,	KernelFileName
	jmp	Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir:
	
	add	word	[SectorNo],	1
	jmp	Lable_Search_In_Root_Dir_Begin
	
;=======	display on screen : ERROR:No KERNEL Found

Label_No_LoaderBin:

	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0300h		;row 3
	mov	cx,	21
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	NoLoaderMessage
	int	10h
	jmp	$

;=======	found kernel.bin name in root director struct

; 當我們找到了 kernel bin ， di 會指向該根目錄的 DIR_NAME 的後一個 bit

Label_FileName_Found:
	mov	ax,	RootDirSectors
	and	di,	0FFE0h
	add	di,	01Ah
	mov	cx,	word	[es:di]
	push	cx
	add	cx,	ax
	add	cx,	SectorBalance
	mov	eax,	BaseTmpOfKernelAddr			;BaseTmpOfKernelFile   == 0x0
	mov	es,	eax			            		;Q: 為什麼這邊突然能用 eax ?
	mov	bx,	OffsetTmpOfKernelFile			;OffsetTmpOfKernelFile == 0x7E00
	mov	ax,	cx

Label_Go_On_Loading_File:
	push	ax
	push	bx
	mov	ah,	0Eh
	mov	al,	'.'
	mov	bl,	0Fh
	int	10h
	pop	bx
	pop	ax

	mov	cl,	1
	call	Func_ReadOneSector
	pop	ax

;;;;;;;;;;;;;;;;;;;;;;;	
	push	cx
	push	eax
	push	fs
	push	edi
	push	ds
	push	esi
; 這裡暫且把可能用到的暫存器先 push 到 stack 上
; 在這裡把 kernel 從 temp 搬到真正想存 kernel 的地方


	mov	cx,	200h					; 0x200 = 512 = 一個磁區的大小

	mov	ax,	BaseOfKernelFile			; BaseOfKernelFile = 0x00
	mov	fs,	ax
	mov	edi,	dword	[OffsetOfKernelFileCount]	; OffsetOfKernelFileCount = OffsetOfKernelFile 

	mov	ax,	BaseTmpOfKernelAddr			; BaseTmpOfKernelAddr = 0x00
	mov	ds,	ax
	mov	esi,	OffsetTmpOfKernelFile   		; OffsetTmpOfKernelFile = 0x7E00

Label_Mov_Kernel:	;------------------
	00000
	mov	al,	byte	[ds:esi]
	mov	byte	[fs:edi],	al

	inc	esi
	inc	edi

	loop	Label_Mov_Kernel				; loop 這個偽指令會執行到 cx == 0
								;   每執行一輪， cx--

	mov	eax,	0x1000
	mov	ds,	eax

	mov	dword	[OffsetOfKernelFileCount],	edi	; buffer 的基底往後挪一個磁區

	pop	esi
	pop	ds
	pop	edi
	pop	fs
	pop	eax
	pop	cx
;;;;;;;;;;;;;;;;;;;;;;;	

	call	Func_GetFATEntry
	cmp	ax,	0FFFh
	jz	Label_File_Loaded
	push	ax
	mov	dx,	RootDirSectors
	add	ax,	dx
	add	ax,	SectorBalance
;	add	bx,	[BPB_BytesPerSec]	

	jmp	Label_Go_On_Loading_File

Label_File_Loaded:
		
	mov	ax, 0B800h
	mov	gs, ax
	mov	ah, 0Fh				; 0000: 黑底    1111: 白字
	mov	al, 'G'
	mov	[gs:((80 * 0 + 39) * 2)], ax	; 屏幕第 0 行, 第 39 列。

KillMotor:
	
	push	dx
	mov	dx,	03F2h
	mov	al,	0	
	out	dx,	al
	pop	dx

; 關閉驅動馬達是靠 I/O port 0x3f2 輸入 0 
; 詳情可看書 62 頁

;=======	get memory address size type

	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0400h		;row 4
	mov	cx,	44
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetMemStructMessage
	int	10h
; 顯示字串


	mov	ebx,	0
	mov	ax,	0x00
	mov	es,	ax
	mov	di,	MemoryStructBufferAddr	

Label_Get_Mem_Struct:

	mov	eax,	0x0E820
	mov	ecx,	20
	mov	edx,	0x534D4150
	int	15h
; BIOS 中斷 : int 0x15, ax 0x0E820
; EDX       : 0x534D4150 --> "SMAP"
; EBX       : 0x00000000
; ECX       : 返結果的長度
; ES:DI     : 保存返回結果的 buffer 

; return value ...
; CF  == 0, 此 BIOS 中斷成功
; EAX == 0x534D4150 --> "SMAP"
; EBX == 0x00000000 --> 當 EBX == 0 時，表示檢測結束。有其他值的話，表示後續映射訊息的結構體編號
; ECX == 保存實際返回的結構的長度

; 若 CF == 1 ， 表示此 BIOS 中斷失敗
; AH == 錯誤碼， 0x80 --> 無效命令， 0x86 --> 不支持此功能

	jc	Label_Get_Mem_Fail
	add	di,	20			                ; 每一個結構體的大小為 20 bytes ， 所以每當我們拿到一個結構體
						                ;   則 buffer 需要往後調 20 bytes
	inc	dword	[MemStructNumber]

	cmp	ebx,	0
	jne	Label_Get_Mem_Struct		    ; 假如 EBX 不等於 0, 表示我們還需要讀取其他的結構體
	jmp	Label_Get_Mem_OK		        ; 假如 EBX   等於 0, 表示我們成功的拿取所有結構體的資訊

Label_Get_Mem_Fail:

	mov	dword	[MemStructNumber],	0

	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0500h		;row 5
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetMemStructErrMessage
	int	10h

Label_Get_Mem_OK:
	
	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0600h		;row 6
	mov	cx,	29
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetMemStructOKMessage
	int	10h	

;=======	get SVGA information

; 小整理
; int 0x10, ax == 0x4F00 --> get information of "VbeInfoBlock"
; int 0x10, ax == 0x4F01 --> get information of "ModeInfoBlock" 
; int 0x10, ax == 0x4F02 --> set the SVGA mode(VESA VBE)
; int 0x10, ax == 0x4F03 --> 獲取當前的 VBE 模式

	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0800h		;row 8
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetSVGAVBEInfoMessage
	int	10h

	mov	ax,	0x00
	mov	es,	ax
	mov	di,	0x8000
	mov	ax,	4F00h

	int	10h
; input : 
;   int 0x10, ax == 0x4f00 --> 可以看書的 p 264，表 7-9 
;     獲取 VBE 控制器的訊息
;   ES:DI : 指向 VbeInfoBlock 這個結構的起始位址

	cmp	ax,	004Fh

; 假如 ax == 0x4f ， 表示這個呼叫有成功

	jz	.KO
	
;=======	Fail

	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0900h		;row 9
	mov	cx,	23
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAVBEInfoErrMessage
	int	10h

	jmp	$

.KO:

	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0A00h		;row 10
	mov	cx,	29
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAVBEInfoOKMessage
	int	10h

;=======	Get SVGA Mode Info

	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0C00h		;row 12
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	StartGetSVGAModeInfoMessage
	int	10h


	mov	ax,	0x00
	mov	es,	ax
	mov	si,	0x800e

	mov	esi,	dword	[es:si]
	mov	edi,	0x8200

; 0x8000 ，是上面我們用 int 0x10, ax == 0x4F00 所載入的 VbeInfoBlock 的位址
; 0xe 是該結構的成員變數 "VideoModePtr" 的偏移量


Label_SVGA_Mode_Info_Get:

	mov	cx,	word	[es:esi]

;=======	display SVGA mode information

	push	ax
	
	mov	ax,	00h
	mov	al,	ch
	call	Label_DispAL

	mov	ax,	00h
	mov	al,	cl	
	call	Label_DispAL
	
	pop	ax

;=======
	
	cmp	cx,	0FFFFh
	jz	Label_SVGA_Mode_Info_Finish

	mov	ax,	4F01h
	int	10h

	cmp	ax,	004Fh

	jnz	Label_SVGA_Mode_Info_FAIL	

	inc	dword		[SVGAModeCounter]
	add	esi,	2                           ; 每次我們會用 Label_DispAL 這個 function 
                                            ;   顯示 2 bytes 長度的資訊
	add	edi,	0x100                       ; 每一個 ModeInfoBlock 的結構長度為 256 Bytes

	jmp	Label_SVGA_Mode_Info_Get

;   先使用 int 0x10, ax == 0x4F00 拿出 VbeInfoBlock 取出 VideoModePtr
;     開始遍尋這個 list，每遍尋一個 entry 就呼叫一次 int 0x10, ax == 0x4F01 來獲取 ModeInfoBlock


Label_SVGA_Mode_Info_FAIL:

	mov	ax,	1301h
	mov	bx,	008Ch
	mov	dx,	0D00h		;row 13
	mov	cx,	24
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAModeInfoErrMessage
	int	10h

Label_SET_SVGA_Mode_VESA_VBE_FAIL:

	jmp	$

Label_SVGA_Mode_Info_Finish:

	mov	ax,	1301h
	mov	bx,	000Fh
	mov	dx,	0E00h		;row 14
	mov	cx,	30
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	GetSVGAModeInfoOKMessage
	int	10h

;=======	set the SVGA mode(VESA VBE)

	mov	ax,	4F02h
	mov	bx,	4180h	;========================mode : 0x180 or 0x143
	int 	10h

; int 0x10, ax == 0x4F02 --> set the SVGA mode
; bx == 0x4180, 4 --> 啟用線性幀緩存, 0x180 --> 設置 VBE 的顯示模式 
; Q: 什麼是 "線性幀緩存"，什麼是 "窗口幀緩存" ?

	cmp	ax,	004Fh
	jnz	Label_SET_SVGA_Mode_VESA_VBE_FAIL

;=======	init IDT GDT goto protect mode 

	cli			;======close interrupt

	lgdt	[GdtPtr]

;	lidt	[IDT_POINTER]

	mov	eax,	cr0
	or	eax,	1
	mov	cr0,	eax	

; cr0 的第一個 bit 為 PE ( protection enable )

	jmp	dword SelectorCode32:GO_TO_TMP_Protect

; SelectorCode32 equ LABEL_DESC_CODE32 - LABEL_GDT ， 代表 GDT 的開頭，到 LABEL_DESC_CODE32 的位址的偏移量
;   此時只有開啟新的段選擇機制，還沒有 paging。 

; 邏輯位址 -- segmentation --> 線性位址 -- paging --> Memory Address
; 若沒 paging ， 則線性位址 == 物理位址

; 虛擬位址 ( Virtual Address )
;   邏輯位址 ( Logical Address   ) : 格式為 segment : Offset ， 這個 Offset 又被稱為 "有效位址" 
;   線性位址 ( Linear  Address   ) : 經邏輯位址 "segment : Offset" 換算而成
;   有效位址 ( Effective Address ) : 同上述
; 物理位址 ( Physical Address ) 
;   I/O 位址 ( I/O Address    )    : 必須經由特殊的 IN/OUT instruction 才能夠訪問
;   記憶體位址 ( Memory Address  ) : 經由 邏輯位址 --> 線性位址 --> 轉換而來的記憶體位址，不只可用來拜訪 Main Memory ， 也可以用以拜訪 Peripheral Device 

[SECTION .s32]
[BITS 32]

GO_TO_TMP_Protect:

;=======	go to tmp long mode

	mov	ax,	0x10
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	ss,	ax
	mov	esp,	7E00h
	
	call	support_long_mode

	test	eax,	eax

	jz	no_support				; 若 eax == 0，就跳到該 label



;=======	init temporary page table 0x90000

;-------- PML4T ( Page Map Level 4 )

	mov	dword	[0x90000],	0x91007
	mov	dword	[0x90800],	0x91007		

; PWT = 0x1
; PCD = 0x1

;--------

;-------- PDPT

	mov	dword	[0x91000],	0x92007

; PWT = 0x1
; PCD = 0x1

;--------

;-------- PDT ， 使用 2MB 物理頁，於是沒有 PT

	mov	dword	[0x92000],	0x000083

	mov	dword	[0x92008],	0x200083

; 0x100000 --> 1 MB
; 0x200000 --> 2 MB
; 每個 entry 大小為 8 bytes
; 每頁能指向的物理位址範圍為 2 MB

	mov	dword	[0x92010],	0x400083

	mov	dword	[0x92018],	0x600083

	mov	dword	[0x92020],	0x800083

	mov	dword	[0x92028],	0xa00083

; R/W = 0x1
; U/S = 0x1
; PAT = 0x1
	
;--------

;=======	load GDTR
	
	lgdt	[GdtPtr64]
	mov	ax,	0x10			; 指向 LABEL_DESC_DATA32
	mov	ds,	ax
	mov	es,	ax
	mov	fs,	ax
	mov	gs,	ax
	mov	ss,	ax

	mov	esp,	7E00h
	
;=======	open PAE

; 書本 p197, PAE ( Physical Address Extension )
; PAE wikipedia : https://zh.wikipedia.org/zh-tw/%E7%89%A9%E7%90%86%E5%9C%B0%E5%9D%80%E6%89%A9%E5%B1%95
;   對於在長模式（long mode）中的x86-64處理器，PAE是必須的

	mov	eax,	cr4
	bts	eax,	5
	mov	cr4,	eax

;=======	load	cr3

	mov	eax,	0x90000
	mov	cr3,	eax

;=======	enable long-mode

	mov	ecx,	0C0000080h		;IA32_EFER

; ecx 需要先載入暫存器地址
;   MSR 暫存器組有多種暫存器，而 0xc0000080 通常代表的是 IA32_EFER 這個暫存器
; 書本 p198 ~ p199

	rdmsr

	bts	eax,	8
	wrmsr



;=======	open PE and paging

; 書本 p196

	mov	eax,	cr0
;	bts	eax,	0				; PE : Protection Enable
							; Q: 為什麼需要這一行 ? 上面應該已經打開了 protection mode 才對
	
	bts	eax,	31				; PG : enable paging
	mov	cr0,	eax

	jmp	SelectorCode64:OffsetOfKernelFile

; 在這邊整理一下，這個位址經由 segmentation 以及 paging 換算出位址的過程：

; SelectorCode64 :	0x8 
; OffsetOfKernelFile :	0x100000 ( 1 MB )

; 在 segmentation 這邊，會選用 LABEL_DESC_CODE64，基底位址為 0 ，偏移為 0x100000 
;   經由 segmentation 後，可得 "線性地址" 0x100000

; 在 paging 這邊，因為我們是使用長度為 0x200000 ( 2MB ) 的物理頁，所以可以很清楚的知道線性地址 0x1000000 ( 1MB )
;   一定會是在第一張頁，並且偏移量為 0x100000 ( 1MB )

;=======	test support long mode or not

; cpuid : https://en.wikipedia.org/wiki/CPUID#EAX=80000000h:_Get_Highest_Extended_Function_Implemented
; eax == 0x80000000 + cpuid
;   get highest extended function implemented

; eax == 0x80000001 + cpuid
;   extended processor info and feature bits

support_long_mode:

	mov	eax,	0x80000000
	cpuid

; 至此可以得到 "highest extended function implemented" , 這個數值要大於等於 0x80000001，才表示 "有可能" 支援 long mode 
; 當我們能確定能使用 eax >= 0x80000001 的功能後，再使用

	cmp	eax,	0x80000001
	setnb	al	
	jb	support_long_mode_done				; Q: 為什麼需要這一行?
								; A: 假如 0x80000001 功能號不存在，就立刻返回 eax == 0
								; jb : 當 cmp a, b 時， 若 a < b 就跳到指定的 label

	mov	eax,	0x80000001
	cpuid
	bt	edx,	29					; bt : bit test

	setc	al						; set if Carry
support_long_mode_done:
	
	movzx	eax,	al
	ret

;=======	no support

no_support:
	jmp	$

;=======	read one sector from floppy

[SECTION .s116]
[BITS 16]

Func_ReadOneSector:
	
	push	bp
	mov	bp,	sp
	sub	esp,	2
	mov	byte	[bp - 2],	cl
	push	bx
	mov	bl,	[BPB_SecPerTrk]
	div	bl
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
	jc	Label_Go_On_Reading
	add	esp,	2
	pop	bp
	ret

;=======	get FAT Entry

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
	div	bx
	cmp	dx,	0
	jz	Label_Even
	mov	byte	[Odd],	1

Label_Even:

	xor	dx,	dx
	mov	bx,	[BPB_BytesPerSec]
	div	bx
	push	dx
	mov	bx,	8000h
	add	ax,	SectorNumOfFAT1Start
	mov	cl,	2
	call	Func_ReadOneSector
	
	pop	dx
	add	bx,	dx
	mov	ax,	[es:bx]
	cmp	byte	[Odd],	1
	jnz	Label_Even_2
	shr	ax,	4

Label_Even_2:
	and	ax,	0FFFh
	pop	bx
	pop	es
	ret

;=======	display num in al

Label_DispAL:

	push	ecx
	push	edx
	push	edi
	
	mov	edi,	[DisplayPosition]
	mov	ah,	0Fh			; Q: 不太懂這一行要做什麼
						; A: 字元的屬性 --> 前 4 bits 0000: 黑底, 後 4 bits 1111: 白字
	mov	dl,	al				
	shr	al,	4			; 每 4 bits 代表一個 16 進位的數字
						;   這邊向右偏移 4 bits， 表示我們想取用後 4 bits 的值
						;   e.g. 0xAD ， 向右偏移 ( shr ) 4 bits 後
						;   我們就能得到 0xA 

	mov	ecx,	2			; Q: 不懂 ecx 是在做什麼
						; 但少了這一行，字元會永無止盡的印下去
						; A: 喔喔看懂了，下面有 loop .begin
						;    每走一步，就會 ecx-- ， 這邊表示每次呼叫
						;    Label_DispAL，都需要印出兩個字元
.begin:
						; 先處理原先 al 的 5 ~ 8 bits ，爾後再處理 0 ~ 4 bits
	and	al,	0Fh
	cmp	al,	9
	ja	.1
	add	al,	'0'
	jmp	.2
.1:						; 假若這次處理的 4 bits 的值 >= 0xa						

	sub	al,	0Ah
	add	al,	'A'
.2:						; 假若這次處理的 4 bits 的值 < 0xa

	mov	[gs:edi],	ax
	add	edi,	2			; ah --> 字元屬性，共 8 bits
						; al --> 決定是要顯示哪個字元, 共 8 bits
						; ax --> 2 bytes
						; 所以這邊 edi 每給一個字元，就需要 +2
	
	mov	al,	dl
	loop	.begin

	mov	[DisplayPosition],	edi

	pop	edi
	pop	edx
	pop	ecx
	
	ret


;=======	tmp IDT

IDT:
	times	0x50	dq	0
IDT_END:

IDT_POINTER:
		dw	IDT_END - IDT - 1
		dd	IDT

;=======	tmp variable

RootDirSizeForLoop	dw	RootDirSectors
SectorNo		dw	0
Odd			db	0
OffsetOfKernelFileCount	dd	OffsetOfKernelFile

MemStructNumber		dd	0

SVGAModeCounter		dd	0

DisplayPosition		dd	0

;=======	display messages

StartLoaderMessage:	db	"Start Loader"
NoLoaderMessage:	db	"ERROR:No KERNEL Found"
KernelFileName:		db	"KERNEL  BIN",0
StartGetMemStructMessage:	db	"Start Get Memory Struct (address,size,type)."
GetMemStructErrMessage:	db	"Get Memory Struct ERROR"
GetMemStructOKMessage:	db	"Get Memory Struct SUCCESSFUL!"

StartGetSVGAVBEInfoMessage:	db	"Start Get SVGA VBE Info"
GetSVGAVBEInfoErrMessage:	db	"Get SVGA VBE Info ERROR"
GetSVGAVBEInfoOKMessage:	db	"Get SVGA VBE Info SUCCESSFUL!"

StartGetSVGAModeInfoMessage:	db	"Start Get SVGA Mode Info"
GetSVGAModeInfoErrMessage:	db	"Get SVGA Mode Info ERROR"
GetSVGAModeInfoOKMessage:	db	"Get SVGA Mode Info SUCCESSFUL!"




