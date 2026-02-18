; beef.asm  –  Brainfuck interpreter, FreeBSD x86-64
;
; Build:
;   nasm -f elf64 beef.asm -o beef.o
;   ld -o beef beef.o
;
; FreeBSD amd64 syscall ABI:
;   number→rax, args→rdi rsi rdx r10 r8 r9
;   return→rax; SYSCALL clobbers rcx and r11 (saves RIP/RFLAGS there)
;
; IMPORTANT: Never use rcx or r11 across a syscall or call boundary
; unless saved/restored explicitly.
;
; Syscall numbers (FreeBSD 13/14 amd64):
;   exit=1 read=3 write=4 open=5 close=6 mmap=477 munmap=73 lseek=478

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
%define TAPE_S     65535

; Instruction layout (24 bytes):
;   +0  cmd   : u8   ('+' '>' '[' ']' '.' ',' '!')
;   +4  count : i32
;   +8  jump  : i64  (index of matching bracket)
%define IS      24
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
; Clobbers: rax rsi rdx r10 r8 r9 rcx r11 (syscall)
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
; Clobbers: rax rcx r11 (syscall)
; =====================================================================
xmunmap:
    mov  rax, SYS_munmap
    syscall
    ret

; =====================================================================
; read_file(rdi=path) → rax=buf, rdx=size  (rax=0 on open error)
; Returns size in rdx (not rcx, to avoid syscall clobber confusion)
; Preserves: rbx r12 r13 r14 r15
; Clobbers: rax rcx rdx rdi rsi r8 r9 r10 r11
; =====================================================================
read_file:
    push rbx
    push r12
    push r13
    ; open(path, O_RDONLY, 0)
    mov  rsi, O_RDONLY
    xor  rdx, rdx
    mov  rax, SYS_open
    syscall
    test rax, rax
    js   .fail
    mov  r12, rax           ; fd

    ; lseek(fd, 0, SEEK_END) → size
    mov  rdi, r12
    xor  rsi, rsi
    mov  rdx, SEEK_END
    mov  rax, SYS_lseek
    syscall
    mov  r13, rax           ; size

    ; lseek(fd, 0, SEEK_SET)
    mov  rdi, r12
    xor  rsi, rsi
    xor  rdx, rdx
    mov  rax, SYS_lseek
    syscall

    ; alloc buf (size+1)
    lea  rdi, [r13+1]
    call xmmap
    mov  rbx, rax           ; buf

    ; read(fd, buf, size)
    mov  rdi, r12
    mov  rsi, rbx
    mov  rdx, r13
    mov  rax, SYS_read
    syscall
    mov  byte [rbx+rax], 0  ; NUL-terminate

    ; close(fd)
    mov  rdi, r12
    mov  rax, SYS_close
    syscall

    mov  rax, rbx
    mov  rdx, r13           ; return size in rdx
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
; Preserves: rbx r12 r13 r14 r15
; Clobbers: rax rcx rdx rdi rsi r8 r9 r10 r11
; =====================================================================
grow_instrs:
    push rbx
    push r12
    mov  rax, [icap]
    shl  rax, 1
    mov  [icap], rax
    imul rdi, rax, IS
    call xmmap              ; → rax = new buf
    mov  r12, rax           ; save new buf

    ; memcpy old → new
    mov  rdi, r12
    mov  rsi, [instrs]
    mov  rdx, [icount]
    imul rdx, IS
    ; copy rdx bytes: use rep movsb (rcx = count)
    mov  rcx, rdx
    rep  movsb

    ; munmap old (old cap = new/2)
    mov  rdi, [instrs]
    mov  rax, [icap]
    shr  rax, 1
    imul rsi, rax, IS
    call xmunmap

    mov  [instrs], r12
    pop  r12
    pop  rbx
    ret

; =====================================================================
; emit_one(al=cmd, ebx=count_i32, rdx=jump_i64)
;
; Appends exactly ONE instruction to the array.
; Uses ebx for count to keep it in a callee-saved register.
; Preserves: rbx r12 r13 r14 r15
; (ebx is the count argument itself - caller must save if needed)
; Clobbers: rax rcx rdx rdi rsi r8 r9 r10 r11
; =====================================================================
emit_one:
    ; Save cmd and count on stack (syscall-safe)
    push rbx                ; count (ebx) stays on stack
    movzx eax, al
    push rax                ; cmd on stack
    push rdx                ; jump on stack

    ; grow if needed
    mov  rax, [icount]
    cmp  rax, [icap]
    jl   .ok
    call grow_instrs
    mov  rax, [icount]
