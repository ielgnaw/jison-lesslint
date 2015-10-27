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
%}

%nonassoc charset_stmt single_comment
%nonassoc SPACE N

%start root

/* enable EBNF grammar syntax */
%ebnf

%%

root
    : blocks EOF {
        ast.imports = yy.imports;
        return {
            root: ast
        };
    }
    | EOF {
        ast.imports = yy.imports || [];
        return {
            root: ast
        };
    }
;

blocks
    : charset_stmt
    | blocks charset_stmt
    | single_comment
    | blocks single_comment
    | mulit_comment
    // | blocks single_comment
;

mulit_comment
    : MC_START MC_END {
        console.warn($1, '111');
        console.warn($2, '222');
        // console.warn($3, '222');
    }
;

single_comment
    : SC {
        ast.sComments.push({
            type: 'sComment',
            content: $1,
            before: '',
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @1.last_line,
                firstCol: @1.first_column + 1,
                lastCol: @1.last_column + 1,
                originContent: $1
            }
        });
    }
    | SPACE SC {
        ast.sComments.push({
            type: 'sComment',
            content: $2,
            before: $1,
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @2.last_line,
                firstCol: @1.first_column + 1 + $1.length,
                lastCol: @2.last_column + 1,
                originContent: $1 + $2
            }
        });
    }
    | single_comment (SPACE|N) {
        $$ = $1;
    }
;

charset_stmt
    : charset_stmt_start CH_STRING CH_SEMICOLON {
        $$ = {
            type: 'charset',
            content: $2,
            quote: $2.slice(0, 1),
            before: $1.before,
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @2.last_line,
                firstCol: @1.first_column + 1 + $1.before.length,
                lastCol: @3.last_column + 1,
                originContent: $1.content + $2 + $3
            }
        };
        ast.charsets.push($$);
        // console.warn(yy.prepareProgram);
    }
    | charset_stmt (SPACE|N) {
        $1.after = $2 || '';
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
