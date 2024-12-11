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
    fmt.Println("\tmovabs $_my_data,%rsi");
    fmt.Println("\tmov\t$1,%edx");


    file,err := os.Open(os.Args[1])
    byteData,err:=io.ReadAll(file)
    _ =err

    for idx:=0;idx<len(byteData);idx++ {
        switch byteData[idx] {
        case '>':
            fmt.Println("\tinc     %rsi")
        case '<':
            fmt.Println("\tdec     %rsi")
        case '+':
            fmt.Println("\tincb     (%rsi)")
        case '-':
            fmt.Println("\tdecb     (%rsi)")
        case '.':
			fmt.Println("\tmov\t%edx,%eax");
     		fmt.Println("\tmov\t%edx,%edi");
			fmt.Println("\tsyscall");
        case ',':
        	fmt.Println("\txor\t%eax, %eax")
		    fmt.Println("\txor\t%ebx, %ebx")
			fmt.Println("\tsyscall\n")
        case '[':
            if lf==']' {
                loopstack[len(loopstack)-1]+=1
            } else {
                loopstack = append(loopstack,1)
            }
            lf='['
            fmt.Print("\tjmp     LE")
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
	        fmt.Println("\tcmp\t%dh,(%rsi)");
            fmt.Print("\tjne\tLB")
            lsout(loopstack)
            fmt.Println("")
        default:
        }
    }

    fmt.Println("\tmov\t$1,%eax");
    fmt.Println("\txor\t%ebx,%ebx");
    fmt.Println("\tint $0x80");
    fmt.Println(".section .bss");
    fmt.Println("_my_data: .zero 65536");
}

