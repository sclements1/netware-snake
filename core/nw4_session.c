#include "nw4_session.h"
#include <stdlib.h>
#include <string.h>
struct nw4_session {nw4_world *world;unsigned processors;uint64_t intervals;};
unsigned nw4_processor_count(unsigned host,int allow32){
 unsigned cap=allow32?32:31;return host? (host<cap?host:cap):1;
}
nw4_session *nw4_session_create(void){
 nw4_session *s=calloc(1,sizeof *s);if(!s)return NULL;
 s->world=nw4_create();if(!s->world){free(s);return NULL;}return s;
}
void nw4_session_destroy(nw4_session *s){if(s){nw4_destroy(s->world);free(s);}}
int nw4_session_start(nw4_session *s,unsigned host,int allow32){
 if(!s)return 0;
 s->processors=nw4_processor_count(host,allow32);s->intervals=0;
 return nw4_activate(s->world,s->processors);
}
int nw4_session_tick(nw4_session *s,const unsigned *loads,unsigned n){
 if(!s||!s->processors)return 0;
 uint8_t chars[2000],attrs[2000];
 memcpy(chars,nw4_characters(s->world),2000);memcpy(attrs,nw4_attributes(s->world),2000);
 for(unsigned p=0;p<s->processors;++p)if(s->intervals>=4*p){
  unsigned u=loads&&p<n?loads[p]:0;
  if(u>100)u=100; /* Adapter input contract; original accepts an OS percentage. */
  nw4_tick(s->world,p,u,NULL,NULL);
 }
 ++s->intervals;
 return memcmp(chars,nw4_characters(s->world),2000)!=0 ||
        memcmp(attrs,nw4_attributes(s->world),2000)!=0;
}
unsigned nw4_session_processors(const nw4_session *s){return s?s->processors:0;}
uint64_t nw4_session_intervals(const nw4_session *s){return s?s->intervals:0;}
const uint8_t *nw4_session_characters(const nw4_session *s){return s?nw4_characters(s->world):NULL;}
const uint8_t *nw4_session_attributes(const nw4_session *s){return s?nw4_attributes(s->world):NULL;}
