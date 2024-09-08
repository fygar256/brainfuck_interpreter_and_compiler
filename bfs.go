package main

import (
    "fmt"
    "os"
    "io"
)

var (
    lf int ='['
    loopstack=[]int{}
)

func lsout(loopstack [] int) {
    for i:=0;i<len(loopstack);i++ {
        fmt.Printf("%d_",loopstack[i])
    }
}

func main() {
    if len(os.Args)!=2 {
        fmt.Println("Usage: bfs.go <file>")
        return
    }
    fmt.Println("    .text")
    fmt.Println("    .globl  main")
    fmt.Println("    .type   main,@function")
    fmt.Println("main:")
    fmt.Println(".LFB0:")
    fmt.Println("    .cfi_startproc")
    fmt.Println("    pushq    %rbp")
    fmt.Println("    .cfi_def_cfa_offset 16")
    fmt.Println("    .cfi_offset 6, -16")
    fmt.Println("    movq    %rsp, %rbp")
    fmt.Println("    .cfi_def_cfa_register 6")
    fmt.Println("    subq    $30032, %rsp")
    fmt.Println("    movq    %fs:40, %rax")
    fmt.Println("    movq    %rax, -8(%rbp)")
    fmt.Println("    xorl    %eax, %eax")
    fmt.Println("    leaq    -30016(%rbp), %rax")
    fmt.Println("    movl    $30000, %edx")
    fmt.Println("    movl    $0, %esi")
    fmt.Println("    movq    %rax, %rdi")
    fmt.Println("    call    memset@PLT")
    fmt.Println("    leaq    -30016(%rbp), %rax")
    fmt.Println("    movq    %rax, -30024(%rbp)")

    file,err := os.Open(os.Args[1])
    byteData,err:=io.ReadAll(file)
    _ =err

    for idx:=0;idx<len(byteData);idx++ {
        switch byteData[idx] {
        case '>':
            fmt.Println("    addq    $1, -30024(%rbp)")
        case '<':
            fmt.Println("    subq    $1, -30024(%rbp)")
        case '+':
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movzbl  (%rax), %eax")
            fmt.Println("    addl    $1, %eax")
            fmt.Println("    movl    %eax, %edx")
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movb    %dl, (%rax)")
        case '-':
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movzbl  (%rax), %eax")
            fmt.Println("    subl    $1, %eax")
            fmt.Println("    movl    %eax, %edx")
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movb    %dl, (%rax)")
        case '.':
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movzbl  (%rax), %eax")
            fmt.Println("    movsbl  %al, %eax")
            fmt.Println("    movl    %eax, %edi")
            fmt.Println("    call    putchar@PLT")
        case ',':
            fmt.Println("    call    getchar@PLT")
            fmt.Println("    movl    %eax, %edx")
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movb    %dl, (%rax)")
        case '[':
            if lf==']' {
                loopstack[len(loopstack)-1]+=1
            } else {
                loopstack = append(loopstack,1)
            }
            lf='['
            fmt.Print("    jmp     LE")
            lsout(loopstack)
            fmt.Println("")
            fmt.Print("LB")
            lsout(loopstack)
            fmt.Println(":")
        case ']':
            if lf==']' {
                loopstack=loopstack[:len(loopstack)-1]
            }
            lf=']'
            fmt.Print("LE")
            lsout(loopstack)
            fmt.Println(":")
            fmt.Println("    movq    -30024(%rbp), %rax")
            fmt.Println("    movzbl  (%rax), %eax")
            fmt.Println("    testb   %al, %al")
            fmt.Print("    jne     LB")
            lsout(loopstack)
            fmt.Println("")
        default:
        }
    }

    fmt.Println("    nop")
    fmt.Println("    movq    -8(%rbp), %rax")
    fmt.Println("    subq    %fs:40, %rax")
    fmt.Println("    je      .LFE1")
    fmt.Println("    call    __stack_chk_fail@PLT")
    fmt.Println(".LFE1:")
    fmt.Println("    leave")
    fmt.Println("    .cfi_def_cfa 7, 8")
    fmt.Println("    ret")
    fmt.Println("    .cfi_endproc")
    fmt.Println(".LFE0:")
    fmt.Println("    .size   main, .-main")
    fmt.Println("    .section .note.GNU-stack,\"\",@progbits")
}
