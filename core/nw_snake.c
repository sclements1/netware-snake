#include "nw_snake.h"
#include <stdlib.h>
#include <string.h>

#define H 51
#define STAGES 5
static const int8_t dx[8] = {0,1,2,1,0,-1,-2,-1};
static const int8_t dy[8] = {-1,-1,0,1,1,1,0,-1};
static const uint8_t glyph[5] = {0xdb,0xb2,0xb1,0xb0,0x20};
static const uint8_t retry_dir[12] = {0,1,1,2,3,3,4,5,5,6,7,7};
static const int8_t auto_turn[11] = {0,0,0,1,1,-1,-1,2,-2,3,-3};

typedef struct {
    uint64_t generation;
    int x, y, stage;
    int alive;
} segment;
typedef struct {
    int stage, slot, x, y;
    uint64_t generation;
} event;
struct nw_snake {
    int columns, rows, x, y, heading, phase;
    int cursors[STAGES], xs[H], ys[H], directions[H];
    uint8_t valid[H];
    uint8_t *raw, *protected_frame, *scratch_raw, *scratch_protected;
    uint8_t *visited, *domain;
    uint32_t seed;
    uint64_t passes, moves, crossing_erasures;
    uint64_t generations[H], next_generation;
    segment active[H];
    int last_write;
};
static int clamp_cpu(int cpu) {return cpu<0?0:(cpu>100?100:cpu);}
int nw_snake_load_band(int cpu) {
    cpu=clamp_cpu(cpu);
    return cpu<=11?1:cpu<=22?2:cpu<=33?3:cpu<=55?4:5;
}
static uint32_t rand_step(uint32_t seed) {return (seed+UINT32_C(1))*UINT32_C(10013);}
static int pair_in_domain(const nw_snake *s, const uint8_t *domain, int x, int y) {
    if (x<0 || x>=s->columns-1 || y<0 || y>=s->rows) return 0;
    size_t pos=(size_t)y*(size_t)s->columns+(size_t)x;
    return !domain || (domain[pos] && domain[pos+1]);
}
static int centered_pair(const nw_snake *s,const uint8_t *domain,int *x,int *y) {
    if (!domain) {*x=(s->columns-2)/2;*y=(s->rows-1)/2;return 1;}
    uint64_t best=UINT64_MAX;
    int found=0;
    for (int row=0;row<s->rows;row++) for (int col=0;col<s->columns-1;col++) {
        if (!pair_in_domain(s,domain,col,row)) continue;
        /* Twice the distance to the center avoids floating-point ties. */
        int64_t a=(int64_t)2*col+2-s->columns,b=(int64_t)2*row+1-s->rows;
        uint64_t distance=(uint64_t)(a*a+b*b);
        if (distance<best) {best=distance;*x=col;*y=row;found=1;}
    }
    return found;
}
static void remove_gen(nw_snake *s, uint64_t gen) {
    if (!gen) return;
    for (int i=0;i<H;i++) if (s->active[i].alive && s->active[i].generation==gen) {
        s->active[i].alive=0;
        return;
    }
}
static void put_gen(nw_snake *s, uint64_t gen,int x,int y,int stage) {
    if (!gen) return;
    for (int i=0;i<H;i++) if (s->active[i].alive && s->active[i].generation==gen) {
        s->active[i].x=x;s->active[i].y=y;s->active[i].stage=stage;return;
    }
    for (int i=0;i<H;i++) if (!s->active[i].alive) {
        s->active[i]=(segment){gen,x,y,stage,1};return;
    }
    /* There are at most 51 live history generations. */
}
static void draw_pair(nw_snake *s,uint8_t *frame,int x,int y,uint8_t g) {
    if (!pair_in_domain(s,s->domain,x,y)) return;
    size_t pos=(size_t)y*(size_t)s->columns+(size_t)x;
    frame[pos]=g;frame[pos+1]=g;
}
static void compose_protected(nw_snake *s) {
    const size_t n=(size_t)s->columns*(size_t)s->rows;
    memset(s->protected_frame,0x20,n);
    /* Oldest first; latest generation wins crossing conflicts. 51 slots max. */
    uint64_t previous=0;
    for (int i=0;i<H;i++) {
        uint64_t best=UINT64_MAX;
        const segment *chosen=NULL;
        for (int j=0;j<H;j++) if (s->active[j].alive &&
            s->active[j].generation>previous && s->active[j].generation<best) {
            best=s->active[j].generation;chosen=&s->active[j];
        }
        if (!chosen) break;
        draw_pair(s,s->protected_frame,chosen->x,chosen->y,glyph[chosen->stage]);
        previous=best;
    }
}
static void reset_at(nw_snake *s,uint32_t seed,int x,int y) {
    s->seed=seed;s->passes=0;s->moves=0;s->crossing_erasures=0;
    s->heading=2;s->x=x;s->y=y;s->phase=40*128;s->last_write=40;
    const int initial[5]={40,30,20,10,0};
    memcpy(s->cursors,initial,sizeof initial);
    for (int i=0;i<H;i++) {s->xs[i]=255;s->ys[i]=255;s->directions[i]=255;s->valid[i]=0;s->generations[i]=0;}
    memset(s->active,0,sizeof s->active);
    s->xs[40]=s->x;s->ys[40]=s->y;s->directions[40]=s->heading;s->valid[40]=1;
    s->generations[40]=1;s->next_generation=2;
    memset(s->raw,0x20,(size_t)s->columns*(size_t)s->rows);
    memset(s->protected_frame,0x20,(size_t)s->columns*(size_t)s->rows);
    memset(s->visited,0,(size_t)s->columns*(size_t)s->rows);
}
void nw_snake_reset(nw_snake *s,uint32_t seed) {
    if (!s) return;
    int x=38,y=12;
    if (s->domain && !centered_pair(s,s->domain,&x,&y)) return;
    reset_at(s,seed,x,y);
}
int nw_snake_recenter(nw_snake *s) {
    if (!s) return 0;
    int x=0,y=0;
    if (!centered_pair(s,s->domain,&x,&y)) return 0;
    reset_at(s,s->seed,x,y);
    return 1;
}
int nw_snake_set_domain(nw_snake *s,const uint8_t *mask,size_t length) {
    if (!s || (!mask && length)) return 0;
    const size_t n=(size_t)s->columns*(size_t)s->rows;
    if (mask && length!=n) return 0;
    int x=0,y=0;
    if (!centered_pair(s,mask,&x,&y)) return 0;
    uint8_t *copy=NULL;
    if (mask) {
        copy=malloc(n);
        if (!copy) return 0;
        for (size_t i=0;i<n;i++) copy[i]=(uint8_t)(mask[i]!=0);
    }
    free(s->domain);s->domain=copy;
    reset_at(s,s->seed,x,y);
    return 1;
}
nw_snake *nw_snake_create(int columns,int rows,uint32_t seed) {
    if (columns<40 || rows<14 || columns>4096 || rows>2048) return NULL;
    nw_snake *s=calloc(1,sizeof *s);
    if (!s) return NULL;
    s->columns=columns;s->rows=rows;
    size_t n=(size_t)columns*(size_t)rows;
    s->raw=malloc(n);s->protected_frame=malloc(n);
    s->scratch_raw=malloc(n);s->scratch_protected=malloc(n);
    s->visited=malloc(n);
    if (!s->raw || !s->protected_frame || !s->scratch_raw || !s->scratch_protected || !s->visited) {nw_snake_destroy(s);return NULL;}
    nw_snake_reset(s,seed);
    return s;
}
void nw_snake_destroy(nw_snake *s) {
    if (!s) return;
    free(s->raw);free(s->protected_frame);free(s->scratch_raw);free(s->scratch_protected);
    free(s->visited);free(s->domain);free(s);
}
unsigned nw_snake_advance(nw_snake *s,int cpu_percent) {
    if (!s) return 0;
    cpu_percent=clamp_cpu(cpu_percent);
    event events[5];int event_count=0;
    for (int stage=4;stage>=0;stage--) {
        const int slot=s->cursors[stage];
        if (s->valid[slot]) events[event_count++]=(event){stage,slot,s->xs[slot],s->ys[slot],s->generations[slot]};
    }
    const size_t n=(size_t)s->columns*(size_t)s->rows;
    memcpy(s->scratch_raw,s->raw,n);
    memcpy(s->scratch_protected,s->protected_frame,n);
    const uint64_t previous_moves=s->moves;
    int placed=0,visited_changed=0;
    for (int stage=4;stage>=0;stage--) {
        const int cursor=s->cursors[stage];
        if (s->valid[cursor]) {
            draw_pair(s,s->raw,s->xs[cursor],s->ys[cursor],glyph[stage]);
            if (stage==0) {
                if (pair_in_domain(s,s->domain,s->xs[cursor],s->ys[cursor])) {
                    size_t p=(size_t)s->ys[cursor]*(size_t)s->columns+(size_t)s->xs[cursor];
                    if (!s->visited[p] || !s->visited[p+1]) visited_changed=1;
                    s->visited[p]=s->visited[p+1]=1;
                }
                const int original_reverse=(s->heading+4)%8;
                int new_x=s->x,new_y=s->y,can_move=1;
                int fallback=-1;
                if (s->domain) {
                    for (int direction=0;direction<8;direction++)
                        if (direction!=original_reverse && pair_in_domain(s,s->domain,s->x+dx[direction],s->y+dy[direction])) {
                            fallback=direction;break;
                        }
                    if (fallback<0) can_move=0;
                }
                for (int tries=0;can_move;tries++) {
                    new_x=s->x+dx[s->heading];new_y=s->y+dy[s->heading];
                    if (pair_in_domain(s,s->domain,new_x,new_y) &&
                        s->heading!=original_reverse) break;
                    /* Irregular enhanced domains may have just one legal
                       direction. Bound rejection work without changing any
                       faithful rectangular RNG sequence. */
                    if (s->domain && tries>=63) {
                        s->heading=fallback;
                        new_x=s->x+dx[fallback];new_y=s->y+dy[fallback];break;
                    }
                    s->seed=rand_step(s->seed);
                    s->heading=retry_dir[(s->seed%47)%12];
                }
                if (can_move) {s->x=new_x;s->y=new_y;s->moves++;}
                const int d=1280/(((9*cpu_percent)/100)+1);
                const int slot=(((d+s->phase)>>7)%H);
                s->last_write=slot;
                s->xs[slot]=s->x;s->ys[slot]=s->y;s->directions[slot]=s->heading;s->valid[slot]=1;
                placed=1;
            }
            if (stage==4) {s->xs[cursor]=255;s->ys[cursor]=255;s->valid[cursor]=0;}
        }
        if (stage==0) {
            s->phase=(s->phase+128)%(H*128);
            s->cursors[0]=s->phase>>7;
        } else s->cursors[stage]=(cursor+1)%H;
    }
    s->passes++;
    if (s->passes%40==0) {
        s->seed=rand_step(s->seed);
        s->heading=(s->heading+auto_turn[s->seed%11]+8)%8;
    }
    /* Preserve the exact drawing events but project them into optional
       overlap-aware display layer, never the historic screen buffer. */
    for (int e=0;e<event_count;e++) {
        const event ev=events[e];
        if (ev.stage==4) {
            for (int i=0;i<H;i++) if (s->active[i].alive &&
                s->active[i].generation>ev.generation &&
                s->active[i].y==ev.y && abs(s->active[i].x-ev.x)<=1) {
                s->crossing_erasures++;break;
            }
            remove_gen(s,ev.generation);s->generations[ev.slot]=0;
        } else put_gen(s,ev.generation,ev.x,ev.y,ev.stage);
    }
    const int moved=(s->moves!=previous_moves);
    if (placed) {
        const int slot=s->last_write;
        remove_gen(s,s->generations[slot]);
        s->generations[slot]=s->next_generation++;
    }
    compose_protected(s);
    unsigned result=0;
    if (memcmp(s->scratch_raw,s->raw,n)!=0)result|=NW_FRAME_CHANGED;
    if (memcmp(s->scratch_protected,s->protected_frame,n)!=0)result|=NW_PROTECTED_CHANGED;
    if (moved)result|=NW_HEAD_MOVED;
    if (visited_changed)result|=NW_VISITED_CHANGED;
    return result;
}
const uint8_t *nw_snake_frame(const nw_snake *s,int protect) {return s?(protect?s->protected_frame:s->raw):NULL;}
const uint8_t *nw_snake_visited(const nw_snake *s){return s?s->visited:NULL;}
int nw_snake_columns(const nw_snake *s){return s?s->columns:0;}
int nw_snake_rows(const nw_snake *s){return s?s->rows:0;}
int nw_snake_x(const nw_snake *s){return s?s->x:0;}
int nw_snake_y(const nw_snake *s){return s?s->y:0;}
int nw_snake_heading(const nw_snake *s){return s?s->heading:0;}
int nw_snake_phase(const nw_snake *s){return s?s->phase:0;}
int nw_snake_cursor(const nw_snake *s,int st){return s&&st>=0&&st<5?s->cursors[st]:-1;}
int nw_snake_history_x(const nw_snake *s,int slot){return s&&slot>=0&&slot<H?s->xs[slot]:-1;}
int nw_snake_history_y(const nw_snake *s,int slot){return s&&slot>=0&&slot<H?s->ys[slot]:-1;}
int nw_snake_history_direction(const nw_snake *s,int slot){return s&&slot>=0&&slot<H?s->directions[slot]:-1;}
uint32_t nw_snake_seed(const nw_snake *s){return s?s->seed:0;}
uint64_t nw_snake_passes(const nw_snake *s){return s?s->passes:0;}
uint64_t nw_snake_moves(const nw_snake *s){return s?s->moves:0;}
uint64_t nw_snake_crossing_erasures(const nw_snake *s){return s?s->crossing_erasures:0;}
