program
var x0,x1,y,i,continuare,a
begin
x0=48
x1=49

masm
    add continuare,0
    ;mov ax,x1
    ;mov continuare,ax
endmasm

read(continuare)

while(continuare<>x0)
    loop 80
        write(2)
    endloop
    read(continuare)
endwhile
end.