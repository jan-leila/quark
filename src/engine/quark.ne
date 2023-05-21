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

    const debug = true
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
}) %}

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

UNSCOPED_STATEMENT -> (PURE_UNSCOPED_STATEMENT | EXPRESSION) {% did %}

PURE_STATEMENT -> (
    PURE_UNSCOPED_STATEMENT
    | DECLARATION
) {% did %}

PURE_UNSCOPED_STATEMENT -> (
    BLOCK
    | INLINE_SEQUENCE
    | BREAK_STATMENT
    | CONTINUE
    | RETURN
    | USE
    | SWITCH
    | IF
    | WHILE
    | DO_WHILE
    | FOR
    | DO
)

BLOCK -> "(" (_ (PURE_STATEMENT | STATEMENT ( _ BREAK _ STATEMENT):+)):? _ ")" {% formating((value) => {
    return {
        type: 'block',
        contents: value[1]?.[1],
    }
}) %}

BREAK_STATMENT -> "break" (_ %identifier):? {% formating((value) => {
    return {
        type: 'break',
        label: value[1]?.[1]
    }
}) %}
CONTINUE -> "continue" (_ %identifier):? {% formating((value) => {
    return {
        type: 'continue',
        label: value[1]?.[1]
    }
}) %}
RETURN -> "return" (_ EXPRESSION):? {% formating((value) => {
    return {
        type: 'return',
        value: value[1]?.[1]
    }
}) %}
USE -> "use" _ EXPRESSION {% formating((value) => {
    return {
        type: 'use',
        value: value[2]
    }
}) %}

CONDITION -> "(" _ EXPRESSION _ ")" {% formating((value) => value[2]) %}
IF -> LABEL:? "if" _ CONDITION _ STATEMENT (_ "else" _ STATEMENT {% formating((value) => value[3]) %}):? {% formating((value) => {
    return {
        type: 'if',
        label: value[0],
        condition: value[3],
        then: value[5],
        else: value[6]
    }
}) %}
CASE -> "case" _ "(" _ MANY[EXPRESSION] _ ")" {% (value) => {
    return value[4]
} %}
SWITCH -> LABEL:? "switch" _ CONDITION _ "(" (_ CASE _ STATEMENT):* (_ "default" (_ CASE):? _ STATEMENT):? _ ")" {% () => {
    return {
        type: 'switch',
        label: value[0],
        condition: value[3],
        cases: value[6].map((value) => {
            return {
                cases: value[1],
                contents: value[3]
            }
        }),
        default_case: {
            cases: value[7]?.[2]?.[1],
            contents: value[7]?.[5]
        }
    }
} %}
WHILE -> LABEL:? "while" _ CONDITION _ UNSCOPED_STATEMENT {% (value) => {
    return {
        type: 'while',
        label: value[0],
        condition: value[3],
        contents: value[5]
    }
} %}
DO_IF -> DO _ "if" _ CONDITION {% (value) => {
    return {
        ...value[0],
        type: 'do_if',
        condition: value[4]
    }
} %}
DO_WHILE -> DO _ "while" _ CONDITION {% (value) => {
    return {
        ...value[0],
        type: 'do_while',
        condition: value[4]
    }
} %}

DO -> LABEL:? "do" _ UNSCOPED_STATEMENT (_ HANDLE):* {% (value) => {
    return {
        type: 'do',
        label: value[0],
        handles: value[4].map((value) => value[1]),
        contents: value[3]
    }
} %}
HANDLE -> "handle" _ MANY[EXPRESSION] _ SINGLE_FUNCTION_ARGUMENT _ UNSCOPED_STATEMENT {% (value) => {
    return {
        handle_types: value[2],
        argument: value[4],
        contents: value[6]
    }
} %}

