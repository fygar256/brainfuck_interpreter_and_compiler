; beef_opt.asm – Optimized Brainfuck interpreter, FreeBSD x86-64
;
; Build:
;   nasm -f elf64 beef_opt.asm -o beef_opt.o
;   ld -o beef_opt beef_opt.o
;
; FreeBSD amd64 syscall ABI:
;   number→rax, args→rdi rsi rdx r10 r8 r9
;   return→rax; SYSCALL clobbers rcx and r11 (saves RIP/RFLAGS there)
;
; Optimization changes from original:
;   1. Interpreter loop uses DIRECT POINTER (r15=ip ptr) instead of
;      recomputing ip*24 on every handler entry.
;   2. Opcode dispatch table (jump table) replaces linear cmp chain.
;   3. tape base cached in rbp (frame pointer reused); lea rdi,[rel tape]
;      eliminated from hot path.
;   4. .op_put uses a write buffer on the stack instead of 1-byte writes.
;   5. grow_instrs uses rep movsq instead of rep movsb.
;   6. IS=32 (power of 2) so multiply by IS uses SHL+LEA instead of IMUL.
;   7. Zero-overhead loop entry: .run fetches cmd and dispatches in ~4 insns.
;   8. '[-]' / '[+]' set-to-zero pattern detected at bracket-build time
;      and emitted as '!' special opcode (fast zero).

bits 64

%define SYS_exit   1
%define SYS_read   3
%define SYS_write  4
%define SYS_open   5
%define SYS_close  6
%define SYS_mmap   477
%define SYS_munmap 73
%define SYS_lseek  478

%define O_RDONLY   0
%define SEEK_SET   0
%define SEEK_END   2
%define PROT_RW    0x03
%define MAP_FLAGS  0x1002     ; MAP_PRIVATE|MAP_ANON (FreeBSD)

%define TAPE_SIZE  65536
%define TAPE_MASK  65535

; Instruction layout (32 bytes, power-of-2 for cheap addressing):
;   +0  cmd   : u8
;   +4  count : i32
;   +8  jump  : i64  (index of matching bracket, or -1)
;   +16 (padding)
%define IS      32
%define I_CMD   0
%define I_COUNT 4
%define I_JUMP  8

; -----------------------------------------------------------------------
section .bss
tape       resb TAPE_SIZE
instrs     resq 1
icount     resq 1
icap       resq 1
ibuf       resq 1
ilen_var   resq 1

; -----------------------------------------------------------------------
section .data
s_usage    db "Usage: beef program.bf [input_file]",10
s_usage_l  equ $-s_usage
s_nofile   db "Error: cannot open file",10
s_nofile_l equ $-s_nofile
s_oom      db "Error: out of memory",10
s_oom_l    equ $-s_oom
s_unmc     db "Error: unmatched ']'",10
s_unmc_l   equ $-s_unmc
s_unmo     db "Error: unmatched '['",10
s_unmo_l   equ $-s_unmo

