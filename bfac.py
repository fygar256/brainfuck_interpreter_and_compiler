#!/usr/bin/env python3

"""
Brainfuck converter
Converts Brainfuck code to any language
"""
import sys
import json

# デフォルトの命令マッピング（C言語）
DEFAULT_INSTRUCTIONS = {
    '>': "ptr++; ",
    '<': "ptr--; ",
    '+': "(*ptr)++; ",
    '-': "(*ptr)--; ",
    '.': "putchar(*ptr); ",
    ',': "*ptr=getchar(); ",
    '[': "while(*ptr){ ",
    ']': "} "
}

def load_instructions(mapfile):
    """外部JSONファイルから命令マッピングを読み込む"""
    if mapfile == '':
        return DEFAULT_INSTRUCTIONS
    try:
        with open(mapfile, 'r') as fp:
            mapping = json.load(fp)
        # 必須キーの確認
        required_keys = set('><+-.,[]')
        missing = required_keys - set(mapping.keys())
        if missing:
            print(f"Warning: Missing keys in map file: {missing}", file=sys.stderr)
        return mapping
    except FileNotFoundError:
        print(f"Error: Map file '{mapfile}' not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in map file: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def emit(text, indent_level, indent_unit, at_line_start):
    """テキストを出力する。改行のたびに次の行頭へインデントを挿入する。"""
    for ch in text:
        if at_line_start and ch not in ('\n', '\r'):
            print(indent_unit * indent_level, end='')
            at_line_start = False
        print(ch, end='')
        if ch == '\n':
            at_line_start = True
    return at_line_start

def convert_brainfuck(filenameh, filename, filenamet, instructions):
    # インデント設定をマッピングから取り出す（変換対象の命令には含めない）
    indent_unit = "    "
    indent_chars = "["
    dedent_chars = "]"
    use_indent = bool(indent_unit)

    indent_level = 0
    at_line_start = True  # 行頭かどうか（インデント挿入タイミング管理）

    def print_file_raw(fp):
        """ヘッダ／テールはインデント処理なしでそのまま出力"""
        for ch in fp.read():
            print(ch, end='')

    def print_bf_char(char, indent_level, at_line_start):
        """brainfuckの1文字を変換して出力し、インデントレベルと行頭フラグを返す"""
        if char not in instructions:
            # brainfuck命令以外はすべて読み飛ばす
            return indent_level, at_line_start

        # dedent命令は出力前にレベルを下げる
        if use_indent and char in dedent_chars:
            indent_level = max(0, indent_level - 1)

        text = instructions[char]
        if use_indent:
            at_line_start = emit(text, indent_level, indent_unit, at_line_start)
        else:
            print(text, end='')

        # indent命令は出力後にレベルを上げる
        if use_indent and char in indent_chars:
            indent_level += 1

        return indent_level, at_line_start

    if filenameh != '':
        try:
            with open(filenameh, 'r') as fp:
                print_file_raw(fp)
        except FileNotFoundError:
            print(f"Error: File '{filenameh}' not found", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

    if filename != '':
        try:
            with open(filename, 'r') as fp:
                for char in fp.read():
                    indent_level, at_line_start = print_bf_char(char, indent_level, at_line_start)
        except FileNotFoundError:
            print(f"Error: File '{filename}' not found", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

    if filenamet != '':
        try:
            with open(filenamet, 'r') as fp:
                print_file_raw(fp)
        except FileNotFoundError:
            print(f"Error: File '{filenamet}' not found", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

def main():
    """メイン関数"""
    # オプション解析: -m <mapfile> を先に取り出す
    args = sys.argv[1:]
    mapfile = ''

    if '-m' in args:
        idx = args.index('-m')
        if idx + 1 >= len(args):
            print("Error: -m option requires a map file argument", file=sys.stderr)
            sys.exit(1)
        mapfile = args[idx + 1]
        del args[idx:idx + 2]

    l = len(args)
    if l not in (1, 2, 3):
        print(f"Usage: {sys.argv[0]} [-m <mapfile>] <headerfile> <file> <tailfile>", file=sys.stderr)
        print(f"or   : {sys.argv[0]} [-m <mapfile>] <headerfile> <file>", file=sys.stderr)
        print(f"or   : {sys.argv[0]} [-m <mapfile>] <file>", file=sys.stderr)
        sys.exit(1)

    if l == 1:
        filenameh = ''
        filename = args[0]
        filenamet = ''
    elif l == 2:
        filenameh = args[0]
        filename = args[1]
        filenamet = ''
    elif l == 3:
        filenameh = args[0]
        filename = args[1]
        filenamet = args[2]

    instructions = load_instructions(mapfile)
    convert_brainfuck(filenameh, filename, filenamet, instructions)

if __name__ == '__main__':
    main()
