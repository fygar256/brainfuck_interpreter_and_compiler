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

    printf("\t.file\t\"%s\"\n",argv[1]);
	printf("\t.text\n");
	printf("\t.globl\tmain\n");
	printf("\t.type\tmain,@function\n");
    printf("main:\n");
    printf(".LFB0:\n");
    printf("\t.cfi_startproc\n");
	printf("\tpushq\t%%rbp\n");
	printf("\t.cfi_def_cfa_offset 16\n");
	printf("\t.cfi_offset 6, -16\n");
	printf("\tmovq\t%%rsp, %%rbp\n");
	printf("\t.cfi_def_cfa_register 6\n");
	printf("\tsubq\t$30032, %%rsp\n");
	printf("\tmovq\t%%fs:40, %%rax\n");
	printf("\tmovq\t%%rax, -8(%%rbp)\n");
	printf("\txorl\t%%eax, %%eax\n");
	printf("\tleaq\t-30016(%%rbp), %%rax\n");
	printf("\tmovl\t$30000, %%edx\n");
	printf("\tmovl\t$0, %%esi\n");
	printf("\tmovq\t%%rax, %%rdi\n");
	printf("\tcall\tmemset@PLT\n");
	printf("\tleaq\t-30016(%%rbp), %%rax\n");
	printf("\tmovq\t%%rax, -30024(%%rbp)\n");

    lsp=0;
    lf='[';
    while((c=fgetc(fp))!=EOF) {
        switch (c) {
            case '>':
                printf("\taddq\t$1, -30024(%%rbp)\n");
                break;
            case '<':
                printf("\tsubq\t$1, -30024(%%rbp)\n");
                break;
            case '+':
				printf("\tmovq\t-30024(%%rbp), %%rax\n");
				printf("\tmovzbl\t(%%rax), %%eax\n");
				printf("\taddl\t$1, %%eax\n");
				printf("\tmovl\t%%eax, %%edx\n");
				printf("\tmovq\t-30024(%%rbp), %%rax\n");
				printf("\tmovb\t%%dl, (%%rax)\n");
                break;
            case '-':
				printf("\tmovq\t-30024(%%rbp), %%rax\n");
				printf("\tmovzbl\t(%%rax), %%eax\n");
				printf("\tsubl\t$1, %%eax\n");
				printf("\tmovl\t%%eax, %%edx\n");
				printf("\tmovq\t-30024(%%rbp), %%rax\n");
				printf("\tmovb\t%%dl, (%%rax)\n");
                break;
            case '.':
				printf("\tmovq\t-30024(%%rbp), %%rax\n");
				printf("\tmovzbl\t(%%rax), %%eax\n");
				printf("\tmovsbl\t%%al, %%eax\n");
				printf("\tmovl\t%%eax, %%edi\n");
				printf("\tcall\tputchar@PLT\n");
                break;
            case ',':
				printf("\tcall	getchar@PLT\n");
				printf("\tmovl	%%eax, %%edx\n");
				printf("\tmovq	-30024(%%rbp), %%rax\n");
				printf("\tmovb	%%dl, (%%rax)\n");
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
                printf("\tmovq\t-30024(%%rbp), %%rax\n");
	            printf("\tmovzbl\t(%%rax), %%eax\n");
	            printf("\ttestb\t%%al, %%al\n");
                printf("\tjne\tLB"); lsout(); printf("\n");
                break;
            default:
            }
    }
    fclose(fp);
	printf("\tnop\n");
	printf("\tmovq\t-8(%%rbp), %%rax\n");
	printf("\tsubq\t%%fs:40, %%rax\n");
	printf("\tje\t.LFE1\n");
	printf("\tcall\t__stack_chk_fail@PLT\n");
	printf(".LFE1:\n");
	printf("\tleave\n");
	printf("\t.cfi_def_cfa 7, 8\n");
	printf("\tret\n");
	printf("\t.cfi_endproc\n");
	printf(".LFE0:\n");
	printf("\t.size\tmain, .-main\n");
	printf("\t.section\t.note.GNU-stack,\"\",@progbits\n");
    exit(0);
}
