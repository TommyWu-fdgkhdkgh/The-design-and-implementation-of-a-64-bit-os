
/***************************************************
*               版权声明
*
*       本操作系统名为：MINE
*       该操作系统未经授权不得以盈利或非盈利为目的进行开发，
*       只允许个人学习以及公开交流使用
*
*       代码最终所有权及解释权归田宇所有；
*
*       本模块作者：    田宇
*       EMail:          345538255@qq.com
*
*
***************************************************/

/*
  kernel_boot_para_info --> 現在才注意到，這個東西會存在 0x60000
  這應該是要丟給 OS 的資料

  我這邊先 workaround ， 直接把 E820 的開頭的指標往外丟

*/

#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>

struct EFI_GRAPHICS_OUTPUT_INFORMATION
{
    unsigned int HorizontalResolution;
    unsigned int VerticalResolution;
    unsigned int PixelsPerScanLine;

    unsigned long FrameBufferBase;
    unsigned long FrameBufferSize;
};

struct EFI_E820_MEMORY_DESCRIPTOR
{
    unsigned long address;
    unsigned long length;
    unsigned int  type;
}__attribute__((packed));
/*
使用 "packed" 的話，就不會幫我們自動 align ，而是每個 member 會緊緊靠在一起。
*/

struct EFI_E820_MEMORY_DESCRIPTOR_INFORMATION
{
    unsigned int E820_Entry_count;
    struct EFI_E820_MEMORY_DESCRIPTOR E820_Entry[0];
};

struct KERNEL_BOOT_PARAMETER_INFORMATION
{
    struct EFI_GRAPHICS_OUTPUT_INFORMATION Graphics_Info;
    struct EFI_E820_MEMORY_DESCRIPTOR_INFORMATION E820_Info;
};

