program
    var key
    $titolo = "Visualizza il numero ASCII decimale del tasto premuto"
begin
    writeStr($titolo)
    newline
    newline
    read(key)
    write(key,':',' ')
    writeInt(key)
    write(10)
    read(key)
end.