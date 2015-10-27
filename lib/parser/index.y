%{

    var chalk = require('chalk');
    var safeStringify = require('json-stringify-safe');

    var variables = [];
    var ast = {
        variables: [],
        imports: [],
        selectors: [],
        charsets: [],
        sComments: []
    };

    var curSelector = null;

    var isDebug = true;
    function debug() {
        if (isDebug) {
            var args = [].slice.call(arguments);
            var len = args.length;
            if (len === 1) {
                console.warn(args[0]);
            }
            else {
                var msg = [];
                while (len) {
                    msg.push(args[args.length - len--]);
                }

                var first = msg.splice(0, 1);
                console.warn(chalk.yellow(first) + ': ' + chalk.cyan(msg.join(' ')));
                console.warn();
            }
        }
    }

    var charsetAfterTmp = '';

%}

// %nonassoc '+'
// %nonassoc '*'

/* enable EBNF grammar syntax */
%ebnf

%start root

%%

root
    : blocks EOF {
        ast.imports = yy.imports;
        // ast.charsets = yy.charsets;
        // ast.sComments = yy.sComments;
        return {
            root: ast
        };
    }
    | EOF {
        ast.imports = yy.imports || [];
        // ast.charsets = yy.charsets || [];
        // ast.sComments = yy.sComments || [];
        return {
            root: ast
        };
    }
;

blocks
    : charset_stmt
    | blocks charset_stmt
    // | single_comment
    // | blocks single_comment
;

// single_comment
//     : SC {
//         ast.sComments.push({
//             type: 'sComment',
//             content: $1,
//             before: '',
//             after: '',
//             loc: {
//                 firstLine: @1.first_line,
//                 lastLine: @1.last_line,
//                 firstCol: @1.first_column + 1,
//                 lastCol: @1.last_column + 1,
//                 originContent: $1
//             }
//         });
//     }
//     | SPACE SC {
//         ast.sComments.push({
//             type: 'sComment',
//             content: $2,
//             before: $1,
//             after: '',
//             loc: {
//                 firstLine: @1.first_line,
//                 lastLine: @2.last_line,
//                 firstCol: @1.first_column + 1 + $1.length,
//                 lastCol: @2.last_column + 1,
//                 originContent: $1 + $2
//             }
//         });
//     }
// ;

charset_stmt
    : charset_stmt_start STRING SEMICOLON (SPACE|N) {
        ast.charsets.push({
            type: 'charset',
            content: $2,
            quote: $2.slice(0, 1),
            before: $1.before,
            after: $4,
            loc: {
                firstLine: @1.first_line,
                lastLine: @2.last_line,
                firstCol: @1.first_column + 1 + $1.before.length,
                lastCol: @3.last_column + 1,
                originContent: $1.content + $2 + $3
            }
        });
    }
;

charset_stmt_start
    : CHARSET {
        $$ = {
            before: '',
            content: $1
        }
    }
    | CHARSET (SPACE|N) {
        $$ = {
            before: '',
            content: $1 + $2
        }
    }
    | (SPACE|N) charset_stmt_start {
        $$ = {
            before: $1,
            content: $2.content
        }
    }
;

%%
