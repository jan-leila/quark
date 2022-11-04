@{%
	const lexer = require('../src/engine/lexer.js');
    const util = require('util');
    const log = (value) => {
        console.log(util.inspect(value, { showHidden: false, depth: null, colors: true }));
        return value
    }
    const location = (value) => {
        let {
            offset,
            lineBreaks,
            line,
            col,
        } = value[0]
        return {
            offset,
            lineBreaks,
            line,
            col,
        }
    }
    const did = value => value[0][0];
    const normalize = (value) => {
        value.filter(value => value).map(value => value[0][0])
    }
    const strip = (type, characters) => {
        return (value) => {
            return {
                type,
                value: value[0].value.substring(characters, value[0].value.length - 1),
                ...location(value)
            }
        }
    }
    const statement = (name) => {
        return (value) => {
            return {
                type: name,
                ...value[0]
            }
        }
    }
    const tag = (name, lambda) => (it) => [name, lambda?.(it) ?? it]

    const chain = (...args) => (init) =>  args.reduce((data, lambda) => lambda(data), init)
%}

@lexer lexer

MANY[T] -> $T (_ "," _ $T):* {%(value) => {
    return [
        value[0],
        ...value[1].map((next_value) => {
            return next_value[3]
        })
    ]
}%}
MANYP[T] -> MANY[$T] (_ ","):? {%(value) => {
    return value[0]
}%}

ROOT -> (_ IMPORT):* (_ TOP_STATEMENT {% ([_, statement]) => statement %}):* {% ([ imports, statements]) => {
    return {
        imports,
        statements,
    }
} %}

IMPORT -> "import" _ (IMPORT_MAP | %identifier ( _ IMPORT_MAP):?) _ "from" _ STRING BREAK
IMPORT_MAP -> "{" (_ MANY[IMPORT_NAME]):? _ "}"
IMPORT_NAME -> %identifier (_ "as" _ %identifier):?

TOP_STATEMENT -> (STATEMENT | EXPORT_EXPRESSION)  _ BREAK {% did %}

EXPORT_EXPRESSION -> "export" _ (EXPORT_NAME | "{" MANYP[EXPORT_NAME] "}")
EXPORT_NAME -> %identifier | EXPRESSION _ "as" (%identifier | "default")

STATEMENT -> (PURE_STATEMENT | EXPRESSION) {% did %}

PURE_STATEMENT -> (
    BLOCK
    | INLINE_SEQUENCE
    | DECLARATION
    | BREAK_STATMENT
    | CONTINUE
    | RETURN
    | USE
    | SWITCH
    | IF
    | WHILE
    | DO_WHILE
    | FOR
    | TRY
)

BLOCK -> "(" _ (PURE_STATEMENT | STATEMENT (_ STATEMENT):+):? ")"

TRY -> LABEL:? "try" _ STATEMENT (_ HANDLE):*
HANDLE -> LABEL:? "handle" _ MANY[EXPRESSION] _ SINGLE_PARAMETER _ STATEMENT

BREAK_STATMENT -> "break" (_ %identifier):?
CONTINUE -> "continue" (_ %identifier):?
RETURN -> "return" (_ EXPRESSION):?
USE -> "use" (_ EXPRESSION):?

CONTROL_CONDITION ->  "(" (_ STATEMENT):? _ EXPRESSION _ ")"

IF -> LABEL:? "if" _ CONTROL_CONDITION _ STATEMENT ( _ LABEL "else" _ "if" CONTROL_CONDITION _ STATEMENT ):* ( _ LABEL "else" _ STATEMENT):?
SWITCH -> LABEL:? "switch" _ CONTROL_CONDITION _ "(" (
    _ CASE
    (
        _ (CASE | STATEMENT )
    ):*
    _
):? _ ")"
CASE -> "case" _ EXPRESSION _ ":"
WHILE -> LABEL:? "while" _ CONTROL_CONDITION _ STATEMENT 
DO_WHILE -> LABEL:? "do" _ STATEMENT _ "while" CONTROL_CONDITION

ENHANCED_FOR_CONDITIONS -> FUNCTION_PARAMETER _ ":" _ EXPRESSION
FOR -> LABEL:? "for" _ "(" _ ENHANCED_FOR_CONDITIONS _ ")" _ STATEMENT

DECLARATION -> (
    DECLARATION_TYPE _ MANY[%identifier]
    | DECLARATION_TYPE _ ( %identifier | DESTRUCTURE_ITERATOR | DESTRUCTURE_STRUCT) _ "=" _ EXPRESSION
)
DECLARATION_TYPE -> "let" | EXPRESSION (_ "?"):? (_ "[" _ "]" (_ "?"):?):*
INLINE_SEQUENCE -> (EXPRESSION _):? (%identifier | DESTRUCTURE_STRUCT) _ "<<=" _ EXPRESSION

