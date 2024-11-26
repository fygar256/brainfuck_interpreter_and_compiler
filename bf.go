package main

import (
	"fmt"
	"io/ioutil"
	"os"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: go run bf.go <filename>")
		return
	}

	filename := os.Args[1]
	program, err := ioutil.ReadFile(filename)
	if err != nil {
		fmt.Println("Error reading file:", err)
		return
	}

	array := make([]byte, 30000)
	ptr := 0
	loopStack := make([]int, 1000)
	lsp := 0

    ip := 0

	for ip < len(program) {
        c:=program[ip]
        ip++
		switch c {
		case '>':
			ptr++
		case '<':
			ptr--
		case '+':
			array[ptr]++
		case '-':
			array[ptr]--
		case '.':
			fmt.Print(string(array[ptr]))
		case ',':
			var input byte
			fmt.Scanf("%c", &input)
			array[ptr] = input
		case '[':
			if array[ptr] != 0 {
				loopStack[lsp] = ip-1
				lsp++
			} else {
                nest := 1
                for ip < len(program) {
                    c:=program[ip]
                    ip++
					if c == '[' {
						nest++
					} else if c == ']' {
						nest--
						if nest == 0 {
							break
						}
					}
				}
			}
		case ']':
			lsp--
			ip = loopStack[lsp]
		}

		// Bounds check for the pointer. Exit with an error if out of bounds.
		if ptr < 0 || ptr >= len(array) {
			fmt.Println("Pointer out of bounds")
			return
		}
	}
}
