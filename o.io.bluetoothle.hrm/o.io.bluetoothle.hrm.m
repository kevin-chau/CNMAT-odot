#define OMAX_DOC_NAME "o.io.bluetoothle.hrm"
#define OMAX_DOC_SHORT_DESC "Outputs OSC data from a Bluetooth LE heart rate monitor."
#define OMAX_DOC_LONG_DESC "Reports OSC data from a Bluetooth LE heart rate monitor."
#define OMAX_DOC_INLETS_DESC (char *[]){""}
#define OMAX_DOC_OUTLETS_DESC (char *[]){"OSC packet."}
#define OMAX_DOC_SEEALSO (char *[]){""}

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <IOBluetooth/IOBluetooth.h>
//#import <QuartzCore/QuartzCore.h>
#include "ext.h"
#include "ext_obex.h"
#include "ext_obex_util.h"
#include "osc.h"
#include "osc_mem.h"
#include "omax_util.h"
#include "omax_doc.h"
#include "omax_dict.h"
#include "o.h"
#include "odot_version.h"

t_symbol *ps_FullPacket;

void ohrm_replaceSpacesWithSlashes(long len, char *buf)
{
	char *ptr = buf;
	while(ptr - buf < len && *ptr != '\0'){
		if(*ptr == ' '){
			*ptr = '/';
		}
		ptr++;
	}
}

@interface HeartRateMonitor : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> 
{
	CBCentralManager *manager;
	struct _ohrm *maxobj;
}

// max object
typedef struct _ohrm
{
	t_object o;
	HeartRateMonitor *hrm;
	void *outlet;
} t_ohrm;

// max object forward decls
void ohrm_outputOSCBundle(t_ohrm *x, t_symbol *msg, int argc, t_atom *argv);

@property (retain) CBCentralManager *manager;

- (void) startScan;
- (void) stopScan;
- (BOOL) isLECapableHardware;
- (void) computeHeartRate:(NSData *)data peripheral:(CBPeripheral *)p OSCBundle:(t_osc_bndl_u *)b;
- (t_symbol *) makeOSCAddressFromPeripheral:(CBPeripheral *)p withPrefix:(const char *)prefix withPostfix:(const char *)postfix;
- (void)ohrm_init:(struct _ohrm *)x;


@end

@implementation HeartRateMonitor
@synthesize manager;

- (void) dealloc
{
	[self stopScan];
	[manager release];
	[super dealloc];
}

#pragma mark - Heart Rate Data

