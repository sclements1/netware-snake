#ifndef NW_SNAKE_H
#define NW_SNAKE_H
/* Portable C11 NetWare 3.12 MONITOR.NLM snake state machine.
   No OS, UI, clock, or telemetry dependencies. */
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef struct nw_snake nw_snake;
enum { NW_SNAKE_FAITHFUL_COLUMNS = 80, NW_SNAKE_FAITHFUL_ROWS = 25,
       NW_SNAKE_HISTORY = 51, NW_SNAKE_HZ_NUM = 182, NW_SNAKE_HZ_DEN = 10 };
enum { NW_FRAME_CHANGED = 1, NW_PROTECTED_CHANGED = 2, NW_HEAD_MOVED = 4,
       NW_VISITED_CHANGED = 8 };
/* Return NULL if dimensions invalid or allocation failed. For historically
   exact console geometry choose (80,25). Larger grids are enhanced-only. */
nw_snake *nw_snake_create(int columns, int rows, uint32_t seed);
void nw_snake_destroy(nw_snake *snake);
void nw_snake_reset(nw_snake *snake, uint32_t seed);
/* Enhanced geometry only: copy a row-major traversal mask of columns*rows
   bytes (nonzero = present). Both cells of a horizontal head pair must be
   present. Returns 0 without changing state for invalid input/allocation
   failure/a mask with no valid pair. NULL with length 0 restores rectangular
   traversal. Success resets animation and visited cells, retaining the RNG
   seed, and centers the head on the closest valid pair. Reset retains a
   configured domain. Default create/reset without a domain remains faithful. */
int nw_snake_set_domain(nw_snake *snake, const uint8_t *mask, size_t length);
/* Reset animation/visited cells at the valid pair nearest the canvas center,
   preserving seed and domain. Use when opting into enlarged geometry. */
int nw_snake_recenter(nw_snake *snake);
/* Persistent row-major cell mask: head cells already painted during this
   activation. Tail erasure/overlap projection never restores these cells. */
const uint8_t *nw_snake_visited(const nw_snake *snake);
/* One complete 1993 paint/simulation pass. CPU is clamped into [0,100]. */
unsigned nw_snake_advance(nw_snake *snake, int cpu_percent);
/* Row-major CP437 character bytes; ASCII space = blank.
   Protected view is display-only; it never modifies the faithful state. */
const uint8_t *nw_snake_frame(const nw_snake *snake, int overlap_protection);
int nw_snake_columns(const nw_snake *snake);
int nw_snake_rows(const nw_snake *snake);
int nw_snake_x(const nw_snake *snake);
int nw_snake_y(const nw_snake *snake);
int nw_snake_heading(const nw_snake *snake);
int nw_snake_phase(const nw_snake *snake);
int nw_snake_cursor(const nw_snake *snake, int stage);
int nw_snake_history_x(const nw_snake *snake, int slot);
int nw_snake_history_y(const nw_snake *snake, int slot);
int nw_snake_history_direction(const nw_snake *snake, int slot);
uint32_t nw_snake_seed(const nw_snake *snake);
uint64_t nw_snake_passes(const nw_snake *snake);
uint64_t nw_snake_moves(const nw_snake *snake);
uint64_t nw_snake_crossing_erasures(const nw_snake *snake);
int nw_snake_load_band(int cpu_percent); /* 1..5 */
#ifdef __cplusplus
}
#endif
#endif