LABEL -> (%identifier _ ":" _)

@{%
    const CHAIN_LEFT = 'CHAIN_LEFT'
    const CHAIN_RIGHT = 'CHAIN_RIGHT'

    const unwrap_operation = (processor) => {
        return ([ tag, contents]) => {
            switch(tag) {
                case CHAIN_LEFT:
                    return processor?.(contents) ?? contents
                case CHAIN_RIGHT:
                    return contents
            }
        }
    }

    const operation = (contents) => {
        return {
            type: 'operation',
            class: 'infix',
            operation: contents[2][0],
            value: {
                left: contents[0][0],
                right: contents[4][0],
            }
        }
    }

    const prefix = (name) => {
        return (contents) => {
            return {
                type: 'expression',
                expression: name,
                contents: contents,
            }
        }
    }

    const postfix = (name) => {
        return (contents) => {
            return {
                type: 'expression',
                expression: name,
                contents: contents,
            }
        }
    }
%}
CHAIN[LEFT] -> $LEFT {% chain(id, tag(CHAIN_LEFT)) %} | $NEXT {% chain(did, tag(CHAIN_RIGHT)) %}

INFIX_OPERATOR[  SELF, TOKEN, NEXT] -> CHAIN[$SELF  _ $TOKEN _ $NEXT ] {% chain(id, unwrap_operation(operation)) %}
PREFIX_OPERATOR[ SELF, TOKEN, NEXT] -> CHAIN[$TOKEN _ $SELF          ] {% chain(id, unwrap_operation()) %}
POSTFIX_OPERATOR[SELF, TOKEN, NEXT] -> CHAIN[$SELF  _ $TOKEN         ] {% chain(id, unwrap_operation()) %}

EXPRESSION  -> INFIX_OPERATOR[  %identifier, %assignment                     {% id %}, SEQUENCE    ] {% id %}
SEQUENCE    -> INFIX_OPERATOR[  SEQUENCE,    ">>="                           {% id %}, WITH        ] {% id %}
WITH        -> PREFIX_OPERATOR[ WITH,        "with"                          {% id %}, CONDITIONAL ] {% id %}
CONDITIONAL -> INFIX_OPERATOR[  CONDITIONAL, "?"                             {% id %}, COALESCE    ] {% id %}
COALESCE    -> INFIX_OPERATOR[  COALESCE,    "??"                            {% id %}, OR          ] {% id %}
OR          -> INFIX_OPERATOR[  OR,          "||"                            {% id %}, AND         ] {% id %}
AND         -> INFIX_OPERATOR[  AND,         "&&"                            {% id %}, BIT_OR      ] {% id %}
BIT_OR      -> INFIX_OPERATOR[  BIT_OR,      "|"                             {% id %}, BIT_XOR     ] {% id %}
BIT_XOR     -> INFIX_OPERATOR[  BIT_XOR,     "^"                             {% id %}, BIT_AND     ] {% id %}
BIT_AND     -> INFIX_OPERATOR[  BIT_AND,     "&"                             {% id %}, EQUALITY    ] {% id %}
EQUALITY    -> INFIX_OPERATOR[  EQUALITY,    ("==" | "!=")                   {% id %}, COMPARISON  ] {% id %}
COMPARISON  -> INFIX_OPERATOR[  COMPARISON,  (">=" | "<=" | "<" | ">")       {% id %}, SHIFT       ] {% id %}
SHIFT       -> INFIX_OPERATOR[  SHIFT,       ("<<<" | ">>>" | "<<" | ">>")   {% id %}, SUM         ] {% id %}
SUM         -> INFIX_OPERATOR[  SUM,         ("+" | "-")                     {% id %}, PRODUCT     ] {% id %}
PRODUCT     -> INFIX_OPERATOR[  PRODUCT,     ("*" | "/" | "%")               {% id %}, POWER       ] {% id %}
POWER       -> INFIX_OPERATOR[  POWER,       "**"                            {% id %}, INFIX       ] {% id %}
INFIX       -> INFIX_OPERATOR[  INFIX,       PREFIX                          {% id %}, PREFIX      ] {% id %}
PREFIX      -> PREFIX_OPERATOR[ PREFIX,      ("!" | "~" | "-" | "++" | "--") {% id %}, POSTFIX     ] {% id %}
POSTFIX     -> POSTFIX_OPERATOR[POSTFIX,     ("!" | "~" | "-" | "++" | "--") {% id %}, VALUE       ] {% id %}

