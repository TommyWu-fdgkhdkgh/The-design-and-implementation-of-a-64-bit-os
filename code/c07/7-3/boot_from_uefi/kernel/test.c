#include <stdio.h>

#define PAGE_OFFSET     ((unsigned long)0xffff800000000000)
// 系統核心的物理位址為 0 的線性地址。

#define PAGE_GDT_SHIFT  39
#define PAGE_1G_SHIFT   30
#define PAGE_2M_SHIFT   21  // 2 的 21 次方 == 2MB
#define PAGE_4K_SHIFT   12  // 2 的 12 次方 == 4KB

#define PAGE_2M_SIZE    (1UL << PAGE_2M_SHIFT)
#define PAGE_4K_SIZE    (1UL << PAGE_4K_SHIFT)

#define PAGE_2M_MASK    (~ (PAGE_2M_SIZE - 1))
#define PAGE_4K_MASK    (~ (PAGE_4K_SIZE - 1))

#define PAGE_2M_ALIGN(addr)     (((unsigned long)(addr) + PAGE_2M_SIZE - 1) & PAGE_2M_MASK)
#define PAGE_4K_ALIGN(addr)     (((unsigned long)(addr) + PAGE_4K_SIZE - 1) & PAGE_4K_MASK)

#define Virt_To_Phy(addr)       ((unsigned long)(addr) - PAGE_OFFSET)
// 用來將系統核心的虛擬位址轉換成物理位址

#define Phy_To_Virt(addr)       ((unsigned long *)((unsigned long)(addr) + PAGE_OFFSET))
// 用來將系統核心的物理位址轉換成虛擬位址

#define Virt_To_2M_Page(kaddr)  (memory_management_struct.pages_struct + (Virt_To_Phy(kaddr) >> PAGE_2M_SHIFT))
#define Phy_to_2M_Page(kaddr)   (memory_management_struct.pages_struct + ((unsigned long)(kaddr) >> PAGE_2M_SHIFT))


int main() {

  for(int i = 0;i < 10;i++) {
    printf("addr = %d, PAGE_2M_ALIGN(%d) = %ld\n", i, i, PAGE_2M_ALIGN(i));
  }

  printf("addr = %d, PAGE_2M_ALIGN(%d) = %ld\n", 2097152, 2097152, PAGE_2M_ALIGN(2097152));
    
  return 0;
}