FOR -> LABEL:? "for" _ "(" _ DECLARATION_IDENTIFIER _ ":" _ EXPRESSION _ ")" _ UNSCOPED_STATEMENT {% () => {
    return {
        type: 'for',
        label: value[0],
        name: value[5],
        target: value[9],
        contents: value[13]
    }
} %}
DECLARATION -> DECLARATION_TYPE _ MANYP[DECLARATION_IDENTIFIER (_ "=" _ EXPRESSION):?] {% (value) => {
    return {
        type: 'declaration',
        data_type: value[0],
        names: value[2],
        value: value[3]?.[3],
    }
} %}
INLINE_SEQUENCE -> DECLARATION_TYPE _ DECLARATION_IDENTIFIER _ "<<=" _ EXPRESSION {% (value) => {
    return {
        type: 'inline_sequence',
        data_type: value[0],
        name: value[2],
        value: value[6],
    }
} %}
DECLARATION_TYPE -> ("let" | EXPRESSION) {% did %}

LABEL -> (%identifier _ ":" _) {% did %}

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
            on: contents[0][0],
            with: contents[2],
        }
    }
%}
CHAIN[LEFT] -> $LEFT {% chain(id, tag(CHAIN_LEFT)) %} | $NEXT {% chain(did, tag(CHAIN_RIGHT)) %}
CHAIN_WRAP[SELF, NEXT] -> CHAIN[$SELF] {% chain(id, unwrap_operation(id))%}
INFIX_OPERATOR[  SELF, TOKEN, NEXT] -> CHAIN[$SELF  _ $TOKEN _ $NEXT] {% chain(id, unwrap_operation(operation)) %}
PREFIX_OPERATOR[ SELF, TOKEN, NEXT] -> CHAIN[$TOKEN _ $SELF         ] {% chain(id, unwrap_operation(prefix)) %}
POSTFIX_OPERATOR[SELF, TOKEN, NEXT] -> CHAIN[$SELF  _ $TOKEN        ] {% chain(id, unwrap_operation(postfix)) %}

EXPRESSION  -> INFIX_OPERATOR[  %identifier, %assignment                            {% id %}, SEQUENCE    ] {% id %}
SEQUENCE    -> INFIX_OPERATOR[  SEQUENCE,    ">>="                                  {% id %}, WITH        ] {% id %}
WITH        -> PREFIX_OPERATOR[ WITH,        "with"                                 {% id %}, CONDITIONAL ] {% id %}

CONDITIONAL -> CHAIN_WRAP[COALESCE _ "?" _ EXPRESSION _ ":" _ EXPRESSION {% (value) => {
    return {
        type: 'ternary',
        condition: value[0],
        left: value[4],
        right: value[6],
    }
} %}, COALESCE]

COALESCE    -> INFIX_OPERATOR[  COALESCE,    "??"                                   {% id %}, OR          ] {% id %}
OR          -> INFIX_OPERATOR[  OR,          "||"                                   {% id %}, AND         ] {% id %}
AND         -> INFIX_OPERATOR[  AND,         "&&"                                   {% id %}, BIT_OR      ] {% id %}
BIT_OR      -> INFIX_OPERATOR[  BIT_OR,      "|"                                    {% id %}, BIT_XOR     ] {% id %}
BIT_XOR     -> INFIX_OPERATOR[  BIT_XOR,     "^"                                    {% id %}, BIT_AND     ] {% id %}
BIT_AND     -> INFIX_OPERATOR[  BIT_AND,     "&"                                    {% id %}, EQUALITY    ] {% id %}
EQUALITY    -> INFIX_OPERATOR[  EQUALITY,    ("==" | "!=")                          {% id %}, COMPARISON  ] {% id %}
COMPARISON  -> INFIX_OPERATOR[  COMPARISON,  (">=" | "<=" | "<" | ">")              {% id %}, SHIFT       ] {% id %}
SHIFT       -> INFIX_OPERATOR[  SHIFT,       ("<<<" | ">>>" | "<<" | ">>")          {% id %}, SUM         ] {% id %}
SUM         -> INFIX_OPERATOR[  SUM,         ("+" | "-")                            {% id %}, PRODUCT     ] {% id %}
PRODUCT     -> INFIX_OPERATOR[  PRODUCT,     ("*" | "/" | "%")                      {% id %}, POWER       ] {% id %}
POWER       -> INFIX_OPERATOR[  POWER,       "**"                                   {% id %}, PREFIX      ] {% id %}
PREFIX      -> PREFIX_OPERATOR[ PREFIX,      ("!" | "~" | "-" | "++" | "--")        {% id %}, POSTFIX     ] {% id %}
POSTFIX     -> POSTFIX_OPERATOR[POSTFIX,     ("!" | "~" | "-" | "++" | "--")        {% id %}, CALL        ] {% id %}

