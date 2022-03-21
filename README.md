# Py16

An assembler and emulator for a fake machine used in my python course.

## Specifications

- `12`-bit program counter
- `4096` `16`-bit memory locations
- `16`-bit `R` register
- `GT`, `EQ`, and `LT` flags
- `16` instructions
- `4`-bit opcode and `12`-bit oprand make up an executed word

## Instructions

| Opcode | Mnemonic        | Meaning                                       |
| ------ | --------------- | --------------------------------------------- |
| `0000` | `LOAD        X` | Copy value at `X` into `R`                    |
| `0001` | `STORE       X` | Store `R` into `X`                            |
| `0010` | `CLEAR       X` | Set value at `X` to `0`                       |
| `0011` | `ADD         X` | Set `R` to `R` + value at `X`                 |
| `0100` | `INCREMENT   X` | Increment value at `X`                        |
| `0101` | `SUBTRACT    X` | Set `R` to `R` - value at `X`                 |
| `0110` | `DECREMENT   X` | Decrement value at `X`                        |
| `0111` | `COMPARE     X` | Compare `R` to value at `X` and set flags     |
| `1000` | `JUMP        X` | Set program counter to `X`                    |
| `1001` | `JUMPGT      X` | Set program counter to `X` if `GT` is set     |
| `1010` | `JUMPEQ      X` | Set program counter to `X` if `EQ` is set     |
| `1011` | `JUMPLT      X` | Set program counter to `X` if `LT` is set     |
| `1010` | `JUMPNEQ     X` | Set program counter to `X` if `EQ` is cleared |
| `1100` | `IN          X` | Input number to `X`                           |
| `1101` | `OUT         X` | Output value at `X`                           |
| `1110` | `HALT         ` | Halt execution                                |

_`COMPARE` is unsigned_

## Assembly Notes

| Note                                                       | Example      |
| ---------------------------------------------------------- | ------------ |
| Use mnemonics and numbers to specify instructions          | `OUT 34`     |
| Prefix a number with `$` to use hex                        | `OUT $22`    |
| Label definitions start with `:`                           | `:loop`      |
| Label references start with `@`                            | `JUMP @loop` |
| Use `.ORIGIN` to specify an origin (defaults to `0`)       | `.ORIGIN $F` |
| Use `.DATA` to insert raw numbers                          | `.DATA 90`   |
