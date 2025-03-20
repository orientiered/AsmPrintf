#include <stdio.h>

// #define _cdecl __attribute__((cdecl))

/// @brief Tiny printf implementation written in assempler 
/// @param fmt format string
/// @param Args See list of supported specificators in README.MD 
/// @return Number of written characters
extern "C" int my_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

/// @brief Flush inner printf buffer.
/// my_printf uses buffer to reduce number of syscalls and flushes it only if it is full and at exit
extern "C" void my_printf_flush();

int main() {
    // int printed_chars = my_printf("%x = %s, %x = %s\n", 0xEDA, "0xEDA", 0x0BED, "0x0BED"); 
    int printed_chars = my_printf("7 + 18 = %d, %s %c %s = %d\n%s --> %s\n%d %s %x %d%%%c%b\n", 25, "7", '*', "-8", -56, 
                                  "This is argument from stack", "another one\n", -1, "love", 3802, 100, 33, 126);
                    
    my_printf_flush();
    
    // my_printf("%b = -%b, %o = -%o\n %x, %x\n", -52, 52, -52, 52, 0xEDA, 0x0BED); 
    printf("Printed chars: %d\n", printed_chars);
    printed_chars = my_printf("int32_t(%u) = %d\n", -52, -52);
    // my_printf("12345678901234567890123456789012345678901234567890 %s\n", "qq");
    // my_printf("12345678901234567890123456789012345678901234567890 %s\n", "qqdfskldfjsklfjslkdfjslkdfjsdkf");

    // my_printf("Hello %s\n", "Whenever you copy something, it gets stored in the system clipboard, a special short-term memory where your system stores the copied text");
    // my_printf("%x%s", 124, "\n");
    return 0;

}