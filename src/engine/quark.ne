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
%}

@lexer lexer

MANY[T] -> $T (_ "," _ $T):* {%(value) => {
    return [
        value[0][0],
        ...value[1].map((_value) => {
            return _value[3][0]
        })
    ]
}%}
MANYP[T] -> MANY[$T] (_ ","):? {%(value) => {
    return value[0]
}%}

ROOT -> (_ IMPORT):* (_ TOP_STATEMENT):* BREAK:? {% (values) => {
    return {
        imports: values[0].map((value) => {
            return value[1]
        }),
        statements: values[1].map((value) => {
            return value[1]
        }),
    }
}%}

IMPORT_NAME -> %identifier (_ "as" _ %identifier):? {%(value) => {
    return {
        target: value[0].value,
        as: value[1] ? value[1][3].value : value[0].value,
    }
}%}
IMPORT_MAP -> "{" (_ MANY[IMPORT_NAME]):? _ "}" {%(value) => {
    return value[1][1]
}%}
IMPORT -> "import" _ (IMPORT_MAP {% (value) => {
    return {
        imports: value[0]
    }
}%} | %identifier ( _ IMPORT_MAP):? {% (values) => {
    return {
        default_import: values[0].value,
        imports: values[1]? values[1][1] : [],
    }
}%}) _ "from" _ STRING BREAK {%(value) => {
    return {
        type: 'import',
        values: value[2],
        from: value[6].value,
        ...location(value),
    }
}%}

TOP_STATEMENT -> STATEMENT | EXPORT_EXPRESSION {% id %}

EXPORT_EXPRESSION -> "export" _ (EXPORT_NAME | "{" MANYP[EXPORT_NAME] "}")
EXPORT_NAME -> EXPRESSION _ "as" (%identifier | "default") | %identifier

STATEMENT -> (
    EXPRESSION        _ BREAK
    | INLINE_SEQUENCE _ BREAK
    | DECLARATION     _ BREAK
    | BREAK           _ BREAK
    | CONTINUE        _ BREAK
    | RETURN          _ BREAK
    | USE             _ BREAK
    | IF             (_ BREAK):?
    | SWITCH         (_ BREAK):?
    | WHILE          (_ BREAK):?
    | DO_WHILE       (_ BREAK):?
    | FOR            (_ BREAK):?
    | TRY            (_ BREAK):?
    | OVERLOAD       (_ BREAK):?
) {% did %}

OVERLOAD -> "overload" _ %operator _ "(" _ EXPRESSION _ %identifier (_ "," _ EXPRESSION _ %identifier) _ ")" _ STATEMENT

TRY -> LABEL:? "try" _ STATEMENT (_ HANDLE):+
HANDLE -> LABEL:? "handle" (_ MANY[EXPRESSION] ):? (_ "(" _ FUNCTION_PARAMETER _ ")"):? _ STATEMENT

BREAK -> "break" (_ %identifier):?
CONTINUE -> "continue" (_ %identifier):?
RETURN -> "return" (_ EXPRESSION):?
USE -> "use" (_ EXPRESSION):?

CONTROL_CONDITION ->  "(" _ EXPRESSION _ ")"

IF -> LABEL:? "if" _ CONTROL_CONDITION _ STATEMENT ( _ LABEL "else" _ "if" CONTROL_CONDITION _ STATEMENT ):* ( _ LABEL "else" _ STATEMENT):?
SWITCH -> LABEL:? "switch" _ CONTROL_CONDITION _ "{" (
    _ CASE
    (
        _ (CASE | STATEMENT )
    ):*
    _
):? _ "}"
CASE -> "case" _ EXPRESSION _ ":"
WHILE -> LABEL:? "while" _ CONTROL_CONDITION _ STATEMENT
DO_WHILE -> LABEL:? "do" _ STATEMENT _ "while" CONTROL_CONDITION

FOR_CONDITIONS -> STATEMENT _ ";" _ EXPRESSION _ ";" _ STATEMENT
ENHANCED_FOR_CONDITIONS -> FUNCTION_PARAMETER _ ":" _ EXPRESSION
FOR -> LABEL:? "for" _ "(" _ ( FOR_CONDITIONS | ENHANCED_FOR_CONDITIONS ) _ ")" _ STATEMENT

DECLARATION -> ("export" _ ("default" _):?):? DECLARATION_TYPE _ %identifier | ("export" _):? DECLARATION_TYPE _ (
    %identifier
    | DESTRUCTURE_ITERATOR
    | DESTRUCTURE_STRUCT
) _ "=" _ EXPRESSION
DECLARATION_TYPE -> EXPRESSION _ "?":? (_ ARRAY_DECLARATION (_ "?"):?):*
INLINE_SEQUENCE -> (EXPRESSION _):? (%identifier | DESTRUCTURE_STRUCT) _ "<<=" _ EXPRESSION

LABEL -> (%identifier _ ":" _)

EXPRESSION -> ASSIGNMENT {% id %}

CHAIN[LEFT, RIGHT] -> $LEFT | $RIGHT {% did %}

OPERATOR[           SELF, TOKEN,          NEXT] -> CHAIN[$SELF _ $TOKEN _ $NEXT {% normalize %},        $NEXT] {% did %}
PREFIX_OPERATOR[    SELF, TOKEN,          NEXT] -> CHAIN[$TOKEN _ $SELF {% normalize %},                $NEXT] {% did %}
TERNARY_OPERATOR[   SELF, TOKEN, SPLITER, NEXT] -> CHAIN[$SELF _ $TOKEN _ $NEXT (_ $SPLITER _ $NEXT):?, $NEXT] {% did %}
POSTFIX_OPERATOR[   SELF, TOKEN,          NEXT] -> CHAIN[$SELF _ $TOKEN {% normalize %},                $NEXT] {% did %}
GROUPING_OPERATOR[  SELF,                 NEXT] -> CHAIN["(" _ $SELF _ ")" {% normalize %},             $NEXT] {% did %}

