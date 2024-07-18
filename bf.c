#include    <stdio.h>
#include    <stdlib.h>
#include    <malloc.h>
#include    "fsize.h"
void main(int argc,char *argv[]) {
    FILE *fp;
    char array[30000]={0},*ptr=array,*pp;
    int  loopstack[1000];
    int  lsp=0,c,idx;
    long len=0;

    if (argc!=2) {
        fprintf(stderr,"Usage %s <file>\n",argv[0]);
        exit(1);
    }

    fp=fopen(argv[1],"rt");
    len=fsize(fp);
    pp=malloc(len);
    idx=0;

    while((c=fgetc(fp))!=EOF)
            pp[idx++]=c;
    fclose(fp);

    idx=0;
    while(idx<len) {
        switch (c=pp[idx++]) {
            case '>':
                ptr++;
                break;
            case '<':
                ptr--;
                break;
            case '+':
                (*ptr)++;
                break;
            case '-':
                (*ptr)--;
                break;
            case '.':
                putchar(*ptr);
                break;
            case ',':
                *ptr=getchar();
                break;
            case '[':
                idx--;
                if (*ptr)
                    loopstack[lsp++]=idx++;
                else {
                    int nest=0;
                    while(idx<len)
                        if ((c=pp[idx++])=='[')
                            nest+=1;
                        else if (c==']')
                            if (--nest==0)
                                break;
                }
                break;
            case ']':
                idx=loopstack[--lsp];
                break;
            default:
            }
        }
    free(pp);
}

