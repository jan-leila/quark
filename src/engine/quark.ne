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

    const debug = false
    const formating = (lambda) => {
        if (debug) {
            return (value) => value
        }
        return lambda
    }
%}

@lexer lexer

MANY[T] -> $T (_ "," _ $T):* {% formating((value) => {
    return [
        value[0],
        ...value[1].map((next_value) => {
            return next_value[3]
        })
    ]
}) %}
MANYP[T] -> MANY[$T] (_ ","):? {% formating((value) => {
    return value[0]
}) %}

ROOT -> (_ IMPORT {% formating((value) => value[1]) %}):* (_ TOP_STATEMENT {% ([_, statement]) => statement %}):* {% formating(([ imports, statements]) => {
    return {
        imports,
        statements,
    }
}) %}

IMPORT -> "import" _ (IMPORT_MAP {% formating((value) => {
    return {
        default: null,
        named: value[0],
    }
}) %} | %identifier (_ IMPORT_MAP):? {% formating((value) => {
    return {
        default: value[0],
        named: value[1]?.[1] ?? [],
    }
}) %}) _ "from" _ IMPORT_TARGET BREAK {% formating((value) => {
    return {
        imports: value[2],
        from: value[6],
    }
}) %}
IMPORT_MAP -> "{" (_ MANY[IMPORT_NAME]):? _ "}" {% formating((value) => {
    return value[1]?.[1] ?? []
}) %}
IMPORT_NAME -> %identifier (_ "as" _ %identifier):? {% formating((value) => {
    return {
        target: value[0],
        as: value[1]?.[3] ?? value[0],
    }
})%}

IMPORT_TARGET -> (FILE | DEPENDENCY) {% formating(did) %}
DEPENDENCY -> FILE_PATH ("@" FILE_PART):? {% formating((value) => {
    return {
        type: 'dependency',
        source: value[1]?.[1],
        package: value[0],
    }
})%}
FILE -> ("." {% formating(() => 0) %} | ".." ("/" ".."):* {% formating((value) => 1 + value[1].length) %}):? "/" FILE_PATH {% formating((value) => {
    return {
        type: 'file',
        path: value[2],
        relitive: value[0] ?? -1,
    }
}) %}
FILE_PATH -> FILE_PART ("/" FILE_PART):* {% formating((value) => {
    return [value[0], ...(value[1].map((value) => value[1]))]
}) %}
FILE_PART -> (%identifier | %filepart) {% formating(did) %}

TOP_STATEMENT -> (STATEMENT | EXPORT_STATEMENT) _ BREAK {% did %}

EXPORT_STATEMENT -> "export" _ MANYP[EXPORT_NAME] {% formating((value) => {
    return {
        type: 'export',
        targets: value[2]
    }
})%}
EXPORT_NAME -> %identifier {% formating((value) => {
    return {
        target: value[0],
        as: value[0],
    }
}) %} | EXPRESSION _ "as" _ (%identifier | "default") {% formating(() => {
    return {
        target: value[0],
        as: value[3],
    }
}) %}

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
) {% did %}

BLOCK -> "(" (_ (PURE_STATEMENT | STATEMENT ( _ BREAK _ STATEMENT):+)):? _ ")" {% (value) => {
    return {
        type: 'block',
        contents: value[1]?.[1],
    }
} %}

TRY -> LABEL:? "try" _ STATEMENT (_ HANDLE):*
HANDLE -> LABEL:? "handle" _ MANY[EXPRESSION] _ SINGLE_PARAMETER _ STATEMENT

BREAK_STATMENT -> "break" (_ %identifier):?
CONTINUE -> "continue" (_ %identifier):?
RETURN -> "return" (_ EXPRESSION):?
USE -> "use" _ EXPRESSION

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
    DECLARATION_TYPE _ MANYP[%identifier {% id %}] (_ "=" _ EXPRESSION):? {% (value) => {
        return {
            type: 'declaration',
            data_type: value[0],
            names: value[2].map(id),
            value: value[3]?.[3],
        }
    }%}
) {% id %}
DECLARATION_TYPE -> ("let" | EXPRESSION) {% did %}
INLINE_SEQUENCE -> (EXPRESSION _):? %identifier _ "<<=" _ EXPRESSION

LABEL -> (%identifier _ ":" _)

@{%
    const CHAIN_LEFT = Symbol('CHAIN_LEFT')
    const CHAIN_RIGHT = Symbol('CHAIN_RIGHT')

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
            first: contents[0][0],
            second: contents[4][0],
        }
    }

    const prefix = (contents) => {
        return {
            type: 'operation',
            class: 'prefix',
            operation: contents[0][0],
            contents: contents[2][0],
        }
    }

    const postfix = (contents) => {
        return {
            type: 'operation',
            class: 'postfix',
            operation: contents[0][0],
            contents: contents[2],
        }
    }
%}
CHAIN[LEFT] -> $LEFT {% chain(id, tag(CHAIN_LEFT)) %} | $NEXT {% chain(did, tag(CHAIN_RIGHT)) %}

