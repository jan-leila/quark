@{%
	const lexer = require('../src/lexer.js');
%}
@lexer lexer

ROOT -> (_ IMPORT):* (_ BLOCK):*

MANY[T] -> $T (_ "," _ $T):*

IMPORT_NAME -> %identifier (_ "as" _ %identifier):?
IMPORT_MAP -> "{" (_ MANY[IMPORT_NAME]):? _ "}"
IMPORT -> "import" _ (IMPORT_MAP | IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string SEMI
DIRECT_EXPORT -> "export" _ (IMPORT_MAP | "*" | IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string SEMI

BLOCK -> ("export" (_ "default"):? _):? (ENUM | STRUCT | FUNCTION | EVENT | MONAD | STATEMENT)

ENUM -> "enum" _ %identifier _ "{" (_ %identifier SEMI (_ %identifier SEMI):* ):? _ "}"

ARRAY_DECLARATION -> "[" (_ EXPRESSION):? _ "]"

STRUCT_VAR -> (TYPE _):? %identifier "?":? (ARRAY_DECLARATION "?":? ):*
STRUCT_CONTENTS -> ("{"
    (_ STRUCT_VAR _ SEMI):*
    (
        _ STRUCT_VAR "?":?  _ SEMI
        | _ STRUCT_VAR "?":? (_ "=" _ EXPRESSION)  _ SEMI
    ):*
    _
"}")

STRUCT -> "struct" (_ GENERIC):? _ %identifier (_ "extends" _ TYPE):? _ STRUCT_CONTENTS

EVENT -> "event" (_ GENERIC):? _ %identifier (_ "in" _ STRUCT_CONTENTS):? (_ "out" _ STRUCT_CONTENTS):?

MONAD -> "monad" (_ GENERIC):? _ %identifier _ STRUCT_CONTENTS _ "bind" _ "(" _ FUNCTION_PARAMETERS:? _ ")" _ STATEMENT (_ "reduce" (_ "(" _ FUNCTION_PARAMETER _ ")"):? _ STATEMENT):*

STATEMENT -> (
    SCOPE
    | EXPRESSION _ SEMI
    | INLINE_SEQUENCE _ SEMI
    | DECLARATION _ SEMI
    | IF
    | SWITCH
    | WHILE
    | DO_WHILE
    | FOR
    | TRY
)

HANDLE -> "handle" _ "(" _ FUNCTION_PARAMETER _ ")" _ SCOPED_STATMENT
CATCH -> "catch" _ "(" _ FUNCTION_PARAMETER _ ")" _ SCOPED_STATMENT
TRY -> "try" _ STATEMENT (_ HANDLE | _ CATCH):+

BREAK -> "break"
CONTINUE -> "CONTINUE"
RETURN -> "return" (_ EXPRESSION):?
USE -> "use" (_ EXPRESSION):?
SCOPED_STATMENT -> (
    STATEMENT
    | BREAK
    | CONTINUE
    | RETURN
    | USE
)
SCOPE -> "{" (_ SCOPED_STATMENT (_ SCOPED_STATMENT):*):? _ "}"

CONTROL_CONDITION ->  "(" _ EXPRESSION _ ")"

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

FOR_CONDITIONS -> STATEMENT _ SEMI _ EXPRESSION _ SEMI _ STATEMENT
ENHANCED_FOR_CONDITIONS -> FUNCTION_PARAMETER _ ":" _ EXPRESSION
FOR -> "for" _ "(" _ ( FOR_CONDITIONS | ENHANCED_FOR_CONDITIONS ) _ ")" _ STATEMENT

DECLARATION_IDENTIFIER -> %identifier "?":? (_ ARRAY_DECLARATION "?":?):*
DECLARATION -> (TYPE _):? (
    DECLARATION_IDENTIFIER
    | (
        DECLARATION_IDENTIFIER
        | DESTRUCTURE_ITERATOR
        | DESTRUCTURE_STRUCT
    ) _ "=" _ EXPRESSION
)
INLINE_SEQUENCE -> (TYPE _):? (%identifier | DESTRUCTURE_STRUCT) _ "<<=" _ EXPRESSION

EXPRESSION -> ASSIGNMENT {% (value) => ["start count", value[0]]%}

@{%
    const did = value => value[0][0];
    const normalize = value => value.filter(value => value).map(value => value[0][0]);
%}

CHAIN[LEFT, RIGHT] -> $LEFT | $RIGHT {% did %}

OPERATOR[           SELF, TOKEN,          NEXT] -> CHAIN[$SELF _ $TOKEN _ $NEXT {% normalize %},                        $NEXT] {% did %}
PREFIX_OPERATOR[    SELF, TOKEN,          NEXT] -> CHAIN[$TOKEN _ $SELF {% normalize %},                                $NEXT] {% did %}
TERNARY_OPERATOR[   SELF, TOKEN, SPLITER, NEXT] -> CHAIN[$SELF _ $TOKEN _ $NEXT (_ $SPLITER _ $NEXT):?, $NEXT] {% did %}
POSTFIX_OPERATOR[   SELF, TOKEN,          NEXT] -> CHAIN[$SELF _ $TOKEN {% normalize %},                                $NEXT] {% did %}
GROUPING_OPERATOR[  SELF,                 NEXT] -> CHAIN["(" _ $SELF _ ")" {% normalize %},                             $NEXT] {% did %}

CALL_OPERATOR[  FROM, INPUT, NEXT]  ->  CHAIN[$FROM ("(" | "?("):? (_ $INPUT _ ","):* (_ $INPUT):? _ ")",  $NEXT] {% did %}
MEMBER_OPERATOR[FROM, NEXT]         ->  CHAIN[$FROM ("." | "?."):? %identifier,                            $NEXT] {% did %}
INDEX_OPERATOR[ FROM, INPUT, NEXT]  ->  CHAIN[$FROM ("[" | "?["):? _ $INPUT _ "]",                         $NEXT] {% did %}

ASSIGNMENT  ->  OPERATOR[           %identifier,                %assignment,                            SEQUENCE    ] {% id %}
SEQUENCE    ->  OPERATOR[           SEQUENCE,                   ">>=",                                  WITH        ] {% id %}
WITH        ->  PREFIX_OPERATOR[    WITH,                       "with",                                 TERNARY     ] {% id %}
TERNARY     ->  TERNARY_OPERATOR[   TERNARY,                    "?",             ":",                   COALESCE    ] {% id %}
COALESCE    ->  OPERATOR[           COALESCE,                   "??",                                   OR          ] {% id %}
OR          ->  OPERATOR[           OR,                         "||",                                   AND         ] {% id %}
AND         ->  OPERATOR[           AND,                        "&&",                                   BIT_OR      ] {% id %}
BIT_OR      ->  OPERATOR[           BIT_OR,                     "|",                                    BIT_XOR     ] {% id %}
BIT_XOR     ->  OPERATOR[           BIT_XOR,                    "^",                                    BIT_AND     ] {% id %}
BIT_AND     ->  OPERATOR[           BIT_AND,                    "&",                                    EQUALITY    ] {% id %}
EQUALITY    ->  OPERATOR[           EQUALITY,                   ("==" | "!="),                          COMPARISON  ] {% id %}
COMPARISON  ->  OPERATOR[           COMPARISON,                 (">=" | "<=" | "<" | ">"),              SHIFT       ] {% id %}
SHIFT       ->  OPERATOR[           SHIFT,                      ("<<<" | ">>>" | "<<" | ">>"),          SUM         ] {% id %}
SUM         ->  OPERATOR[           SUM,                        ("+" | "-"),                            PRODUCT     ] {% id %}
PRODUCT     ->  OPERATOR[           PRODUCT,                    ("*" | "/" | "%"),                      POWER       ] {% id %}
POWER       ->  OPERATOR[           POWER,                      "**",                                   PREFIX      ] {% id %}
PREFIX      ->  PREFIX_OPERATOR[    PREFIX,                     ("!" | "~" | "-" | "++" | "--"){% id %},POSTFIX     ] {% id %}
POSTFIX     ->  POSTFIX_OPERATOR[   POSTFIX,                    ("++" | "--"),                          CALL        ] {% id %}
CALL        ->  CALL_OPERATOR[      CALL, GROUPING,                                                 MEMBER      ] {% id %}
MEMBER      ->  MEMBER_OPERATOR[    MEMBER,                                                           INDEX       ] {% id %}
INDEX       ->  INDEX_OPERATOR[     INDEX, GROUPING,                                                 GROUPING    ] {% id %}
GROUPING    ->  CHAIN[              "(" _ GROUPING _ ")",                                               VALUE       ] {% id %}

VALUE -> (
    %identifier
    | LITERAL               {% id %}
    | TEMPLATE_STRING       {% id %}
    | REGEX                 {% id %}
    | FRAGMENT              {% id %}
    | ELEMENT               {% id %}
    | ANONYMOUS_FUNCTION    {% id %}
    | ARRAY                 {% id %}
    | ANONYMOUS_STRUCT      {% id %}
    | ANONYMOUS_ITERATOR    {% id %}
) {% id %}

ANONYMOUS_ITERATOR_VALUE -> EXPRESSION | "..." EXPRESSION
ANONYMOUS_ITERATOR -> "[" (_ MANY[ANONYMOUS_ITERATOR_VALUE] (_ ","):? ):? _ "]"

ANONYMOUS_STRUCT_VALUE -> (TYPE _):? %identifier (_ "=" _ EXPRESSION):? | "..." EXPRESSION
ANONYMOUS_STRUCT -> "{" (_ MANY[ANONYMOUS_STRUCT_VALUE] (_ ","):?):? _ "}"

SPREAD_MEMBER -> "..." %identifier

DESTRUCTURE_ITERATOR_MEMBER -> (TYPE _):? (
    %identifier "?" (_ "=" %identifier):?
    | DESTRUCTURE_ITERATOR
    | DESTRUCTURE_STRUCT
)
DESTRUCTURE_ITERATOR -> ( "["
    (
        _ MANY[(DESTRUCTURE_ITERATOR_MEMBER)]
        ( _ "," (_ SPREAD_MEMBER):?):?
    ):?
_ "]")

DESTRUCTURED_STRUCT_MEMBER -> (TYPE _):? (
    %identifier "?":? _ (
        "=" _ VALUE
        | ":" _ (DESTRUCTURE_ITERATOR | DESTRUCTURE_STRUCT)
    ):?
)
DESTRUCTURE_STRUCT -> ( "{"
    (
        _ MANY[DESTRUCTURED_STRUCT_MEMBER]
        ( _ "," (_ SPREAD_MEMBER):?):?
    ):?
_ "}")

FUNCTION_PARAMETER -> (TYPE _):? (%identifier "?":? | DESTRUCTURE_ITERATOR | DESTRUCTURE_STRUCT)
FUNCTION_PARAMETERS -> MANY[FUNCTION_PARAMETER]
ANONYMOUS_FUNCTION -> (GENERIC _):? ( FUNCTION_PARAMETERS | "(" _ FUNCTION_PARAMETERS:? _ ")") _ "=>" _ STATEMENT
FUNCTION -> "function" _ (GENERIC _):? %identifier _ "(" _ FUNCTION_PARAMETERS:? _ ")" _ STATEMENT

TYPE -> (
    "any"
    | "symbol"
    | "boolean"
    | "int"
    | "float"
    | "string"
    | "char"
) | (
    (
        %identifier
        | "func"
    )
    (
        "<" (_ MANY[TYPE]):? _ ">"
    ):?
)

GENERIC_ITEM -> %identifier ( _ "extends" TYPE):?
GENERIC -> "<" (_ MANY[GENERIC_ITEM]):? _ ">"

ELEMENT_CONTENT -> (EXPRESSION (_ EXPRESSION):*):?
FRAGMENT -> "<" _ ">" _ ELEMENT_CONTENT _ "</" _ ">"
ELEMENT -> "<" _ %identifier (_ %identifier _ "=" _ EXPRESSION):* _ (
    "/>"
    | ">" _ ELEMENT_CONTENT _ "<" (_ %identifier):? _ ">"
)

"<" _ %identifier (_ %identifier _ "=" _ EXPRESSION):* _ ("/>" | ">" (_ EXPRESSION):* _ %tag_close (_ %identifier):? _ ">")

ANONYMOUS_STRUCT_VALUE -> %identifier | (%identifier _ "=" EXPRESSION)
ANONYMOUS_STRUCT -> "{"
    (_ MANY[ANONYMOUS_STRUCT_VALUE]):? _
"}"

ARRAY -> "[" (_ MANY[EXPRESSION]):? _ "]"

# TODO: real regex parsing
REGEX -> %regex %regex_content %regex_end

TEMPLATE_STRING -> %template_string_start (
    %template_string_content    |
    (%template_string_interpreter _ EXPRESSION _ "}")
):* %template_string_end

LITERAL -> (
	"null"
    | %binary
    | %hex
    | %int
    | %float
    | %color
	| %string
) {% id %}

SEMI -> ";" {%() => null%}
# mandatory whitespace
__ -> (%whitespace | %comment):+ {%() => null%}
# optional whitespace 
_ -> (%whitespace | %comment):* {%() => null%}
