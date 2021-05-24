/***************************************************
*		版权声明
*
*	本操作系统名为：MINE
*	该操作系统未经授权不得以盈利或非盈利为目的进行开发，
*	只允许个人学习以及公开交流使用
*
*	代码最终所有权及解释权归田宇所有；
*
*	本模块作者：	田宇
*	EMail:		345538255@qq.com
*
*
***************************************************/

/*
		static var 
*/


/*

   在 head.S 就已經初步的初始化好 IDT 了，
   所以一進來這個 function，就可以用 i/0 來看除以 0 所發生的例外有沒有被處理。

*/
#include "printk.h"

// workaround, memory.h
#define PAGE_GDT_SHIFT  39
#define PAGE_1G_SHIFT   30
#define PAGE_2M_SHIFT   21  // 2 的 21 次方 == 2MB
#define PAGE_4K_SHIFT   12  // 2 的 12 次方 == 4KB

#define PAGE_2M_SIZE    (1UL << PAGE_2M_SHIFT)
#define PAGE_4K_SIZE    (1UL << PAGE_4K_SHIFT)

#define PAGE_2M_MASK    (~ (PAGE_2M_SIZE - 1))
#define PAGE_4K_MASK    (~ (PAGE_4K_SIZE - 1))
// workaround end

void Start_Kernel(void)
{

        int *addr = (int *)0xffff800003000000;
        int i;


        for(i = 0 ;i<1024*20;i++)
        {
                *((char *)addr+0)=(char)0x00;
                *((char *)addr+1)=(char)0x00;
                *((char *)addr+2)=(char)0xff;
                *((char *)addr+3)=(char)0x00;
                addr +=1;
        }
        for(i = 0 ;i<1024*20;i++)
        {
                *((char *)addr+0)=(char)0x00;
                *((char *)addr+1)=(char)0xff;
                *((char *)addr+2)=(char)0x00;
                *((char *)addr+3)=(char)0x00;
                addr +=1;
        }
        for(i = 0 ;i<1024*20;i++)
        {
                *((char *)addr+0)=(char)0xff;
                *((char *)addr+1)=(char)0x00;
                *((char *)addr+2)=(char)0x00;
                *((char *)addr+3)=(char)0x00;
                addr +=1;
        }
        for(i = 0 ;i<1024*20;i++)
        {
                *((char *)addr+0)=(char)0xff;
                *((char *)addr+1)=(char)0xff;
                *((char *)addr+2)=(char)0xff;
                *((char *)addr+3)=(char)0x00;
                addr +=1;
        }

        /*

        初始化螢幕顯示所需要的資訊

        */
        /* 螢幕解析度 */
        Pos.XResolution = 1024;
        Pos.YResolution = 768;

        /* 初始化顯示字元的位置 */
        Pos.XPosition = 0;
        Pos.YPosition = 0;

        /* XCharSize -- 字元的高度 */
        /* YCharSize -- 字元的寬度 */
        Pos.XCharSize = 8;
        Pos.YCharSize = 16;

	/* 初始化 FrameBuffer 的起始 "虛擬位址" */
        Pos.FB_addr = (int *)0xffff800003000000;
	/* FrameBuffer 的長度 ... 解析度 * 4 bytes ( 一個 pixel 用 4 bytes 表示 ) 並對齊一個 page 的大小 */
        Pos.FB_length = (Pos.XResolution * Pos.YResolution * 4 + PAGE_4K_SIZE - 1) & PAGE_4K_MASK;

	color_printk(WHITE, BLACK,"Hello World %s!\n", "fdgkhdkgh");

	int a = 1 / 0;

	while(1)
		;
}