- (void) computeHeartRate:(NSData *)data peripheral:(CBPeripheral *)p OSCBundle:(t_osc_bndl_u *)b
{
	const uint8_t *reportData = [data bytes];
	uint8_t *ptr = reportData + 1;

	// would be great to put this in the bundle as a blob!
	/*
	for(int i = 0; i < [data length]; i++){
		printf("0x%x ", reportData[i]);
	}
	printf("\n");
	*/

	//uint16_t bpm = 0;
    
	t_osc_msg_u *bpm = osc_message_u_alloc();
	osc_bundle_u_addMsg(b, bpm);
	osc_message_u_setAddress(bpm, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/heartrate"]->s_name);
	// heart rate can be reported as either an 8-bit or 16-bit unsigned int
	if((reportData[0] & 0x01) == 0){
		// uint8 bpm
		osc_message_u_appendInt32(bpm, *ptr);
		ptr++;
	}else{
		// uint16 bpm
		osc_message_u_appendInt32(bpm, CFSwapInt16LittleToHost(*(uint16_t *)ptr));
		ptr += 2;
	}

	t_osc_msg_u *scsupport = osc_message_u_alloc();
	osc_bundle_u_addMsg(b, scsupport);
	osc_message_u_setAddress(scsupport, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/sensorcontact/support"]->s_name);
	switch((reportData[0] >> 1) & 0x03){
	case 0: // not supported
	case 1: // not supported
		osc_message_u_appendFalse(scsupport);
		break;
	case 2: // supported but not connected
		osc_message_u_appendTrue(scsupport);
		{
			t_osc_msg_u *scstatus = osc_message_u_alloc();
			osc_bundle_u_addMsg(b, scstatus);
			osc_message_u_setAddress(scstatus, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/sensorcontact/status"]->s_name);
			osc_message_u_appendFalse(scstatus);
		}
		break;
	case 3: // supported and connected
		osc_message_u_appendTrue(scsupport);
		{
			t_osc_msg_u *scstatus = osc_message_u_alloc();
			osc_bundle_u_addMsg(b, scstatus);
			osc_message_u_setAddress(scstatus, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/sensorcontact/status"]->s_name);
			osc_message_u_appendTrue(scstatus);
		}
		break;
	}

	t_osc_msg_u *eesupport = osc_message_u_alloc();
	osc_bundle_u_addMsg(b, eesupport);
	osc_message_u_setAddress(eesupport, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/energyexpended/support"]->s_name);
	if(!(reportData[0] & 0x08)){
		osc_message_u_appendFalse(eesupport);
	}else{
		osc_message_u_appendTrue(eesupport);
		t_osc_msg_u *eestatus = osc_message_u_alloc();
		osc_bundle_u_addMsg(b, eestatus);
		osc_message_u_setAddress(eestatus, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/energyexpended/kJoules"]->s_name);
		osc_message_u_appendInt32(eestatus, CFSwapInt16LittleToHost(*(uint16_t *)ptr));
		ptr += 2;
	}

	t_osc_msg_u *rrsupport = osc_message_u_alloc();
	osc_bundle_u_addMsg(b, rrsupport);
	osc_message_u_setAddress(rrsupport, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/rrinterval/support"]->s_name);
	if(!(reportData[0] & 0x10)){
		osc_message_u_appendFalse(rrsupport);
	}else{
		osc_message_u_appendTrue(rrsupport);
		t_osc_msg_u *rrstatus = osc_message_u_alloc();
		osc_bundle_u_addMsg(b, rrstatus);
		osc_message_u_setAddress(rrstatus, [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/rrinterval/seconds"]->s_name);
		while(ptr - reportData < [data length]){
			double rr = (double)CFSwapInt16LittleToHost(*(uint16_t *)ptr);
			osc_message_u_appendDouble(rrstatus, rr / 1024.);
			ptr += 2;
		}
	}
}

- (t_symbol *) makeOSCAddressFromPeripheral:(CBPeripheral *)p withPrefix:(const char *)prefix withPostfix:(const char *)postfix
{
	const char *name = [p.name UTF8String];
	char buf[128];
	if(prefix && postfix){
		sprintf(buf, "%s/%s%s", prefix, name, postfix);
	}else if(prefix){
		sprintf(buf, "%s/%s", prefix, name);
	}else if(postfix){
		sprintf(buf, "/%s%s", name, postfix);
	}else{
		sprintf(buf, "/%s", name);
	}
	char *ptr = buf;
	while(*ptr != '\0' && ptr - buf < sizeof(buf)){
		if(*ptr == ' '){
			*ptr = '/';
		}
		ptr++;
	}
	return gensym(buf);
}

- (t_osc_msg_u *) makeOSCSelfMessage:(CBPeripheral *)p
{
	t_osc_msg_u *m = osc_message_u_alloc();
	osc_message_u_setAddress(m, "/self");
	t_symbol *s = [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:NULL];
	osc_message_u_appendString(m, s->s_name);
	return m;
}

- (void) sendOSCStatusBundle:(CBPeripheral *)p status:(const char *)status
{
	t_osc_bndl_u *b = osc_bundle_u_alloc();
	t_osc_msg_u *m = osc_message_u_alloc();
	t_symbol *s = [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:"/status"];
	osc_message_u_setAddress(m, s->s_name);
	osc_message_u_appendString(m, status);
	osc_bundle_u_addMsg(b, m);
	t_osc_msg_u *mself = osc_message_u_alloc();
	osc_message_u_setAddress(mself, "/self");
	s = [self makeOSCAddressFromPeripheral:p withPrefix:NULL withPostfix:NULL];
	osc_message_u_appendString(mself, s->s_name);
	osc_bundle_u_addMsg(b, mself);
	long len = 0;
	char *buf = NULL;
	osc_bundle_u_serialize(b, &len, &buf);
	if(buf){
		t_atom a[2];
		atom_setlong(a, len);
		atom_setlong(a + 1, (long)buf);
		schedule_delay(maxobj, (method)ohrm_outputOSCBundle, 0, ps_FullPacket, 2, a);
		osc_bundle_u_free(b);
		// don't free buf here!!!
	}
}

#pragma mark - Start/Stop Scan methods

- (BOOL) isLECapableHardware
{
	NSString * state = nil;

	switch ([manager state]) 
		{
		case CBCentralManagerStateUnsupported:
			state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
			break;
		case CBCentralManagerStateUnauthorized:
			state = @"The app is not authorized to use Bluetooth Low Energy.";
			break;
		case CBCentralManagerStatePoweredOff:
			state = @"Bluetooth is currently powered off.";
			break;
		case CBCentralManagerStatePoweredOn:
			return TRUE;
		case CBCentralManagerStateUnknown:
		default:
			return FALSE;
            
		}
    
	NSLog(@"Central manager state: %@", state);
	return FALSE;
}

- (void) startScan 
{
	[manager scanForPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:@"180D"]] options:nil];
}

- (void) stopScan 
{
	[manager stopScan];
}

#pragma mark - CBCentralManager delegate methods

// Invoked whenever the central manager's state is updated.
- (void) centralManagerDidUpdateState:(CBCentralManager *)central 
{
	[self isLECapableHardware];
}
    
// Invoked when the central discovers heart rate peripheral while scanning.
- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI 
{    
	[aPeripheral retain];
	[manager connectPeripheral:aPeripheral options: nil];
	[self startScan];
}

// Invoked when the central manager retrieves the list of known peripherals.
// Automatically connect to first known peripheral
// this method should no longer be called...
- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{
	NSLog(@"%s\n", __func__);
}

// Invoked whenever a connection is succesfully created with the peripheral. 
// Discover available services on the peripheral
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral 
{    
	[self sendOSCStatusBundle:aPeripheral status:"connected"];
	[aPeripheral setDelegate:self];
	[aPeripheral discoverServices:nil];
}

// Invoked whenever an existing connection with the peripheral is torn down. 
// Reset local variables
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
	[self sendOSCStatusBundle:aPeripheral status:"disconnected"];
	[aPeripheral setDelegate:nil];
	[aPeripheral release];
}

// Invoked whenever the central manager fails to create a connection with the peripheral.
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
	[self sendOSCStatusBundle:aPeripheral status:"disconnected"];
	[aPeripheral setDelegate:nil];
	[aPeripheral release];
}

/*
2013-09-20 15:40:12.492 Max[51380:707] -[HeartRateMonitor peripheral:didDiscoverServices:]: Generic Access Profile
2013-09-20 15:40:12.492 Max[51380:707] -[HeartRateMonitor peripheral:didDiscoverServices:]: Generic Attribute Profile
2013-09-20 15:40:12.493 Max[51380:707] -[HeartRateMonitor peripheral:didDiscoverServices:]: Unknown (<180d>) heart rate
2013-09-20 15:40:12.493 Max[51380:707] -[HeartRateMonitor peripheral:didDiscoverServices:]: Unknown (<180a>) device info
2013-09-20 15:40:12.493 Max[51380:707] -[HeartRateMonitor peripheral:didDiscoverServices:]: Unknown (<180f>) battery service
2013-09-20 15:40:12.493 Max[51380:707] -[HeartRateMonitor peripheral:didDiscoverServices:]: Unknown (<6217ff49 ac7b547e eecf016a 06970ba9>)
 */

#pragma mark - CBPeripheral delegate methods
// Invoked upon completion of a -[discoverServices:] request.
// Discover available characteristics on interested services
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error 
{
	for(CBService *aService in aPeripheral.services){
		// Heart Rate Service
		if([aService.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]){
			[aPeripheral discoverCharacteristics:nil forService:aService];
		}
        
		// Device Information Service
		if([aService.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]){
			[aPeripheral discoverCharacteristics:nil forService:aService];
		}
        
		// GAP (Generic Access Profile) for Device Name
		if([aService.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]]){
			[aPeripheral discoverCharacteristics:nil forService:aService];
		}

		if([aService.UUID isEqual:[CBUUID UUIDWithString:@"6217ff49ac7b547eeecf016a06970ba9"]]){
			[aPeripheral discoverCharacteristics:nil forService:aService];
		}

		NSLog(@"%s: %@", __func__, aService.UUID);
	}
}

// Invoked upon completion of a -[discoverCharacteristics:forService:] request.
// Perform appropriate operations on interested characteristics
- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error 
{    
	if([service.UUID isEqual:[CBUUID UUIDWithString:@"180D"]]){
		for(CBCharacteristic *aChar in service.characteristics){
			// Set notification on heart rate measurement
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]){
				// heart rate monitor characteristic
				[aPeripheral setNotifyValue:YES forCharacteristic:aChar];
			}
			// Read body sensor location
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]]){
				// body sensor location characteristic
				[aPeripheral readValueForCharacteristic:aChar];
			} 
			// Write heart rate control point
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A39"]]){
				uint8_t val = 1;
				NSData* valData = [NSData dataWithBytes:(void*)&val length:sizeof(val)];
				[aPeripheral writeValue:valData forCharacteristic:aChar type:CBCharacteristicWriteWithResponse];
			}
		}
	}
	if([service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]]){
		for(CBCharacteristic *aChar in service.characteristics){
			// Read device name
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]]){
				// device name characteristic
				[aPeripheral readValueForCharacteristic:aChar];
			}
		}
	}
	if([service.UUID isEqual:[CBUUID UUIDWithString:@"180A"]]){
		for(CBCharacteristic *aChar in service.characteristics){
			// Read manufacturer name
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]]){
				// device manufacturer name characteristic
				[aPeripheral readValueForCharacteristic:aChar];
			}
		}
	}
	if([service.UUID isEqual:[CBUUID UUIDWithString:@"6217ff49ac7b547eeecf016a06970ba9"]]){
		for(CBCharacteristic *aChar in service.characteristics){
			NSLog(@"%s: %@\n", __func__, aChar.UUID);
		}
	}
}

