#import "NWCPUReader.h"
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <math.h>

@implementation NWCPUReader {
    uint32_t _lastTicks[CPU_STATE_MAX];
    BOOL _hasSample;
    CFTimeInterval _lastTime;
    double _usage;
    NSMutableData *_previousProcessorTicks;
    NSArray<NSNumber *> *_processorUsages;
    CFTimeInterval _lastProcessorTime;
    BOOL _hasProcessorTime;
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
- (NSUInteger)hostProcessorCount {
    @synchronized(self) {
        if (_processorUsages.count)return _processorUsages.count;
        return MAX((NSUInteger)1, NSProcessInfo.processInfo.processorCount);
    }
}
- (NSArray<NSNumber *> *)processorUsagesAtTime:(CFTimeInterval)now {
    @synchronized(self) {
        if (_hasProcessorTime && now-_lastProcessorTime<0.5)return _processorUsages?:@[];
        _lastProcessorTime=now;_hasProcessorTime=YES;
        natural_t processors=0;
        processor_info_array_t info=NULL;
        mach_msg_type_number_t count=0;
        host_t port=mach_host_self();
        kern_return_t status=host_processor_info(port,PROCESSOR_CPU_LOAD_INFO,
                                                &processors,&info,&count);
        mach_port_deallocate(mach_task_self(),port);
        if (status!=KERN_SUCCESS || !info || !processors ||
            (uint64_t)processors*CPU_STATE_MAX>count) {
            if(info)vm_deallocate(mach_task_self(),(vm_address_t)info,
                                 (vm_size_t)count*sizeof(integer_t));
            if (!_processorUsages) {
                NSMutableArray *zeros=[NSMutableArray array];
                for(NSUInteger p=0;p<[self hostProcessorCount];p++)[zeros addObject:@0];
                _processorUsages=[zeros copy];
            }
            return _processorUsages;
        }
        const NSUInteger bytes=(NSUInteger)processors*CPU_STATE_MAX*sizeof(uint32_t);
        BOOL baseline=(_previousProcessorTicks.length==bytes);
        const uint32_t *previous=_previousProcessorTicks.bytes;
        const uint32_t *current=(const uint32_t *)info;
        NSMutableArray<NSNumber *> *loads=[NSMutableArray arrayWithCapacity:processors];
        for(natural_t p=0;p<processors;p++) {
            uint64_t idle=0,total=0;
            if(baseline)for(int state=0;state<CPU_STATE_MAX;state++) {
                NSUInteger i=(NSUInteger)p*CPU_STATE_MAX+state;
                uint32_t delta=current[i]-previous[i];
                total+=delta;if(state==CPU_STATE_IDLE)idle=delta;
            }
            double value=total?100.0*(double)(total-idle)/(double)total:0;
            [loads addObject:@(fmax(0,fmin(100,value)))];
        }
        _previousProcessorTicks=[NSMutableData dataWithBytes:current length:bytes];
        vm_deallocate(mach_task_self(),(vm_address_t)info,(vm_size_t)count*sizeof(integer_t));
        _processorUsages=[loads copy];return _processorUsages;
    }
}
@end
