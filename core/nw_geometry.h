#ifndef NW_GEOMETRY_H
#define NW_GEOMETRY_H
/* Cross-platform text-grid layout. Core movement and drawing remain separate. */
#ifdef __cplusplus
extern "C" {
#endif
/* size: 0=small cells, 1=standard, 2=large cells. Aspect of CP437 cells is
   8:16. Widescreen adds columns at the same cell proportions, no stretching. */
void nw_grid_for_view(double width, double height, int faithful, int wide,
                      int size, int *columns, int *rows);
/* Compute aspect-preserving cell dimensions and letterbox offsets. */
void nw_grid_metrics(double view_width, double view_height, int columns, int rows,
                     double *cell_width, double *cell_height,
                     double *offset_x, double *offset_y);
/* Faithful mode uses a 640x480 logical VGA canvas (4:3) with the 80x25,
   8x16-cell raster centered within it (640x400 + 40 blank scanlines each
   side vertically). Scale the entire logical VGA viewport uniformly to
   fit the target view. Non-faithful mode retains its original cell metrics. */
void nw_grid_metrics_for_mode(double view_width, double view_height,
                              int columns, int rows, int faithful,
                              double *cell_width, double *cell_height,
                              double *offset_x, double *offset_y);

#ifdef __cplusplus
}
#endif
#endif

