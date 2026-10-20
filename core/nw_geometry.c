#include "nw_geometry.h"
#include <math.h>
void nw_grid_for_view(double width,double height,int faithful,int wide,int size,int *columns,int *rows) {
    if (!columns || !rows)return;
    if (faithful) {*columns=80;*rows=25;return;}
    const int selected_rows=size==0?34:size==2?18:25;
    int selected_columns=80;
    if (wide && width>0 && height>0) {
        selected_columns=(int)floor((width/height)*(double)selected_rows*2.0);
        if (selected_columns<80)selected_columns=80;
        if (selected_columns>512)selected_columns=512;
    }
    *columns=selected_columns;*rows=selected_rows;
}
void nw_grid_metrics(double width,double height,int cols,int rows,double *cellw,double *cellh,double *x,double *y) {
    if (width<=0 || height<=0 || cols<=0 || rows<=0) {
        if(cellw)*cellw=0;
        if(cellh)*cellh=0;
        if(x)*x=0;
        if(y)*y=0;
        return;
    }
    const double h=fmin(height/(double)rows, 2.0*width/(double)cols);
    const double w=h*0.5;
    if(cellw)*cellw=w;
    if(cellh)*cellh=h;
    if(x)*x=(width-w*(double)cols)/2.0;
    if(y)*y=(height-h*(double)rows)/2.0;
}

void nw_grid_metrics_for_mode(double width,double height,int cols,int rows,int faithful,
                              double *cellw,double *cellh,double *x,double *y) {
    if (!faithful) {
        nw_grid_metrics(width,height,cols,rows,cellw,cellh,x,y);
        return;
    }
    if (width<=0 || height<=0 || cols<=0 || rows<=0) {
        if(cellw)*cellw=0;
        if(cellh)*cellh=0;
        if(x)*x=0;
        if(y)*y=0;
        return;
    }
    /* Model a 640x480 VGA picture inside any display size. The historical
       80x25 glyph raster is 80*8 by 25*16 = 640x400, so it sits centered
       within the VGA viewport with 40 virtual scanlines of black at top
       and bottom. This intentionally favors a consistent 4:3 presentation
       over extending or stretching the snake into physical widescreen. */
    const double scale=fmin(width/640.0,height/480.0);
    const double viewport_x=(width-640.0*scale)*0.5;
    const double viewport_y=(height-480.0*scale)*0.5;
    if(cellw)*cellw=(640.0*scale)/(double)cols;
    if(cellh)*cellh=(400.0*scale)/(double)rows;
    if(x)*x=viewport_x;
    if(y)*y=viewport_y+40.0*scale;
}
