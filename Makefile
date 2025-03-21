main.exe: build/printf.o build/main.o
	gcc -no-pie -o $@  $^ 
	objdump -D -Mintel main.exe > main.disasm 

build/printf.o: printf.s
	nasm -f elf64  -l $<.lst $< -o $@

build/main.o: main.cpp
	g++ -Og -c $< -o $@

.PHONY:clean
clean:
	rm build/*