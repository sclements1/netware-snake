#include "nw4_snake.h"
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
/* Layout explicitly matches the recovered 32-bit object's scalar/byte fields.
 * Export is serialized, avoiding host endianness/alignment assumptions. */
typedef struct {
 uint32_t backing,handle,phase,cursor[5];
 int32_t dx[8],dy[8];
 uint32_t processor,color,heading,x,y,reserved;
 uint8_t glyph[5],pad[3],xs[52],ys[52],directions[52];
} snake;
_Static_assert(sizeof(snake)==284,"snake layout");
_Static_assert(offsetof(snake,xs)==0x80,"history layout");
struct nw4_world {
 uint16_t random_words[55]; unsigned ri,rj,color_index;
 snake snakes[32]; unsigned active[32],passes[32];
 uint8_t characters[2000],attributes[2000];
};
static const uint16_t seed[55]={
 1,2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,3,1,4,1,5,9,2,6,5,4,7,2,
 7,1,8,2,8,4,5,7,2,9,9,3,5,2,3,0,5,0,5,5,6,8,5,8,8,8,5};
static const int32_t dx[8]={0,1,2,1,0,-1,-2,-1};
static const int32_t dy[8]={-1,-1,0,1,1,1,0,-1};
static const int turn[11]={0,0,0,1,1,-1,-1,2,-2,3,-3};
static const unsigned retry[12]={0,1,1,2,3,3,4,5,5,6,7,7};
static const unsigned colors[15]={12,9,10,11,13,7,4,1,2,3,6,14,5,8,15};
uint16_t nw4_random(nw4_world *w) {
 uint16_t v=(uint16_t)(w->random_words[w->ri]+w->random_words[w->rj]);
 w->random_words[w->rj]=v;w->ri=w->ri? w->ri-1:54;w->rj=w->rj?w->rj-1:54;
 return v;
}
static void random_turn(nw4_world *w,snake *s) {
 s->heading=(unsigned)((int)s->heading+turn[nw4_random(w)%11]+8)%8;
}
nw4_world *nw4_create(void) {
 nw4_world *w=calloc(1,sizeof *w);if(!w)return NULL;
 memcpy(w->random_words,seed,sizeof seed);w->ri=23;w->rj=54;
 memset(w->characters,32,sizeof w->characters);return w;
}
void nw4_destroy(nw4_world *w){free(w);}
void nw4_reset_colors(nw4_world *w){if(w)w->color_index=0;}
int nw4_init(nw4_world *w,unsigned p,int color,const uint8_t glyphs[5]) {
 if(!w||p>=32||!glyphs)return 0;
 snake *s=&w->snakes[p];memset(s,0,sizeof *s);s->processor=p;
 memcpy(s->glyph,glyphs,4);s->glyph[4]=32;
 memcpy(s->dx,dx,sizeof dx);memcpy(s->dy,dy,sizeof dy);
 s->x=38;s->y=12;s->heading=nw4_random(w)%8;
 memset(s->xs,255,51);memset(s->ys,255,51);
 const unsigned cursors[5]={40,30,20,10,0};memcpy(s->cursor,cursors,sizeof cursors);
 s->xs[40]=38;s->ys[40]=12;s->directions[40]=2;s->phase=40*128;
 if(w->color_index==15)w->color_index=0;if(!color)w->color_index=0;
 s->color=colors[w->color_index++];random_turn(w,s);
 w->active[p]=1;w->passes[p]=0;return 1;
}
unsigned nw4_slot_lead(unsigned u){if(u>100)return 0;if(!u)u=1;return (1280/((9*u)/100+1))/128;}
static void emit(nw4_world *w,nw4_write_fn cb,void *ctx,unsigned kind,unsigned x,unsigned y,unsigned value) {
 if((kind==NW4_ATTRIBUTE||kind==NW4_CHARACTER)&&x<80&&y<25) {
  if(kind==NW4_ATTRIBUTE)w->attributes[y*80+x]=(uint8_t)value;
  else w->characters[y*80+x]=(uint8_t)value;
 }
 if(cb)cb(ctx,kind,x,y,value);
}
int nw4_tick(nw4_world *w,unsigned p,unsigned u,nw4_write_fn cb,void *ctx) {
 if(!w||p>=32||!w->active[p]||u>100)return 0;
 snake *s=&w->snakes[p];emit(w,cb,ctx,NW4_BEGIN,0,0,0);
 for(int stage=4;stage>=0;--stage) {
  unsigned cur=s->cursor[stage];
  if(s->xs[cur]<81) {
   unsigned x=s->xs[cur],y=s->ys[cur];
   emit(w,cb,ctx,NW4_ATTRIBUTE,x,y,s->color);
   emit(w,cb,ctx,NW4_CHARACTER,x,y,s->glyph[stage]);
   emit(w,cb,ctx,NW4_ATTRIBUTE,x+1,y,s->color);
   emit(w,cb,ctx,NW4_CHARACTER,x+1,y,s->glyph[stage]);
   if(!stage) {
    unsigned reverse=(s->heading+4)%8;int x1,y1;
    for(;;) {
     x1=(int)s->x+s->dx[s->heading];y1=(int)s->y+s->dy[s->heading];
     if(x1>=0&&x1<=78&&y1>=0&&y1<=24&&s->heading!=reverse)break;
     s->heading=retry[nw4_random(w)%12];
    }
    s->x=(unsigned)x1;s->y=(unsigned)y1;
    unsigned load=u?u:1,d=1280/((9*load)/100+1),slot=((s->phase+d)>>7)%51;
    s->xs[slot]=(uint8_t)x1;s->ys[slot]=(uint8_t)y1;s->directions[slot]=(uint8_t)s->heading;
   }
   if(stage==4){s->xs[cur]=255;s->ys[cur]=255;}
  }
  if(!stage){s->phase=(s->phase+128)%(51*128);s->cursor[0]=s->phase>>7;}
  else s->cursor[stage]=(cur+1)%51;
 }
 emit(w,cb,ctx,NW4_END,0,0,0);
 if(++w->passes[p]%40==0)random_turn(w,s);
 return 1;
}
static void put32(uint8_t *p,uint32_t v){for(unsigned i=0;i<4;++i)p[i]=(uint8_t)(v>>(i*8));}
int nw4_state(const nw4_world *w,unsigned p,uint8_t out[284]) {
 if(!w||p>=32||!w->active[p]||!out)return 0;
 const snake *s=&w->snakes[p];
 /* 30 scalar words precede the byte arrays. Explicit copies avoid aliasing. */
 for(unsigned i=0;i<30;++i){uint32_t v;memcpy(&v,(const uint8_t *)s+4*i,4);put32(out+4*i,v);}
 memcpy(out+120,(const uint8_t *)s+120,164);return 1;
}
void nw4_random_state(const nw4_world *w,uint8_t out[118]) {
 for(unsigned i=0;i<55;++i){out[2*i]=(uint8_t)w->random_words[i];out[2*i+1]=(uint8_t)(w->random_words[i]>>8);}
 put32(out+110,w->ri);put32(out+114,w->rj);
}
const uint8_t *nw4_characters(const nw4_world *w){return w?w->characters:NULL;}
const uint8_t *nw4_attributes(const nw4_world *w){return w?w->attributes:NULL;}

int nw4_activate(nw4_world *w,unsigned processors) {
 if(!w||!processors||processors>32)return 0;
 memset(w->active,0,sizeof w->active);memset(w->passes,0,sizeof w->passes);
 memset(w->snakes,0,sizeof w->snakes);memset(w->characters,32,sizeof w->characters);
 memset(w->attributes,0,sizeof w->attributes);nw4_reset_colors(w);
 /* Verified from the supplied SERVER and NWSNUT instruction chain. */
 const uint8_t glyphs[5]={0xdb,0xb2,0xb1,0xb0,0x20};
 for(unsigned p=0;p<processors;++p)if(!nw4_init(w,p,1,glyphs))return 0;
 return 1;
}