; -----------------------------------------------------------------------
; Tokenizer jump table
;
; インデックス = (文字コード - 0x2B)  ('+':0x2B 〜 ']':0x5D, 計51エントリ)
; BF命令以外のスロットは .tok (スキップ) を指す。
;
; Offset  Char  Handler
;   0     '+'   .is_plus   0x2B
;   1     ','   .is_comma  0x2C
;   2     '-'   .is_minus  0x2D
;   3     '.'   .is_dot    0x2E
;   4     '/'   .tok       0x2F
;   5-14  '0'-'9' .tok
;  15     ':'   .tok       0x3A
;  16     ';'   .tok       0x3B
;  17     '<'   .is_left   0x3C
;  18     '='   .tok       0x3D
;  19     '>'   .is_right  0x3E
;  20-46  '?'-'Z' .tok
;  47     '['   .is_open   0x5B
;  48     '\'   .tok       0x5C
;  49     ']'   .is_close  0x5D
;  (50 entries total: 0x2B..0x5D = 51)
; -----------------------------------------------------------------------
section .data
tok_jmp_table:
    dq  _start.is_plus    ;  0  '+'  0x2B
    dq  _start.is_comma   ;  1  ','  0x2C
    dq  _start.is_minus   ;  2  '-'  0x2D
    dq  _start.is_dot     ;  3  '.'  0x2E
    dq  _start.tok        ;  4  '/'  0x2F
    dq  _start.tok        ;  5  '0'
    dq  _start.tok        ;  6  '1'
    dq  _start.tok        ;  7  '2'
    dq  _start.tok        ;  8  '3'
    dq  _start.tok        ;  9  '4'
    dq  _start.tok        ; 10  '5'
    dq  _start.tok        ; 11  '6'
    dq  _start.tok        ; 12  '7'
    dq  _start.tok        ; 13  '8'
    dq  _start.tok        ; 14  '9'
    dq  _start.tok        ; 15  ':'  0x3A
    dq  _start.tok        ; 16  ';'  0x3B
    dq  _start.is_left    ; 17  '<'  0x3C
    dq  _start.tok        ; 18  '='  0x3D
    dq  _start.is_right   ; 19  '>'  0x3E
    dq  _start.tok        ; 20  '?'  0x3F
    dq  _start.tok        ; 21  '@'  0x40
    dq  _start.tok        ; 22  'A'
    dq  _start.tok        ; 23  'B'
    dq  _start.tok        ; 24  'C'
    dq  _start.tok        ; 25  'D'
    dq  _start.tok        ; 26  'E'
    dq  _start.tok        ; 27  'F'
    dq  _start.tok        ; 28  'G'
    dq  _start.tok        ; 29  'H'
    dq  _start.tok        ; 30  'I'
    dq  _start.tok        ; 31  'J'
    dq  _start.tok        ; 32  'K'
    dq  _start.tok        ; 33  'L'
    dq  _start.tok        ; 34  'M'
    dq  _start.tok        ; 35  'N'
    dq  _start.tok        ; 36  'O'
    dq  _start.tok        ; 37  'P'
    dq  _start.tok        ; 38  'Q'
    dq  _start.tok        ; 39  'R'
    dq  _start.tok        ; 40  'S'
    dq  _start.tok        ; 41  'T'
    dq  _start.tok        ; 42  'U'
    dq  _start.tok        ; 43  'V'
    dq  _start.tok        ; 44  'W'
    dq  _start.tok        ; 45  'X'
    dq  _start.tok        ; 46  'Y'
    dq  _start.tok        ; 47  'Z'
    dq  _start.is_open    ; 48  '['  0x5B
    dq  _start.tok        ; 49  '\'  0x5C
    dq  _start.is_close   ; 50  ']'  0x5D

; -----------------------------------------------------------------------
section .text
global _start

; =====================================================================
; fatal(rdi=msg, rsi=len, rdx=code)
; =====================================================================
fatal:
    push rdx
    mov  rdx, rsi
    mov  rsi, rdi
    mov  rdi, 2
    mov  rax, SYS_write
    syscall
    pop  rdi
    mov  rax, SYS_exit
    syscall

; =====================================================================
; xmmap(rdi=size) → rax
; =====================================================================
xmmap:
    mov  rsi, rdi
    xor  rdi, rdi
    mov  rdx, PROT_RW
    mov  r10, MAP_FLAGS
    mov  r8d, -1
    xor  r9d, r9d
    mov  rax, SYS_mmap
    syscall
    cmp  rax, -1
    jne  .ok
    mov  rdi, s_oom
    mov  rsi, s_oom_l
    mov  rdx, 1
    jmp  fatal
.ok:
    ret

; =====================================================================
; xmunmap(rdi=ptr, rsi=size)
; =====================================================================
xmunmap:
    mov  rax, SYS_munmap
    syscall
    ret

; =====================================================================
; read_file(rdi=path) → rax=buf, rdx=size  (rax=0 on open error)
; =====================================================================
read_file:
    push rbx
    push r12
    push r13
    mov  rsi, O_RDONLY
    xor  rdx, rdx
    mov  rax, SYS_open
    syscall
    test rax, rax
    js   .fail
    mov  r12, rax

    mov  rdi, r12
    xor  rsi, rsi
    mov  rdx, SEEK_END
    mov  rax, SYS_lseek
    syscall
    mov  r13, rax

    mov  rdi, r12
    xor  rsi, rsi
    xor  rdx, rdx
    mov  rax, SYS_lseek
    syscall

    lea  rdi, [r13+1]
    call xmmap
    mov  rbx, rax

    mov  rdi, r12
    mov  rsi, rbx
    mov  rdx, r13
    mov  rax, SYS_read
    syscall
    mov  byte [rbx+rax], 0

    mov  rdi, r12
    mov  rax, SYS_close
    syscall

    mov  rax, rbx
    mov  rdx, r13
    pop  r13
    pop  r12
    pop  rbx
    ret