.ok:
    imul rax, IS
    add  rax, [instrs]      ; rax → slot

    pop  rdx                ; jump
    pop  rcx                ; cmd
    mov  byte  [rax+I_CMD],   cl
    pop  rcx                ; count (was ebx)
    mov  dword [rax+I_COUNT], ecx
    mov  qword [rax+I_JUMP],  rdx
    inc  qword [icount]
    ret

; =====================================================================
; _start
; =====================================================================
_start:
    ; FreeBSD amd64 の _start 時点のスタックレイアウト:
    ; ALSRのスタックランダム化により、rspが16バイトアラインの場合と
    ; 8バイトずれの場合がある。
    ; 8バイトずれの場合: [rsp]=0 (fake return addr), [rsp+8]=argc
    ; 16バイトアラインの場合: [rsp]=argc (return addr無し)
    ; → [rsp]==0 なら rsp を 8 進めて argc を正しく読む
    mov  r15, rsp
    cmp  qword [r15], 0
    jne  .argc_ok
    add  r15, 8             ; fake return address をスキップ
.argc_ok:

    mov  eax, [r15]
    cmp  eax, 2
    jl   .die_usage

    ; ---- read source file ----------------------------------------
    mov  rdi, [r15+16]
    call read_file
    test rax, rax
    jz   .die_nofile
    mov  r12, rax           ; src buf
    mov  r13, rdx           ; src size

    ; ---- alloc instruction array ---------------------------------
    mov  qword [icap],   1024
    mov  qword [icount], 0
    mov  rdi, 1024*IS
    call xmmap
    mov  [instrs], rax

    ; ====================================================================
    ; Tokenize
    ;
    ; r14 = source read pointer
    ;
    ; Register use during tokenize:
    ;   r12 = src buf (for later munmap)
    ;   r13 = src size (for later munmap)
    ;   r14 = src read pointer
    ;   r15 = original rsp (argv)
    ;
    ; All other regs (rax,rbx,rcx,rdx,rdi,rsi,r8,r9,r10,r11) are scratch.
    ; We must NOT use r11 or rcx to hold values across calls/syscalls.
    ;
    ; For emit_one: count goes in ebx (callee-saved by emit_one's push rbx,
    ; but caller still sees rbx clobbered after return – we reload as needed).
    ; ====================================================================
    mov  r14, r12           ; src pointer

.tok:
    movzx eax, byte [r14]
    test  al, al
    jz    .tok_done
    inc   r14               ; advance past command char

    cmp  al, '+'
    je   .is_plus
    cmp  al, '-'
    je   .is_minus
    cmp  al, '>'
    je   .is_right
    cmp  al, '<'
    je   .is_left
    cmp  al, '.'
    je   .is_dot
    cmp  al, ','
    je   .is_comma
    cmp  al, '['
    je   .is_open
    cmp  al, ']'
    je   .is_close
    jmp  .tok

    ; ------------------------------------------------------------------
    ; read_decimal: read optional digits from [r14], advance r14.
    ; Result returned in eax (≥1 if no digits: returns 1).
    ; Preserves: rbx r12 r13 r14(advances) r15
    ; Clobbers: rax (result), rdx
    ; Does NOT use rcx or r11.
    ; ------------------------------------------------------------------
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

    ; ------------------------------------------------------------------
    ; Plain commands
    ; ------------------------------------------------------------------
.is_plus:
    call .read_decimal      ; eax = count
    mov  ebx, eax           ; count in ebx
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

    ; ------------------------------------------------------------------
    ; Brackets: emit `count` copies, each with count=1
    ; Loop counter kept on stack (safe across syscalls).
    ; ------------------------------------------------------------------
.is_open:
    call .read_decimal      ; eax = repeat count
    push rax                ; loop counter on stack
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

    ; ====================================================================
.tok_done:
    ; free source buffer
    mov  rdi, r12
    lea  rsi, [r13+1]
    call xmunmap

    ; ====================================================================
    ; Build bracket jump table
    ; Stack of open-bracket indices: (icount+1)*8 bytes
    ; ====================================================================
    mov  rax, [icount]
    inc  rax
    imul rdi, rax, 8
    call xmmap
    mov  r12, rax           ; bracket stack base
    xor  r13d, r13d         ; stack depth

    xor  r14, r14           ; instruction index i
