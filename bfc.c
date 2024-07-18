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
    printf("#include    <stdio.h>\n");
    printf("void main() {\n");
    printf("char array[30000]={0};\n");
    printf("char *ptr=array;\n");
    while((c=fgetc(fp))!=EOF) {
        switch (c) {
            case '>':
                printf("ptr++; ");
                break;
            case '<':
                printf("ptr--; ");
                break;
            case '+':
                printf("(*ptr)++; ");
                break;
            case '-':
                printf("(*ptr)--; ");
                break;
            case '.':
                printf("putchar(*ptr); ");
                break;
            case ',':
                printf("*ptr=getchar(); ");
                break;
            case '[':
                printf("while(*ptr){ ");
                break;
            case ']':
                printf("} ");
                break;
            default:
            }
    }
    fclose(fp);
    printf("}\n");
    exit(0);
}

