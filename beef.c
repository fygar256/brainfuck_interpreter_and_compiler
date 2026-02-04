#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MEMORY_SIZE 30000
#define MAX_CODE_SIZE 1000000
#define MAX_INSTRUCTIONS 1000000

typedef struct {
    char cmd;
    int count;
} Instruction;

typedef struct {
    Instruction *instructions;
    int *bracket_map;
    int count;
    int capacity;
} Program;

// Read entire file into string
char *read_file(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "Error: Cannot open file '%s'\n", filename);
        return NULL;
    }
    
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    char *content = malloc(size + 1);
    if (!content) {
        fclose(f);
        return NULL;
    }
    
    size_t bytes_read = fread(content, 1, size, f);
    content[bytes_read] = '\0';
    fclose(f);
    
    return content;
}

// Read input file
char *read_input(const char *filename, int *input_len) {
    FILE *f = fopen(filename, "rb");
    if (!f) {
        *input_len = 0;
        return NULL;
    }
    
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    char *content = malloc(size + 1);
    if (!content) {
        fclose(f);
        *input_len = 0;
        return NULL;
    }
    
    size_t bytes_read = fread(content, 1, size, f);
    content[bytes_read] = '\0';
    *input_len = bytes_read;
    fclose(f);
    
    return content;
}

// Tokenize brainfuck code
Program *tokenize(const char *code) {
    Program *prog = malloc(sizeof(Program));
    prog->capacity = 1024;
    prog->count = 0;
    prog->instructions = malloc(sizeof(Instruction) * prog->capacity);
    prog->bracket_map = NULL;
    
    int i = 0;
    while (code[i]) {
        char cmd = code[i];
        
        // Check if it's a valid BF command
        if (strchr("+-<>.,[]", cmd)) {
            int count = 1;
            
            // All commands can now be compressed (including brackets)
            i++;
            // Check if there's a number following
            if (code[i] && isdigit(code[i])) {
                count = 0;
                while (code[i] && isdigit(code[i])) {
                    count = count * 10 + (code[i] - '0');
                    i++;
                }
            }
            // i is now at the next character to process
            i--;
            
            // For brackets, expand them into individual instructions
            // For other commands, keep them compressed
            int repeat = (cmd == '[' || cmd == ']') ? count : 1;
            int instr_count = (cmd == '[' || cmd == ']') ? 1 : count;
            
            for (int r = 0; r < repeat; r++) {
                // Expand capacity if needed
                if (prog->count >= prog->capacity) {
                    prog->capacity *= 2;
                    prog->instructions = realloc(prog->instructions, 
                                                sizeof(Instruction) * prog->capacity);
                }
                
                prog->instructions[prog->count].cmd = cmd;
                prog->instructions[prog->count].count = instr_count;
                prog->count++;
            }
        }
        
        i++;
    }
    
    return prog;
}

// Build jump table for brackets
int build_bracket_map(Program *prog) {
    prog->bracket_map = malloc(sizeof(int) * prog->count);
    memset(prog->bracket_map, -1, sizeof(int) * prog->count);
    
    int *stack = malloc(sizeof(int) * prog->count);
    int stack_top = 0;
    
    for (int i = 0; i < prog->count; i++) {
        if (prog->instructions[i].cmd == '[') {
            stack[stack_top++] = i;
        } else if (prog->instructions[i].cmd == ']') {
            if (stack_top == 0) {
                fprintf(stderr, "Error: Unmatched ']' at position %d\n", i);
                free(stack);
                return -1;
            }
            int j = stack[--stack_top];
            prog->bracket_map[i] = j;
            prog->bracket_map[j] = i;
        }
    }
    
    if (stack_top != 0) {
        fprintf(stderr, "Error: Unmatched '['\n");
        free(stack);
        return -1;
    }
    
    free(stack);
    return 0;
}

// Run the brainfuck program
void run_brainfuck(Program *prog, const char *input_stream, int input_len) {
    unsigned char memory[MEMORY_SIZE] = {0};
    int ptr = 0;
    int ip = 0;
    int input_ptr = 0;
    
    while (ip < prog->count) {
        Instruction instr = prog->instructions[ip];
        
        switch (instr.cmd) {
            case '+':
                memory[ptr] = (memory[ptr] + instr.count) % 256;
                ip++;
                break;
                
            case '-':
                memory[ptr] = (memory[ptr] - instr.count) % 256;
                ip++;
                break;
                
            case '>':
                ptr = (ptr + instr.count) % MEMORY_SIZE;
                ip++;
                break;
                
            case '<':
                ptr = (ptr - instr.count + MEMORY_SIZE * ((instr.count / MEMORY_SIZE) + 1)) % MEMORY_SIZE;
                ip++;
                break;
                
            case '.':
                for (int i = 0; i < instr.count; i++) {
                    putchar(memory[ptr]);
                }
                fflush(stdout);
                ip++;
                break;
                
            case ',':
                for (int i = 0; i < instr.count; i++) {
                    if (input_ptr < input_len) {
                        memory[ptr] = (unsigned char)input_stream[input_ptr++];
                    } else {
                        memory[ptr] = 0;
                    }
                }
                ip++;
                break;
                
            case '[':
                if (memory[ptr] == 0) {
                    ip = prog->bracket_map[ip] + 1;
                } else {
                    ip++;
                }
                break;
                
            case ']':
                if (memory[ptr] != 0) {
                    ip = prog->bracket_map[ip] + 1;
                } else {
                    ip++;
                }
                break;
        }
    }
}

void free_program(Program *prog) {
    if (prog) {
        free(prog->instructions);
        free(prog->bracket_map);
        free(prog);
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s program.bf [input_file]\n", argv[0]);
        return 1;
    }
    
    // Read program
    char *code = read_file(argv[1]);
    if (!code) {
        return 1;
    }
    
    // Tokenize
    Program *prog = tokenize(code);
    free(code);
    
    // Build bracket map
    if (build_bracket_map(prog) != 0) {
        free_program(prog);
        return 1;
    }
    
    // Read input if provided
    char *input_stream = NULL;
    int input_len = 0;
    if (argc > 2) {
        input_stream = read_input(argv[2], &input_len);
    }
    
    // Run
    run_brainfuck(prog, input_stream, input_len);
    
    // Cleanup
    free_program(prog);
    if (input_stream) {
        free(input_stream);
    }
    
    return 0;
}