INFIX_OPERATOR[  SELF, TOKEN, NEXT] -> CHAIN[$SELF  _ $TOKEN _ $NEXT] {% chain(id, unwrap_operation(operation)) %}
PREFIX_OPERATOR[ SELF, TOKEN, NEXT] -> CHAIN[$TOKEN _ $SELF         ] {% chain(id, unwrap_operation()) %}
POSTFIX_OPERATOR[SELF, TOKEN, NEXT] -> CHAIN[$SELF  _ $TOKEN        ] {% chain(id, unwrap_operation()) %}

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
POWER       -> INFIX_OPERATOR[  POWER,       "**"                            {% id %}, PREFIX      ] {% id %}
PREFIX      -> PREFIX_OPERATOR[ PREFIX,      ("!" | "~" | "-" | "++" | "--") {% id %}, POSTFIX     ] {% id %}
POSTFIX     -> POSTFIX_OPERATOR[POSTFIX,     ("!" | "~" | "-" | "++" | "--") {% id %}, CALL        ] {% id %}

CALL        -> POSTFIX_OPERATOR[ CALL  , (("(" | "?(") (_ MANYP[(SEQUENCE | %identifier _ "=" _ EXPRESSION)]):? _ ")") {% id %}, MEMBER] {% id %}
MEMBER      -> POSTFIX_OPERATOR[ MEMBER, (("." | "?.") _ %identifier)                 {% id %}, INDEX ] {% id %}
INDEX       -> POSTFIX_OPERATOR[ INDEX , (("[" | "?[") _ EXPRESSION "]")              {% id %}, VALUE ] {% id %}

VALUE -> (
    %identifier
    | LITERAL
    | TEMPLATE_STRING
    | REGEX
    | FUNCTION
    | ANONYMOUS_ITERATOR
    | STRUCT
    | GROUPING
) {% did %}

GROUPING -> "(" _ EXPRESSION _ ")"

STRUCT -> (EXPRESSION _ ":" _):? ("{"
    (
        (_ STRUCT_PARAMETER):+
        |
        (_ STRUCT_OPTINAL):+
        |
        (_ STRUCT_PARAMETER):+
        (_ STRUCT_OPTINAL):+
    ):?
    (_ STRUCT_PROPERTY):*
    (_ STRUCT_METHOD):*
    (_ STRUCT_OVERLOAD):*
    _
"}") {% chain(formating((value) => {
    return {
        type: "struct",
        extends: value[0]?.[0],
        parameters: value[1][1]?.[0]?.map(([_, value]) => value) ?? [],
        optionals: value[1][1]?.[1]?.map(([_, value]) => value) ?? [],
        properties: value[1][2].map(([_, value]) => value),
        methods: value[1][3].map(([_, value]) => value),
        overloads: value[1][4].map(([_, value]) => value),
    }
})) %}

STRUCT_PARAMETER -> DECLARATION_TYPE _ MANY[%identifier] BREAK {% formating((value) => {
    return {
        type: value[0],
        identifiers: value[2].map(id),
    }
}) %}
STRUCT_OPTINAL -> DECLARATION_TYPE _ MANY[%identifier _ "=" _ EXPRESSION] BREAK {% formating((value) => {
    return {
        type: did(value),
        identifiers: value[2].map((value) => {
            return {
                identifier: value[0],
                default_value: value[4],
            }
        }),
    }
}) %}

STRUCT_PROPERTY -> %identifier _ "=" _ EXPRESSION BREAK {% formating((value) => {
    return {
        identifier: value[0],
        value: value[4],
    }
}) %}

STRUCT_METHOD -> %identifier _ FUNCTION {% formating((value) => {
    return {
        identifier: value[0],
        value: value[2],
    }
}) %}

STRUCT_OVERLOAD -> (
    UNARY_OPERATOR (_ "(" _ ")"):? _ STATEMENT {% (value) => {
        return {
            type: 'unary',
            operator: value[0],
            statement: value[3]
        }
    }%}
    | INFIX_OPERATOR _ SINGLE_PARAMETER _ STATEMENT {% (value) => {
        return {
            type: 'infix_left',
            operator: value[0],
            parameter: value[2],
            statement: value[4]
        }
    }%}
    | SINGLE_PARAMETER _ INFIX_OPERATOR _ STATEMENT {% (value) => {
        return {
            type: 'infix_right',
            operator: value[2],
            parameter: value[0],
            statement: value[4]
        }
    }%}
) {% id %}
INFIX_OPERATOR -> ("||" | "&&" | "|" | "^" | "&" | "<" | ">" | "<<<" | ">>>" | "<<" | ">>" | "+" | "-" | "*" | "/" | "%" | "**") {% id %}
UNARY_OPERATOR -> ("!" | "~" | "-" | "++" | "--") {% id %}

FUNCTION -> (
    FUNCTION_PARAMETERS | ENCLOSED_PARAMETERS
) _ "=>" _ STATEMENT
ENCLOSED_PARAMETERS -> "(" (_ FUNCTION_PARAMETERS):? _ ")"
FUNCTION_PARAMETERS -> MANY[FUNCTION_PARAMETER]
FUNCTION_PARAMETER -> (
    (DECLARATION_TYPE _):? (
        %identifier {% (value) => {
            return {
                type: 'identifier',
                value: value[0],
            }
        } %}
    )
) {% chain(id, (value) => {
    return {
        type: value[0]?.[0],
        name: value[1]
    }
}) %}
SINGLE_PARAMETER -> (
    "(" _ (FUNCTION_PARAMETER _):? ")" {% (value) => {
        return value[2]?.[0]
    } %}
) {% id %}

ANONYMOUS_ITERATOR -> "["
    (_ MANYP[EXPRESSION]):? _
"]"

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
