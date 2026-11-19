program
    var k,cESC
begin
    cESC=27
    read(k)
    while(k<>cESC)
        if((k>='a') & (k<='z')) | ((k>='A') & (k<='Z'))
            k=k+1
        endif
        write(k)
        read(k)
    endwhile
end.