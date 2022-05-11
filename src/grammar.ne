
ROOT -> (_ IMPORT):* (_ BLOCK):*

IMPORT_NAME -> %identifier (_ "as" _ %identifier):?
IMPORT_MAP -> "{" (_ IMPORT_NAME (_ "," _ IMPORT_NAME):*):? _ "}"
IMPORT -> "import" _ (IMPORT_MAP | IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string BREAK
DIRECT_EXPORT -> "export" _ (IMPORT_MAP | "*" | IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string BREAK

# statements that can only be used at the top level
BLOCK -> ("export" (_ "default"):? _):? (STATEMENT | STRUCT_DECLARATION | ENUM_DECLARATION)

# chunks of code that do an action
STATEMENT -> (
    HANDLE
    | VARIABLE_DECLARATION
    | FUNCTION_DECLARATION
    | SEQUENCE_STATEMENT
    | RETURN_STATEMENT
    | CALL
    | BREAK_STATEMENT
    | RETURN_STATEMENT
    | IF
    | SWITCH
    | WHILE
    | DO_WHILE
    | FOR
) _ BREAK | SCOPE_STATEMENT

SCOPE_STATEMENT -> "{" (_ STATEMENT):* _ "}"
BREAK_STATEMENT -> "break"
RETURN_STATEMENT -> "return" _ EXPRESSION
SEQUENCE_STATEMENT -> EXPRESSION "?>" STATEMENT

# control feature extractions
CONTROL_CONDITION ->  "(" _ EXPRESSION _ ")"

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

FUNCTION_DECLARATION -> (
    "async":? "function" _ FUNCTION_PARAMETERS _ "{"
        STATEMENT:*
    "}"
)

STRUCT_DECLARATION -> (
    "struct" _ TYPE_DECLARATION _ "{"
        ( _ ( VARIABLE_DECLARATION | CONSTRUCTOR )):*
        _
    "}"
)

ENUM_DECLARATION -> (
    "enum" _ "{"
        ( _ %identifier _ ";"):*
        _
    "}"
)

IF -> "if" _ CONTROL_CONDITION _ STATEMENT ( _ "else" _ "if" CONTROL_CONDITION _ STATEMENT ):* ( _ "else" _ STATEMENT):?
SWITCH -> "switch" _ CONTROL_CONDITION _ "{" (
    _ "case" _ EXPRESSION _ ":"
    (
        _ ("case" _ EXPRESSION _ ":" | STATEMENT )
    ):*
    _
):? _ "}"
WHILE -> "while" _ CONTROL_CONDITION _ STATEMENT
DO_WHILE -> "do" _ STATEMENT _ "while" CONTROL_CONDITION

FOR_CONDITIONS -> STATEMENT _ ";" _ EXPRESSION _ ";" _ STATEMENT
ENHANCED_FOR_CONDITIONS -> PARAMETER_DECLARATION _ ":" _ EXPRESSION
FOR -> "for" _ "(" _ ( FOR_CONDITIONS | ENHANCED_FOR_CONDITIONS ) _ ")" _ STATEMENT

# something that resolves to a value
EXPRESSION -> (
    %identifier
    | NATIVE_LITERAL
    | STRING_LITERAL
    | ELEMENT_LITERAL
    | TERNARY
    | ASSIGNMENT
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
    | ANONYMOUS_FUNCTION
) 

TERNARY -> EXPRESSION _ "?" _ EXPRESSION (_ ":" _ EXPRESSION):?

CALL -> ("await" _ ):? EXPRESSION _ ("(" | "?(") _ (EXPRESSION ( _ "," _ EXPRESSION ):* _ ):? ")"

PROPERTY -> EXPRESSION ("." | "?.") %identifier

# ordering is for order of operations
COMPARISON -> EXPRESSION _ ("!=" | ">=" | "<=" | ">" | "<" | "==") _ EXPRESSION
BITWISE -> EXPRESSION _ ("&" | "|" | "^" | "<<<" | ">>>" | "<<" | ">>") _ EXPRESSION
BOOLEAN -> EXPRESSION _ ("&&" | "||" ) _ EXPRESSION
SUM -> EXPRESSION _ ("+" | "-") _ EXPRESSION
PRODUCT -> EXPRESSION _ ("*" | "/" | "%") _ EXPRESSION
EXPONENT -> EXPRESSION _ "**" _ EXPRESSION

UNARY -> 
	"(" _ EXPRESSION _ ")" |
	("-" | "!" | "~") EXPRESSION

COALESCE -> EXPRESSION "??" EXPRESSION
SEQUENCE_EXPRESSION -> EXPRESSION "?>" EXPRESSION

ARRAY -> "[" (_ EXPRESSION (_ "," _ EXPRESSION):* ):? _ "]"

ANONYMOUS_STRUCT_VALUE -> %identifier | (%identifier _ "=" EXPRESSION)
ANONYMOUS_STRUCT -> "{"
    (_ ANONYMOUS_STRUCT_VALUE (_ "," _ ANONYMOUS_STRUCT_VALUE):* ):? _
"}"

CONSTRUCTOR_PARAMETERS -> (
    PARAMETER_DECLARATION ( _ "," _ PARAMETER_DECLARATION):*
)
CONSTRUCTOR -> "async":? "function" _ "(" ( _ FUNCTION_PARAMETERS ):? _ ")" _ "{"
    STATEMENT:*
"}"

# things like:
# param?, param ?? value, param { param? }
DESTRUCTURED_PARAMETER -> FUNCTION_PARAMETER ("?" | (_ "??" STATEMENT | PARAMETER_DESTRUCTUR)):?
# things like:
# { param1?, param2? }
PARAMETER_DESTRUCTUR -> (
    "{"
        DESTRUCTURED_PARAMETER:? ( _ "," _ DESTRUCTURED_PARAMETER):*
        ( _ "..." _ %identifier):?
        _
    "}"
)
# things like:
# value, int value, { value }
FUNCTION_PARAMETER -> PARAMETER_DECLARATION | PARAMETER_DESTRUCTUR
FUNCTION_PARAMETERS -> "(" _ (
    FUNCTION_PARAMETER ( _ "," _ FUNCTION_PARAMETER):*
):? _ ")"
ANONYMOUS_FUNCTION -> (
    "async":? ("function" _ FUNCTION_PARAMETERS | FUNCTION_PARAMETERS _ "=>") _ "{"
        STATEMENT:*
    "}"
)

# a = 1, b = "test"
ASSIGNMENT -> %identifier (_ %assignment _ EXPRESSION | "++" | "--")

# let a[]?, int b = 1;
VARIABLE_DECLARATION -> TYPE _ VARIABLE_KEYWORD (_ "=" _ EXPRESSION):?
# let a, int b, stirng c[]?, d
PARAMETER_DECLARATION -> (TYPE _):? VARIABLE_KEYWORD
# a[]?, b?, c[], d
VARIABLE_KEYWORD -> %identifier ("[" _ "]"):? "?":?

# Type, Type<int>, Type1<Type2<int>>, Type1<int, int>
TYPE -> %type | (%identifier ("<" _ TYPE:? ( _  "," _ TYPE):* _ ">"):?)
# Type<T>, Type<ParentType T>, Type<T, K>
TYPE_DECLARATION_PARAM -> ( TYPE _ ):? %identifier
TYPE_DECLARATION -> %identifier ( "<" _ TYPE_DECLARATION_PARAM:? ( _  "," _ TYPE_DECLARATION_PARAM):* _ ">" ):?

# <></>, <tag></>, <tag value=1/> <tag>value</>
ELEMENT_LITERAL -> "<" EXPRESSION (_ %identifier _ "=" _ EXPRESSION):* _ ("/>" | ">" (_ EXPRESSION):? _ %tag_close)

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

# semantic things
BREAK -> ";"
_ -> %whitespace:?
