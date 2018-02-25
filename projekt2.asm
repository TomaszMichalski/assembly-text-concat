dane segment

help_msg		db	"-h - wyswietla help",10,13,"-i - dodaje plik wejsciowy",10,13,"-o - okresla nazwe pliku wyjsciowego",10,13,"-t - okresla znak rozdzielajacy",10,13,"Moze byc wiele plikow wejsciowych",10,13,"Brak podanego pliku wyjsciowego skutkuje wyswietleniem pliku wynikowego na konsoli",10,13,"Domyslnym znakiem rozdzielajacym jest spacja",10,13,"$"
syntax_error	db	"Bledna skladnia wywolania",10,13,"$"
input_error		db	"Brak pliku wejsciowego",10,13,"$"
file_error		db	"Blad pliku",10,13,"$"
file_load_error	db	"Blad otwarcia pliku",10,13,"$"
file_close_error db	"Blad zamkniecia pliku",10,13,"$"
file_read_error	db	"Blad odczytu pliku",10,13,"$"
file_jump_error	db	"Blad przesuniecia w pliku",10,13,"$"

cmdline_length 	dw ?
cmdline 		db 129 dup ("$") ;max dlugosc linii komend + ostatni "$" jesli jest cala zapelniona

separatorChar	db	" $"
newline			db 	10,13,"$"

inputfile_count	db 0 ;liczba podanych plikow wejsciowych
input_filenames	db 255 dup ("$")
output_flag		db 0 ;0 - nie podano pliku wyjsciowego, 1 - podano plik wyjsciowy
output_filename	db 255 dup ("$") ;nazwa pliku wyjsciowego

cx_point		dw 16 dup (0)
dx_point		dw 16 dup (0)
file_done		db 0
input_copied	dw ?
bufor			db ?
input_handle	dw ?
output_handle	dw ?

dane ends

code segment

	assume cs:code,ds:dane

start:

	mov ax,seg top1 ;inicjalizacja stosu
	mov ss,ax
	mov sp,offset top1
	
	mov ax,seg help_msg ;ustawienie segmentu danych
	mov ds,ax
	mov dx, offset help_msg
	
	xor di,di
	
	;linia komend znajduje sie w ES
	mov cl,es:[80h] ;zapisanie w cl dlugosci linii komend
	xor ch,ch
	cmp cl,0 ;sprawdzenie czy nie jest pusta
	je syntax ;jesli tak, to wyswietlenie komunikatu o bledzie
	
	mov ds:[cmdline_length],cx ;zapisanie dlugosci linii komend
	
	xor ax,ax
	xor si,si
	
copycmdline: ;kopiuje zawartosc linii komend do zmienej cmdline, w cx dalej jest dlugosc linii komend
	mov ah,es:[81h+si]
	mov byte ptr ds:[cmdline+si],ah
	inc si
	loop copycmdline
	
	xor si,si ;wyzerowanie licznika do poruszania sie po linii komend
readcmdline:
	mov al,byte ptr ds:[cmdline+si] ;przenoszenie do zbadania kolejnych znakow linii komend
	
	cmp al,'-' ;znacznik poczatku opcji
	je options ;skok do bloku obslugujacego opcje
	
	cmp al,' ' ;porownania ze spacja
	je next ;przeskoczenie do kolejnego obrotu petli
	
	jmp syntax ;jesli wczesniej nie doszlo do skoku to znaczy, ze doszlo do bledu skladniowego
	
options:
	inc si ;przejscie na znak nastepny po '-'
	cmp si,ds:[cmdline_length] ;sprawdzenie czy nie wyszlismy poza dlugosc linii komend (np. kiedy na koncu linii komend jest pojedynczy '-')
	ja syntax ;skok do bledu skladniowego
	
	mov al,byte ptr ds:[cmdline+si] ;przeniesienie do al znaku opcji
	
	cmp al,'h' ;help
	je help
	
	cmp al,'i' ;plik wejsciowy
	je input
	
	cmp al,'o' ;plik wyjsciowy
	je output
	
	cmp al,'t' ;separator
	je separator
	
	jmp syntax ;jesli nie doszlo do skoku to znaczy, ze doszlo do bledu skladniowego
	
