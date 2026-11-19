program
    var key
    $title = "Press keys to see their ASCII codes. Esc quits."
begin
    writeStr($title)
    newline
    newline
    read(key)
    while key <> 27
        write(key,':',' ')
        writeInt(key)
        newline
        read(key)
    endwhile
end.