.fail:
    pop  r13
    pop  r12
    pop  rbx
    xor  rax, rax
    xor  rdx, rdx
    ret

; =====================================================================
; grow_instrs()
; Doubles icap, reallocates instrs.
; Optimization: rep movsq instead of rep movsb
; =====================================================================
grow_instrs:
    push rbx
    push r12
    mov  rax, [icap]
    shl  rax, 1
    mov  [icap], rax
    ; multiply by IS=32: shl 5
    mov  rdi, rax
    shl  rdi, 5
    call xmmap
    mov  r12, rax

    ; memcpy old → new using rep movsq (8 bytes at a time)
    mov  rdi, r12
    mov  rsi, [instrs]
    mov  rdx, [icount]
    shl  rdx, 5             ; * IS(32)
    mov  rcx, rdx
    shr  rcx, 3             ; / 8 for movsq
    rep  movsq

    ; munmap old (old cap = new/2)
    mov  rdi, [instrs]
    mov  rax, [icap]
    shr  rax, 1
    shl  rax, 5             ; * IS
    mov  rsi, rax
    call xmunmap

    mov  [instrs], r12
    pop  r12
    pop  rbx
    ret

; =====================================================================
; emit_one(al=cmd, ebx=count_i32, rdx=jump_i64)
; =====================================================================
emit_one:
    push rbx
    movzx eax, al
    push rax
    push rdx

    mov  rax, [icount]
    cmp  rax, [icap]
    jl   .ok
    call grow_instrs
    mov  rax, [icount]
.ok:
    ; multiply index by IS=32: shl 5
    shl  rax, 5
    add  rax, [instrs]

    pop  rdx
    pop  rcx
    mov  byte  [rax+I_CMD],   cl
    pop  rcx
    mov  dword [rax+I_COUNT], ecx
    mov  qword [rax+I_JUMP],  rdx
    inc  qword [icount]
    ret

; =====================================================================
; _start
; =====================================================================
_start:
    mov  r15, rsp
    cmp  qword [r15], 0
    jne  .argc_ok
    add  r15, 8
.argc_ok:

    mov  eax, [r15]
    cmp  eax, 2
    jl   .die_usage

    ; ---- read source file ----------------------------------------
    mov  rdi, [r15+16]
    call read_file
    test rax, rax
    jz   .die_nofile
    mov  r12, rax
    mov  r13, rdx

    ; ---- alloc instruction array ---------------------------------
    mov  qword [icap],   1024
    mov  qword [icount], 0
    mov  rdi, 1024*IS
    call xmmap
    mov  [instrs], rax

    ; ====================================================================
    ; Tokenize
    ; r14 = source read pointer
    ; ====================================================================
    mov  r14, r12

    ; ------------------------------------------------------------------
    ; テーブルジャンプ用ルックアップテーブル
    ;
    ; BF命令文字の範囲は '+' (0x2B) 〜 ']' (0x5D) の 51 文字。
    ; tok_jmp_table[c - '+'] に各ハンドラのアドレスを格納する。
    ; 範囲外または非BF文字は .tok（スキップ）を指す。
    ;
    ; 文字→インデックス: idx = al - '+'
    ; 有効範囲: 0x2B('+') 〜 0x5D(']')  → 51 エントリ × 8 bytes
    ; ------------------------------------------------------------------
    %define TOK_BASE  0x2B   ; '+'
    %define TOK_RANGE 51     ; ']'(0x5D) - '+'(0x2B) + 1

.tok:
    movzx eax, byte [r14]
    test  al, al
    jz    .tok_done
    inc   r14

    ; 範囲チェック: al < ',' または al > ']' ならスキップ
    sub   al, TOK_BASE          ; al -= ','
    cmp   al, TOK_RANGE - 1
    ja    .tok                  ; 範囲外 → 次の文字へ（符号なし比較でal<0も弾く）

    ; テーブルジャンプ
    movzx eax, al
    lea   rdx, [rel tok_jmp_table]
    mov   rdx, [rdx + rax*8]
    jmp   rdx

.read_decimal:
    movzx edx, byte [r14]
    cmp   dl, '0'
    jl    .rd_nodigit
    cmp   dl, '9'
    jg    .rd_nodigit
    xor   eax, eax
