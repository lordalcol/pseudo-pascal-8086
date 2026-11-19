program
    var a,b,t
    $title = "The first 23 Fibonacci numbers (the 24th needs more than 16 bits):"
begin
    writeStr($title)
    newline
    a = 0
    b = 1
    loop 23
        writeInt(b)
        write(' ')
        t = a + b
        a = b
        b = t
    endloop
end.