// Invoked upon completion of a -[readValueForCharacteristic:] request or on the reception of a notification/indication.
- (void) peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error 
{
	t_osc_bndl_u *b = osc_bundle_u_alloc();
	t_osc_msg_u *msg_self = [self makeOSCSelfMessage:aPeripheral];
	osc_bundle_u_addMsg(b, msg_self);
	const char *name = [aPeripheral.name UTF8String];
	if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A37"]]){
		// Updated value for heart rate measurement received
		if((characteristic.value)  || !error){
			// Update UI with heart rate data
			[self computeHeartRate:characteristic.value peripheral:aPeripheral OSCBundle:b];
		}
	}else  if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A38"]]){
		// Value for body sensor location received
		NSData * updatedValue = characteristic.value;        
		uint8_t* dataPointer = (uint8_t*)[updatedValue bytes];
		if(dataPointer){
			t_osc_msg_u *msg_data = osc_message_u_alloc();
			osc_bundle_u_addMsg(b, msg_data);
			char data_address[128];
			uint8_t location = dataPointer[0];
			char *locationString;
			switch(location)
				{
				case 0:
					locationString = "Other";
					break;
				case 1:
					locationString = "Chest";
					break;
				case 2:
					locationString = "Wrist";
					break;
				case 3:
					locationString = "Finger";
					break;
				case 4:
					locationString = "Hand";
					break;
				case 5:
					locationString = "Ear Lobe";
					break;
				case 6: 
					locationString = "Foot";
					break;
				default:
					locationString = "Reserved";
					break;
				}
			sprintf(data_address, "/%s/location", name);
			osc_message_u_appendString(msg_data, locationString);
			ohrm_replaceSpacesWithSlashes(sizeof(data_address), data_address);
			osc_message_u_setAddress(msg_data, data_address);
		}
	}else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]]){
		// Value for device Name received
		t_osc_msg_u *msg_data = osc_message_u_alloc();
		osc_bundle_u_addMsg(b, msg_data);
		char data_address[128];
		sprintf(data_address, "/%s/devicename", name);
		osc_message_u_appendString(msg_data, [characteristic.value bytes]);
		ohrm_replaceSpacesWithSlashes(sizeof(data_address), data_address);
		osc_message_u_setAddress(msg_data, data_address);
	}else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A29"]]){
		// Value for manufacturer name received
		t_osc_msg_u *msg_data = osc_message_u_alloc();
		osc_bundle_u_addMsg(b, msg_data);
		char data_address[128];
		sprintf(data_address, "/%s/manufacturer", name);
		osc_message_u_appendString(msg_data, [characteristic.value bytes]);
		ohrm_replaceSpacesWithSlashes(sizeof(data_address), data_address);
		osc_message_u_setAddress(msg_data, data_address);
	}else{
	}
	long len = 0;
	char *buf = NULL;
	osc_bundle_u_serialize(b, &len, &buf);
	if(buf){
		t_atom a[2];
		atom_setlong(a, len);
		atom_setlong(a + 1, (long)buf);
		schedule_delay(maxobj, (method)ohrm_outputOSCBundle, 0, ps_FullPacket, 2, a);
		osc_bundle_u_free(b);
		// don't free buf here!! it's pointer has been passed to the scheduler and will be freed when
		// the callback executes
	}
	[aPeripheral readRSSI];
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
	//NSLog(@"%@", [peripheral RSSI]);
	t_osc_bndl_u *b = osc_bundle_u_alloc();
	t_osc_msg_u *msg_self = [self makeOSCSelfMessage:peripheral];
	osc_bundle_u_addMsg(b, msg_self);
	int rssi = [peripheral.RSSI intValue];
	t_osc_msg_u *data = osc_message_u_alloc();
	t_symbol *s = [self makeOSCAddressFromPeripheral:peripheral withPrefix:NULL withPostfix:"/RSSI/dBm"];
	osc_message_u_setAddress(data, s->s_name);
	osc_message_u_appendInt32(data, rssi);
	osc_bundle_u_addMsg(b, data);
	long len = 0;
	char *buf = NULL;
	osc_bundle_u_serialize(b, &len, &buf);
	if(buf){
		t_atom a[2];
		atom_setlong(a, len);
		atom_setlong(a + 1, (long)buf);
		schedule_delay(maxobj, (method)ohrm_outputOSCBundle, 0, ps_FullPacket, 2, a);
		osc_bundle_u_free(b);
		// don't free buf here!!!
	}
}