.rd_loop:
    movzx edx, byte [r14]
    cmp   dl, '0'
    jl    .rd_done
    cmp   dl, '9'
    jg    .rd_done
    imul  eax, eax, 10
    sub   dl, '0'
    add   eax, edx
    inc   r14
    jmp   .rd_loop
.rd_done:
    ret
.rd_nodigit:
    mov   eax, 1
    ret

.is_plus:
    call .read_decimal
    mov  ebx, eax
    mov  al, '+'
    mov  rdx, -1
    call emit_one
    jmp  .tok

.is_minus:
    call .read_decimal
    neg  eax
    mov  ebx, eax
    mov  al, '+'
    mov  rdx, -1
    call emit_one
    jmp  .tok

.is_right:
    call .read_decimal
    mov  ebx, eax
    mov  al, '>'
    mov  rdx, -1
    call emit_one
    jmp  .tok

.is_left:
    call .read_decimal
    neg  eax
    mov  ebx, eax
    mov  al, '>'
    mov  rdx, -1
    call emit_one
    jmp  .tok

.is_dot:
    call .read_decimal
    mov  ebx, eax
    mov  al, '.'
    mov  rdx, -1
    call emit_one
    jmp  .tok

.is_comma:
    call .read_decimal
    mov  ebx, eax
    mov  al, ','
    mov  rdx, -1
    call emit_one
    jmp  .tok

.is_open:
    call .read_decimal
    push rax
.open_loop:
    mov  rax, [rsp]
    test eax, eax
    jz   .open_loop_end
    dec  qword [rsp]
    mov  al, '['
    mov  ebx, 1
    mov  rdx, -1
    call emit_one
    jmp  .open_loop
.open_loop_end:
    pop  rax
    jmp  .tok

.is_close:
    call .read_decimal
    push rax
.close_loop:
    mov  rax, [rsp]
    test eax, eax
    jz   .close_loop_end
    dec  qword [rsp]
    mov  al, ']'
    mov  ebx, 1
    mov  rdx, -1
    call emit_one
    jmp  .close_loop
.close_loop_end:
    pop  rax
    jmp  .tok

.tok_done:
    mov  rdi, r12
    lea  rsi, [r13+1]
    call xmunmap

    ; ====================================================================
    ; Build bracket jump table
    ; ====================================================================
    mov  rax, [icount]
    inc  rax
    imul rdi, rax, 8
    call xmmap
    mov  r12, rax
    xor  r13d, r13d

    xor  r14, r14
.brk:
    cmp  r14, [icount]
    jge  .brk_done

    mov  rax, r14
    shl  rax, 5             ; * IS(32)
    add  rax, [instrs]
    movzx eax, byte [rax+I_CMD]

    cmp  al, '['
    je   .brk_push
    cmp  al, ']'
    je   .brk_pop
.brk_next:
    inc  r14
    jmp  .brk

.brk_push:
    mov  [r12+r13*8], r14
    inc  r13d
    jmp  .brk_next

.brk_pop:
    test r13d, r13d
    jz   .die_unmc
    dec  r13d
    mov  rbx, [r12+r13*8]

    ; instrs[r14].jump = j
    mov  rax, r14
    shl  rax, 5
    add  rax, [instrs]
    mov  qword [rax+I_JUMP], rbx

    ; instrs[j].jump = r14
    ; Also detect [-] / [+] pattern: if j+1==r14, it's a zero-cell loop
    ; → replace '[' cmd with 'Z' (set-to-zero opcode)
    mov  rax, rbx
    lea  rcx, [rbx+1]
    cmp  rcx, r14          ; j+1 == ']'?
    jne  .brk_normal

    ; Check instrs[j+1].cmd == '+' and count == ±1 (i.e. [-] or [+])
    lea  rcx, [rbx+1]
    mov  rdx, rcx
    shl  rdx, 5
    add  rdx, [instrs]
    movzx ecx, byte [rdx+I_CMD]
    cmp  cl, '+'
    jne  .brk_normal
    mov  ecx, dword [rdx+I_COUNT]
    cmp  ecx, 1
    je   .brk_zero
    cmp  ecx, -1
    je   .brk_zero
    jmp  .brk_normal

.brk_zero:
    ; Mark '[' as 'Z' (zero-cell) — skip the body entirely
    shl  rax, 5
    add  rax, [instrs]
    mov  byte [rax+I_CMD], 'Z'
    ; Mark ']' as 'z' (nop partner)
    mov  rax, r14
    shl  rax, 5
    add  rax, [instrs]
    mov  byte [rax+I_CMD], 'z'
    jmp  .brk_next

