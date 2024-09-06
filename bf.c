#include    <stdio.h>
#include    <stdlib.h>
void main(int argc,char *argv[]) {
    FILE *fp;
    char prog[65536]={0},array[30000]={0},*ptr=array;
    int  loopstack[1000],lsp=0,idx,len;

    fp=fopen(argv[1],"rt");
    for(len=0; (prog[len]=fgetc(fp))!=EOF;len++);
    fclose(fp);

    for(idx=0;idx<len;idx++)
        switch (prog[idx]) {
            case '>': ptr++; break;
            case '<': ptr--; break;
            case '+': (*ptr)++; break;
            case '-': (*ptr)--; break;
            case '.': putchar(*ptr); break;
            case ',': *ptr=getchar(); break;
            case '[':
                if (*ptr)
                    loopstack[lsp++]=idx++;
                else for(int nest=0;idx<len;)
                        if (prog[idx++]=='[') nest++;
                        else if (prog[idx-1]==']')
                            if (!--nest) break;
                break;
            case ']': idx=loopstack[--lsp]; break;
            default:
            }
}
