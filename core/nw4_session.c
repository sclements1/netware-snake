#include "nw4_session.h"
#include <stdlib.h>
#include <string.h>
struct nw4_session {nw4_world *world;unsigned processors;uint64_t intervals;uint8_t *snapshot;int enhanced;};
unsigned nw4_processor_count(unsigned host,int allow32){
 unsigned cap=allow32?32:31;return host?(host<cap?host:cap):1;
}
nw4_session *nw4_session_create_grid(int columns,int rows){
 nw4_session *s=calloc(1,sizeof *s);if(!s)return NULL;
 s->world=nw4_create_grid(columns,rows);
 if(!s->world){free(s);return NULL;}
 s->snapshot=malloc((size_t)columns*(size_t)rows*5);
 if(!s->snapshot){nw4_session_destroy(s);return NULL;}return s;
}
nw4_session *nw4_session_create(void){return nw4_session_create_grid(80,25);}
void nw4_session_destroy(nw4_session *s){if(s){nw4_destroy(s->world);free(s->snapshot);free(s);}}
int nw4_session_start(nw4_session *s,unsigned host,int allow32){
 if(!s)return 0;
 unsigned count=nw4_processor_count(host,allow32);
 if(!nw4_activate(s->world,count))return 0;
 s->processors=count;s->intervals=0;s->enhanced=0;return 1;
}
int nw4_session_start_configured(nw4_session *s,unsigned count,unsigned color_start){
 if(!s||!nw4_activate_with_options(s->world,count,color_start))return 0;
 s->processors=count;s->intervals=0;s->enhanced=1;return 1;
}
int nw4_session_set_domain(nw4_session *s,const uint8_t *mask,size_t length){
 if(!s||!nw4_set_domain(s->world,mask,length))return 0;
 s->processors=0;s->intervals=0;return 1;
}
int nw4_session_tick(nw4_session *s,const unsigned *loads,unsigned n){
 if(!s||!s->processors)return 0;
 size_t length=(size_t)nw4_columns(s->world)*(size_t)nw4_rows(s->world);
 memcpy(s->snapshot,nw4_characters(s->world),length);memcpy(s->snapshot+length,nw4_attributes(s->world),length);
 if(s->enhanced){
  memcpy(s->snapshot+2*length,nw4_protected_characters(s->world),length);
  memcpy(s->snapshot+3*length,nw4_protected_attributes(s->world),length);
  memcpy(s->snapshot+4*length,nw4_visited(s->world),length);
 }
 for(unsigned p=0;p<s->processors;p++)if(s->intervals>=4*p){
  unsigned u=loads&&p<n?loads[p]:0;if(u>100)u=100;
  nw4_tick(s->world,p,u,NULL,NULL);
 }
 ++s->intervals;
 int changed=memcmp(s->snapshot,nw4_characters(s->world),length)!=0||
  memcmp(s->snapshot+length,nw4_attributes(s->world),length)!=0;
 if(s->enhanced)changed=changed||memcmp(s->snapshot+2*length,nw4_protected_characters(s->world),length)!=0||
  memcmp(s->snapshot+3*length,nw4_protected_attributes(s->world),length)!=0||
  memcmp(s->snapshot+4*length,nw4_visited(s->world),length)!=0;
 return changed;
}
unsigned nw4_session_processors(const nw4_session *s){return s?s->processors:0;}
uint64_t nw4_session_intervals(const nw4_session *s){return s?s->intervals:0;}
int nw4_session_columns(const nw4_session *s){return s?nw4_columns(s->world):0;}
int nw4_session_rows(const nw4_session *s){return s?nw4_rows(s->world):0;}
const uint8_t *nw4_session_characters(const nw4_session *s){return s?nw4_characters(s->world):NULL;}
const uint8_t *nw4_session_attributes(const nw4_session *s){return s?nw4_attributes(s->world):NULL;}
const uint8_t *nw4_session_protected_characters(const nw4_session *s){return s?nw4_protected_characters(s->world):NULL;}
const uint8_t *nw4_session_protected_attributes(const nw4_session *s){return s?nw4_protected_attributes(s->world):NULL;}
const uint8_t *nw4_session_visited(const nw4_session *s){return s?nw4_visited(s->world):NULL;}
