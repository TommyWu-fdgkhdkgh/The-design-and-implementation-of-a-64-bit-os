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


	while(1)
		;
}