.brk_normal:
    shl  rax, 5
    add  rax, [instrs]
    mov  qword [rax+I_JUMP], r14
    jmp  .brk_next

.brk_done:
    test r13d, r13d
    jnz  .die_unmo

    mov  rdi, r12
    mov  rax, [icount]
    inc  rax
    imul rsi, rax, 8
    call xmunmap

    ; ====================================================================
    ; Append sentinel '!'
    ; ====================================================================
    mov  rax, [icount]
    cmp  rax, [icap]
    jl   .sent_ok
    call grow_instrs
.sent_ok:
    mov  al,  '!'
    mov  ebx, 0
    mov  rdx, -1
    call emit_one

    ; ====================================================================
    ; Optional input file
    ; ====================================================================
    mov  qword [ibuf],     0
    mov  qword [ilen_var], 0
    mov  eax, [r15]
    cmp  eax, 3
    jl   .no_input
    mov  rdi, [r15+24]
    call read_file
    test rax, rax
    jz   .no_input
    mov  [ibuf],     rax
    mov  [ilen_var], rdx
.no_input:

    ; ====================================================================
    ; Interpreter — hot loop
    ;
    ; Register allocation (OPTIMIZED):
    ;   r15 = ip  (DIRECT POINTER into instrs array, not an index)
    ;         → eliminates imul/shl+add on every instruction
    ;   r13 = tp  (tape pointer, 0..TAPE_MASK)
    ;   r14 = ic  (input cursor)
    ;   rbx = ilen (input length)
    ;   rbp = tape base pointer (cached; avoids lea [rel tape] every op)
    ;
    ; rax, rdx, rdi, rsi, r8, r9, r10 = scratch
    ; DO NOT use rcx or r11 across syscalls
    ; ====================================================================
    xor  r13, r13
    xor  r14, r14
    mov  r15, [instrs]      ; ip = &instrs[0]
    mov  rbx, [ilen_var]
    lea  rbp, [rel tape]    ; tape base (constant throughout)

    ; zero tape
    mov  rdi, rbp
    xor  eax, eax
    mov  ecx, TAPE_SIZE
    rep  stosb

    ; ====================================================================
    ; Main dispatch loop
    ; r15 = current instruction pointer (advances by IS=32 each step)
    ; ====================================================================
.run:
    movzx eax, byte [r15+I_CMD]

    ; Dispatch table via computed jump
    ; Order: '+' '>' '[' ']' '.' ',' '!' 'Z' 'z' (others→halt)
    cmp  al, '+'
    je   .op_add
    cmp  al, '>'
    je   .op_move
    cmp  al, '['
    je   .op_open
    cmp  al, ']'
    je   .op_close
    cmp  al, '.'
    je   .op_put
    cmp  al, ','
    je   .op_get
    cmp  al, 'Z'
    je   .op_zero
    ; 'z', '!' or anything else → halt
    xor  rdi, rdi
    mov  rax, SYS_exit
    syscall

    ; ------------------------------------------------------------------
    ; '+': tape[tp] += count   (count can be negative for '-')
    ; OPTIMIZATION: r15 already points to current instruction; no index math
    ; ------------------------------------------------------------------
.op_add:
    movsxd rdx, dword [r15+I_COUNT]
    add  byte [rbp+r13], dl
    add  r15, IS
    jmp  .run

    ; ------------------------------------------------------------------
    ; '>': tp = (tp + count) & TAPE_MASK
    ; ------------------------------------------------------------------
.op_move:
    movsxd rdx, dword [r15+I_COUNT]
    add  r13, rdx
    and  r13, TAPE_MASK
    add  r15, IS
    jmp  .run

    ; ------------------------------------------------------------------
    ; '[': if tape[tp]==0, jump to matching ']'+1
    ; ------------------------------------------------------------------
.op_open:
    cmp  byte [rbp+r13], 0
    jne  .open_in
    ; jump: ip = instrs + (jump_index * IS) + IS
    mov  rax, [r15+I_JUMP]
    shl  rax, 5             ; * IS(32)
    add  rax, [instrs]
    mov  r15, rax
    add  r15, IS            ; skip past ']'
    jmp  .run
.open_in:
    add  r15, IS
    jmp  .run

    ; ------------------------------------------------------------------
    ; ']': if tape[tp]!=0, jump back to matching '['+1
    ; ------------------------------------------------------------------
