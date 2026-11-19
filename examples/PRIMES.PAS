program
    ; the sieve of Eratosthenes
    array sieve[500]
    var i,j,n,count
    $title = "Prime numbers below 500:"
    $total = "Primes found: "
begin
    n = 500
    writeStr($title)
    newline
    count = 0
    i = 2
    while i < n
        if sieve[i] = 0
            writeInt(i)
            write(' ')
            count = count + 1
            ; cross out the multiples, starting from i*i
            if i <= n / i
                j = i * i
                while j < n
                    sieve[j] = 1
                    j = j + i
                endwhile
            endif
        endif
        i = i + 1
    endwhile
    newline
    writeStr($total)
    writeInt(count)
end.