help: ;wyswietlenie komunikatu help
	mov dx,offset help_msg
	mov ah,9
	int 21h
	jmp exit

input:
	add ds:[inputfile_count],1 ;dodajemy nowy plik wejsciowy
	add si,2 ;pomijamy spacje po "-i"
	get_name:
		xor ah,ah
		mov ah,byte ptr ds:[cmdline+si] ;pobieramy znak nazwy pliku
		mov byte ptr ds:[input_filenames+di],ah ;i przepisujemy go do zmiennej input_filenames
		inc di ;przesuwamy na nastepny znak
		inc si
		cmp si,ds:[cmdline_length] ;sprawdzenie czy nie doszlismy do konca linii komend
		je end_input
		mov ah,byte ptr ds:[cmdline+si]
		cmp ah,' ' ;sprawdzenie czy nie jest to koniec nazwy pliku
		jne get_name
	end_input:
		mov ah,0
		mov byte ptr ds:[input_filenames+di],ah ;wstawiamy 0 na koncu nazwy pliku
		inc di ;przygotowujemy do ewentualnego wpisania kolejnej nazwy inkrementujac licznik di
		
	jmp next

output:
	cmp ds:[output_flag],1 ;sprawdzenie czy jest to jedyny podany plik wyjsciowy
	je syntax ;jesli nie, to doszlo do bledu skladniowego
	mov ds:[output_flag],1 ;ustawiamy, ze wczytano nazwe pliku wyjsciowego
	add si,2 ;pomijamy spacje po "-o"
	xor bx,bx ;zerujemy bx - do przepisywania nazwy do zmiennej output_filename
	get_filename:
		mov ah,byte ptr ds:[cmdline+si] ;pobieramy znak nazwy pliku
		mov byte ptr ds:[output_filename+bx],ah ;i przepisujemy go do zmiennej output_filename
		inc bx ;przesuwamy na nastepny znak
		inc si
		cmp si,ds:[cmdline_length] ;sprawdzenie czy nie doszlismy do konca linii komend
		je end_output
		mov ah,byte ptr ds:[cmdline+si]
		cmp ah,' ' ;sprawdzenie czy nie jest to koniec nazwy pliku
		jne get_filename
	end_output:
		cmp ds:[output_filename],' '
		je syntax
		mov ah,0
		mov byte ptr ds:[output_filename+bx],ah ;wstawiamy 0 na koncu nazwy pliku
	
	jmp next

separator:
	add si,2
	cmp ds:[separatorChar],' ' ;sprawdzenie czy separator jest defaultowy
	jne syntax
	mov ah,byte ptr ds:[cmdline+si] ;zapisanie nowego separatora
	mov byte ptr ds:[separatorChar],ah
	jmp next
	
next:
	inc si
	cmp si,word ptr ds:[cmdline_length]
	jb readcmdline ;jesli nie doszlismy do konca linii komendt, to kontynuujemy petle
	
	cmp ds:[inputfile_count],0
	je syntax
	
	cmp ds:[output_flag],0
	je write_console
	jne write_file
	
