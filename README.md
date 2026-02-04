FILES:
beef.py,beef.c extended brainfuck interpreters

bfo.py brainfuck compressor

bf.c and bf.go are brainfuck interpreters.

bfa.c,bfa.py are brainfuck disassemblers in c and python for axx

bfc.c is a brainfuck compiler to c.

bfs.c, bfs.py and bfs.go are brainfuck compiler to x86_64 assembly language for linux.

bfsf.py is brainfuck compiler to x86_64 assembly for FreeBSD.

bfsf.go is brainfuck compiler to x86_64 assembly for FreeBSD.

bfe.c is brainfuck extra. 7 commanded bf interpreter.

bfr.c is brainfuck reduction interpreter.

bfrr.c is brainfuck reduction reduced interpreter.

bfrf.c is brainfuck reduntion finite interpreter.

bfrfr.c is brainfuck reduction finite reduced interpreter

hello.bfe is hellowrold for bfe.

hello.bfr is helloworld for bfr and bfrr.

hello.bfrf is helloworld for bfrf and bfrfr. 

# Brainf*ck compiler to x86_64 assembly for FreeBSD.

The assembly file is output to standard output, so
run it with go run bfsf.go <file.bf> >out.s.

out.s can be assembled with as,
to assemble the assembly file with as out.s -o out.o,
and link it with ld out.o -o out.

Run it with ./out.

# Brainf*ck's Fundamentals of Computation

Programs can be written using concatenation and branching, but Brainfuck, a rehash of P'', resolves branching using loops.

Neither P'' nor Brainfuck have program addresses, labels, or branching, and their only control is nested loops. The structural theorem shows that programs can be written using concatenation, selection, and repetition, but P'' can be written using only concatenation and repetition.

Resolving branching using repetition would result in a more complex program.

Turing completeness is different from the ability to write a program using concatenation and branching, but a program is Turing complete if it can perform operations, access memory, and handle concatenation and branching.

"Turing completeness means that a computational model A can theoretically perform all computations that are computable. In other words, any computation, no matter how complex, can be expressed in terms of A, given enough time and memory." (Gemini) A slight correction by me.

Thanks for letting me know, Computer Scientist.

Humans can perform all of Brainfuck's calculations, so it's Turing complete.

Also, the code to process `if (*ptr) then A else B` in Brainfuck looks like this:

```
>+<[>-<A[-]]>[B[-]]<
```

Before execution, this code requires `*(ptr+1)` to be 0, and after execution, the value of `*ptr` becomes 0. `ptr` is preserved. It's not equivalent code because it's difficult to preserve memory cell values, but here's what it looks like. Conditional execution looks like this, but it's not a conditional jump.

#### An idea for further reducing Brainfuck. brainfuck extra

Since the data it can handle is one byte, the next to 255 in a 256 loop is 0, so there's no need for a `-`.
This brings the total number of commands to seven.

brainfuck extra is the limit of Turing completeness. If time is infinite and memory starts at address 0 and has no end, mapping mem[n] as mem[f(n)] (f(n)=n//2+1 if n=odd, f(n)=-n//2 if n=even) creates a tape with no end. Even if memory starts at address 0, mem[-∞] and mem[∞] can be allocated. (This is Hilbert's idea of the Hotel of Infinity.)
The Turing Machine Halting Problem is whether a Turing machine will halt in finite time.

### Implementation 'bfe' brainfuck extra

Memory, loopstack, prog, lsp, idx, and len are finite, but please forgive me. In reality, this is probably about it.

Apparently, Urban Müller also came up with the idea for bfe.

#### hello world on bfe

#### (I'm redacting the part because it's too obvious) Brainf*ck reduction 'bfr'

If memory is finite, the pointer should be set to 0 when it reaches the upper memory address limit, eliminating the need for `<`.
If the pointer overflows and becomes 0 (given finite memory), it is not (virtually) Turing complete. bfr is Turing incomplete.

#### Implementation of 'bfr'

#### Hello world using bfr (no optimization)

bfr is completely useless.
Is six instructions the minimum? If you're just outputting stored data, you don't need the input `,`. Five is the minimum.

```
> Move pointer to the right
+ Increment the cell pointed to by the pointer
. Output 1 byte
[If the cell pointed to by the pointer is 0, jump to the next corresponding]
] Jump to the corresponding [
```
.
Implementation: brainfuck reduction reduction 'bfrr'

bfrr runs hello.bfr.

bfr and bfrr are subsets of the brainfuck processing system that returns the pointer to 0 when it overflows.
I'm sure Urban Müller thought of something like this.

If there is no input, everything is constant unless the program is rewritten, so
If the processing is finite, `[`,`]` is not necessary. The following command will suffice.

```
+ Increment the value of the cell pointed to by the pointer
> Move the pointer one position to the right
. Output 1 byte
```

Only three instructions are needed. Implementation: 'bfrf' brainfuck reduction finite.

This is useless. A bit overdone...?

Hello world using bfrf.

Displaying an arbitrary string requires just two commands.

hanoi.bf in brainfuck also simply displays a constant string.

```
+Increment variable A
.Output 1 byte
```

Implemented. This is called brainfuck reduction finite reduced 'bfrfr'.

hello.bfrf works with bfrfr.

That's too much! bfrfr, I'm staggering.