- (void)ohrm_init:(struct _ohrm *)x
{
	manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
	[self startScan];
	maxobj = x;
}

@end

// Max object

t_class *ohrm_class;

void ohrm_outputOSCBundle(t_ohrm *x, t_symbol *msg, int argc, t_atom *argv)
{
	OMAX_UTIL_GET_LEN_AND_PTR;
	if(ptr){
		omax_util_outletOSC(x->outlet, len, ptr);
		osc_mem_free(ptr); // scary business...
	}

}

void ohrm_bang(t_ohrm *x)
{
}

void ohrm_assist(t_ohrm *x, void *b, long io, long num, char *buf)
{
	omax_doc_assist(io, num, buf);
}

void ohrm_doc(t_ohrm *x)
{
	omax_doc_outletDoc(x->outlet);
}

void ohrm_free(t_ohrm *x)
{
	HeartRateMonitor *hrm = x->hrm;
	[hrm release];
}

void *ohrm_new(t_symbol *msg, short argc, t_atom *argv)
{
	t_ohrm *x = NULL;
	HeartRateMonitor *hrm = [[HeartRateMonitor alloc] init];
	if(hrm){
		if((x = (t_ohrm *)object_alloc(ohrm_class))){
			x->outlet = outlet_new((t_object *)x, "FullPacket");
			[hrm ohrm_init:x];
			x->hrm = hrm;
		}
	}
	return x;
}

int main(void)
{
	t_class *c = class_new("o.io.bluetoothle.hrm", (method)ohrm_new, (method)ohrm_free, sizeof(t_ohrm), 0L, A_GIMME, 0);

	//class_addmethod(c, (method)ohrm_fullPacket, "FullPacket", A_GIMME, 0);
	class_addmethod(c, (method)ohrm_assist, "assist", A_CANT, 0);
	class_addmethod(c, (method)ohrm_doc, "doc", 0);
	//class_addmethod(c, (method)ohrm_bang, "bang", 0);
	class_addmethod(c, (method)odot_version, "version", 0);

	ps_FullPacket = gensym("FullPacket");
	
	class_register(CLASS_BOX, c);
	ohrm_class = c;

	common_symbols_init();

	ODOT_PRINT_VERSION;
	return 0;
}