#import <Foundation/Foundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

#include <unistd.h>

typedef struct __IOHIDEvent* IOHIDEventRef;
typedef struct __IOHIDServiceClient* IOHIDServiceClientRef;
typedef double IOHIDFloat;

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
CFStringRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

NSDictionary* matching(int page, int usage)
{
    NSDictionary* dict = @ {
        @"PrimaryUsagePage" : [NSNumber numberWithInt:page],
        @"PrimaryUsage" : [NSNumber numberWithInt:usage],
    };
    return dict;
}

NSArray* getProductNames(NSDictionary* sensors)
{
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)sensors);
    NSArray* matchingsrvs = (__bridge NSArray*)IOHIDEventSystemClientCopyServices(system);

    long count = [matchingsrvs count];
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef sc = (IOHIDServiceClientRef)matchingsrvs[i];
        NSString* name = (NSString*)IOHIDServiceClientCopyProperty(sc, (__bridge CFStringRef) @"Product");
        if (name) {
            [array addObject:name];
        } else {
            [array addObject:@"noname"];
        }
    }

    return array;
}

#define IOHIDEventFieldBase(type) (type << 16)
#define kIOHIDEventTypeTemperature 15
#define kIOHIDEventTypePower 25

NSArray* getPowerValues(NSDictionary* sensors)
{
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)sensors);
    NSArray* matchingsrvs = (NSArray*)IOHIDEventSystemClientCopyServices(system);

    long count = [matchingsrvs count];
    NSMutableArray* array = [[NSMutableArray alloc] init];
    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef sc = (IOHIDServiceClientRef)matchingsrvs[i];
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypePower, 0, 0);

        NSNumber* value;
        double temp = 0.0;
        if (event != 0) {
            temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypePower)) / 1000.0;
        }
        value = [NSNumber numberWithDouble:temp];
        [array addObject:value];
    }

    return array;
}

NSArray* getThermalValues(NSDictionary* sensors)
{
    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)sensors);
    NSArray* matchingsrvs = (__bridge NSArray*)IOHIDEventSystemClientCopyServices(system);

    long count = [matchingsrvs count];
    NSMutableArray* array = [[NSMutableArray alloc] init];

    for (int i = 0; i < count; i++) {
        IOHIDServiceClientRef sc = (IOHIDServiceClientRef)matchingsrvs[i];
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(sc, kIOHIDEventTypeTemperature, 0, 0);

        NSNumber* value;
        double temp = 0.0;
        if (event != 0) {
            temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        }
        value = [NSNumber numberWithDouble:temp];
        [array addObject:value];
    }

    return array;
}

void dumpPairs(NSArray* kvs, NSString* cat) {
    int count = [kvs count];
    for (int i = 0; i < count; i++) {
        if (i > 0)
            printf("\n");
        printf("%s = %lf %s", 
            [[kvs[i] firstObject] UTF8String], 
            [[kvs[i] lastObject] doubleValue],
            [cat UTF8String]); 
    }
}

NSArray* sortKeyValuePairs(NSArray* keys, NSArray* values)
{

    NSMutableArray* unsorted_array = [[NSMutableArray alloc] init];
    for (int i = 0; i < [keys count]; i++) {
        [unsorted_array addObject:[[NSArray alloc] initWithObjects:keys[i], values[i], nil]];
    }

    NSArray* sortedArray = [unsorted_array sortedArrayUsingComparator:^(id obj1, id obj2) {
        return [[obj1 firstObject] compare:[obj2 firstObject]];
    }];

    return sortedArray;
}

void usage()
{
    printf("-t: show temperature meter values\n");
    printf("-c: show current meter values\n");
    printf("-v: show voltage meter values\n");
    return;
}

int main(int argc, char* argv[])
{

    bool show_voltage = false, show_current = false, show_temperature = false;
    int ch;

    while ((ch = getopt(argc, argv, "cvt")) != -1) {
        switch (ch) {
        case 'v':
            show_voltage = true;
            break;
        case 'c':
            show_current = true;
            break;
        case 't':
            show_temperature = true;
            break;
        default:
            usage();
            exit(-1);
        }
    }
    argc -= optind;
    argv += optind;

    //  Magics:
    //    See IOHIDFamily/AppleHIDUsageTables.h for more information
    //    https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-701.60.2/IOHIDFamily/AppleHIDUsageTables.h.auto.html

    //    kHIDPage_AppleVendor                        = 0xff00,
    //    kHIDPage_AppleVendorTemperatureSensor       = 0xff05,
    //    kHIDPage_AppleVendorPowerSensor             = 0xff08,
    //
    //    kHIDUsage_AppleVendor_TemperatureSensor     = 0x0005,
    //    kHIDUsage_AppleVendorPowerSensor_Current    = 0x0002,
    //    kHIDUsage_AppleVendorPowerSensor_Voltage    = 0x0003,
    //  ------------------------------

    NSDictionary* currentSensors = matching(0xff08, 0x0002);
    NSDictionary* voltageSensors = matching(0xff08, 0x0003);
    NSDictionary* thermalSensors = matching(0xff00, 0x0005);

    NSArray* currentNames = getProductNames(currentSensors);
    NSArray* voltageNames = getProductNames(voltageSensors);
    NSArray* thermalNames = getProductNames(thermalSensors);

    NSArray* currentValues = getPowerValues(currentSensors);
    NSArray* voltageValues = getPowerValues(voltageSensors);
    NSArray* thermalValues = getThermalValues(thermalSensors);

    NSArray* sortedCurrent = sortKeyValuePairs(currentNames, currentValues);
    NSArray* sortedVoltage = sortKeyValuePairs(voltageNames, voltageValues);
    NSArray* sortedThermal = sortKeyValuePairs(thermalNames, thermalValues);

    if (!show_voltage && !show_current && !show_temperature) {
        usage();
        return 0;
    }

    if (show_voltage) {
        dumpPairs(sortedVoltage, @"V");
    }
    if (show_current) {
        dumpPairs(sortedCurrent, @"A");
    }
    if (show_temperature) {
        dumpPairs(sortedThermal, @"°C");
    }

    CFRelease(currentValues);
    CFRelease(voltageValues);
    CFRelease(thermalValues);

    printf("\n");
    
    return 0;
}