write_file: ;wywolana jesli podano plik wyjsciowy
	mov ah,3ch ;stworzenie pliku wyjsciowego
	mov dx,offset ds:[output_filename]
	int 21h
	jc fileerr
	mov output_handle,ax
	f_line:
		xor si,si
		mov ds:[input_copied],0
		f_file:
			xor ax,ax
			mov ah,3dh
			mov al,0
			xor dx,dx
			mov dx,offset input_filenames
			add dx,si
			int 21h
			jc file_load_error_msg
			mov ds:[input_handle],ax
			xor cx,cx
			xor dx,dx
			xor bx,bx
			mov bx,ds:[input_copied]
			shl bx,1
			mov dx,word ptr ds:[dx_point+bx]
			mov cx,word ptr ds:[cx_point+bx]
			mov ah,42h
			mov bx,ds:[input_handle]
			mov al,0
			int 21h
			jc file_jump_error_msg
			
			f_write_line:
				mov ah,3fh
				mov cx,1 ;czytamy po jednym bajcie
				mov bx,ds:[input_handle]
				mov dx,offset ds:[bufor]
				int 21h
				jc file_read_error_msg
				
				cmp ax,0 ;jesli plik zwrocil 0 bajtow to jest zakonczony
				jne f_file_not_ended
				add ds:[file_done],1 ;jesli jest zakonczony to inkrementujemy ilosc zakonczonych plikow
				jmp f_file_end
				
				f_file_not_ended:
					mov bx,ds:[input_copied]
					shl bx,1 ;przesuniecie zeby odczytac odpowiednia wartosc xx_point
					add ds:[dx_point+bx],1 ;inkrementujemy przesuniecie jesli przeczytalismy bajt
					jnc f_cont ;jesli nie nastapil carry to nie trzeba zwiekszac cx_point
					add ds:[cx_point+bx],1 ;inkrementujemy przesuniecie
					f_cont:
						;sprawdzenie czy odczytany bit nie jest znakiem nowej linii
						mov ah,ds:[bufor]
						cmp ah,10
						je f_file_line_end
						cmp ah,13
						je f_file_line_end
						;jesli nie, to nastepuje wpisanie bajtu
						mov ah,40h
						mov bx,ds:[output_handle]
						mov dx,offset bufor
						mov cx,1
						int 21h
						jc fileerr
						jmp f_write_line
				f_file_line_end:
					mov bx,ds:[input_copied]
					shl bx,1 ;przesuniecie zeby odczytac odpowiednia wartosc xx_point
					add ds:[dx_point+bx],1 ;inkrementujemy przesuniecie przez znak nowej linii
					jnc f_file_end
					add ds:[cx_point+bx],1
				f_file_end:
					;zamkniecie pliku
					mov ah,3eh
					mov bx,ds:[input_handle]
					int 21h
					jc file_close_error_msg
					add ds:[input_copied],1 ;inkrementujemy liczbe skopiowanych plikow
					mov ax,ds:[input_copied]
					cmp al,ds:[inputfile_count] ;sprawdzamy czy to wszystkie pliki
					jnb f_stop
					;jesli nie to wypisz separator
					mov ah,40h
					mov bx,ds:[output_handle]
					mov dx,offset separatorChar
					mov cx,1
					int 21h
					jc fileerr
				f_filename_search: ;przesuniecie si na kolejna nazwe pliku
					mov ah,byte ptr ds:[input_filenames+si]
					inc si
					cmp ah,0
					jne f_filename_search
				jmp f_file
		f_stop: ;wypisanie nowej linii po zakonczeniu kopiowania
			mov ds:[bufor],13
			mov ah,40h
			mov bx,ds:[output_handle]
			mov dx,offset bufor
			mov cx,1
			int 21h
			mov ds:[bufor],10
			mov ah,40h
			mov bx,ds:[output_handle]
			mov dx,offset bufor
			mov cx,1
			int 21h
			
		mov ah,ds:[file_done]
		cmp ah,ds:[inputfile_count]
		jbe f_line ;jesli nie wszystkie pliki zostaly zakonczone to pisz nastepna linijke
		mov ah,3eh
		mov bx,ds:[output_handle]
		int 21h
		jc fileerr
	jmp exit

