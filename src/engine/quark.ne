@{%
    const util = require('util');
	const lexer = require('../src/engine/lexer.js');
    const {
        LITERAL,
        WHITESPACE,
        BREAK,
        TEMPLATE_STRING,
        TEMPLATE_STRING_LITERAL,
        TEMPLATE_STRING_INTERPRETATION,
        ARRAY,
        FUNCTION_SIGNATURE,
        STATEMENT_FUNCTION,
        UNARY_OVERLOAD,
        LEFT_INFIX_OVERLOAD,
        RIGHT_INFIX_OVERLOAD,
        STRUCT,
        CALL,
        MEMBER,
        INDEX,
        REFERENCE,
        TYPE_REFERENCE,
        INFIX,
        SEQUENCE,
        WITH,
        CONDITIONAL,
        PREFIX,
        POSTFIX,
        DO_IF,
        DO_WHILE,
        DO,
        FOR,
        DECLARATION,
        INLINE_SEQUENCE,
        ASSIGNMENT,
        AUTO_TYPE,
        WHILE,
        SWITCH,
        IF,
    } = require('../src/engine/nodes.js')

    const debug = false
    const formating = (lambda) => {
        if (debug) {
            return (value) => value
        }
        return lambda
    }

    const log = (value) => console.log(util.inspect(value, { showHidden: false, depth: null, colors: true }));
    
    const did = value => value[0][0];
    const tag = (name, lambda) => (it) => [name, lambda?.(it) ?? it]

    const format = debug ? ()  => (tree) => tree : (lambda) => lambda

    const drill = (...offsets) => (tree) => offsets.reduce((subtree, offset) => subtree?.[offset], tree)
    const chain = (...lambdas) => (tree, context) => lambdas.reduce((data, lambda) => lambda(data, context), tree)
    const build = (...lambdas) => (tree, context) => lambdas.reduce((data, lambda) => ({ ...data, ...(lambda?.(tree, context) ?? {}) }), {})
    const join  = (...lambdas) => (tree, context) => lambdas.map((lambda) => lambda(tree, context)).flat()

    const each =  (lambda) => (tree, context) => tree.map((subTree) => lambda(subTree, context))

    const withLog = (lambda) => (tree) => {
        const value = lambda(tree)
        log(value)
        return value
    }
    const withType = (type) => (tree) => ({ type })
    const withName = (name) => (lambda) => (tree) => ({ [name]: lambda(tree) })
    /*
    const withDrill = (name, ...offsets) => {
        const activeDrill = drill(...offsets)
        return (tree) => ({[name]: activeDrill(tree)})
    }
    */
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

ROOT -> _ %file_end | (_ IMPORT {% formating((value) => value[1]) %}):* (_ TOP_STATEMENT {% formating(([_, statement]) => statement) %}):* {% formating(([ imports, statements]) => {
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

TOP_STATEMENT -> (STATEMENT | EXPORT_STATEMENT) _ BREAK {% formating(did) %}

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
}) %} | EXPRESSION _ "as" _ (%identifier | "default") {% formating((value) => {
    return {
        target: value[0],
        as: value[3],
    }
}) %}

STATEMENT -> (PURE_STATEMENT | EXPRESSION) {% formating(did) %}

UNSCOPED_STATEMENT -> (PURE_UNSCOPED_STATEMENT | EXPRESSION) {% formating(did) %}

PURE_STATEMENT -> (
    PURE_UNSCOPED_STATEMENT
    | DECLARATION
) {% formating(did) %}

PURE_UNSCOPED_STATEMENT -> (
    BLOCK
    | INLINE_SEQUENCE
    | BREAK_STATEMENT
    | CONTINUE
    | RETURN
    | USE
    | SWITCH
    | IF
    | WHILE
    | DO_WHILE
    | FOR
    | DO
    | ASSIGNMENT
)

BLOCK -> "(" (_ (PURE_STATEMENT | STATEMENT ( _ BREAK _ STATEMENT):+)):? _ ")" {% formating((value) => {
    return {
        type: 'block',
        contents: value[1]?.[1],
    }
}) %}

BREAK_STATEMENT -> "break" (_ %identifier):? {% formating((value) => {
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
IF -> LABEL:? "if" _ CONDITION _ STATEMENT (_ "else" _ STATEMENT):? {% format(
    build(
        withType(IF),
        withName('label')(drill(0)),
        withName('condition')(drill(3)),
        withName('then')(drill(5)),
        withName('else')(drill(6, 3)),
    )
) %}
MANY_CASES -> "(" _ MANY[EXPRESSION] _ ")" {% format(
    drill(2)
) %}
CASE -> "case" _ (EXPRESSION | MANY_CASES) _ ":" STATEMENT {% format(
    build(
        withName('targets')(drill(2, 0)),
        withName('body')(drill(5)),
    )
) %}
DEFAULT_CASE -> "default" _ ":" STATEMENT
SWITCH -> LABEL:? "switch" _ CONDITION _ "(" (_ CASE):* (_ DEFAULT_CASE (_ CASE):* ):? _ ")" {% format(
    build(
        withType(SWITCH),
        withName('label')(drill(0)),
        withName('condition')(drill(3)),
        withName('cases')(join(drill(6, 1), drill(7, 2, 1))),
        withName('default_case')(drill(7, 1)),
    )
) %}
WHILE -> LABEL:? "while" _ CONDITION _ UNSCOPED_STATEMENT {% format(
    build(
        withType(WHILE),
        withName('label')(drill(0)),
        withName('condition')(drill(3)),
        withName('body')(drill(5)),
    )
) %}
DO_IF -> DO _ "if" _ CONDITION {% format(
    build(
        withType(DO_IF),
        withName('body')(drill(0)),
        withName('condition')(drill(4)),
    )
) %}
DO_WHILE -> DO _ "while" _ CONDITION {% format(
    build(
        withType(DO_WHILE),
        withName('body')(drill(0)),
        withName('condition')(drill(4)),
    )
) %}

DO -> LABEL:? "do" _ UNSCOPED_STATEMENT (_ HANDLE):* {% format(
    build(
        withType(DO),
        withName('label')(drill(0)),
        withName('body')(drill(3)),
        withName('handles')(drill(4)),
    )
) %}
HANDLE -> "handle" _ MANY[EXPRESSION] _ SINGLE_FUNCTION_ARGUMENT _ UNSCOPED_STATEMENT {% format(
    build(
        withName('types')(drill(2)),
        withName('argument')(drill(4)),
        withName('body')(drill(6))
    )
) %}

FOR -> LABEL:? "for" _ "(" _ DECLARATION_IDENTIFIER _ ":" _ EXPRESSION _ ")" _ UNSCOPED_STATEMENT {% format(
    build(
        withType(FOR),
        withName('label')(drill(0)),
        withName('identifier')(drill(5)),
        withName('producer')(drill(9)),
        withName('body')(drill(13)),
    )
) %}

DECLARATION -> DECLARATION_TYPE _ MANYP[DECLARATION_PARTS] {% format(
    build(
        withType(DECLARATION),
        withName('data_type')(drill(0)),
        withName('parts')(drill(2)),
    ),
) %}
DECLARATION_PARTS -> %identifier {% format(
    build(
        withName('identifier')(drill(0)),
    )
) %} | DECLARATION_IDENTIFIER (_ "=" _ EXPRESSION):? {% format(
    build(
        withName('identifier')(drill(0)),
        withName('value')(drill(1, 3)),
    )
) %}
INLINE_SEQUENCE -> DECLARATION_TYPE _ DECLARATION_IDENTIFIER _ "<<=" _ EXPRESSION {% format(
    build(
        withType(INLINE_SEQUENCE),
        withName('data_type')(drill(0)),
        withName('name')(drill(2)),
        withName('value')(drill(6)),
    )
) %}
ASSIGNMENT -> %identifier _ %assignment _ EXPRESSION {% format(
    build(
        withType(ASSIGNMENT),
        withName('name')(drill(0)),
        withName('assignment_type')(drill(2)),
        withName('value')(drill(4)),
    )
) %}

DECLARATION_TYPE -> "let" {% format(
    build(
        withName('type')(() => AUTO_TYPE)
    )
) %} | EXPRESSION "?":? ("[" "]" "?":?):* {% format(
    build(
        withName('type')(drill(0))
    )
) %}

LABEL -> %identifier _ ":" _ {% format(drill(0)) %}

@{%
    const formatInfix = format(
        build(
            withType(INFIX),
            withName('operation')(drill(2)),
            withName('left')(drill(0)),
            withName('right')(drill(4)),
        )
    )
%}

EXPRESSION  -> MULTI_FUNCTION_ARGUMENT _ "=>" _ EXPRESSION {% formatInfix %} | SEQUENCE {% format(drill(0)) %}
SEQUENCE    -> SEQUENCE _ ">>=" _ WITH {% format(
    build(
        withType(SEQUENCE),
        withName('target')(drill(0)),
        withName('lambda')(drill(4)),
    )
) %} | WITH {% format(drill(0)) %}
WITH        ->  "with" _ WITH {% format(
    build(
        withType(WITH),
        withName('target')(drill(2)),
    )
) %} | CONDITIONAL {% format(drill(0)) %}

CONDITIONAL -> COALESCE _ "?" _ EXPRESSION _ ":" _ EXPRESSION {% format(
    build(
        withType(CONDITIONAL),
        withName('condition')(drill(0)),
        withName('first')(drill(4)),
        withName('second')(drill(8)),
    )
) %} | COALESCE {% format(drill(0)) %}

COALESCE -> COALESCE _ "??" _ OR {% formatInfix %} | OR {% format(drill(0)) %}
OR -> OR _ "||" _ AND {% formatInfix %} | AND {% format(drill(0)) %}
AND -> AND _ "&&" _ BIT_OR {% formatInfix %} | BIT_OR {% format(drill(0)) %}
BIT_OR -> BIT_OR _ "|" _ BIT_XOR {% formatInfix %} | BIT_XOR {% format(drill(0)) %}
BIT_XOR -> BIT_XOR _ "^" _ BIT_AND {% formatInfix %} | BIT_AND {% format(drill(0)) %}
BIT_AND -> BIT_AND _ "&" _ EQUALITY {% formatInfix %} | EQUALITY {% format(drill(0)) %}
EQUALITY -> EQUALITY _ ("==" | "!=") _ COMPARISON {% formatInfix %} | COMPARISON {% format(drill(0)) %}
COMPARISON -> COMPARISON _ (">=" | "<=" | "<" | ">") _ SHIFT {% formatInfix %} | SHIFT {% format(drill(0)) %}
SHIFT -> SHIFT _ ("<<<" | ">>>" | "<<" | ">>") _ SUM {% formatInfix %} | SUM {% format(drill(0)) %}
SUM -> SUM _ ("+" | "-") _ PRODUCT {% formatInfix %} | PRODUCT {% format(drill(0)) %}
PRODUCT -> PRODUCT _ ("*" | "/" | "%") _ POWER {% formatInfix %} | POWER {% format(drill(0)) %}
POWER -> POWER _ "**" _ PREFIX {% formatInfix %} | PREFIX {% format(drill(0)) %}

PREFIX      -> ("!" | "~" | "-" | "++" | "--") _ PREFIX {% format(
    build(
        withType(PREFIX),
        withName('operation')(drill(0)),
        withName('target')(drill(2)),
    )
)%} | POSTFIX {% format(drill(0)) %}

POSTFIX     -> POSTFIX _ ("!" | "~" | "-" | "++" | "--") {% format(
    build(
        withType(POSTFIX),
        withName('target')(drill(0)),
        withName('operation')(drill(2)),
    )
)%} | CALL {% format(drill(0)) %}

KEY_WORD_PARAMETER -> %identifier _ "=" _ EXPRESSION {% format(
    build(
        withName('name')(drill(0)),
        withName('value')(drill(4)),
    ),
) %}
CALL -> CALL ("(" | "?(") (
    _ (
        MANYP[SEQUENCE] {% format(
            build(
                withName('parameters')(drill(1)),
                withName('named_parameters')(() => []),
            ),
        ) %}
        | MANYP[KEY_WORD_PARAMETER] {% format(
            build(
                withName('parameters')(() => []),
                withName('named_parameters')(drill(1)),
            ),
        ) %}
        | MANY[SEQUENCE] _ "," _ MANYP[KEY_WORD_PARAMETER] {% format(
            build(
                withName('parameters')(drill(1)),
                withName('named_parameters')(drill(5)),
            ),
        ) %}
    ):?
) _ ")" {% format(
    build(
        withType(CALL),
        withName('safe')(chain(drill(1), (tree) => tree === '?(')),
        withName('target')(drill(0)),
        drill(2, 1)
    )
) %} | MEMBER {% format(drill(0)) %}
MEMBER -> MEMBER ("." | "?.") %identifier {% format(
    build(
        withType(MEMBER),
        withName('safe')(chain(drill(1), (tree) => tree === '?.')),
        withName('target')(drill(0)),
        withName('property')(drill(2)),
    )
) %} | INDEX {% format(drill(0)) %}
INDEX -> INDEX ("[" | "?[") _ EXPRESSION _ "]" {% format(
    build(
        withType(INDEX),
        withName('safe')(chain(drill(1), (tree) => tree === '?[')),
        withName('target')(drill(0)),
        withName('property')(drill(3)),
    )
) %} | REFERENCE {% format(drill(0)) %}
REFERENCE      -> TYPE_REFERENCE "::" %identifier {% format(
    build(
        withType(REFERENCE),
        withName('target')(drill(0)),
        withName('property')(drill(2)),
    )
) %} | TYPE_REFERENCE {% format(drill(0)) %}
TYPE_REFERENCE -> "::" VALUE {% () => (
    build(
        withType(TYPE_REFERENCE),
        withName('target')(drill(1)),
    )
) %} | VALUE {% format(drill(0)) %}

VALUE -> 
    %identifier {% format(drill(0)) %}
    | LITERAL {% format(drill(0)) %}
    | TEMPLATE_STRING {% format(drill(0)) %}
    | REGEX {% format(drill(0)) %}
    | STATEMENT_FUNCTION {% format(drill(0)) %}
    | ARRAY {% format(drill(0)) %}
    | STRUCT {% format(drill(0)) %}
    | FUNCTION_SIGNATURE {% format(drill(0)) %}
    | GROUPING {% format(drill(0)) %}

GROUPING -> "(" _ EXPRESSION _ ")" {% format(drill(2)) %}

@{%
    const METHOD = Symbol('METHOD')
    const OVERLOAD = Symbol('OVERLOAD')
    const PROPERTY = Symbol('OVERLOAD')
%}
STRUCT -> "{"
    _
    (
        (STRUCT_ARGUMENTS _):+ {% format(
            build(
                (tree) => ({
                    arguments: each(drill(0, 0))(tree),
                    optionals: [],
                }),
            ),
        ) %}
        | (STRUCT_OPTIONALS _):+ {% format(
            build(
                (tree) => ({
                    arguments: [],
                    optionals: each(drill(0, 0))(tree),
                }),
            ),
        ) %}
        | (STRUCT_ARGUMENTS _):+ (STRUCT_OPTIONALS _):+ {% format(
            build(
                (tree) => ({
                    arguments: each(drill(0, 0))(tree),
                    optionals: each(drill(1, 0))(tree),
                }),
            ),
        ) %}
    ):?
    (
        (
            (STRUCT_PROPERTY _) {% format(
                (tree) => [
                    PROPERTY, drill(0)(tree),
                ]
            ) %}
            | (STRUCT_METHOD _)  {% format(
                (tree) => [
                    METHOD, drill(0)(tree),
                ]
            ) %}
            | (STRUCT_OVERLOAD _)  {% format(
                (tree) => [
                    OVERLOAD, drill(0)(tree),
                ]
            ) %}
        ):* {% format(
            chain(drill(0), (tree) => {
                const properties = tree.filter((value) => value[0] === PROPERTY).map((value) => value[1])
                const methods = tree.filter((value) => value[0] === METHOD).map((value) => value[1])
                const overloads = tree.filter((value) => value[0] === OVERLOAD).map((value) => value[1])
                return {
                    properties,
                    methods,
                    overloads,
                }
            })
        ) %}
    )
"}" {% format(
    build(
        withType(STRUCT),
        drill(2),
        drill(3),
    ),
) %}

STRUCT_ARGUMENTS -> DECLARATION_TYPE _ MANY[%identifier] {% format(
    build(
        withName('arguments_type')(drill(0)),
        withName('names')(drill(2))
    )
) %}
STRUCT_OPTIONALS -> DECLARATION_TYPE _ MANY[STRUCT_OPTIONAL_NAME] {% format(
    build(
        withName('optinals_type')(drill(0)),
        withName('values')(drill(2))
    )
) %}
STRUCT_OPTIONAL_NAME -> %identifier _ "=" _ WITH {% format(
    build(
        withName('name')(drill(0)),
        withName('default_value')(drill(4))
    )
) %}

STRUCT_PROPERTY -> %identifier _ "=" _ WITH BREAK {% format(
    build(
        withName('name')(drill(0)),
        withName('value')(drill(4)),
    )
) %}

STRUCT_METHOD -> %identifier _ MULTI_FUNCTION_ARGUMENT _ UNSCOPED_STATEMENT {% format(
    build(
        withName('name')(drill(0)),
        withName('arguments')(drill(2)),
        withName('body')(drill(4)),
    )
) %}

STRUCT_OVERLOAD -> UNARY_OVERLOAD | RIGHT_INFIX_OVERLOAD | LEFT_INFIX_OVERLOAD

UNARY_OVERLOAD -> UNARY_OPERATOR _ UNSCOPED_STATEMENT {% format(
    withType(UNARY_OVERLOAD),
    withName('operator')(drill(0)),
    withName('statement')(drill(3)),
) %}
UNARY_OPERATOR -> "!" | "~" | "-" | "++" | "--"

LEFT_INFIX_OVERLOAD -> INFIX_OPERATOR _ SINGLE_FUNCTION_ARGUMENT _ UNSCOPED_STATEMENT {% format(
    withType(LEFT_INFIX_OVERLOAD),
    withName('operator')(drill(0)),
    withName('parameter')(drill(2)),
    withName('statement')(drill(4)),
) %}

RIGHT_INFIX_OVERLOAD -> SINGLE_FUNCTION_ARGUMENT _ INFIX_OPERATOR _ UNSCOPED_STATEMENT {% format(
    withType(RIGHT_INFIX_OVERLOAD),
    withName('operator')(drill(2)),
    withName('parameter')(drill(0)),
    withName('statement')(drill(4)),
) %}
INFIX_OPERATOR -> "||" | "&&" | "|" | "^" | "&" | "<" | ">" | "<<<" | ">>>" | "<<" | ">>" | "+" | "-" | "*" | "/" | "%" | "**"

STATEMENT_FUNCTION -> MULTI_FUNCTION_ARGUMENT _ "=>" _ PURE_UNSCOPED_STATEMENT {% format(
    build(
        withType(STATEMENT_FUNCTION),
        withName('arguments')(drill(0)),
        withName('body')(drill(4)),
    )
) %}

MULTI_FUNCTION_ARGUMENT -> "(" _ (MANYP[FUNCTION_ARGUMENT] _):? ")" {% format(drill(2, 0)) %}
SINGLE_FUNCTION_ARGUMENT -> "(" _ (FUNCTION_ARGUMENT _):? ")" {% format(
    drill(2, 0)
) %}
FUNCTION_ARGUMENT -> (EXPRESSION _):? DECLARATION_IDENTIFIER {% format(
    build(
        withName('argument_type')(drill(0, 0)),
        withName('argument_name')(drill(1)),
    )
) %}
# TODO: destructuring objects and arrays
DECLARATION_IDENTIFIER -> %identifier

# the right side here is explicet effects
FUNCTION_SIGNATURE -> "(" (_ MANYP[EXPRESSION]):? _ ")" _ "->" _ EXPRESSION (_ ":" _ MANY[EXPRESSION]):? {% format(
    build(
        withType(FUNCTION_SIGNATURE),
        withName('paramTypes')(drill(1, 1)),
        withName('returnType')(drill(7)),
        withName('explicit_use_types')(drill(8, 3)),
    )
) %}

ARRAY -> "[" (_ MANYP[EXPRESSION]):? _ "]" {% format(
    build(withType(ARRAY), withName('values')(drill(1, 1)))
) %}

# TODO: real regex parsing
REGEX -> %regex %regex_content %regex_end

TEMPLATE_STRING_LITERAL -> %template_string_content {% format(
    build(withType(TEMPLATE_STRING_LITERAL), withName('value')(drill(0)))
) %}
TEMPLATE_STRING_INTERPRETATION -> %template_string_interpreter _ EXPRESSION _ "}" {% format(
    build(withType(TEMPLATE_STRING_INTERPRETATION), withName('value')(drill(2)))
) %}
TEMPLATE_STRING -> %template_string_start (TEMPLATE_STRING_LITERAL | TEMPLATE_STRING_INTERPRETATION):* %template_string_end {% format(
    build(withType(TEMPLATE_STRING), withName('parts')(drill(1)))
) %}

LITERAL -> (
	"null"
    | %binary 
    | %hex 
    | %int
    | %float
    | %exponential
    | %color
	| %string 
) {% format(build(withType(LITERAL), withName('value')(drill(0, 0)))) %}

BREAK -> %newline:+ | %file_end {% format(() => BREAK) %}

# optional whitespace 
_ -> (%newline | %whitespace | %comment):* {% format(() => WHITESPACE) %}
