build:
	rgbasm -L -o viridian.o main.asm
	rgblink -o viridian.gb viridian.o

	# `-v` makes the header valid by injecting the Nintendo logo and computing two checksums.
	# `-p 0xFF` ensures the ROM is padded to a valid size and it sets the corresponding value in the "ROM size" header field.
	rgbfix -v -p 0xFF viridian.gb

run_bgb:
	wine ../bgb/bgb64.exe viridian.gb

run_emulicious:
	java -jar ../Emulicious.jar viridian.gb

clean:
	rm viridian.o viridian.gb
