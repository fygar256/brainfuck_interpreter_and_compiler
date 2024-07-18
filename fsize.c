#include    <stdio.h>
#include    <stdlib.h>
long fsize(FILE *fp) {
    long f=ftell(fp),g;
    if (f==-1L) return -1L;
    if (fseek(fp,0,SEEK_END)) return -1L;
    g=ftell(fp);
    if (fseek(fp,f,SEEK_SET)) return -1L;
    return g;
}
