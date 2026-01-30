#include    <stdio.h>
#include    <stdlib.h>
void main(int argc,char *argv[]) {
    FILE *fp;
    int  c;
    if (argc!=2) {
        fprintf(stderr,"Usage: %s <file>\n",argv[0]);
        exit(1);
    }
    fp=fopen(argv[1],"rt");
    while((c=fgetc(fp))!=EOF) {
        switch (c) {
            case '>':
                printf("inc p\n");
                break;
            case '<':
                printf("dec p\n");
                break;
            case '+':
                printf("inc *p\n");
                break;
            case '-':
                printf("dec *p\n");
                break;
            case '.':
                printf("output\n");
                break;
            case ',':
                printf("input\n");
                break;
            case '[':
                printf("while *p\n");
                break;
            case ']':
                printf("wend\n");
                break;
            case '\n':
                printf("eol\n");
                break
            default:
            }
    }
    fclose(fp);
    exit(0);
}

