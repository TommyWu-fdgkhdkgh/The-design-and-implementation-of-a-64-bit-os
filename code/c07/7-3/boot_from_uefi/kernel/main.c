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

#include "lib.h"
#include "printk.h"
#include "gate.h"
#include "trap.h"
#include "memory.h"
#include "task.h"

/*
		static var 
*/

struct Global_Memory_Descriptor memory_management_struct = {{0},0};

/*

   在 head.S 就已經初步的初始化好 IDT 了，
   所以一進來這個 function，就可以用 i/0 來看除以 0 所發生的例外有沒有被處理。

*/

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
	Pos.XResolution = 1024;
	Pos.YResolution = 768;

	Pos.XPosition = 0;
	Pos.YPosition = 0;

	Pos.XCharSize = 8;
	Pos.YCharSize = 16;

	Pos.FB_addr = (int *)0xffff800003000000;
	Pos.FB_length = (Pos.XResolution * Pos.YResolution * 4 + PAGE_4K_SIZE - 1) & PAGE_4K_MASK;

	color_printk(RED,BLACK,"fdgk say Hello World!\n");

        /*i = 1/0;  // try exception handler

	while(1)
		;*/

	/*
        
          TR 這個 register 載入了 TSS 在 GDT 的段選擇子
          因為 TSS 在這裡是位於 GDT 的第 10 個 entry ， 所以這邊是 10	  

	*/

	load_TR(10);

	/*
	  書本 p119 下面
	*/
	set_tss64(_stack_start, _stack_start, _stack_start, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00, 0xffff800000007c00);

	sys_vector_init();

        i = 1/0;  // try exception handler

	memory_management_struct.start_code = (unsigned long)& _text;
	memory_management_struct.end_code   = (unsigned long)& _etext;
	memory_management_struct.end_data   = (unsigned long)& _edata;
	memory_management_struct.end_brk    = (unsigned long)& _end;

	color_printk(RED,BLACK,"memory init \n");
	init_memory();

	color_printk(RED,BLACK,"interrupt init \n");
	init_interrupt();

	color_printk(RED,BLACK,"task_init \n");
	task_init();

	while(1)
		;
}
