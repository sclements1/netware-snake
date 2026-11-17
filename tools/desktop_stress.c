/* Native stress driver for the enhanced desktop domain and eaten-cell mask.
   Example (from repository root):
   cc -O1 -g -std=c11 -fsanitize=address,undefined -fno-omit-frame-pointer \
      -Icore core/nw_snake.c core/nw_desktop.c tools/desktop_stress.c -lm \
      -o /tmp/nw-desktop-stress && /tmp/nw-desktop-stress
*/
#include "nw_snake.h"
#include "nw_desktop.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc,char **argv) {
    int loops=argc>1?atoi(argv[1]):12000;
    if (loops<1 || loops>1000000) loops=12000;
    const nw_desktop_rect screens[]={{-1000,-500,1000,500},{0,-250,1000,500}};
    for (int size=0;size<3;size++) {
        nw_desktop_layout grid={0};
        assert(nw_desktop_build(screens,2,500,size,&grid));
        const size_t cells=(size_t)grid.columns*(size_t)grid.rows;
        nw_snake *s=nw_snake_create(grid.columns,grid.rows,42);
        assert(s && nw_snake_set_domain(s,grid.domain,cells));
        for (int i=0;i<loops;i++) {
            nw_snake_advance(s,i%101);
            int x=nw_snake_x(s),y=nw_snake_y(s);
            assert(x>=0 && x+1<grid.columns && y>=0 && y<grid.rows);
            assert(grid.domain[(size_t)y*grid.columns+x]);
            assert(grid.domain[(size_t)y*grid.columns+x+1]);
        }
        const uint8_t *visited=nw_snake_visited(s);
        for (size_t i=0;i<cells;i++) {
            if (!grid.domain[i]) {
                assert(!visited[i]);
                assert(nw_snake_frame(s,0)[i]==32);
                assert(nw_snake_frame(s,1)[i]==32);
            }
        }
        nw_desktop_dispose(&grid);
        /* ASan detects a borrowed/freed mask here; the snake owns its copy. */
        nw_snake_reset(s,7);
        for (size_t i=0;i<cells;i++) assert(!nw_snake_visited(s)[i]);
        for (int i=0;i<100;i++) nw_snake_advance(s,100);
        nw_snake_destroy(s);
    }
    printf("Desktop-domain stress PASS: %d passes, three cell sizes, copied domain survives layout disposal\n",
           3*(loops+100));
    return 0;
}
