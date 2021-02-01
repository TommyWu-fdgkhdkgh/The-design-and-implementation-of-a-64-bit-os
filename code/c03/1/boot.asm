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

; 小總結
; 1. 設定好 cs, ds, es, ss, sp
; 2. clean screen
; 3. set cursor focus --> 應該是不用
; 4. display something on the screen
; 5. reset floppy
; 6. fill zero until whole sector

	org	0x7c00	


; org 意思為 origin ，用來標示起始地址。假如沒有這條指令的話，編譯器會把 0x0000 作為程式的起始地址。

; Q: 書中所說，不同的起始地址會產生出不同的絕對地址，是什麼意思呢？
; G: 當我想要跳到某個 label 上時，沒有設定 org 的話，很可能會跳到 0x0000 附近的位址。

; 當年的 bios 會把 boot sector 的程式加載到 0x7c00 的位置，所以不做此設定的話，訪問絕對地址時可能會出錯。

; 在這裡我們會頻繁的使用 BIOS 中斷 INT 10h 

; 我們想要用 BIOS 的某個中斷的某個功能，就是 INT xh + ah == xh


BaseOfStack	equ	0x7c00

Label_Start:

	mov	ax,	cs
	mov	ds,	ax
	mov	es,	ax
	mov	ss,	ax
	mov	sp,	BaseOfStack

; 將 cs 的值丟到 ds, es, ss
; 設定 sp (stack pointer)


; cs --> code  segment
; ds --> data  segment
; ss --> stack segment
; es --> extra segment

;=======	clear screen

	mov	ax,	0600h
	mov	bx,	0700h
	mov	cx,	0
	mov	dx,	0184fh
	int	10h

; mov ax, 0600h --> mov ah, 6h  && mov al, 0h
; int 0x10 搭配上 ah == 6 --> 指定範圍滾動窗口
; al --> 指定想要滾動的列數，假如是零的話，就清空螢幕
; ch --> 起始的列數, cl --> 起始的行數
; dh --> 終止的列數, dl --> 終止的行數

;=======	set focus

	mov	ax,	0200h
	mov	bx,	0000h
	mov	dx,	0000h
	int	10h

; int 0x10 搭配上 ah == 2 --> 設定游標位置
; dh == 0x00 --> 游標的列數
; dl == 0x00 --> 游標的行數
; bh == 0x00 --> 頁碼

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

; int 0x10 搭配上 ah == 0x13 --> 顯示字串
; al == 0x00 --> 寫入模式
; bh == 0x00 --> 頁碼
; bl == 0x0f --> 字元屬性/顏色屬性
; dh == 0x00 --> 游標的行號
; dl == 0x00 --> 游標的列號
; cx == 10   --> 顯示字元的數量

;=======	reset floppy

	xor	ah,	ah
	xor	dl,	dl
	int	13h

; int 0x13 搭配 ah == 0x00 --> 重置磁碟驅動
; dl == 0x00               --> 代表第一個磁碟驅動器 

	jmp	$          ; 無窮迴圈

StartBootMessage:	db	"Start Boot"

;=======	fill zero until whole sector

	times	510 - ($ - $$)	db	0
	dw	0xaa55

; $ 表示當前這個 instruction 的位址
; $$ 表示當前這的 section 的初始位址
; $ - $$ 就是當前這行 instruction 相對於 section 的偏移
; 利用 times 這個偽指令來填充剩餘的空間，讓 bootsector 是 512 Bytes

