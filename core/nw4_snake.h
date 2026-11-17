#ifndef NW4_SNAKE_H
#define NW4_SNAKE_H
#include <stdint.h>
#include <stddef.h>
/* Portable NetWare 4.2 engine. No OS, graphics, clock, or thread dependencies.
 * A world owns the SHARED RNG, palette and destructive framebuffer.
 * Keep a world between activations; reset_colors does not reseed the RNG. */
typedef struct nw4_world nw4_world;
enum { NW4_BEGIN=0, NW4_END=1, NW4_ATTRIBUTE=2, NW4_CHARACTER=3 };
typedef void (*nw4_write_fn)(void *context, unsigned kind, unsigned x,
                             unsigned y, unsigned value);
nw4_world *nw4_create(void);
nw4_world *nw4_create_grid(int columns, int rows);
void nw4_destroy(nw4_world *);
void nw4_reset_colors(nw4_world *);
/* Start a new console activation, keeping the shared RNG sequence. */
int nw4_activate(nw4_world *, unsigned processors);
int nw4_activate_with_options(nw4_world *, unsigned processors, unsigned color_start);
/* Copied traversal mask; NULL,0 restores rectangle. Success clears activation;
 * activate/init before ticking. Invalid masks leave state unchanged. */
int nw4_set_domain(nw4_world *, const uint8_t *mask, size_t length);
int nw4_columns(const nw4_world *);
int nw4_rows(const nw4_world *);
/* glyphs are the resolved NWS requests 47,46,45,44, then literal space.
 * Color=0 reproduces the observed ReturnScreenType-second-output-zero branch. */
int nw4_init(nw4_world *, unsigned processor, int color, const uint8_t glyphs[5]);
/* One original update pass, followed by periodic turn on each 40th pass.
 * Input contract 0..100. Invalid inputs/indices return 0 without updates.
 * This API does not claim a verified NetWare delay-to-wall-clock conversion. */
int nw4_tick(nw4_world *, unsigned processor, unsigned utilization,
             nw4_write_fn, void *context);
/* Export exact 0x11c-byte state image for differential verification.
 * Pointer/handle fields remain zero; no host pointers are put in this image. */
int nw4_state(const nw4_world *, unsigned processor, uint8_t out[284]);
void nw4_random_state(const nw4_world *, uint8_t out[118]);
uint16_t nw4_random(nw4_world *);
const uint8_t *nw4_characters(const nw4_world *);
const uint8_t *nw4_attributes(const nw4_world *);
const uint8_t *nw4_protected_characters(const nw4_world *);
const uint8_t *nw4_protected_attributes(const nw4_world *);
const uint8_t *nw4_visited(const nw4_world *);
/* Enhanced coordinates use full-width histories. Legacy state export remains
 * the exact original byte representation for 80x25 grids. */
int nw4_x(const nw4_world *, unsigned processor);
int nw4_y(const nw4_world *, unsigned processor);
int nw4_heading(const nw4_world *, unsigned processor);
int nw4_history_x(const nw4_world *, unsigned processor, unsigned slot);
int nw4_history_y(const nw4_world *, unsigned processor, unsigned slot);
unsigned nw4_slot_lead(unsigned utilization);
#endif
