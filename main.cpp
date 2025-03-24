#include <stdio.h>
#include <assert.h>

// #define _cdecl __attribute__((cdecl))

/// @brief Tiny printf implementation written in assempler 
/// @param fmt format string
/// @param Args See list of supported specificators in README.MD 
/// @return Number of written characters
extern "C" int my_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

/// @brief Flush inner printf buffer.
/// my_printf uses buffer to reduce number of syscalls and flushes it only if it is full and at exit
extern "C" void my_printf_flush();

float fsum(double a, float b) {
    return a + b;
}

void printf_test() {
    // Testing 
    my_printf("1 - %f 2 - %f 3 - %f 4 - %f 5 - %f 6 - %f 7 - %f 8 - %f\n", 
                1.11,   2.22,   3.33,   4.44,  5.55,  6.66,  7.77,  8.88);

    my_printf("1 - %f ;%s; 2 - %f 3 - %f 4 - %f ;%d; 5 - %f 6 - %f 7 - %f 8 - %f\n", 
                1.11, "heh",  2.22,  3.33, 4.44, -123,  5.55,  6.66,  7.77,  8.88);

    my_printf_flush();
    int printed_chars = my_printf("7 + 18 = %d, %s %c %s = %d\n%s --> %s\n%d %s %x %d%%%c%b\n", 25, "7", '*', "-8", -56, 
                                  "This is argument from stack", "another one\n", -1, "love", 3802, 100, 33, 126);


    assert(printed_chars == 96);
}

int main() {
    printf_test();


    my_printf("%f %s %f\n", 52.52, "hello", 0.04);

                    
    my_printf_flush();
    
    // my_printf("%b = -%b, %o = -%o\n %x, %x\n", -52, 52, -52, 52, 0xEDA, 0x0BED); 
    printed_chars = my_printf("int32_t(%u) = %d\n", -52, -52);
    // my_printf("12345678901234567890123456789012345678901234567890 %s\n", "qq");
    // my_printf("12345678901234567890123456789012345678901234567890 %s\n", "qqdfskldfjsklfjslkdfjslkdfjsdkf");

    // my_printf("Hello %s\n", "Whenever you copy something, it gets stored in the system clipboard, a special short-term memory where your system stores the copied text");
    // my_printf("%x%s", 124, "\n");

    float number = 100.55f;
    number += 10.0f;
    printf("%f %lf\n", number, -(double) number);

    
    float  b = 52.52;
    scanf("%f", &b);
    my_printf("%f\n", b);
    printf("%f\n", b); 
    return 0;

}