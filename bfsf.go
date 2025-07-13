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
        fmt.Println("Usage: go run bfs.go file.bf >out.s")
        return
    }
    fmt.Println("\t.section .text");
    fmt.Println("\t.globl _start");
    fmt.Println("_start:");
    fmt.Println("\tmovabs\t$_my_data,%rsi");


    file,err := os.Open(os.Args[1])
    byteData,err:=io.ReadAll(file)
    _ =err

    for idx:=0;idx<len(byteData);idx++ {
        switch byteData[idx] {
        case '>':
            fmt.Println("\tinc\t%rsi")
        case '<':
            fmt.Println("\tdec\t%rsi")
        case '+':
            fmt.Println("\tincb\t(%rsi)")
        case '-':
            fmt.Println("\tdecb\t(%rsi)")
        case '.':
	    fmt.Println("\tmov\t$4,%rax")
     	    fmt.Println("\tmov\t$1,%rdi")
	    fmt.Println("\tmov\t$1,%rdx")
	    fmt.Println("\tsyscall")
        case ',':
            fmt.Println("\tmov\t$3,%rax")
	    fmt.Println("\tmov\t$1,%rdi")
	    fmt.Println("\tmov\t$1,%rdx")
	    fmt.Println("\tsyscall\n")
        case '[':
            if lf==']' {
                loopstack[len(loopstack)-1]+=1
            } else {
                loopstack = append(loopstack,1)
            }
            lf='['
            fmt.Print("LB")
            lsout(loopstack)
            fmt.Println(":")
	    fmt.Println("\tcmpb\t$0,(%rsi)")
            fmt.Print("\tje     LE")
            lsout(loopstack)
            fmt.Println("")
        case ']':
            if lf==']' {
                loopstack=loopstack[:len(loopstack)-1]
            }
            lf=']'
            fmt.Print("\tjmp\tLB")
            lsout(loopstack)
            fmt.Println("")
            fmt.Print("LE")
            lsout(loopstack)
            fmt.Println(":")
        default:
        }
    }

    fmt.Println("\tmov\t$1,%rax")
    fmt.Println("\txor\t%rdi,%rdi")
    fmt.Println("\tsyscall")
    fmt.Println(".section .bss")
    fmt.Println("_my_data: .zero 65536")
}

