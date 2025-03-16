#include <stdio.h>

// #define _cdecl __attribute__((cdecl))

extern "C" int my_printf(const char *fmt, ...);

int main() {
    int printed_chars = my_printf("1 %c 2 %s 3 %", '$', "cheburek"); 
    printed_chars = my_printf("1:%s 2:%s 3:%s 4:%s 5:%s 6:%s argument from stack 7:%s 8: %s\n", 
    "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "");
    printf("Printed chars: %d\n", printed_chars);

    // printf("\n%d\n", my_printf("Ded obed %s ded, %s\n", "lox", "gorox") );
    return 0;
}