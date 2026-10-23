#include "nw4_snake.h"
#include "nw4_session.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
static unsigned writes;
static void event(void *ctx,unsigned kind,unsigned x,unsigned y,unsigned value){
 (void)ctx;assert(kind<=3);if(kind>=2){assert(x<80&&y<25);assert(value<=255);}++writes;
}
int main(void){
 nw4_world *w=nw4_create();assert(w);uint8_t glyph[5]={219,178,177,176,32};
 for(unsigned p=0;p<32;++p)assert(nw4_init(w,p,1,glyph));
 for(unsigned t=0;t<5000;++t)for(unsigned p=0;p<32;++p)
  assert(nw4_tick(w,p,(t*7+p*13)%101,event,0));
 uint8_t out[284],rng[118];for(unsigned p=0;p<32;++p)assert(nw4_state(w,p,out));
 nw4_random_state(w,rng);assert(!nw4_tick(w,32,0,event,0));assert(!nw4_tick(w,0,101,event,0));
 assert(!nw4_init(w,32,1,glyph));assert(!nw4_state(w,32,out));
 nw4_destroy(w);
 nw4_session *session=nw4_session_create();assert(session);
 for(unsigned activation=0;activation<40;activation++) {
  assert(nw4_session_start(session,64,activation%2));
  unsigned loads[32];
  for(unsigned t=0;t<500;t++) {
   for(unsigned p=0;p<32;p++)loads[p]=(p*13+t*7)%150;
   nw4_session_tick(session,loads,32);
   const uint8_t *chars=nw4_session_characters(session),*attrs=nw4_session_attributes(session);
   for(unsigned i=0;i<2000;i++) {
    assert(chars[i]==32||chars[i]==219||chars[i]==178||chars[i]==177||chars[i]==176);
    assert(attrs[i]<16);
   }
  }
 }
 nw4_session_destroy(session);
 printf("PASS 160000 portable passes and 20000 session intervals with sanitizers; %u drawing events\n",writes);
}