.brk:
    cmp  r14, [icount]
    jge  .brk_done

    mov  rax, r14
    imul rax, IS
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
    mov  rbx, [r12+r13*8]  ; j = matching '[' index

    ; instrs[r14].jump = j
    mov  rax, r14
    imul rax, IS
    add  rax, [instrs]
    mov  qword [rax+I_JUMP], rbx

    ; instrs[j].jump = r14
    mov  rax, rbx
    imul rax, IS
    add  rax, [instrs]
    mov  qword [rax+I_JUMP], r14

    jmp  .brk_next

.brk_done:
    test r13d, r13d
    jnz  .die_unmo

    ; free bracket stack
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
    call read_file          ; → rax=buf, rdx=size
    test rax, rax
    jz   .no_input
    mov  [ibuf],     rax
    mov  [ilen_var], rdx
.no_input:

    ; ====================================================================
    ; Interpreter
    ;
    ; r12 = ip    (instruction index)
    ; r13 = tp    (tape pointer, 0..TAPE_SIZE-1)
    ; r14 = ic    (input cursor)
    ; r15 = ibase (instrs array base pointer)
    ; rbx = ilen  (input length)
    ;
    ; rax, rdx, rdi, rsi, r8, r9, r10 = scratch (per instruction)
    ; DO NOT use rcx or r11 as persistent values (syscall clobbers them)
    ; ====================================================================
    xor  r12, r12
    xor  r13, r13
    xor  r14, r14
    mov  r15, [instrs]
    mov  rbx, [ilen_var]

    ; zero tape
    lea  rdi, [rel tape]
    xor  eax, eax
    mov  ecx, TAPE_SIZE
    rep  stosb

.run:
    mov  rax, r12
    imul rax, IS
    add  rax, r15           ; rax = &instrs[ip]

    movzx eax, byte [rax+I_CMD]
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
    ; '!' → halt
    xor  rdi, rdi
    mov  rax, SYS_exit
    syscall

.op_add:
    ; reload full instruction ptr (eax was overwritten by cmd)
    mov  rax, r12
    imul rax, IS
    add  rax, r15
    movsxd rdx, dword [rax+I_COUNT]
    lea  rdi, [rel tape]
    add  byte [rdi+r13], dl
    inc  r12
    jmp  .run

.op_move:
    mov  rax, r12
    imul rax, IS
    add  rax, r15
    movsxd rdx, dword [rax+I_COUNT]
    add  r13, rdx
    and  r13, TAPE_S   ; modulo 65536
    inc  r12
    jmp  .run

.op_open:
    mov  rax, r12
    imul rax, IS
    add  rax, r15
    lea  rdi, [rel tape]
    cmp  byte [rdi+r13], 0
    jne  .open_in
    mov  r12, [rax+I_JUMP]
    inc  r12
    jmp  .run
.open_in:
    inc  r12
    jmp  .run

.op_close:
    mov  rax, r12
    imul rax, IS
    add  rax, r15
    lea  rdi, [rel tape]
    cmp  byte [rdi+r13], 0
    je   .close_out
    mov  r12, [rax+I_JUMP]
    inc  r12
    jmp  .run
.close_out:
    inc  r12
    jmp  .run

.op_put:
    mov  rax, r12
    imul rax, IS
    add  rax, r15
    lea  rdi, [rel tape]
    movzx esi, byte [rdi+r13]      ; char to write
    movsxd rdi, dword [rax+I_COUNT]
    test rdi, rdi
    jle  .put_done
    push rsi                        ; char on stack
    mov  rsi, rsp                   ; rsi → char
.put_loop:
    push rdi
    mov  rdi, 1
    mov  rdx, 1
    mov  rax, SYS_write
    syscall
    pop  rdi
    dec  rdi
    jnz  .put_loop
    pop  rsi
.put_done:
    inc  r12
    jmp  .run

.op_get:
    mov  rax, r12
    imul rax, IS
    add  rax, r15
    movsxd rdi, dword [rax+I_COUNT]
    test rdi, rdi
    jle  .get_done
    mov  rsi, [ibuf]                ; input buffer base
.get_loop:
    cmp  r14, rbx
    jge  .get_eof
    movzx eax, byte [rsi+r14]
    inc  r14
    jmp  .get_store
.get_eof:
    xor  eax, eax
.get_store:
    lea  rdx, [rel tape]
    mov  [rdx+r13], al
    dec  rdi
    jnz  .get_loop
.get_done:
    inc  r12
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
