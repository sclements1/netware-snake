#include "nw4_snake.h"
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
/* Keep the canonical 284-byte object unchanged. Enhanced coordinates use
 * separate integer histories and never truncate the actual drawing path. */
typedef struct {
 uint32_t backing,handle,phase,cursor[5];
 int32_t dx[8],dy[8];
 uint32_t processor,color,heading,x,y,reserved;
 uint8_t glyph[5],pad[3],xs[52],ys[52],directions[52];
} snake;
typedef struct {uint64_t generation;int x,y,stage;uint8_t color,glyph,alive;} segment;
_Static_assert(sizeof(snake)==284,"snake layout");
_Static_assert(offsetof(snake,xs)==0x80,"history layout");
struct nw4_world {
 uint16_t random_words[55];unsigned ri,rj,color_index;
 snake snakes[32];unsigned active[32],passes[32];
 int columns,rows,start_x,start_y;
 int hx[32][51],hy[32][51];
 uint64_t generation[32][51],next_generation;
 segment live[32][51];
 uint8_t *characters,*attributes,*protected_characters,*protected_attributes,*visited,*domain;
 int projection_dirty;
};
static const uint16_t seed[55]={
 1,2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,3,1,4,1,5,9,2,6,5,4,7,2,
 7,1,8,2,8,4,5,7,2,9,9,3,5,2,3,0,5,0,5,5,6,8,5,8,8,8,5};
static const int32_t dx[8]={0,1,2,1,0,-1,-2,-1};
static const int32_t dy[8]={-1,-1,0,1,1,1,0,-1};
static const int turn[11]={0,0,0,1,1,-1,-1,2,-2,3,-3};
static const unsigned retry[12]={0,1,1,2,3,3,4,5,5,6,7,7};
static const unsigned colors[15]={12,9,10,11,13,7,4,1,2,3,6,14,5,8,15};
static size_t cells(const nw4_world *w){return (size_t)w->columns*(size_t)w->rows;}
static int pair(const nw4_world *w,const uint8_t *domain,int x,int y) {
 if(x<0||x>=w->columns-1||y<0||y>=w->rows)return 0;
 size_t p=(size_t)y*(size_t)w->columns+(size_t)x;
 return !domain||(domain[p]&&domain[p+1]);
}
static int center(const nw4_world *w,const uint8_t *domain,int *x,int *y) {
 if(!domain){*x=w->columns==80&&w->rows==25?38:(w->columns-2)/2;
  *y=w->columns==80&&w->rows==25?12:(w->rows-1)/2;return 1;}
 uint64_t best=UINT64_MAX;int found=0;
 for(int row=0;row<w->rows;row++)for(int col=0;col<w->columns-1;col++)if(pair(w,domain,col,row)) {
  int64_t a=(int64_t)2*col+2-w->columns,b=(int64_t)2*row+1-w->rows;
  uint64_t d=(uint64_t)(a*a+b*b);
  if(d<best){best=d;*x=col;*y=row;found=1;}
 }
 return found;
}
static void clear_activation(nw4_world *w) {
 memset(w->active,0,sizeof w->active);memset(w->passes,0,sizeof w->passes);
 memset(w->snakes,0,sizeof w->snakes);memset(w->live,0,sizeof w->live);
 memset(w->generation,0,sizeof w->generation);w->next_generation=1;
 for(unsigned p=0;p<32;p++)for(unsigned i=0;i<51;i++)w->hx[p][i]=w->hy[p][i]=-1;
 memset(w->characters,32,cells(w));memset(w->attributes,0,cells(w));
 memset(w->protected_characters,32,cells(w));memset(w->protected_attributes,0,cells(w));
 memset(w->visited,0,cells(w));w->projection_dirty=0;
}
uint16_t nw4_random(nw4_world *w) {
 uint16_t v=(uint16_t)(w->random_words[w->ri]+w->random_words[w->rj]);
 w->random_words[w->rj]=v;w->ri=w->ri?w->ri-1:54;w->rj=w->rj?w->rj-1:54;return v;
}
static void random_turn(nw4_world *w,snake *s) {
 s->heading=(unsigned)((int)s->heading+turn[nw4_random(w)%11]+8)%8;
}
nw4_world *nw4_create_grid(int columns,int rows) {
 if(columns<40||rows<14||columns>4096||rows>2048)return NULL;
 nw4_world *w=calloc(1,sizeof *w);if(!w)return NULL;
 w->columns=columns;w->rows=rows;size_t n=cells(w);
 w->characters=malloc(n);w->attributes=malloc(n);w->protected_characters=malloc(n);
 w->protected_attributes=malloc(n);w->visited=malloc(n);
 if(!w->characters||!w->attributes||!w->protected_characters||!w->protected_attributes||!w->visited){nw4_destroy(w);return NULL;}
 memcpy(w->random_words,seed,sizeof seed);w->ri=23;w->rj=54;
 center(w,NULL,&w->start_x,&w->start_y);clear_activation(w);return w;
}
nw4_world *nw4_create(void){return nw4_create_grid(80,25);}
void nw4_destroy(nw4_world *w){if(w){free(w->characters);free(w->attributes);free(w->protected_characters);
 free(w->protected_attributes);free(w->visited);free(w->domain);free(w);}}