EFI_STATUS EFIAPI UefiMain(IN EFI_HANDLE ImageHandle,IN EFI_SYSTEM_TABLE *SystemTable)
{
    // Q: ImageHandle
    // R: https://blog.csdn.net/jiangwei0512/article/details/52541652
    // R: https://uefi.org/sites/default/files/resources/UEFI%20Spec%202_6.pdf, chapter 4.1, UEFI Image Entry Point

    EFI_LOADED_IMAGE        *LoadedImage;
    EFI_FILE_IO_INTERFACE   *Vol;
    EFI_FILE_HANDLE         RootFs;
    EFI_FILE_HANDLE         FileHandle;

    int i = 0;
    void (*func)(void);
    EFI_STATUS status = EFI_SUCCESS;
    struct KERNEL_BOOT_PARAMETER_INFORMATION *kernel_boot_para_info = NULL;

    ///////////////////////////////////////////////////////////////////////

    gBS->HandleProtocol(ImageHandle,&gEfiLoadedImageProtocolGuid,(VOID*)&LoadedImage);
    // Q: gBS ?
    // G: 我猜是 global Boot Service 的意思
    // R: https://github.com/tianocore/edk2/blob/master/MdePkg/Library/UefiBootServicesTableLib/UefiBootServicesTableLib.c
    // R: https://blog.csdn.net/choumin/article/details/109849675
    //
    // Q: gEfiLoadedImageProtocolGuid
    // R: https://edk2-docs.gitbook.io/edk-ii-uefi-driver-writer-s-guide/27_load_file_driver_design_guidelines
    // R: https://github.com/tianocore/edk2/blob/master/MdePkg/Include/Protocol/SimpleFileSystem.h
    //
    // Q: 我猜這裡的功用是藉由 ImageHandle 的資訊來初始化 LoadedImage
    //
    //
    // R: http://white5168.blogspot.com/2013/06/uefi-locateprotocolhandleprotocol.html#.YIT2HHUzZE4
    // G: HandleProtocol 的作用是從某個 Handle ( 上述的 ImageHandle ) 中指定的 Protocol ( gEfiLoadedImageProtocolGuid )，取出另一個 Handle ( 放在 LoadedImage )

    gBS->HandleProtocol(LoadedImage->DeviceHandle,&gEfiSimpleFileSystemProtocolGuid,(VOID*)&Vol);
    // Q: 我猜這裡的功用是初始化 Vol
    //
    // Q: 猜是從 LoadedImage 這個 Handle 拿到了 DeviceHandle，從 DeviceHandle 裡面對指令的 Protocol ( gEfiSimpleFileSystemProtocolGuid ) 取出相對應的 Handle ( 放在 Vol )

    Vol->OpenVolume(Vol,&RootFs);
    // Q: 我猜這裡的功用是初始化 RootFs

    status = RootFs->Open(RootFs,&FileHandle,(CHAR16*)L"kernel.bin",EFI_FILE_MODE_READ,0);
    if(EFI_ERROR(status))
    {
        Print(L"Open kernel.bin Failed.\n");
        return status;
    }

    EFI_FILE_INFO* FileInfo;
    UINTN BufferSize = 0;
    EFI_PHYSICAL_ADDRESS pages = 0x100000;

    BufferSize = sizeof(EFI_FILE_INFO) + sizeof(CHAR16) * 100;
    /* AllocatePool 主要是用來 alloc 一段比較小的 buffer */
    gBS->AllocatePool(EfiRuntimeServicesData,BufferSize,(VOID**)&FileInfo);
    FileHandle->GetInfo(FileHandle,&gEfiFileInfoGuid,&BufferSize,FileInfo);
    Print(L"\tFileName:%s\t Size:%d\t FileSize:%d\t Physical Size:%d\n",FileInfo->FileName,FileInfo->Size,FileInfo->FileSize,FileInfo->PhysicalSize);

    // 這邊是為了 allocate 放 kernel.bin 的位址
    // 我們將 kernel.bin 載入到物理位址 0x100000 的地方
    gBS->AllocatePages(AllocateAddress,EfiConventionalMemory,(FileInfo->FileSize + 0x1000 - 1) / 0x1000,&pages);
    Print(L"Read Kernel File to Memory Address:%018lx\n",pages);
    BufferSize = FileInfo->FileSize;

    //Q: 從 FileHandle 讀資料到 pages， BufferSize 會回傳我們讀了多少 Bytes 的資料
    FileHandle->Read(FileHandle,&BufferSize,(VOID*)pages);
    gBS->FreePool(FileInfo);
    FileHandle->Close(FileHandle);
    RootFs->Close(RootFs);
    /* Read File to memory end */
  
    Print(L"try to print BufferSize : %d\n", BufferSize);
 
    ///////////////////////////////////////////////////////////////////////

    /* Read graphics information start */
    EFI_GRAPHICS_OUTPUT_PROTOCOL* gGraphicsOutput = 0;
    EFI_GRAPHICS_OUTPUT_MODE_INFORMATION* Info = 0;
    UINTN InfoSize = 0;

    pages = 0x60000;
    kernel_boot_para_info = (struct KERNEL_BOOT_PARAMETER_INFORMATION *)0x60000;

    /*
      AllocatePages(
        此 page 的 type,
        一樣是此 page 的 type,
        要多少 page 呢  ( 每個 page 最小 4 KB ),        
        page 要放在哪裡
      )
    */

    // 這邊又對 0x100000 進行 allocate page ， 是為了要把 graphic 位址的映射填到 OS 的 PTE 
    // 上面說錯了，現在 pages 的值是 0x60000
    
    gBS->AllocatePages(AllocateAddress,EfiConventionalMemory,1,&pages);
    gBS->SetMem((void*)kernel_boot_para_info,0x1000,0);

    gBS->LocateProtocol(&gEfiGraphicsOutputProtocolGuid,NULL,(VOID **)&gGraphicsOutput);

    //long H_V_Resolution = gGraphicsOutput->Mode->Info->HorizontalResolution * gGraphicsOutput->Mode->Info->VerticalResolution;
    //int MaxResolutionMode = gGraphicsOutput->Mode->Mode;

    int fdgkResolutionMode = gGraphicsOutput->Mode->Mode;
    for(i = 0;i < gGraphicsOutput->Mode->MaxMode;i++)
    {
        gGraphicsOutput->QueryMode(gGraphicsOutput,i,&InfoSize,&Info);
        /*if((Info->PixelFormat == 1) && (Info->HorizontalResolution * Info->VerticalResolution > H_V_Resolution))
        {
            H_V_Resolution = Info->HorizontalResolution * Info->VerticalResolution;
            MaxResolutionMode = i;
        }*/

	// 因為我的電腦在最高畫質的時候，顯示起來怪怪的，所以我在這邊只要解析有到 1024 * 768 ，我就停下來。
	if((Info->PixelFormat == 1) && Info->HorizontalResolution == 1024 && Info->VerticalResolution == 768) {
          fdgkResolutionMode = i; 
	  break;
	}
        gBS->FreePool(Info);
    }

    //gGraphicsOutput->SetMode(gGraphicsOutput,MaxResolutionMode);
    gGraphicsOutput->SetMode(gGraphicsOutput, fdgkResolutionMode);
    gBS->LocateProtocol(&gEfiGraphicsOutputProtocolGuid,NULL,(VOID **)&gGraphicsOutput);
    Print(L"Current Mode:%02d,Version:%x,Format:%d,Horizontal:%d,Vertical:%d,ScanLine:%d,FrameBufferBase:%018lx,FrameBufferSize:%018lx\n",gGraphicsOutput->Mode->Mode,gGraphicsOutput->Mode->Info->Version,gGraphicsOutput->Mode->Info->PixelFormat,gGraphicsOutput->Mode->Info->HorizontalResolution,gGraphicsOutput->Mode->Info->VerticalResolution,gGraphicsOutput->Mode->Info->PixelsPerScanLine,gGraphicsOutput->Mode->FrameBufferBase,gGraphicsOutput->Mode->FrameBufferSize);

    //while(1);

    kernel_boot_para_info->Graphics_Info.HorizontalResolution = gGraphicsOutput->Mode->Info->HorizontalResolution;
    kernel_boot_para_info->Graphics_Info.VerticalResolution = gGraphicsOutput->Mode->Info->VerticalResolution;
    kernel_boot_para_info->Graphics_Info.PixelsPerScanLine = gGraphicsOutput->Mode->Info->PixelsPerScanLine;
    kernel_boot_para_info->Graphics_Info.FrameBufferBase = gGraphicsOutput->Mode->FrameBufferBase;
    kernel_boot_para_info->Graphics_Info.FrameBufferSize = gGraphicsOutput->Mode->FrameBufferSize;

    // 這邊開始將 frame buffer 映射到 Virtual Address
    // 最好是畫個圖解釋一下
    Print(L"Map Graphics FrameBufferBase to Virtual Address 0xffff800003000000\n");
    Print(L"gGraphicsOuput->Mode->FrameBufferSize : %d, gGraphicsOutput->Mode->FrameBufferBase : %ld\n", gGraphicsOutput->Mode->FrameBufferBase);    
    long * PageTableEntry = (long *)0x103000;
    /*for(i = 0;i < 10;i++) {
      Print(L"fdgk print addr : 0x%lx, val : 0x%lx\n", PageTableEntry, *PageTableEntry);
      PageTableEntry++;
    }*/

    //int fdgki = 0;
    for(i = 0;i < (gGraphicsOutput->Mode->FrameBufferSize + 0x200000 - 1) >> 21;i++)    // map to virtual address 0xffff800003000000
    {
        *(PageTableEntry + 24 + i) = gGraphicsOutput->Mode->FrameBufferBase | 0x200000 * i | 0x87;
        Print(L"Page %02d,Address:%018lx,Value:%018lx\n",i,(long)(PageTableEntry + 24 + i),*(PageTableEntry + 24 + i));

        // workaround
        /*fdgki++;
        if(fdgki == 6) {
            while(1);
        }*/
    }

    //while(1);
    /* read graphic information end */

    ///////////////////////////////////////////////////////////////////////

    /* 取得記憶體配置 */
    struct EFI_E820_MEMORY_DESCRIPTOR *E820p = kernel_boot_para_info->E820_Info.E820_Entry;
    struct EFI_E820_MEMORY_DESCRIPTOR *LastE820 = NULL;
    unsigned long LastEndAddr = 0;
    int E820Count = 0;        /* 紀錄總共有多少個 E820 */

    UINTN MemMapSize = 0;
    EFI_MEMORY_DESCRIPTOR* MemMap = 0;
    UINTN MapKey = 0;
    UINTN DescriptorSize = 0;
    UINT32 DesVersion = 0;

    gBS->GetMemoryMap(&MemMapSize,MemMap,&MapKey,&DescriptorSize,&DesVersion);
    MemMapSize += DescriptorSize * 5;
    gBS->AllocatePool(EfiRuntimeServicesData,MemMapSize,(VOID**)&MemMap);
    Print(L"Get MemMapSize:%d,DescriptorSize:%d,count:%d\n",MemMapSize,DescriptorSize,MemMapSize/DescriptorSize);
    gBS->SetMem((void*)MemMap,MemMapSize,0);
    status = gBS->GetMemoryMap(&MemMapSize,MemMap,&MapKey,&DescriptorSize,&DesVersion);
    Print(L"Get MemMapSize:%d,DescriptorSize:%d,count:%d\n",MemMapSize,DescriptorSize,MemMapSize/DescriptorSize);
    if(EFI_ERROR(status)) {
         Print(L"status:%018lx\n",status);
    }

    Print(L"Get EFI_MEMORY_DESCRIPTOR Structure:%018lx\n",MemMap);
    for(i = 0;i < MemMapSize / DescriptorSize;i++)
    {
        int MemType = 0;
        EFI_MEMORY_DESCRIPTOR* MMap = (EFI_MEMORY_DESCRIPTOR*) ((CHAR8*)MemMap + i * DescriptorSize);
        if(MMap->NumberOfPages == 0)
            continue;
//        Print(L"MemoryMap %4d %10d (%16lx<->%16lx) %016lx\n",MMap->Type,MMap->NumberOfPages,MMap->PhysicalStart,MMap->PhysicalStart + (MMap->NumberOfPages << 12),MMap->Attribute);
        switch(MMap->Type)
        {
            case EfiReservedMemoryType:
            case EfiMemoryMappedIO:
            case EfiMemoryMappedIOPortSpace:
            case EfiPalCode:
                MemType= 2;    //2:ROM or Reserved
                break;

            case EfiUnusableMemory:
                MemType= 5;    //5:Unusable
                break;

            case EfiACPIReclaimMemory:
                MemType= 3;    //3:ACPI Reclaim Memory
                break;

            case EfiLoaderCode:
            case EfiLoaderData:
            case EfiBootServicesCode:
            case EfiBootServicesData:
            case EfiRuntimeServicesCode:
            case EfiRuntimeServicesData:
            case EfiConventionalMemory:
            case EfiPersistentMemory:
                MemType= 1;    //1:RAM
                break;

            case EfiACPIMemoryNVS:
                MemType= 4;    //4:ACPI NVS Memory
                break;

            default:
                Print(L"Invalid UEFI Memory Type:%4d\n",MMap->Type);
                continue;
        }

        if((LastE820 != NULL) && (LastE820->type == MemType) && (MMap->PhysicalStart == LastEndAddr))
        {
            LastE820->length += MMap->NumberOfPages << 12;
            LastEndAddr += MMap->NumberOfPages << 12;
        }
        else
        {
            E820p->address = MMap->PhysicalStart;
            E820p->length = MMap->NumberOfPages << 12;
            E820p->type = MemType;
            LastEndAddr = MMap->PhysicalStart + (MMap->NumberOfPages << 12);
            LastE820 = E820p;
            E820p++;
            E820Count++;
        }
    }

    kernel_boot_para_info->E820_Info.E820_Entry_count = E820Count;
    LastE820 = kernel_boot_para_info->E820_Info.E820_Entry;
    int j = 0;
    for(i = 0; i< E820Count; i++)
    {
        struct EFI_E820_MEMORY_DESCRIPTOR* e820i = LastE820 + i;
        struct EFI_E820_MEMORY_DESCRIPTOR MemMap;
        for(j = i + 1; j< E820Count; j++)
        {
            struct EFI_E820_MEMORY_DESCRIPTOR* e820j = LastE820 + j;
            if(e820i->address > e820j->address)
            {
                MemMap = *e820i;
                *e820i = *e820j;
                *e820j = MemMap;
            }
        }
    }

    // Q: 印象中 kernel_boot_para_info->E820_Info.E820_Entry 有個特殊用途
    LastE820 = kernel_boot_para_info->E820_Info.E820_Entry;
    for(i = 0;i < E820Count;i++)
    {
        //Print(L"MemoryMap (%10lx<->%10lx) %4d\n",LastE820->address,LastE820->address+LastE820->length,LastE820->type);
        LastE820++;
    }
    Print(L"kernel_boot_para_info->E820_Info.E820_Entry : 0x%lx", kernel_boot_para_info->E820_Info.E820_Entry);

    /*while(1) {

    }*/

    gBS->FreePool(MemMap);

    Print(L"Call ExitBootServices And Jmp to Kernel.\n");
    gBS->GetMemoryMap(&MemMapSize,MemMap,&MapKey,&DescriptorSize,&DesVersion);
    /* 取得記憶體配置 end */

    ///////////////////////////////////////////////////////////////////////

    /* close protocol and jump to kernel */
    gBS->CloseProtocol(LoadedImage->DeviceHandle,&gEfiSimpleFileSystemProtocolGuid,ImageHandle,NULL);
    gBS->CloseProtocol(ImageHandle,&gEfiLoadedImageProtocolGuid,ImageHandle,NULL);

    gBS->CloseProtocol(gGraphicsOutput,&gEfiGraphicsOutputProtocolGuid,ImageHandle,NULL);
    status = gBS->ExitBootServices(ImageHandle,MapKey);
    if(EFI_ERROR(status))
    {
        Print(L"ExitBootServices: Failed, Memory Map has Changed.\n");
        return EFI_INVALID_PARAMETER;
    }
    func = (void *)0x100000;
    func();

    return EFI_SUCCESS;
}

