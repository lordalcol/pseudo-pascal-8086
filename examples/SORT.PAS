program
    array a[6]
    var i,j,N,tmp,x,y
    $title = "SORTS A LIST OF INTEGERS"
    $input1 = "Enter an integer ["
    $input2 = "]: "
    $output = "Sorted: "
begin
    N=6
    i=0
    writeStr($title)
    newline

    ;read the list
    loop N
        writeStr($input1)
        writeInt(i)
        writeStr($input2)
        readInt(a[i])
        newline
        i=i+1
    endloop

    ;sort it
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
    ;print it
    writeStr($output)
    newline
    i=0
    loop N
        writeInt(a[i])
        write(' ')
        i=i+1
    endloop
end.
