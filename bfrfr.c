#include    <stdio.h>
#include    <stdlib.h>
#define MEMSIZE (30000)
void main(int argc,char *argv[]) {
    FILE *fp;
    char prog[6553600]={0},a=0;
    int  idx,len;

    fp=fopen(argv[1],"rt");
    for(len=0; (prog[len]=fgetc(fp))!=EOF;len++);
    fclose(fp);

    for(idx=0;idx<len;)
        switch (prog[idx++]) {
            case '+': a++; continue;
            case '.': putchar(a); continue;
            }
}

