#!/usr/bin/env python3
"""
Brainfuck to Assembly-like converter
Converts Brainfuck code to pseudo-assembly instructions
"""

import sys


def convert_brainfuck(filename):
    """
    Brainfuckファイルを読み込み、疑似アセンブリ命令に変換する
    
    Args:
        filename: 入力ファイル名
    """
    # 命令マッピング
    instructions = {
        '>': 'inc p',
        '<': 'dec p',
        '+': 'inc *p',
        '-': 'dec *p',
        '.': 'output',
        ',': 'input',
        '[': 'while *p',
        ']': 'wend'
    }
    
    try:
        with open(filename, 'r') as fp:
            for char in fp.read():
                if char in instructions:
                    print(instructions[char])
    
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    """メイン関数"""
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <file>", file=sys.stderr)
        sys.exit(1)
    
    convert_brainfuck(sys.argv[1])


if __name__ == '__main__':
    main()