void nw4_reset_colors(nw4_world *w){if(w)w->color_index=0;}
int nw4_set_domain(nw4_world *w,const uint8_t *mask,size_t length) {
 if(!w||(!mask&&length)||(mask&&length!=cells(w)))return 0;
 int x=0,y=0;if(!center(w,mask,&x,&y))return 0;
 uint8_t *copy=NULL;if(mask){copy=malloc(length);if(!copy)return 0;
  for(size_t i=0;i<length;i++)copy[i]=(uint8_t)(mask[i]!=0);}
 free(w->domain);w->domain=copy;w->start_x=x;w->start_y=y;clear_activation(w);return 1;
}
int nw4_init(nw4_world *w,unsigned p,int color,const uint8_t glyphs[5]) {
 if(!w||p>=32||!glyphs)return 0;
 snake *s=&w->snakes[p];memset(s,0,sizeof *s);s->processor=p;
 memset(w->live[p],0,sizeof w->live[p]);memset(w->generation[p],0,sizeof w->generation[p]);
 memcpy(s->glyph,glyphs,4);s->glyph[4]=32;memcpy(s->dx,dx,sizeof dx);memcpy(s->dy,dy,sizeof dy);
 s->x=(unsigned)w->start_x;s->y=(unsigned)w->start_y;s->heading=nw4_random(w)%8;
 memset(s->xs,255,51);memset(s->ys,255,51);
 for(unsigned i=0;i<51;i++)w->hx[p][i]=w->hy[p][i]=-1;
 const unsigned cursors[5]={40,30,20,10,0};memcpy(s->cursor,cursors,sizeof cursors);
 s->xs[40]=(uint8_t)s->x;s->ys[40]=(uint8_t)s->y;s->directions[40]=2;s->phase=40*128;
 w->hx[p][40]=(int)s->x;w->hy[p][40]=(int)s->y;w->generation[p][40]=w->next_generation++;
 if(w->color_index>=15)w->color_index=0;
 if(!color)w->color_index=0;
 s->color=colors[w->color_index++];random_turn(w,s);
 w->active[p]=1;w->passes[p]=0;w->projection_dirty=1;return 1;
}
unsigned nw4_slot_lead(unsigned u){if(u>100)return 0;if(!u)u=1;return (1280/((9*u)/100+1))/128;}
static void emit(nw4_world *w,nw4_write_fn cb,void *ctx,unsigned kind,unsigned x,unsigned y,unsigned value) {
 if((kind==NW4_ATTRIBUTE||kind==NW4_CHARACTER)&&x<(unsigned)w->columns&&y<(unsigned)w->rows) {
  size_t offset=(size_t)y*(size_t)w->columns+x;
  if(kind==NW4_ATTRIBUTE)w->attributes[offset]=(uint8_t)value;else w->characters[offset]=(uint8_t)value;
 }
 if(cb)cb(ctx,kind,x,y,value);
}
static void remove_generation(nw4_world *w,unsigned p,uint64_t generation) {
 if(!generation)return;
 for(unsigned i=0;i<51;i++)if(w->live[p][i].alive&&w->live[p][i].generation==generation) {
  w->live[p][i].alive=0;return;
 }
}
static void put_generation(nw4_world *w,unsigned p,uint64_t generation,int x,int y,int stage) {
 if(!generation)return;
 segment *empty=NULL;
 for(unsigned i=0;i<51;i++) {
  segment *live=&w->live[p][i];
  if(live->alive&&live->generation==generation){live->x=x;live->y=y;live->stage=stage;
   live->glyph=w->snakes[p].glyph[stage];return;}
  if(!live->alive&&!empty)empty=live;
 }
 if(empty)*empty=(segment){generation,x,y,stage,(uint8_t)w->snakes[p].color,w->snakes[p].glyph[stage],1};
}
int nw4_tick(nw4_world *w,unsigned p,unsigned u,nw4_write_fn cb,void *ctx) {
 if(!w||p>=32||!w->active[p]||u>100)return 0;
 snake *s=&w->snakes[p];emit(w,cb,ctx,NW4_BEGIN,0,0,0);
 for(int stage=4;stage>=0;--stage) {
  unsigned cur=s->cursor[stage];int x=w->hx[p][cur],y=w->hy[p][cur];
  if(pair(w,w->domain,x,y)) {
   emit(w,cb,ctx,NW4_ATTRIBUTE,(unsigned)x,(unsigned)y,s->color);
   emit(w,cb,ctx,NW4_CHARACTER,(unsigned)x,(unsigned)y,s->glyph[stage]);
   emit(w,cb,ctx,NW4_ATTRIBUTE,(unsigned)x+1,(unsigned)y,s->color);
   emit(w,cb,ctx,NW4_CHARACTER,(unsigned)x+1,(unsigned)y,s->glyph[stage]);
   if(stage==4)remove_generation(w,p,w->generation[p][cur]);
   else put_generation(w,p,w->generation[p][cur],x,y,stage);
   if(!stage) {
    size_t offset=(size_t)y*(size_t)w->columns+(size_t)x;
    w->visited[offset]=w->visited[offset+1]=1;
    unsigned reverse=(s->heading+4)%8;int x1=(int)s->x,y1=(int)s->y,fallback=-1,can_move=1;
    if(w->domain) {
     for(unsigned direction=0;direction<8;direction++)if(direction!=reverse&&
      pair(w,w->domain,(int)s->x+dx[direction],(int)s->y+dy[direction])){fallback=(int)direction;break;}
     if(fallback<0)can_move=0;
    }
    for(unsigned tries=0;can_move;tries++) {
     x1=(int)s->x+s->dx[s->heading];y1=(int)s->y+s->dy[s->heading];
     if(pair(w,w->domain,x1,y1)&&s->heading!=reverse)break;
     if(w->domain&&tries>=63){s->heading=(unsigned)fallback;
      x1=(int)s->x+dx[fallback];y1=(int)s->y+dy[fallback];break;}
     s->heading=retry[nw4_random(w)%12];
    }
    if(can_move){s->x=(unsigned)x1;s->y=(unsigned)y1;}
    unsigned load=u?u:1,d=1280/((9*load)/100+1),slot=((s->phase+d)>>7)%51;
    remove_generation(w,p,w->generation[p][slot]);
    w->hx[p][slot]=(int)s->x;w->hy[p][slot]=(int)s->y;
    s->xs[slot]=(uint8_t)s->x;s->ys[slot]=(uint8_t)s->y;s->directions[slot]=(uint8_t)s->heading;
    w->generation[p][slot]=w->next_generation++;
   }
   if(stage==4){s->xs[cur]=255;s->ys[cur]=255;w->hx[p][cur]=w->hy[p][cur]=-1;w->generation[p][cur]=0;}
  }
  if(!stage){s->phase=(s->phase+128)%(51*128);s->cursor[0]=s->phase>>7;}
  else s->cursor[stage]=(cur+1)%51;
 }
 emit(w,cb,ctx,NW4_END,0,0,0);w->projection_dirty=1;
 if(++w->passes[p]%40==0)random_turn(w,s);
 return 1;
}
static int compare_segments(const void *a,const void *b) {
 uint64_t x=(*(const segment *const *)a)->generation,y=(*(const segment *const *)b)->generation;
 return (x>y)-(x<y);
}
static void compose(nw4_world *w) {
 if(!w||!w->projection_dirty)return;
 const segment *ordered[32*51];size_t count=0;
 for(unsigned p=0;p<32;p++)for(unsigned i=0;i<51;i++)if(w->live[p][i].alive)ordered[count++]=&w->live[p][i];
 qsort(ordered,count,sizeof *ordered,compare_segments);
 memset(w->protected_characters,32,cells(w));memset(w->protected_attributes,0,cells(w));
 for(size_t i=0;i<count;i++) {
  const segment *s=ordered[i];if(!pair(w,w->domain,s->x,s->y))continue;
  size_t pos=(size_t)s->y*(size_t)w->columns+(size_t)s->x;
  w->protected_characters[pos]=w->protected_characters[pos+1]=s->glyph;
  w->protected_attributes[pos]=w->protected_attributes[pos+1]=s->color;
 }
 w->projection_dirty=0;
}
static void put32(uint8_t *p,uint32_t v){for(unsigned i=0;i<4;++i)p[i]=(uint8_t)(v>>(i*8));}
int nw4_state(const nw4_world *w,unsigned p,uint8_t out[284]) {
 if(!w||p>=32||!w->active[p]||!out)return 0;
 const snake *s=&w->snakes[p];
 for(unsigned i=0;i<30;++i){uint32_t v;memcpy(&v,(const uint8_t *)s+4*i,4);put32(out+4*i,v);}
 memcpy(out+120,(const uint8_t *)s+120,164);return 1;
}
void nw4_random_state(const nw4_world *w,uint8_t out[118]) {
 for(unsigned i=0;i<55;++i){out[2*i]=(uint8_t)w->random_words[i];out[2*i+1]=(uint8_t)(w->random_words[i]>>8);}
 put32(out+110,w->ri);put32(out+114,w->rj);
}
const uint8_t *nw4_characters(const nw4_world *w){return w?w->characters:NULL;}
const uint8_t *nw4_attributes(const nw4_world *w){return w?w->attributes:NULL;}
const uint8_t *nw4_protected_characters(const nw4_world *w){compose((nw4_world *)w);return w?w->protected_characters:NULL;}
const uint8_t *nw4_protected_attributes(const nw4_world *w){compose((nw4_world *)w);return w?w->protected_attributes:NULL;}
const uint8_t *nw4_visited(const nw4_world *w){return w?w->visited:NULL;}
int nw4_columns(const nw4_world *w){return w?w->columns:0;}
int nw4_rows(const nw4_world *w){return w?w->rows:0;}
int nw4_x(const nw4_world *w,unsigned p){return w&&p<32&&w->active[p]?(int)w->snakes[p].x:-1;}
int nw4_y(const nw4_world *w,unsigned p){return w&&p<32&&w->active[p]?(int)w->snakes[p].y:-1;}
int nw4_heading(const nw4_world *w,unsigned p){return w&&p<32&&w->active[p]?(int)w->snakes[p].heading:-1;}
int nw4_history_x(const nw4_world *w,unsigned p,unsigned i){return w&&p<32&&i<51&&w->active[p]?w->hx[p][i]:-1;}
int nw4_history_y(const nw4_world *w,unsigned p,unsigned i){return w&&p<32&&i<51&&w->active[p]?w->hy[p][i]:-1;}
int nw4_activate_with_options(nw4_world *w,unsigned processors,unsigned color_start) {
 if(!w||!processors||processors>32||color_start>31)return 0;
 clear_activation(w);w->color_index=color_start%15;
 const uint8_t glyphs[5]={0xdb,0xb2,0xb1,0xb0,0x20};
 for(unsigned p=0;p<processors;p++)if(!nw4_init(w,p,1,glyphs))return 0;
 return 1;
}
int nw4_activate(nw4_world *w,unsigned processors){return nw4_activate_with_options(w,processors,0);}
