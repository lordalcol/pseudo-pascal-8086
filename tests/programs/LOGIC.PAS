program
    ; operators, precedence, booleans and many labels
    var a,b,d,i,t
    array v[12]
    $sep = ", "
    $done = "done"
begin
    a = 7
    b = 3
    d = a - b + 2 - 1            ; 5: left to right
    writeInt(d)
    writeStr($sep)
    writeInt(a / b * b)          ; 6
    writeStr($sep)
    writeInt(-a + 10)            ; 3
    writeStr($sep)
    writeInt(a - (b - 10) * 2)   ; 21
    writeStr($sep)
    writeInt(-20 / 3)            ; -6
    writeStr($sep)
    writeInt(a * (-b))           ; -21
    newline
    t = !(a > b)                 ; 0
    writeInt((t & 1))
    t = !(a < b)
    writeInt((t & 1))
    writeInt(((a = 7) ~ (b = 3))) ; 0
    writeInt(((a = 7) | (b = 4))) ; 1
    writeInt(((a <> 7) | (b >= 3) & (b <= 3))) ; 1
    newline
    i = 0
    while i < 12
        v[i] = i * i - 5 * i
        i = i + 1
    endwhile
    i = 0
    while i < 12
        if v[i] < 0
            write('-')
        else
            if v[i] = 0
                write('0')
            else
                if v[i] > 20
                    write('#')
                else
                    write('+')
                endif
            endif
        endif
        i = i + 1
    endwhile
    newline
    writeInt(v[v[3] + 9 - (-1)]) ; v[4] = -4
    newline
    i = 0
    loop 3
        if i = 1
            write('b')
        else
            write('a')
        endif
        i = i + 1
    endloop
    newline
    writeStr($done, $sep, $done)
end.
