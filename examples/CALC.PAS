program
    var x,y,op,kESC
    $title = "RUNNING CALCULATOR (operators: + - * / then a number and Enter, Esc quits)"
begin
    writeStr($title)
    newline
    newline
    kESC=27

    x=0
    writeInt(x)
    read(op)
    write(op)
    while(op<>kESC)
        readInt(y)
        write('=')
        newline
        if op='+'
            x=x+y
        endif
        if op='-'
            x=x-y
        endif
        if op='*'
            x=x*y
        endif
        if op='/'
            x=x/y
        endif
        writeInt(x)
        read(op)
        write(op)
    endwhile

end.
