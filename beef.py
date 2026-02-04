#!/usr/bin/env python3 
import sys
import re

def run_brainfuck(code, input_stream=""):
    memory = [0] * 30000
    ptr = 0
    ip = 0
    input_ptr = 0

    # tokenize - support both compressed (e.g., +5) and normal commands
    # For brackets, expand them into individual instructions
    tokens = re.findall(r'([+\-<>.,\[\]])(\d*)', code)
    instructions = []
    for cmd, count_str in tokens:
        count = int(count_str) if count_str else 1
        
        # For brackets, expand them into individual instructions
        # For other commands, keep them compressed
        if cmd in '[]':
            for _ in range(count):
                instructions.append((cmd, 1))
        else:
            instructions.append((cmd, count))

    # jump table
    bracket_map = {}
    stack = []
    for i, (cmd, _) in enumerate(instructions):
        if cmd == "[":
            stack.append(i)
        elif cmd == "]":
            if not stack:
                raise ValueError("Unmatched ']' in brainfuck code")
            j = stack.pop()
            bracket_map[i] = j
            bracket_map[j] = i
    
    if stack:
        raise ValueError("Unmatched '[' in brainfuck code")

    # operations (return next ip)
    def op_add(c):
        nonlocal ptr
        memory[ptr] = (memory[ptr] + c) % 256
        return ip + 1

    def op_sub(c):
        nonlocal ptr
        memory[ptr] = (memory[ptr] - c) % 256
        return ip + 1

    def op_right(c):
        nonlocal ptr
        ptr = (ptr + c) % len(memory)
        return ip + 1

    def op_left(c):
        nonlocal ptr
        ptr = (ptr - c) % len(memory)
        return ip + 1

    def op_out(c):
        for _ in range(c):
            sys.stdout.write(chr(memory[ptr]))
        return ip + 1

    def op_in(c):
        nonlocal input_ptr
        for _ in range(c):
            if input_ptr < len(input_stream):
                memory[ptr] = ord(input_stream[input_ptr])
                input_ptr += 1
            else:
                memory[ptr] = 0
        return ip + 1

    def op_lbracket(_):
        if memory[ptr] == 0:
            return bracket_map[ip] + 1
        return ip + 1

    def op_rbracket(_):
        if memory[ptr] != 0:
            return bracket_map[ip] + 1
        return ip + 1

    ops = {
        "+": op_add,
        "-": op_sub,
        ">": op_right,
        "<": op_left,
        ".": op_out,
        ",": op_in,
        "[": op_lbracket,
        "]": op_rbracket,
    }

    while ip < len(instructions):
        cmd, count = instructions[ip]
        ip = ops[cmd](count)


def main():
    if len(sys.argv) < 2:
        print("Usage: python beef.py program.bf [input_file]", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        code = f.read()

    if len(sys.argv) > 2:
        with open(sys.argv[2], "rb") as f:
            input_stream = f.read().decode("latin1")
    else:
        input_stream = ""

    run_brainfuck(code, input_stream)


if __name__ == "__main__":
    main()
