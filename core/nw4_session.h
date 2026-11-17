#ifndef NW4_SESSION_H
#define NW4_SESSION_H
#include "nw4_snake.h"
/* Host policy around the verified engine, with no wall-clock or OS APIs.
 * Ties use ascending CPU index; original NetWare process ordering may vary. */
typedef struct nw4_session nw4_session;
unsigned nw4_processor_count(unsigned host_count, int allow32);
nw4_session *nw4_session_create(void);
nw4_session *nw4_session_create_grid(int columns, int rows);
void nw4_session_destroy(nw4_session *);
/* Fresh activation clears the console/palette and preserves module RNG state. */
int nw4_session_start(nw4_session *, unsigned host_count, int allow32);
/* Explicit 1..32 CPUs, starting color index 0..31 modulo fifteen. Enhanced
 * ticks additionally report protected-plane and visited-mask changes. */
int nw4_session_start_configured(nw4_session *, unsigned count, unsigned color_start);
int nw4_session_set_domain(nw4_session *, const uint8_t *mask, size_t length);
int nw4_session_columns(const nw4_session *);
int nw4_session_rows(const nw4_session *);
/* One nominal 1/18.2-second interval. CPU p starts at interval 4*p.
 * Returns nonzero when visible characters or attributes changed. */
int nw4_session_tick(nw4_session *, const unsigned *loads, unsigned load_count);
unsigned nw4_session_processors(const nw4_session *);
uint64_t nw4_session_intervals(const nw4_session *);
const uint8_t *nw4_session_characters(const nw4_session *);
const uint8_t *nw4_session_attributes(const nw4_session *);
const uint8_t *nw4_session_protected_characters(const nw4_session *);
const uint8_t *nw4_session_protected_attributes(const nw4_session *);
const uint8_t *nw4_session_visited(const nw4_session *);
#endif
