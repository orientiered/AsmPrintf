#include <stdio.h>

// #define _cdecl __attribute__((cdecl))

extern "C" int my_printf(const char *fmt, ...);

int main() {
    // int printed_chars = my_printf("%x = %s, %x = %s\n", 0xEDA, "0xEDA", 0x0BED, "0x0BED"); 
    int printed_chars = my_printf("%b = -%b, %o = -%o\n %x, %x\n", -52, 52, -52, 52, 0xEDA, 0x0BED); 
    printf("Printed chars: %d\n", printed_chars);
    // printf("\n%d\n", my_printf("Ded obed %s ded, %s\n", "lox", "gorox") );
    return 0;
}