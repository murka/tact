asm fun keccak256(s: Slice): Int {
    1
    INT
    HASHEXT_KECCAK256
}

asm( -> 1 0) extends fun loadCoins(self: Slice): Int {
    LDVARUINT16
}

asm(c b) extends fun storeDict(b: Builder, c: Cell) {
    STDICT
}

asm(s len -> 1 0) extends fun loadInt(self: Slice, len: Int): Int {
    LDIX
}
