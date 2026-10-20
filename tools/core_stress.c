#include "nw_snake.h"
#include "nw_geometry.h"
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <stdlib.h>

static uint64_t hash_frames(const nw_snake *s) {
    uint64_t h=UINT64_C(14695981039346656037);
    const int length=nw_snake_columns(s)*nw_snake_rows(s);
    const uint8_t *screen=nw_snake_frame(s,0);
    for(int i=0;i<length;i++) {h^=screen[i];h*=UINT64_C(1099511628211);}
    return h;
}
int main(int argc,char **argv) {
    int loops=argc>1?atoi(argv[1]):250000;
    if(loops<1)loops=250000;
    const int dims[][2]={{80,25},{90,25},{178,25},{120,34},{80,18}};
    uint64_t signature=0;
    const clock_t t0=clock();
    for(int d=0;d<5;d++) {
        nw_snake *s=nw_snake_create(dims[d][0],dims[d][1],42+(uint32_t)d);
        assert(s);
        for(int i=0;i<loops;i++) {
            const int cpu=(i*977+(i/41)*9)%101;
            nw_snake_advance(s,cpu);
            assert(nw_snake_x(s)>=0 && nw_snake_x(s)<=dims[d][0]-2);
            assert(nw_snake_y(s)>=0 && nw_snake_y(s)<dims[d][1]);
        }
        signature^=hash_frames(s);
        nw_snake_destroy(s);
    }
    const double secs=(double)(clock()-t0)/(double)CLOCKS_PER_SEC;
    printf("Stress OK: %d passes across %d geometries, elapsed %.3f CPU seconds, checksum %016llx\n",
           5*loops,5,secs,(unsigned long long)signature);
    return 0;
}