KEY_WORD_PARAMETER -> %identifier _ "=" _ EXPRESSION {% (value) => ({name: value[0], value: value[4]})%}
CALL -> CHAIN_WRAP[CALL ("(" | "?(") (
    _ MANYP[SEQUENCE] {% (value) => ({ params: value[1][0] }) %}
    | _ MANYP[KEY_WORD_PARAMETER] {% (value) => ({ namedParams: value[1].map(did) }) %}
    | _ MANY[SEQUENCE] _ "," _ MANYP[KEY_WORD_PARAMETER] {% (value) => ({ params: value[1][0], namedParams: value[5].map(did) }) %}
):? _ ")" {% (value) => {
    return {
        type: 'call',
        target: value[0],
        nullish: value[1][0].value === '?(',
        ...value[2],
    }
} %}, MEMBER] {% id %}
MEMBER -> CHAIN_WRAP[MEMBER ("." | "?.") _ %identifier {% (value) => {
    return {
        type: 'member',
        target: value[0],
        nullish: value[1][0].value === '?.',
        member: value[3]
    }
} %}, INDEX] {% id%}
INDEX -> CHAIN_WRAP[INDEX ("[" | "?[") _ EXPRESSION _ "]" {% (value) => {
    return {
        type: 'index',
        target: value[0],
        nullish: value[1][0].value === '?[',
        value: value[3]
    }
} %}, REFERENCE] {% id%}
REFERENCE -> CHAIN_WRAP[TYPE_REFERENCE "::" %identifier, TYPE_REFERENCE]
TYPE_REFERENCE -> CHAIN_WRAP["::" VALUE, VALUE]

VALUE -> (
    %identifier
    | LITERAL
    | TEMPLATE_STRING
    | REGEX
    | FUNCTION
    | ARRAY
    | STRUCT
    | FUNCTION_SIGNATURE
    | GROUPING
) {% did %}

GROUPING -> "(" _ EXPRESSION _ ")" {% (value) => value[2] %}

@{%
    const METHOD = Symbol('METHOD')
    const OVERLOAD = Symbol('OVERLOAD')
    const PROPERTY = Symbol('OVERLOAD')
%}
STRUCT -> "{"
    (
        (_ STRUCT_ARGUMENTS):+ {% (value) => ({ arguments: value[0].map((value) => value[1])}) %}
        |
        (_ STRUCT_OPTINAL):+ {% (value) => ({ optionals: value[0].map((value) => value[1])}) %}
        |
        (_ STRUCT_ARGUMENTS):+
        (_ STRUCT_OPTINAL):+ {% (value) => ({ arguments: value[0].map((value) => value[1]), optionals: value[1].map((value) => value[1])}) %}
    ):?
    (_ (STRUCT_PROPERTY {% (value) => [PROPERTY, value] %} | STRUCT_METHOD {% (value) => [METHOD, value] %} | STRUCT_OVERLOAD {% (value) => [OVERLOAD, value] %})):*
    _
"}" {% chain(formating((value) => {
    const name = value[2].map((value) => value[1])
    const properties = name.filter((value) => value[0] === PROPERTY).map((value) => value[1])
    const methods = name.filter((value) => value[0] === METHOD).map((value) => value[1])
    const overloads = name.filter((value) => value[0] === OVERLOAD).map((value) => value[1])
    return {
        type: "struct",
        ...value[1],
        properties,
        methods,
        overloads,
    }
})) %}

