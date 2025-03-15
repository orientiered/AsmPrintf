#include <stdio.h>

#define _cdecl __attribute__((cdecl))

extern "C" int _cdecl my_printf(const char *fmt, ...);

int main() {
    printf("hi %d\n", my_printf("Jeep\n", 1, 2, 3, 4, 5, 6, 7) );
    return 0;
}