#include <msp430f5510.h>

// Declare pointers to variables we access in Novatouch fw
unsigned char* const repeat_flags = (unsigned char*)0x2404;
unsigned char* const repeat_rate = (unsigned char*)0x252f;
unsigned char* const num_for_7x_c1 = (unsigned char*)0x2530;
unsigned char* const current_keycode = (unsigned char*)0x2400;

// Defines for internal scancodes (corresponding to scancode_table_1). Find out
// missing ones by using table at bottom of README.org.
#define KEY_H 0x24
#define KEY_J 0x25
#define KEY_K 0x26
#define KEY_L 0x27
#define KEY_UP 0x53
#define KEY_DOWN 0x54
#define KEY_LEFT 0x4f
#define KEY_RIGHT 0x59

// Seems like original FW is compiled with IAR compiler and has different
// calling convention than mspgcc. Use macro to call functions and get correct
// parameter passing.
#define QUEUE_KEY(code) asm("mov.b %0, r12\n" \
                            "calla #0x91a2" : : "i"(code))

#define UNQUEUE_KEY(code) asm("mov.b %0, r12\n"                     \
                              "calla #0x9086" : : "i"(code))

// To be called when key is pressed and fn is also pressed
void on_fn_key_down() {
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

    // Extra bindings for fn + key
    switch (*current_keycode) {
        case KEY_H:
            QUEUE_KEY(KEY_LEFT);
            break;
        case KEY_J:
            QUEUE_KEY(KEY_DOWN);
            break;
        case KEY_K:
            QUEUE_KEY(KEY_UP);
            break;
        case KEY_L:
            QUEUE_KEY(KEY_RIGHT);
            break;
    }
}

// To be called when key is released and fn is also down
void on_fn_key_up() {

    // Extra bindings for fn + key
    switch (*current_keycode) {
    case KEY_H:
        UNQUEUE_KEY(KEY_LEFT);
        break;
    case KEY_J:
        UNQUEUE_KEY(KEY_DOWN);
        break;
    case KEY_K:
        UNQUEUE_KEY(KEY_UP);
        break;
    case KEY_L:
        UNQUEUE_KEY(KEY_RIGHT);
        break;
    default:
        // Moar ugly hacks! To hook this function we replaced the
        // original call to unqueue key, setup original argument and
        // do the call.
        asm("mov.b &0x2400, r12\n"
            "calla #0x9086");
        break;
    }
}