STRUCT_ARGUMENTS -> DECLARATION_TYPE _ MANY[%identifier] {% formating((value) => {
    return {
        type: value[0],
        identifiers: value[2].map(id),
    }
}) %}
STRUCT_OPTINAL -> DECLARATION_TYPE _ MANY[%identifier _ "=" _ WITH] {% formating((value) => {
    return {
        type: id(value),
        identifiers: value[2].map((value) => {
            return {
                identifier: value[0],
                default_value: value[4],
            }
        }),
    }
}) %}

STRUCT_PROPERTY -> %identifier _ "=" _ WITH BREAK {% formating((value) => {
    return {
        identifier: value[0],
        value: value[4],
    }
}) %}

STRUCT_METHOD -> %identifier _ MULTI_FUNCTION_ARGUMENT _ UNSCOPED_STATEMENT {% formating((value) => {
    return {
        identifier: value[0],
        value: value[2],
    }
}) %}

STRUCT_OVERLOAD -> (
    UNARY_OPERATOR _ UNSCOPED_STATEMENT {% (value) => {
        return {
            type: 'unary',
            operator: value[0],
            statement: value[3]
        }
    } %}
    | INFIX_OPERATOR _ SINGLE_FUNCTION_ARGUMENT _ UNSCOPED_STATEMENT {% (value) => {
        return {
            type: 'infix_left',
            operator: value[0],
            parameter: value[2],
            statement: value[4]
        }
    } %}
    | SINGLE_FUNCTION_ARGUMENT _ INFIX_OPERATOR _ UNSCOPED_STATEMENT {% (value) => {
        return {
            type: 'infix_right',
            operator: value[2],
            parameter: value[0],
            statement: value[4]
        }
    } %}
) {% id %}
INFIX_OPERATOR -> ("||" | "&&" | "|" | "^" | "&" | "<" | ">" | "<<<" | ">>>" | "<<" | ">>" | "+" | "-" | "*" | "/" | "%" | "**") {% id %}
UNARY_OPERATOR -> ("!" | "~" | "-" | "++" | "--") {% id %}

FUNCTION -> MULTI_FUNCTION_ARGUMENT _ "=>" _ UNSCOPED_STATEMENT

MULTI_FUNCTION_ARGUMENT -> "(" _ (MANYP[FUNCTION_ARGUMENT] _):? ")" {% (value) => value[2]?.[0] %}
SINGLE_FUNCTION_ARGUMENT -> "(" _ (FUNCTION_ARGUMENT _):? ")" {% (value) => value[2]?.[0] %}
FUNCTION_ARGUMENT -> EXPRESSION _ DECLARATION_IDENTIFIER {% formating((value) => {
    return {
        type: value[0],
        name: value[2]
    }
}) %}
# TODO: destructuring objects and arrays
DECLARATION_IDENTIFIER -> %identifier

# the right side here is explicet effects
FUNCTION_SIGNATURE -> "(" (_ MANYP[EXPRESSION]) _ ")" _ "->" _ EXPRESSION (_ ":" _ MANY[EXPRESSION]):?

ARRAY -> "[" (_ MANYP[EXPRESSION]):? _ "]"

# TODO: real regex parsing
REGEX -> %regex %regex_content %regex_end

TEMPLATE_STRING -> %template_string_start (%template_string_content | %template_string_interpreter _ EXPRESSION _ "}"):* %template_string_end

LITERAL -> (
	"null"
    | %binary 
    | %hex 
    | %int
    | %float
    | %exponential
    | %color
	| %string 
) {% (value) => {
    return {
        type: 'literal',
        value: did(value),
    }
} %}

BREAK -> %newline:+ | %file_end

# optional whitespace 
_ -> (%newline | %whitespace | %comment):* {% () => null %}
