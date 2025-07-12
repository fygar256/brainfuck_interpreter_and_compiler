#!/usr/local/bin/python3
import sys

def lsout(loopstack):
    return str(loopstack).replace(', ','_').replace('[','').replace(']','')

def main():
    if len(sys.argv)!=2:
        print(f"Usage: {sys.argv[0]} <file>")
        return
    print("    .section .text")
    print("    .globl _start")
    print("_start:")
    print("    movabs $_my_data,%rsi")

    f=open(sys.argv[1],"rt")
    loopstack=[]
    lf='['
    for s in f:
        for c in s:
            if c=='>':
                print("    inc     %rsi")
            elif c=='<':
                print("    dec     %rsi")
            elif c=='+':
                print("    incb     (%rsi)")
            elif c=='-':
                print("    decb     (%rsi)")
            elif c=='.':
                print("    mov     $4,%rax") # syscall Write
                print("    mov     $1,%rdi") # fd: stdout
                print("    mov     $1,%rdx") # count
                print("    syscall")
            elif c==',':
                print("    mov     $3,%rax") # syscall Read
                print("    mov     $0,%rdi") # fd: stdin
                print("    mov     $1,%rdx") # count
                print("    syscall")
            elif c=='[':
                if lf==']':
                    loopstack[len(loopstack)-1]+=1
                else:
                    loopstack.append(1)
                lf='['
                print(f"LB{lsout(loopstack)}:")
                print("    cmpb   $0,(%rsi)")
                print(f"    je     LE{lsout(loopstack)}")
            elif c==']':
                if lf==']':
                    loopstack.pop()
                lf=']'
                print(f"    jmp     LB{lsout(loopstack)}")
                print(f"LE{lsout(loopstack)}:")
    f.close()
    print("    mov     $1,%rax")  # syscall exit
    print("    xor     %rdi,%rdi") # status = 0
    print("    syscall")
    print(".section .bss")
    print("_my_data: .zero 65536")

if __name__=='__main__':
    main()
    exit(0)