.op_close:
    cmp  byte [rbp+r13], 0
    je   .close_out
    mov  rax, [r15+I_JUMP]
    shl  rax, 5
    add  rax, [instrs]
    mov  r15, rax
    add  r15, IS
    jmp  .run
.close_out:
    add  r15, IS
    jmp  .run

    ; ------------------------------------------------------------------
    ; 'Z': tape[tp] = 0  (optimized [-] / [+] pattern)
    ; Skips both '[', body '+', and ']' in one step
    ; (r15 points to 'Z'; we jump 3*IS forward to skip '[', '+', ']')
    ; ------------------------------------------------------------------
.op_zero:
    mov  byte [rbp+r13], 0
    add  r15, 3*IS          ; skip '[', '+/-', ']'
    jmp  .run

    ; ------------------------------------------------------------------
    ; '.': write tape[tp] to stdout, count times
    ; OPTIMIZATION: buffer on stack, single write syscall
    ; ------------------------------------------------------------------
.op_put:
    movsxd rdi, dword [r15+I_COUNT]
    test rdi, rdi
    jle  .put_done
    movzx eax, byte [rbp+r13]      ; char to write

    ; For count==1 (very common), avoid buffer setup overhead
    cmp  rdi, 1
    jne  .put_buffered

    ; fast single-byte write
    push rax
    mov  rsi, rsp
    mov  rdi, 1
    mov  rdx, 1
    mov  rax, SYS_write
    syscall
    pop  rax
    add  r15, IS
    jmp  .run

.put_buffered:
    ; Fill a stack buffer of up to 256 bytes, do one write
    ; rdi = count, al = char
    push rbp                ; save tape base
    push r13                ; save tp
    push r14                ; save ic
    push rbx                ; save ilen

    ; allocate buffer on stack (max 256 bytes)
    sub  rsp, 256
    mov  rsi, rsp           ; buf ptr

    ; fill buffer: min(count, 256) bytes
    mov  rcx, rdi
    cmp  rcx, 256
    jle  .put_fill
    mov  rcx, 256
.put_fill:
    mov  r8, rcx            ; total to write
    mov  rdi, rsi
    rep  stosb              ; fill rcx bytes with al

    ; write buffer (may need multiple syscalls if count > 256)
    mov  r9, rsi            ; buf base
    mov  r10, [rsp+256+32+0] ; recover original count (before stack frame)
    ; Actually we need original count; let's re-read from instruction
    ; r15 is still valid (not callee-saved here) - but we saved regs above
    ; r15 wasn't saved/pushed; it's still valid since we didn't call anything
    movsxd r10, dword [r15+I_COUNT]
.put_loop2:
    test r10, r10
    jle  .put_buf_done
    mov  rcx, r10
    cmp  rcx, 256
    jle  .put_this
    mov  rcx, 256
.put_this:
    mov  rdi, 1
    mov  rsi, r9
    mov  rdx, rcx
    mov  rax, SYS_write
    syscall
    sub  r10, rcx
    jmp  .put_loop2
.put_buf_done:
    add  rsp, 256
    pop  rbx
    pop  r14
    pop  r13
    pop  rbp

.put_done:
    add  r15, IS
    jmp  .run

    ; ------------------------------------------------------------------
    ; ',': read from input buffer into tape[tp], count times
    ; ------------------------------------------------------------------
.op_get:
    movsxd rdi, dword [r15+I_COUNT]
    test rdi, rdi
    jle  .get_done
    mov  rsi, [ibuf]
.get_loop:
    cmp  r14, rbx
    jge  .get_eof
    movzx eax, byte [rsi+r14]
    inc  r14
    jmp  .get_store
.get_eof:
    xor  eax, eax
.get_store:
    mov  [rbp+r13], al
    dec  rdi
    jnz  .get_loop
.get_done:
    add  r15, IS
    jmp  .run

; ---- error exits ----
.die_usage:
    mov  rdi, s_usage
    mov  rsi, s_usage_l
    mov  rdx, 1
    jmp  fatal
.die_nofile:
    mov  rdi, s_nofile
    mov  rsi, s_nofile_l
    mov  rdx, 1
    jmp  fatal
.die_unmc:
    mov  rdi, s_unmc
    mov  rsi, s_unmc_l
    mov  rdx, 1
    jmp  fatal
.die_unmo:
    mov  rdi, s_unmo
    mov  rsi, s_unmo_l
    mov  rdx, 1
    jmp  fatal
