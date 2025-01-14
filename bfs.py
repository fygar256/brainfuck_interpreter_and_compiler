#!/usr/bin/python3
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
    print("    mov    $1,%edx")

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
                print("    mov     %edx,%eax")
                print("    mov     %edx,%ebx")
                print("    syscall")
            elif c==',':
                print("    xor     %eax,%eax")
                print("    xor     %ebx,%ebx")
                print("    syscall")
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
                print("    cmp     %dh,(%rsi)")
                print(f"    jne     LB{lsout(loopstack)}")
    f.close()
    print("    mov     $1,%eax")
    print("    xor     %ebx,%ebx")
    print("    int $0x80")
    print(".section .bss")
    print("_my_data: .zero 65536")

if __name__=='__main__':
    main()
    exit(0)

