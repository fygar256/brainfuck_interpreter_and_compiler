#include    <stdio.h>
#include    <stdlib.h>
#define MEMSIZE (30000)
void main(int argc,char *argv[]) {
    FILE *fp;
    char prog[6553600]={0},array[MEMSIZE]={0},*ptr=array;
    int  loopstack[1000],lsp=0,idx,len;

    fp=fopen(argv[1],"rt");
    for(len=0; (prog[len]=fgetc(fp))!=EOF;len++);
    fclose(fp);

    for(idx=0;idx<len;)
        switch (prog[idx++]) {
            case '>': ptr++;
                      if (ptr==&array[MEMSIZE]) ptr=array;
                      continue;
            case '+': (*ptr)++; continue;
            case '.': putchar(*ptr); continue;
            default: continue;
            }
}
