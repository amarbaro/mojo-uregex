from uregex import findall


def main() raises:
    # a GPT-2 style pre-tokenizer: contractions, letters of any script, digit groups
    for tok in findall(r"(?i:'s|'t|'re)|\p{L}+|\p{N}{1,3}", "It's héllo 一二 12345"):
        print(tok)
