#include "nw_desktop.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

int nw_desktop_build(const nw_desktop_rect *rects,size_t count,
                     double reference_height,int size,nw_desktop_layout *out) {
    if (!rects || !out || !count || count>1024 || !isfinite(reference_height) ||
        reference_height<=0 || size<0 || size>2) return 0;
    double left=0,top=0,right=0,bottom=0;
    for (size_t i=0;i<count;i++) {
        const nw_desktop_rect r=rects[i];
        if (!isfinite(r.x) || !isfinite(r.y) || !isfinite(r.width) || !isfinite(r.height) ||
            r.width<=0 || r.height<=0 || !isfinite(r.x+r.width) || !isfinite(r.y+r.height) ||
            r.x+r.width<=r.x || r.y+r.height<=r.y) return 0;
        if (!i) {left=r.x;top=r.y;right=r.x+r.width;bottom=r.y+r.height;}
        else {
            left=fmin(left,r.x);top=fmin(top,r.y);
            right=fmax(right,r.x+r.width);bottom=fmax(bottom,r.y+r.height);
        }
    }
    const double width=right-left,height=bottom-top;
    if (!isfinite(width) || !isfinite(height) || width<=0 || height<=0) return 0;
    /* Choose a common physical cell size, rather than independently fitting
       each display. Limits scale cells uniformly and never stretch glyphs. */
    const double low=fmax(2.0*width/4096.0,height/2048.0);
    const double high=fmin(2.0*width/40.0,height/14.0);
    if (!isfinite(low) || !isfinite(high) || low<=0 || high<low) return 0;
    const int target_rows=size==0?34:size==2?18:25;
    double cellh=reference_height/(double)target_rows;
    cellh=fmax(low,fmin(high,cellh));
    const double cellw=cellh*0.5;
    if (!isfinite(cellw) || cellw<=0) return 0;
    /* A small tolerance prevents exact integral dimensions losing a cell
       through floating-point division (e.g. 1080/(1080/25)). */
    int cols=(int)floor(width/cellw+1e-9),rows=(int)floor(height/cellh+1e-9);
    if (cols<40 || rows<14 || cols>4096 || rows>2048) return 0;
    const size_t cells=(size_t)cols*(size_t)rows;
    uint8_t *mask=calloc(cells,1);
    if (!mask) return 0;
    nw_desktop_layout result={0};
    result.bounds=(nw_desktop_rect){left,top,width,height};
    result.origin_x=left+(width-cols*cellw)*0.5;
    result.origin_y=top+(height-rows*cellh)*0.5;
    result.cell_width=cellw;result.cell_height=cellh;
    result.columns=cols;result.rows=rows;result.domain=mask;
    int pair_found=0;
    for (int y=0;y<rows;y++) for (int x=0;x<cols;x++) {
        double cx=result.origin_x+(x+0.5)*cellw;
        double cy=result.origin_y+(y+0.5)*cellh;
        for (size_t i=0;i<count;i++) if (cx>=rects[i].x && cx<rects[i].x+rects[i].width &&
            cy>=rects[i].y && cy<rects[i].y+rects[i].height) {
            size_t p=(size_t)y*(size_t)cols+(size_t)x;
            mask[p]=1;
            if (x && mask[p-1]) pair_found=1;
            break;
        }
    }
    if (!pair_found) {free(mask);return 0;}
    *out=result;
    return 1;
}

void nw_desktop_dispose(nw_desktop_layout *layout) {
    if (!layout) return;
    free(layout->domain);
    memset(layout,0,sizeof *layout);
}
