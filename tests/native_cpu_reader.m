/* Exercise actual sampling code with synthetic Mach counters, including wrap,
   caching, per-core asymmetry, topology changes and failed reads. */
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import "NWCPUReader.h"
#include <assert.h>
#include <math.h>
static uint32_t ticks[3][CPU_STATE_MAX];
static natural_t processorCount=2;
static BOOL failRead=NO;
static unsigned calls;
kern_return_t host_processor_info(host_t host,processor_flavor_t flavor,
    natural_t *count,processor_info_array_t *info,mach_msg_type_number_t *infoCount) {
    (void)host;assert(flavor==PROCESSOR_CPU_LOAD_INFO);calls++;
    if(failRead)return KERN_FAILURE;
    *count=processorCount;*infoCount=processorCount*CPU_STATE_MAX;
    vm_address_t data=0;
    assert(vm_allocate(mach_task_self(),&data,*infoCount*sizeof(integer_t),VM_FLAGS_ANYWHERE)==KERN_SUCCESS);
    memcpy((void *)data,ticks,*infoCount*sizeof(integer_t));*info=(processor_info_array_t)data;
    return KERN_SUCCESS;
}
static void expect(NSArray<NSNumber *> *a,double x,double y) {
    assert(a.count==2);assert(fabs(a[0].doubleValue-x)<0.001);assert(fabs(a[1].doubleValue-y)<0.001);
}
int main(void) {
    @autoreleasepool {
        NWCPUReader *reader=[NWCPUReader new];
        ticks[0][CPU_STATE_USER]=UINT32_MAX-10;
        expect([reader processorUsagesAtTime:1],0,0);
        ticks[0][CPU_STATE_USER]=9; /* 20 busy ticks across wrap */
        ticks[1][CPU_STATE_IDLE]=20;
        expect([reader processorUsagesAtTime:1.49],0,0);assert(calls==1);
        expect([reader processorUsagesAtTime:1.5],100,0);assert(calls==2);
        ticks[0][CPU_STATE_USER]+=5;ticks[0][CPU_STATE_IDLE]+=15;
        ticks[1][CPU_STATE_USER]+=15;ticks[1][CPU_STATE_IDLE]+=5;
        expect([reader processorUsagesAtTime:2],25,75);
        expect([reader processorUsagesAtTime:2.5],0,0); /* zero delta */
        failRead=YES;expect([reader processorUsagesAtTime:3],0,0);
        failRead=NO;processorCount=3;
        NSArray *a=[reader processorUsagesAtTime:3.5];
        assert(a.count==3);for(NSNumber *n in a)assert(n.doubleValue==0);
        assert(reader.hostProcessorCount==3);
        failRead=YES;NWCPUReader *fresh=[NWCPUReader new];
        a=[fresh processorUsagesAtTime:1];assert(a.count>=1);
        for(NSNumber *n in a)assert(n.doubleValue==0);
        puts("Native per-CPU reader: baseline, cache, wrap, asymmetric loads, topology and failure PASS");
    }
    return 0;
}
