#include <intrinsics.h>
#include <msp430f5510.h>

// Declare pointers to variables we access in Novatouch fw
unsigned char* const repeat_flags = (unsigned char*)0x2404;
unsigned char* const repeat_rate = (unsigned char*)0x252f;
unsigned char* const num_for_7x_c1 = (unsigned char*)0x2530;

void check_bsl_enter() {
    // We just replaced this copy to get here, perform it here instead
    // (although it seems to be redundant because it is never actually
    // read)
    *num_for_7x_c1 = *repeat_rate;

    // Enter BSL if fn + f1 + f4 is pressed
    if ((*repeat_flags & 0x9) == 0x09) {
        __dint();
        // Maybe need to slow down clock to 8 MHz also, not sure what
        // is configured by Novatouch fw
        USBKEYPID = 0x9628;
        USBCNF &= ~PUR_EN;
        USBPWRCTL &= ~VBOFFIE;
        USBKEYPID = 0x9600;
        ((void (*)())0x1000)();
    }
}
