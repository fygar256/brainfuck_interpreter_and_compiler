#!/usr/bin/python3
import sys

def lsout(loopstack):
    return str(loopstack).replace(', ','_').replace('[','').replace(']','')

def main():
    if len(sys.argv)!=2:
        print(f"Usage: {sys.argv[0]} <file>")
        return

    print(f"\t.file\t\"{sys.argv[1]}\"")
    print("    .text")
    print("    .globl  main")
    print("    .type   main,@function")
    print("main:")
    print(".LFB0:")
    print("    .cfi_startproc")
    print("    pushq    %rbp")
    print("    .cfi_def_cfa_offset 16")
    print("    .cfi_offset 6, -16")
    print("    movq    %rsp, %rbp")
    print("    .cfi_def_cfa_register 6")
    print("    subq    $30032, %rsp")
    print("    movq    %fs:40, %rax")
    print("    movq    %rax, -8(%rbp)")
    print("    xorl    %eax, %eax")
    print("    leaq    -30016(%rbp), %rax")
    print("    movl    $30000, %edx")
    print("    movl    $0, %esi")
    print("    movq    %rax, %rdi")
    print("    call    memset@PLT")
    print("    leaq    -30016(%rbp), %rax")
    print("    movq    %rax, -30024(%rbp)")

    f=open(sys.argv[1],"rt")
    loopstack=[]
    lf='['
    for s in f:
        for c in s:
            if c=='>':
                print("    addq    $1, -30024(%rbp)")
            elif c=='<':
                print("    subq    $1, -30024(%rbp)")
            elif c=='+':
                print("    movq    -30024(%rbp), %rax")
                print("    movzbl  (%rax), %eax")
                print("    addl    $1, %eax")
                print("    movl    %eax, %edx")
                print("    movq    -30024(%rbp), %rax")
                print("    movb    %dl, (%rax)")
            elif c=='-':
                print("    movq    -30024(%rbp), %rax")
                print("    movzbl  (%rax), %eax")
                print("    subl    $1, %eax")
                print("    movl    %eax, %edx")
                print("    movq    -30024(%rbp), %rax")
                print("    movb    %dl, (%rax)")
            elif c=='.':
                print("    movq    -30024(%rbp), %rax")
                print("    movzbl  (%rax), %eax")
                print("    movsbl  %al, %eax")
                print("    movl    %eax, %edi")
                print("    call    putchar@PLT")
            elif c==',':
                print("    call    getchar@PLT")
                print("    movl    %eax, %edx")
                print("    movq    -30024(%rbp), %rax")
                print("    movb    %dl, (%rax)")
            elif c=='[':
                if lf==']':
                    loopstack[len(loopstack)-1]+=1
                else:
                    loopstack.append(1)
                lf='['
                print(f"    jmp     LE{lsout(loopstack)}")
                print(f"LB{lsout(loopstack)}:")
            elif c==']':
                if lf==']':
                    loopstack.pop()
                lf=']'
                print(f"LE{lsout(loopstack)}:")
                print("    movq    -30024(%rbp), %rax")
                print("    movzbl  (%rax), %eax")
                print("    testb   %al, %al")
                print(f"    jne     LB{lsout(loopstack)}")
    f.close()
    print("    nop")
    print("    movq    -8(%rbp), %rax")
    print("    subq    %fs:40, %rax")
    print("    je      .LFE1")
    print("    call    __stack_chk_fail@PLT")
    print(".LFE1:")
    print("    leave")
    print("    .cfi_def_cfa 7, 8")
    print("    ret")
    print("    .cfi_endproc")
    print(".LFE0:")
    print("    .size   main, .-main")
    print("    .section .note.GNU-stack,\"\",@progbits")

if __name__=='__main__':
    main()
    exit(0)

