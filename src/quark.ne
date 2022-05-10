@{%
	const lexer = require('./lexer.js');
	const util = require('util');
%}
@lexer lexer

ROOT -> (_ IMPORT):* (_ BLOCK):*

IMPORT_NAME -> %identifier (_ "as" _ %identifier):?
IMPORT_MAP -> "{" (_ IMPORT_NAME (_ "," _ IMPORT_NAME):*):? _ "}"
IMPORT -> "import" _ IMPORT_MAP | ( IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string BREAK
DIRECT_EXPORT -> "export" _ IMPORT_MAP | "*" | ( IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string BREAK

BLOCK -> ("export" (_ "default"):? _):? STATEMENT | STRUCT_DECLARATION | ENUM_DECLARATION

STATEMENT -> HANDLE | ASSIGNMENT | VARIABLE_DECLARATION | FUNCTION_DECLARATION | SEQUENCE_STATEMENT | RETURN_STATEMENT | CALL

RETURN_STATEMENT -> "return" _ EXPRESSION
SEQUENCE_STATEMENT -> EXPRESSION "?>" STATEMENT

EXPRESSION -> (
    %identifier
    | NATIVE_LITERAL
    | ELEMENT_LITERAL
    | STRING_LITERAL
    | TERNARY
    | CALL
    | PROPERTY
    | COMPARISON
    | BITWISE
    | BOOLEAN
    | SUM
    | PRODUCT
    | EXPONENT
    | UNARY
    | COALESCE
    | SEQUENCE_EXPRESSION
    | ARRAY
    | ANONYMOUS_STRUCT
) 

# control feature extractions
CONTROL_BLOCK -> STATEMENT | ("{" (_ STATEMENT):* "}")
CONTROL_CONDITION ->  "(" _ EXPRESSION _ ")"

# control strucutres
IF -> "if" CONTROL_CONDITION _ CONTROL_BLOCK ( _ "else" _ "if" CONTROL_CONDITION _ CONTROL_BLOCK ):* ( _ "else" _ CONTROL_BLOCK):?
SWITCH -> "switch" CONTROL_CONDITION _ "{" ( _ "case" _ (LITERAL | %identifier) _ ":" ( _ CLAUSE):* ( _ "break" _ BREAK):?):* _ "}"
FOR -> "for" "(" (CLAUSE:? _ VALUE _ BREAK _ VALUE:?) | (TYPE _ ASSIGNMENT_IDENTIFIER _ ":" _ VALUE) ")" _ CONTROL_BLOCK
WHILE -> "while" CONTROL_CONDITION _ CONTROL_BLOCK
DO_WHILE -> "do" _ CONTROL_BLOCK _ "while" CONTROL_CONDITION

TERNARY -> EXPRESSION _ "?" _ EXPRESSION (_ ":" _ EXPRESSION):?

CALL -> "await":? EXPRESSION "(" | "?(" ( _ EXPRESSION ( _ "," EXPRESSION ):*):? _ ")"

PROPERTY -> EXPRESSION "." | "?." %identifier

# ordering is for order of operations
COMPARISON -> EXPRESSION _ ("!=" | ">=" | "<=" | ">" | "<" | "==") _ EXPRESSION
BITWISE -> EXPRESSION _ ("&" | "|" | "^" | "<<<" | ">>>" | "<<" | ">>") _ EXPRESSION
BOOLEAN -> EXPRESSION _ ("&&" | "||" ) _ EXPRESSION
SUM -> EXPRESSION _ ("+" | "-") _ EXPRESSION
PRODUCT -> EXPRESSION _ ("*" | "/" | "%") _ EXPRESSION
EXPONENT -> EXPRESSION _ "**" _ EXPRESSION

UNARY -> 
	"(" _ EXPRESSION _ ")" |
	(("-" | "!" | "~") EXPRESSION)

COALESCE -> EXPRESSION "??" EXPRESSION
SEQUENCE_EXPRESSION -> EXPRESSION "?>" EXPRESSION

ARRAY -> "[" (_ VALUE (_ "," _ VALUE):* ):? _ "]"

ANONYMOUS_STRUCT_VALUE -> %identifier | (%identifier _ "=" EXPRESSION)
ANONYMOUS_STRUCT -> "{"
    (_ ANONYMOUS_STRUCT_VALUE (_ "," _ ANONYMOUS_STRUCT_VALUE):* ):? _
"}"

ENUM_DECLARATION -> (
    "enum" _ "{"
        ( _ %identifier _ ";"):*
        _
    "}"
)

STRUCT_DECLARATION -> (
    "struct" _ TYPE_DECLARATION _ "{"
        ( _ VARIABLE_DECLARATION | CONSTRUCTOR ):*
        _
    "}"
)

CONSTRUCTOR_PARAMETER -> PARAMETER_DECLARATION | VARIABLE_DECLARATION
CONSTRUCTOR_PARAMETERS -> (
    CONSTRUCTOR_PARAMETER ( _ "," _ CONSTRUCTOR_PARAMETER):*
)
CONSTRUCTOR -> "async":? "function" _ "(" ( _ FUNCTION_PARAMETERS ):? _ ")" _ "{"
    STATEMENT:*
"}"

HANDLE_EFFECT -> (
    ("with" | "catch") _
    "(" _ VARIABLE_DECLARATION _ ")" _
    "{" 
        STATEMENT:*
    "}"
)

HANDLE -> (
    "handle" _ "{"
        STATEMENT:*
    "}"
    ( _ HANDLE_EFFECT ):*
)

# things like:
# param?, param ?? value, param { param? }
DESTRUCTURED_PARAMETER -> FUNCTION_PARAMETER "?" | ( _ ?? STATEMENT):? | PARAMETER_DESTRUCTUR:?
# things like:
# { param1?, param2? }
PARAMETER_DESTRUCTUR -> (
    "{"
        DESTRUCTURED_PARAMETER:? ( _ "," _ DESTRUCTURED_PARAMETER):* _
    "}"
)
# things like:
# value, int value, { value }
FUNCTION_PARAMETER -> PARAMETER_DECLARATION | VARIABLE_DECLARATION | PARAMETER_DESTRUCTUR
FUNCTION_PARAMETERS -> (
    FUNCTION_PARAMETER ( _ "," _ FUNCTION_PARAMETER):*
)

FUNCTION_DECLARATION -> (
    "async":? "function" _ "(" ( _ FUNCTION_PARAMETERS ):? _ ")" _ "{"
        STATEMENT:*
    "}"
)

ASSIGNMENT -> %identifier _ %assignment _ EXPRESSION

# things like:
# let a[]?, int b = 1;
VARIABLE_DECLARATION -> TYPE _ PARAMETER_DECLARATION ("=" _ EXPRESSION):?
PARAMETER_DECLARATION -> %identifier ("[" "]"):? "?":?

# element literal
# <></>, <tag></>, <tag value=1/> <tag>value</>
ELEMENT_BODY -> ">" (_ EXPRESSION):? _ %tag_close
ELEMENT_FRAGMENT -> "<" _ ELEMENT_BODY
ELEMENT_LITERAL -> "<" EXPRESSION (_ %identifier _ "=" _ EXPRESSION):* _ "/>" | ELEMENT_BODY

# string literal
# `this is some text ${getValue()} more text`
STRING_LITERAL -> %lit_str_start (
    %str_content
    | %escape
    | (%interp _ EXPRESSION _ "}")
):* %lit_str_end

# literal values such as numbers text and undefined
NATIVE_LITERAL -> (
    %int	|
	%float	|
	%hex    |
	%string |
	%undefined
)

# things like:
# Type, Type<int>, Type1<Type2<int>>, Type1<int, int>
TYPE -> %type | (%identifier ("<" _ TYPE:? ( _  "," _ TYPE):* _ ">"):?)
# things like:
# Type<T>, Type<ParentType T>, Type<T, K>
TYPE_DECLARATION_PARAM -> ( TYPE _ ):? %identifier
TYPE_DECLARATION -> %identifier ( "<" _ TYPE_DECLARATION_PARAM:? ( _  "," _ TYPE_DECLARATION_PARAM):* _ ">" ):?

# semantic things
BREAK -> ";"
_ -> %whitespace:?