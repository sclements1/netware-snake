#include "nw4_snake.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
int main(void){
 const int cols=640,rows=300;size_t n=(size_t)cols*rows;
 uint8_t *mask=calloc(n,1);assert(mask);
 /* Start above byte-coordinate limits, with a connected seam and a hole. */
 for(int y=260;y<rows;y++)for(int x=280;x<cols;x++)mask[(size_t)y*cols+x]=1;
 nw4_world *w=nw4_create_grid(cols,rows);assert(w&&nw4_set_domain(w,mask,n));
 assert(nw4_activate_with_options(w,32,31));
 unsigned palette[15]={12,9,10,11,13,7,4,1,2,3,6,14,5,8,15};
 for(unsigned p=0;p<32;p++){
  uint8_t state[284];assert(nw4_state(w,p,state));assert(state[100]==palette[(31+p)%15]);
 }
 for(unsigned t=0;t<600;t++){
  for(unsigned p=0;p<32;p++){
   assert(nw4_tick(w,p,(t+p)%101,NULL,NULL));
   int x=nw4_x(w,p),y=nw4_y(w,p);assert(x>=280&&x<cols-1&&y>=260&&y<rows);
   for(unsigned h=0;h<51;h++){
    int hx=nw4_history_x(w,p,h),hy=nw4_history_y(w,p,h);
    if(hx>=0)assert(hx>=280&&hx<cols-1&&hy>=260&&hy<rows);
   }
  }
  const uint8_t *raw=nw4_characters(w),*protected=nw4_protected_characters(w),*visited=nw4_visited(w);
  for(size_t i=0;i<n;i++)if(!mask[i])assert(raw[i]==32&&protected[i]==32&&!visited[i]);
 }
 nw4_destroy(w);free(mask);puts("Enhanced 4.2: 19,200 wide-coordinate/domain passes and 32 shifted colors PASS");return 0;
}
