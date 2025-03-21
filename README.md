# Small `printf` implementation for Linux x86-64

## Dependencies

+ **g++** - Given example uses `_start` from `libc`
+ **nasm** - To compile [printf.s](printf.s)
+ **x86-64 Linux machine** - 32 bit is not supported, works only on Linux 

## Compilation

```bash
mkdir build
make
```

Or just link `build/printf.o` to your program

## Usage

```c
// function prototype, extern "C" to disable mangling
extern "C" int my_printf(const char *fmt, ...); 

int main() {
    my_printf("Hello %s \n", "world");
    return 0;
}
```

> [!IMPORTANT]
> `my_printf` uses buffer to reduce number of syscalls and flushes it only if it is full and when program stops execution \
> If you want to flush the buffer use `my_printf_flush`

```c
#include <stdio.h>
extern "C" void my_printf_flush();
extern "C" int my_printf(const char *fmt, ...); 

int main() {
    my_printf("Hello world\n");
    my_printf_flush();                  // flushing buffer
    printf("Using libc printf now");    
}
```

See [main.c](main.c) for more examples

## Supported specificators

+ `%%` - prints `%`
+ `%s` - prints c-style string from `const char *` argument
+ `%c` - prints character
+ `%x` - prints unsigned 32-bit integer in hex,    without leading zeros
+ `%o` - prints unsigned 32-bit integer in octal,  without leading zeros
+ `%b` - prints unsigned 32-bit integer in binary, without leading zeros
+ `%d` - prints signed   32-bit integer as decimal number
+ `%u` - prints unsigned 32-bit integer as decimal number
+ `%` with any other symbol stops printing  

## Under the hood

`my_printf` is actually a trampoline that pushes first 6 argument registers ([System V AMD64 ABI](https://en.wikipedia.org/wiki/X86_calling_conventions#System_V_AMD64_ABI)) to the stack and jumps to `my_printf_cdecl` (local function in `printf.s`) that takes arguments from stack like in `cdecl` call convention. 