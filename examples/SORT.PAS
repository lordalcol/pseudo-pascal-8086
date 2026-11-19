program
    array a[6]
    var i,j,N,tmp,x,y
    $titolo = "PROGRAMMA PER L'ORDINAMENTO DI UN VETTORE DI INTERI"
    $input1 = "Inserire un intero ["
    $input2 = "]: "
    $output = "Ecco il vettore ordinato: "
begin
    N=6
    i=0
    writeStr($titolo)
    newline
    
    ;lettura del vettore
    loop N
        writeStr($input1)
        writeInt(i)
        writeStr($input2)
        readInt(a[i])
        newline
        i=i+1
    endloop

    ;ordinamento
    j=0
    i=1
    while(j<N)
        while(i<N)
            if a[i]<a[j]
                tmp=a[i]
                a[i]=a[j]
                a[j]=tmp
            endif
            i=i+1
        endwhile
        j=j+1
        i=j
    endwhile
    ;output
    writeStr($output)
    newline
    i=0
    loop N
        writeInt(a[i])
        write(' ')
        i=i+1
    endloop
end.