VALUE -> (
    %identifier
    | LITERAL
    | TEMPLATE_STRING
    | REGEX
    | FUNCTION
    | ANONYMOUS_ITERATOR
    | STRUCT
    | CALL
    | MEMBER
    | INDEX
    | GROUPING
) {% () => 'value' %}

CALL ->  EXPRESSION _ ("(" | "?(") (_ MANY[EXPRESSION]):? _ ")"
MEMBER ->  EXPRESSION _ ("." | "?.") _ %identifier
INDEX -> EXPRESSION _ ("[" | "?[") _ EXPRESSION "]"
GROUPING -> "(" _ EXPRESSION _ ")"

STRUCT -> ("{"
    (
        (_ STRUCT_PARAMETER):+
        (_ STRUCT_OPTINAL):*
        |
        (_ STRUCT_PARAMETER):*
        (_ STRUCT_OPTINAL):+
    )
    (_ OVERLOAD):*
    _
"}")

STRUCT_PARAMETER -> DECLARATION_TYPE _ MANY[%identifier] _ BREAK
STRUCT_OPTINAL -> DECLARATION_TYPE _ MANY[%identifier _ "=" _ EXPRESSION] _ BREAK
OVERLOAD -> (
    UNARY_OPERATOR _  ("(" _ ")" _):?  STATEMENT
    | INFIX_OPERATOR _ INFIX_PARAMETERS _ STATEMENT
    | INFIX_PARAMETERS _ INFIX_OPERATOR _ STATEMENT
)
INFIX_PARAMETERS -> (SINGLE_PARAMETER | FUNCTION_PARAMETER) 
INFIX_OPERATOR -> ("||" | "&&" | "|" | "^" | "&" | "<" | ">" | "<<<" | ">>>" | "<<" | ">>" | "+" | "-" | "*" | "/" | "%" | "**") 
UNARY_OPERATOR -> ("!" | "~" | "-" | "++" | "--") 

FUNCTION -> (
    FUNCTION_PARAMETERS | ENCLOSED_PARAMETERS
) _ "=>" _ STATEMENT
ENCLOSED_PARAMETERS -> "(" (_ FUNCTION_PARAMETERS):? _ ")"
FUNCTION_PARAMETERS -> MANY[FUNCTION_PARAMETER]
FUNCTION_PARAMETER -> (DECLARATION_TYPE _):? (%identifier | (%identifier _ ":" _):? (DESTRUCTURE_ITERATOR | DESTRUCTURE_STRUCT))
SINGLE_PARAMETER -> "(" _ (FUNCTION_PARAMETER _):? ")"

DESTRUCTURE_STRUCT -> ( "{"
    (
        _ MANY[DESTRUCTURED_STRUCT_MEMBER]
        ( _ "," (_ SPREAD_MEMBER):?):?
    ):?
_ "}")
DESTRUCTURED_STRUCT_MEMBER -> (EXPRESSION _):? (
    %identifier "?":? _ (
        "=" _ EXPRESSION
        | ":" _ (DESTRUCTURE_ITERATOR | DESTRUCTURE_STRUCT)
    ):?
)

DESTRUCTURE_ITERATOR -> ( "["
    (
        _ MANY[(DESTRUCTURE_ITERATOR_MEMBER)]
        ( _ "," (_ SPREAD_MEMBER):?):?
    ):?
_ "]")
DESTRUCTURE_ITERATOR_MEMBER -> (EXPRESSION _):? (
    %identifier "?" (_ "=" %identifier):?
    | DESTRUCTURE_ITERATOR
    | DESTRUCTURE_STRUCT
)

SPREAD_MEMBER -> "..." %identifier

ANONYMOUS_ITERATOR -> "["
    (_ MANYP[ANONYMOUS_ITERATOR_VALUE]):? _
"]"
ANONYMOUS_ITERATOR_VALUE -> EXPRESSION | "..." EXPRESSION

# TODO: real regex parsing
REGEX -> %regex %regex_content %regex_end 

TEMPLATE_STRING -> %template_string_start (
    %template_string_content
    | %template_string_interpreter _ EXPRESSION _ "}"
):* %template_string_end

LITERAL -> (
	"null"
    | %binary 
    | %hex 
    | %int
    | %float
    | %color 
	| STRING 
) {% (value) => {
    return {
        type: 'literal',
        value: did(value),
    }
} %}

STRING -> %string

BREAK -> (";" | %newline):+  | %file_end

# optional whitespace 
_ -> (%newline | %whitespace | %comment):* 
