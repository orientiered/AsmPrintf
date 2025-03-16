#include <stdio.h>

// #define _cdecl __attribute__((cdecl))

extern "C" int my_printf(const char *fmt, ...);

int main() {
    // int printed_chars = my_printf("%x = %s, %x = %s\n", 0xEDA, "0xEDA", 0x0BED, "0x0BED"); 
    int printed_chars = my_printf("7 + 18 = %d, %s %c %s = %d\n", 25, "7", '*', "-8", -56);
    // my_printf("%b = -%b, %o = -%o\n %x, %x\n", -52, 52, -52, 52, 0xEDA, 0x0BED); 
    printf("Printed chars: %d\n", printed_chars);
    printed_chars = my_printf("int32_t(%u) = %d\n", -52, -52);
    // my_printf("12345678901234567890123456789012345678901234567890 %s\n", "qq");

    // my_printf("12345678901234567890123456789012345678901234567890 %s\n", "qqdfskldfjsklfjslkdfjslkdfjsdkf");

    // my_printf("Hello %s\n", "Whenever you copy something, it gets stored in the system clipboard, a special short-term memory where your system stores the copied text");
    // my_printf("%x%s", 124, "\n");
    return 0;

}