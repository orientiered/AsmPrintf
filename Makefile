main.exe: build/printf.o build/main.o
	g++ -o $@  $^ 
	objdump -D main.exe > main.disasm 

build/printf.o: printf.s
	nasm -f elf64  -l $<.lst $< -o $@

build/main.o: main.c
	g++ -Og -c $< -o $@

.PHONY:clean
clean:
	rm build/*