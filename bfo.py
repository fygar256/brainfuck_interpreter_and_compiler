#!/usr/bin/env python3
import argparse

# Commands that can be compressed (now includes [])
BF_COMMANDS = set("><+-.,[]")


def compress_bf(s):
    if not s:
        return ""

    result = []
    prev = None
    count = 0

    for ch in s:
        if ch == prev and ch in BF_COMMANDS:
            count += 1
        else:
            if prev is not None:
                if prev in BF_COMMANDS and count > 1:
                    result.append(f"{prev}{count}")
                else:
                    result.append(prev * count)
            prev = ch
            count = 1

    # Don't forget the last character/sequence
    if prev is not None:
        if prev in BF_COMMANDS and count > 1:
            result.append(f"{prev}{count}")
        else:
            result.append(prev * count)

    return "".join(result)


def decompress_bf(s):
    result = []
    i = 0

    while i < len(s):
        ch = s[i]

        if ch in BF_COMMANDS:
            i += 1
            num = 0
            # Read the number following the command
            while i < len(s) and s[i].isdigit():
                num = num * 10 + int(s[i])
                i += 1

            # If no number was specified, it means repeat once
            if num == 0:
                result.append(ch)
            else:
                result.append(ch * num)
        else:
            # Non-compressible character (like whitespace/comments)
            result.append(ch)
            i += 1

    return "".join(result)


def main():
    parser = argparse.ArgumentParser(
        description="Brainfuck RLE compress / decompress tool"
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-c", "--compress", action="store_true", help="compress")
    group.add_argument("-d", "--decompress", action="store_true", help="decompress")

    parser.add_argument("input", help="input .bf file")
    parser.add_argument("output", help="output file")

    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        src = f.read()

    if args.compress:
        dst = compress_bf(src)
    else:
        dst = decompress_bf(src)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(dst)


if __name__ == "__main__":
    main()
