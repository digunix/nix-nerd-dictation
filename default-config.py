# Default English configuration for nerd-dictation
# This file is automatically installed to ~/.config/nerd-dictation/nerd-dictation.py

def nerd_dictation_process(text):
    """
    Text replacement function for English punctuation and common expressions.
    Converts spoken punctuation and symbols to their written form.
    """

    # Navigation and formatting (process first - these are commands)
    text = text.replace(" new line", "\n")
    text = text.replace(" newline", "\n")
    text = text.replace(" new paragraph", "\n\n")
    text = text.replace(" tab", "\t")

    # Punctuation - basic
    text = text.replace(" comma", ",")
    text = text.replace(" period", ".")
    text = text.replace(" full stop", ".")
    text = text.replace(" question mark", "?")
    text = text.replace(" exclamation mark", "!")
    text = text.replace(" exclamation point", "!")
    text = text.replace(" colon", ":")
    text = text.replace(" semicolon", ";")
    text = text.replace(" semi colon", ";")
    text = text.replace(" ellipsis", "...")
    text = text.replace(" dot dot dot", "...")

    # Dashes and hyphens
    text = text.replace(" dash", " - ")
    text = text.replace(" hyphen", "-")
    text = text.replace(" em dash", " -- ")
    text = text.replace(" en dash", " - ")

    # Quotes and brackets
    text = text.replace(" open paren", " (")
    text = text.replace(" close paren", ")")
    text = text.replace(" open parenthesis", " (")
    text = text.replace(" close parenthesis", ")")
    text = text.replace(" left paren", " (")
    text = text.replace(" right paren", ")")
    text = text.replace(" open bracket", " [")
    text = text.replace(" close bracket", "]")
    text = text.replace(" left bracket", " [")
    text = text.replace(" right bracket", "]")
    text = text.replace(" open brace", " {")
    text = text.replace(" close brace", "}")
    text = text.replace(" left brace", " {")
    text = text.replace(" right brace", "}")
    text = text.replace(" open quote", ' "')
    text = text.replace(" close quote", '"')
    text = text.replace(" end quote", '"')
    text = text.replace(" quote", '"')
    text = text.replace(" single quote", "'")
    text = text.replace(" apostrophe", "'")

    # Common symbols - email/web
    text = text.replace(" at sign", "@")
    text = text.replace(" at symbol", "@")
    text = text.replace(" dot com", ".com")
    text = text.replace(" dot org", ".org")
    text = text.replace(" dot net", ".net")
    text = text.replace(" dot io", ".io")

    # Common symbols - general
    text = text.replace(" hash", "#")
    text = text.replace(" hashtag", "#")
    text = text.replace(" pound sign", "#")
    text = text.replace(" number sign", "#")
    text = text.replace(" dollar sign", "$")
    text = text.replace(" dollar", "$")
    text = text.replace(" percent", "%")
    text = text.replace(" percent sign", "%")
    text = text.replace(" ampersand", "&")
    text = text.replace(" and sign", "&")
    text = text.replace(" asterisk", "*")
    text = text.replace(" star", "*")
    text = text.replace(" plus sign", "+")
    text = text.replace(" plus", "+")
    text = text.replace(" equals sign", "=")
    text = text.replace(" equals", "=")
    text = text.replace(" equal sign", "=")
    text = text.replace(" minus sign", "-")
    text = text.replace(" minus", "-")
    text = text.replace(" underscore", "_")
    text = text.replace(" slash", "/")
    text = text.replace(" forward slash", "/")
    text = text.replace(" backslash", "\\")
    text = text.replace(" back slash", "\\")
    text = text.replace(" pipe", "|")
    text = text.replace(" vertical bar", "|")
    text = text.replace(" tilde", "~")
    text = text.replace(" caret", "^")
    text = text.replace(" less than", "<")
    text = text.replace(" greater than", ">")
    text = text.replace(" left angle", "<")
    text = text.replace(" right angle", ">")

    # Programming symbols
    text = text.replace(" arrow", "->")
    text = text.replace(" fat arrow", "=>")
    text = text.replace(" double arrow", "=>")
    text = text.replace(" triple equals", "===")
    text = text.replace(" double equals", "==")
    text = text.replace(" not equals", "!=")
    text = text.replace(" plus plus", "++")
    text = text.replace(" minus minus", "--")
    text = text.replace(" plus equals", "+=")
    text = text.replace(" minus equals", "-=")
    text = text.replace(" colon colon", "::")
    text = text.replace(" double colon", "::")

    # Clean up spacing around punctuation
    text = text.replace(" ,", ",")
    text = text.replace(" .", ".")
    text = text.replace(" ?", "?")
    text = text.replace(" !", "!")
    text = text.replace(" :", ":")
    text = text.replace(" ;", ";")
    text = text.replace("( ", "(")
    text = text.replace(" )", ")")
    text = text.replace("[ ", "[")
    text = text.replace(" ]", "]")
    text = text.replace("{ ", "{")
    text = text.replace(" }", "}")
    text = text.replace("  ", " ")  # Remove double spaces

    return text
