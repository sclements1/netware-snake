#ifndef NW_DESKTOP_H
#define NW_DESKTOP_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Display rectangles use global top-left coordinates in points. Coordinates
   may be negative; width/height must be finite and positive. */
typedef struct { double x, y, width, height; } nw_desktop_rect;
typedef struct {
    nw_desktop_rect bounds;
    double origin_x, origin_y, cell_width, cell_height;
    int columns, rows;
    uint8_t *domain;
} nw_desktop_layout;
/* One uniform 1:2 character grid across the display union. Cell height starts
   at reference_height / (34,25,18) for sizes 0,1,2, adjusted only for grid
   limits (40x14 through 4096x2048). Grid is centered within the bounding box.
   A cell belongs to the domain if its center lies on any physical display;
   adjoining displays therefore share a passable seam and holes stay absent.
   Returns 1 on success, owning columns*rows domain bytes. Invalid rectangles,
   impossible aspect ratio, empty union or allocation failure return 0 and
   leave out unchanged. Dispose a previous result before replacing it. */
int nw_desktop_build(const nw_desktop_rect *rects, size_t count,
                     double reference_height, int size, nw_desktop_layout *out);
void nw_desktop_dispose(nw_desktop_layout *layout);
#ifdef __cplusplus
}
#endif
#endif
