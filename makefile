#tatOS Makefile
#Sept 2009
#this will assemble everything from scratch
#just type "make" from the Linux commandline
#if you only have nasm and not the gcc tools
#just issue these commands manually to build the image file
#or use a script
#tatOS is built on a Linux PIII desktop with Debian Lenny installed
#if you get an error:" TIMES value -8 is negative" or something like that
#then edit tatOS.inc  SIZEOFTLIB define to some bigger number

build:
	
	#assemble boot1
	nasm -f bin boot/boot1.s
	
	#assemble boot2
	nasm -f bin boot/boot2.s

	#assemble tlib  
	nasm -f bin tlib/tlib.s

	#tatOS.img=boot1+boot2+tlib
	nasm -f bin build.s -o tatOS.img

	#use <dd if=tatOS.img of=/dev/fd0 or sda> to make bootable floppy or flash


clean:
	rm boot/boot1 boot/boot2 tlib/tlib  