CALL_OPERATOR[  FROM, INPUT, NEXT]  ->  CHAIN[$FROM ("(" | "?(") _ MANY[$INPUT]:? _ ")",    $NEXT] {% did %}
MEMBER_OPERATOR[FROM, NEXT]         ->  CHAIN[$FROM ("." | "?.") %identifier,               $NEXT] {% did %}
INDEX_OPERATOR[ FROM, INPUT, NEXT]  ->  CHAIN[$FROM ("[" | "?[") _ $INPUT _ "]",            $NEXT] {% did %}

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
PREFIX      ->  PREFIX_OPERATOR[    PREFIX,                     ("!" | "~" | "-" | "++" | "--"){% id %},CALL     ] {% id %}
POSTFIX     ->  POSTFIX_OPERATOR[   POSTFIX,                    ("++" | "--"),                          CALL        ] {% id %}
CALL        ->  CALL_OPERATOR[      CALL, GROUPING,                                                     MEMBER      ] {% id %}
MEMBER      ->  MEMBER_OPERATOR[    MEMBER,                                                             INDEX       ] {% id %}
INDEX       ->  INDEX_OPERATOR[     INDEX, GROUPING,                                                    GROUPING    ] {% id %}
GROUPING    ->  CHAIN[              "(" _ GROUPING _ ")",                                               VALUE       ] {% id %}

VALUE -> (
    %identifier
    | LITERAL               {% id %}
    | TYPE_LITERAL          {% id %}
    | TEMPLATE_STRING       {% id %}
    | REGEX                 {% id %}
    | FUNCTION              {% id %}
    | ANONYMOUS_STRUCT      {% id %}
    | ANONYMOUS_ITERATOR    {% id %}
    | STRUCT                {% id %}
) {% id %}

STRUCT -> (EXPRESSION _ ":" _ ):? STRUCT_CONTENTS
STRUCT_CONTENTS -> ("{"
    (
        _ EXPRESSION (_ ARRAY_DECLARATION (_ "?"):? ):* _ %identifier (_ "=" _ EXPRESSION):? _ BREAK
    ):*
    (
        _ EXPRESSION (_ "?" (_ ARRAY_DECLARATION (_ "?"):? ):*):? _ %identifier (_ "=" _ EXPRESSION)  _ BREAK
    ):*
    # TODO: operator overloading here:
    _
"}")

FUNCTION -> (
    FUNCTION_PARAMETERS | ENCLOSED_PARAMETERS
) _ "=>" _ STATEMENT
ENCLOSED_PARAMETERS -> "(" (_ FUNCTION_PARAMETERS):? _ ")"
FUNCTION_PARAMETERS -> MANY[FUNCTION_PARAMETER]
FUNCTION_PARAMETER -> (EXPRESSION _):? (%identifier "?":? | (%identifier _ ":" _):? DESTRUCTURE_ITERATOR | (%identifier _ ":" _):? DESTRUCTURE_STRUCT)

DESTRUCTURE_STRUCT -> ( "{"
    (
        _ MANY[DESTRUCTURED_STRUCT_MEMBER]
        ( _ "," (_ SPREAD_MEMBER):?):?
    ):?
_ "}")
DESTRUCTURED_STRUCT_MEMBER -> (EXPRESSION _):? (
    %identifier "?":? _ (
        "=" _ VALUE
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

ANONYMOUS_STRUCT -> "{"
    (_ MANYP[ANONYMOUS_STRUCT_VALUE]):? _
"}"
ANONYMOUS_STRUCT_VALUE -> %identifier | (%identifier _ "=" EXPRESSION)

ANONYMOUS_ITERATOR -> "["
    (_ MANYP[ANONYMOUS_ITERATOR_VALUE]):? _
"]" {%(value) => {
    return {
        type: 'array',
        parts: value[1][1][0],
        ...location(value[0])
    }
}%}
ANONYMOUS_ITERATOR_VALUE -> EXPRESSION | "..." EXPRESSION

# TODO: real regex parsing
REGEX -> %regex %regex_content %regex_end {% () => 'not implemented 💀'%}

TEMPLATE_STRING -> %template_string_start (
    %template_string_content {% ([ {type, ...rest} ]) => {
        return {
            type: 'content',
            ...rest
        }
    } %}
    | %template_string_interpreter _ EXPRESSION _ "}" {% (value) => {
        const {type, ...rest} = value[2][0];
        return { type: 'interpolate', ...rest}
    } %}
):* %template_string_end {% (value) => {
    return {
        type: 'template_string',
        parts: value[1],
        ...location(value[0])
    }
}%}

TYPE_LITERAL -> "let"

LITERAL -> (
	"null"
    | %binary {% strip('binary', 2) %}
    | %hex {% strip('hex', 2) %}
    | %int
    | %float
    | %color {% strip('color', 1) %}
	| STRING {% id %}
) {% id %}

STRING -> %string {%(value) => {
    return {
        type: 'string',
        value: value[0].value.substring(1, value[0].value.length - 1),
        ...location(value)
    }
}%}

ARRAY_DECLARATION -> "[" _ "]"

BREAK -> (";" | %newline | %end):+ {%() => null%}

# optional whitespace 
_ -> (%newline | %whitespace | %comment):* {%() => null%}