write_console: ;wywolana jesli nie podano pliku wyjsciowego - nastapy wypis do konsoli
	line: ;przechodzenie linijkami
		xor si,si ;zerowanie si jako pointera na kolejne nazwy plikow
		mov ds:[input_copied],0 ;zaczynamy zawsze od zerowego pliku
		file: ;otwieranie kolejnych plikow
			xor ax,ax
			mov ah,3dh
			mov al,0
			xor dx,dx
			mov dx,offset input_filenames
			add dx,si
			int 21h
			jc file_load_error_msg
			mov ds:[input_handle],ax
			;przesuniecie wskaznika do odczytania wlasciwego miejsca w pliku
			xor cx,cx
			xor dx,dx
			xor bx,bx
			mov bx,ds:[input_copied]
			shl bx,1
			mov dx,word ptr ds:[dx_point+bx]
			mov cx,word ptr ds:[cx_point+bx]
			mov ah,42h
			mov bx,ds:[input_handle]
			mov al,0
			int 21h
			jc file_jump_error_msg
			
			write_line: ;przepisujemy linijke z pliku
				mov ah,3fh
				mov cx,1 ;czytamy po jednym bajcie
				mov bx,ds:[input_handle]
				mov dx,offset ds:[bufor]
				int 21h
				jc file_read_error_msg
				
				cmp ax,0 ;jesli plik zwrocil 0 bajtow to jest zakonczony
				jne file_not_ended
				add ds:[file_done],1 ;jesli jest zakonczony to inkrementujemy ilosc zakonczonych plikow
				jmp file_end
				
				file_not_ended:
					mov bx,ds:[input_copied]
					shl bx,1 ;przesuniecie zeby odczytac odpowiednia wartosc xx_point
					add ds:[dx_point+bx],1 ;inkrementujemy przesuniecie jesli przeczytalismy bajt
					jnc cont ;jesli nie nastapil carry to nie trzeba zwiekszac cx_point
					add ds:[cx_point+bx],1 ;inkrementujemy przesuniecie
					cont:
						;sprawdzenie czy odczytany bit nie jest znakiem nowej linii
						mov ah,ds:[bufor]
						cmp ah,10
						je file_line_end
						cmp ah,13
						je file_line_end
						;jesli nie, to nastepuje wpisanie bajtu
						mov ah,2
						mov dl,ds:[bufor]
						int 21h
						jmp write_line
				file_line_end:
					mov bx,ds:[input_copied]
					shl bx,1 ;przesuniecie zeby odczytac odpowiednia wartosc xx_point
					add ds:[dx_point+bx],1 ;inkrementujemy przesuniecie przez znak nowej linii
					jnc file_end
					add ds:[cx_point+bx],1
				file_end:
					;zamkniecie pliku
					mov ah,3eh
					mov bx,ds:[input_handle]
					int 21h
					jc file_close_error_msg
					add ds:[input_copied],1 ;inkrementujemy liczbe skopiowanych plikow
					mov ax,ds:[input_copied]
					cmp al,ds:[inputfile_count] ;sprawdzamy czy to wszystkie pliki
					jnb stop
					;jesli nie to wypisz separator
					mov ah,9
					mov dx,offset separatorChar
					int 21h
				filename_search: ;przesuniecie si na kolejna nazwe pliku
					mov ah,byte ptr ds:[input_filenames+si]
					inc si
					cmp ah,0
					jne filename_search
				jmp file
		stop: ;wypisanie nowej linii po zakonczeniu kopiowania
			mov ah,9
			mov dx,offset newline
			int 21h
		mov ah,ds:[file_done]
		cmp ah,ds:[inputfile_count]
		jbe line ;jesli nie wszystkie pliki zostaly zakonczone to pisz nastepna linijke
	jmp exit
	
syntax:
	mov dx,offset syntax_error ;wyswietlenie komunikatu o bledzie
	mov ah,9
	int 21h
	jmp exit
	
fileerr:
	mov dx, offset file_error
	mov ah,9
	int 21h
	jmp exit
	
file_close_error_msg:
	mov dx,offset file_close_error
	mov ah,9
	int 21h
	jmp exit
	
file_jump_error_msg:
	mov dx,offset file_jump_error
	mov ah,9
	int 21h
	jmp exit
	
file_load_error_msg:
	mov dx,offset file_load_error
	mov ah,9
	int 21h
	jmp exit
	
file_read_error_msg:
	mov dx,offset file_read_error
	mov ah,9
	int 21h
	jmp exit

exit:
	mov ah,4ch ;wyjscie z programu i powrot do DOS
	int 21h;

code ends

stos1 segment stack

		dw 200 dup(?)
top1	dw ?

stos1 ends

end start

