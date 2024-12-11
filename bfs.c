#include    <stdio.h>
#include    <stdlib.h>
static int loopstack[1000];
static int lsp=0;

void lsout() {
    for (int i=0;i<lsp;i++)
        printf("%d_",loopstack[i]);
}

void main(int argc,char *argv[]) {
    FILE *fp;
    int  c,lf;
    if (argc!=2) {
        fprintf(stderr,"Usage: bfs <file>\n");
        exit(1);
    }
    fp=fopen(argv[1],"rt");
    if (fp==NULL) {
        fprintf(stderr,"File open error.\n");
        exit(1);
    }

	printf("\t.section .text\n");
	printf("\t.globl _start\n");
    printf("_start:\n");
    printf("\tmovabs $_my_data,%%rsi\n");
    printf("\tmov\t$1,%%edx\n");

    lsp=0;
    lf='[';
    while((c=fgetc(fp))!=EOF) {
        switch (c) {
            case '>':
                printf("\tinc\t%%rsi\n");
                break;
            case '<':
                printf("\tdec\t%%rsi\n");
                break;
            case '+':
				printf("\tincb\t(%%rsi)\n");
                break;
            case '-':
				printf("\tdecb\t(%%rsi)\n");
                break;
            case '.':
				printf("\tmov\t%%edx,%%eax\n");
				printf("\tmov\t%%edx,%%ebx\n");
				printf("\tsyscall\n");
                break;
            case ',':
				printf("\txor\t%%eax, %%eax\n");
				printf("\txor\t%%ebx, %%ebx\n");
				printf("\tsyscall\n");
                break;
            case '[':
                if (lf==']')
                    loopstack[(lsp-1)]++;
                else
                    loopstack[lsp++]=1;
                lf='[';
                printf("\tjmp LE"); lsout(); printf("\n");
                printf("LB"); lsout(); printf(":\n");
                break;
            case ']':
                if (lf==']')
                    lsp--;
                lf=']';
                printf("LE"); lsout(); printf(":\n");
	            printf("\tcmp\t%%dh,(%%rsi)\n");
                printf("\tjne\tLB"); lsout(); printf("\n");
                break;
            default:
            }
    }
    fclose(fp);
    printf("\tmov\t$1,%%eax\n");
    printf("\txor\t%%ebx,%%ebx\n");
    printf("\tint $0x80\n");
    printf(".section .bss\n");
    printf("_my_data: .zero 65536\n");
    exit(0);
}
