#import "NWCPUReader.h"
#import <mach/mach.h>
#import <mach/mach_host.h>

@implementation NWCPUReader {
    uint32_t _lastTicks[CPU_STATE_MAX];
    BOOL _hasSample;
    CFTimeInterval _lastTime;
    double _usage;
}
+ (instancetype)sharedReader {
    static NWCPUReader *reader;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ reader=[[self alloc] init]; });
    return reader;
}
- (double)aggregateUsageAtTime:(CFTimeInterval)now {
    @synchronized(self) {
        if (_hasSample && now-_lastTime<0.50)return _usage;
        host_cpu_load_info_data_t sample;
        mach_msg_type_number_t count=HOST_CPU_LOAD_INFO_COUNT;
        host_t port=mach_host_self();
        kern_return_t status=host_statistics(port,HOST_CPU_LOAD_INFO,(host_info_t)&sample,&count);
        mach_port_deallocate(mach_task_self(),port);
        if (status!=KERN_SUCCESS)return _usage;
        if (_hasSample) {
            uint64_t idle=0,total=0;
            for (int i=0;i<CPU_STATE_MAX;i++) {
                /* Wrap-safe subtraction for 32-bit Mach tick counters. */
                uint32_t delta=sample.cpu_ticks[i]-_lastTicks[i];
                total+=delta;
                if (i==CPU_STATE_IDLE)idle+=delta;
            }
            if (total>0) _usage=100.0*(double)(total-idle)/(double)total;
        }
        for(int i=0;i<CPU_STATE_MAX;i++)_lastTicks[i]=sample.cpu_ticks[i];
        _hasSample=YES;_lastTime=now;
        if(_usage<0)_usage=0;
        if(_usage>100)_usage=100;
        return _usage;
    }
}
@end
