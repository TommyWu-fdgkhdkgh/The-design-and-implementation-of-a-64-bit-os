# 1 "head.S"
# 1 "<built-in>"
# 1 "<command-line>"
# 31 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 32 "<command-line>" 2
# 1 "head.S"
# 17 "head.S"
.section .text

.global _start;
_start:

 mov %ss, %ax
 mov %ax, %ds
 mov %ax, %es
 mov %ax, %fs
 mov %ax, %ss
 mov $0x7E00, %esp




 movq $0x101000, %rax
 movq %rax, %cr3



 lgdt GDT_POINTER(%rip)



 lidt IDT_POINTER(%rip)

 mov $0x10, %ax
 mov %ax, %ds
 mov %ax, %es
 mov %ax, %fs
 mov %ax, %gs
 mov %ax, %ss



 movq switch_seg(%rip), %rax
 pushq $0x08
 pushq %rax
 lretq



switch_seg:
 .quad entry64

entry64:
 movq $0x10, %rax
 movq %rax, %ds
 movq %rax, %es
 movq %rax, %gs
 movq %rax, %ss
 movq $0xffff800000007e00, %rsp

        movq go_to_kernel(%rip), %rax
        pushq $0x08
        pushq %rax
        lretq

go_to_kernel:
 .quad Start_Kernel



.align 8

.org 0x1000

__PML4E:

 .quad 0x102007
 .fill 255,8,0
 .quad 0x102007
 .fill 255,8,0

.org 0x2000

__PDPTE:

 .quad 0x103007
 .fill 511,8,0

.org 0x3000

__PDE:

 .quad 0x000087
 .quad 0x200087
 .quad 0x400087
 .quad 0x600087
 .quad 0x800087
 .quad 0xa00087
 .quad 0xc00087
 .quad 0xe00087
 .quad 0x1000087
 .quad 0x1200087
 .quad 0x1400087
 .quad 0x1600087
 .quad 0x1800087
 .fill 499,8,0



.section .data

.globl GDT_Table

GDT_Table:
 .quad 0x0000000000000000
 .quad 0x0020980000000000
 .quad 0x0000920000000000
 .quad 0x0000000000000000
 .quad 0x0000000000000000
 .quad 0x0020f80000000000
 .quad 0x0000f20000000000
 .quad 0x00cf9a000000ffff
 .quad 0x00cf92000000ffff
 .fill 10,8,0
GDT_END:

GDT_POINTER:
GDT_LIMIT: .word GDT_END - GDT_Table - 1
GDT_BASE: .quad GDT_Table



.globl IDT_Table

IDT_Table:
 .fill 512,8,0
IDT_END:

IDT_POINTER:
IDT_LIMIT: .word IDT_END - IDT_Table - 1
IDT_BASE: .quad IDT_Table



.globl TSS64_Table

TSS64_Table:
 .fill 13,8,0
TSS64_END:


TSS64_POINTER:
TSS64_LIMIT: .word TSS64_END - TSS64_Table - 1
TSS64_BASE: .quad TSS64_Table
