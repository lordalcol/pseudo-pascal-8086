program
    var secret,guess,tries
    $title = "GUESS THE NUMBER (1 to 100)"
    $ask   = "Your guess: "
    $low   = "Too low"
    $high  = "Too high"
    $win   = "Got it! Tries: "
begin
    writeStr($title)
    newline
    ; inline assembly: the BIOS clock (ticks since midnight) as a seed
    masm
        mov ah,0
        int 1Ah
        and dx,7FFFh
        mov secret,dx
    endmasm
    secret = secret - (secret / 100) * 100 + 1
    tries = 0
    guess = 0
    while guess <> secret
        writeStr($ask)
        readInt(guess)
        newline
        tries = tries + 1
        if guess < secret
            writeStr($low)
            newline
        endif
        if guess > secret
            writeStr($high)
            newline
        endif
    endwhile
    writeStr($win)
    writeInt(tries)
end.
