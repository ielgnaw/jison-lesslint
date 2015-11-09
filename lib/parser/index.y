%{

    // var chalk = require('chalk');

    // var isDebug = true;
    // function debug() {
    //     if (isDebug) {
    //         var args = [].slice.call(arguments);
    //         var len = args.length;
    //         if (len === 1) {
    //             console.warn(args[0]);
    //         }
    //         else {
    //             var msg = [];
    //             while (len) {
    //                 msg.push(args[args.length - len--]);
    //             }

    //             var first = msg.splice(0, 1);
    //             console.warn(chalk.yellow(first) + ': ' + chalk.cyan(msg.join(' ')));
    //             console.warn();
    //         }
    //     }
    // }

    var util = require('util');
    var debug = require('debug')('jison-lesslint: grammar');

    var ast = {
        variables: [],
        imports: [],
        selectors: [],
        charsets: [],
        sComments: [],
        mComments: []
    };


%}

// %nonassoc mulit_comment
// %nonassoc single_comment
// %nonassoc SPACE N

%start root

/* enable EBNF grammar syntax */
%ebnf

%%

root
    : EOF {
        return {
            root: ast
        };
    }
    // rules 指的是一个块，（逻辑上的）
    // 1. 一个选择器块
    // 2. 一行单行注释
    // 3. 一个多行注释块
    // 4. 一行 @charset 语句；一行 @import 语句；一行变量定义
    // @charset, @import, 以及变量定义需要合在一起来做（词法中）
    // 因为 @charset: 12px 和 @import: 30px 是一个合法的变量定义
    | rules EOF {
        return {
            root: ast
        };
    }
;

rules
    : mulit_comment
    | rules mulit_comment
    | single_comment
    | rules single_comment
    | charset_stmt
    | rules charset_stmt
    | import_stmt
    | rules import_stmt
;

single_comment
    : SC {
        ast.sComments.push({
            type: 'sComment',
            originContent: $1,
            content: $1,
            before: '',
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @1.last_line,
                firstCol: @1.first_column + 1,
                lastCol: @1.last_column + 1
            }
        });
    }
    | S_SPACE SC {
        ast.sComments.push({
            type: 'sComment',
            originContent: $2,
            content: $2,
            before: $1,
            after: '',
            loc: {
                firstLine: @2.first_line,
                lastLine: @2.last_line,
                firstCol: @2.first_column + 1,
                lastCol: @2.last_column + 1
            }
        });
    }
;

mulit_comment
    : MC MC_END {
        ast.mComments.push({
            type: 'mComment',
            content: $1 + $2,
            before: '',
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @2.last_line,
                firstCol: @1.first_column + 1,
                lastCol: @2.last_column + 1,
                originContent: $1 + $2
            }
        });
    }
    | M_SPACE MC MC_END {
        ast.mComments.push({
            type: 'mComment',
            content: $2 + $3,
            before: $1,
            after: '',
            loc: {
                firstLine: @2.first_line,
                lastLine: @3.last_line,
                firstCol: @2.first_column + 1,
                lastCol: @3.last_column + 1,
                originContent: $2 + $3
            }
        });
    }
;

charset_stmt
    : CH_START CHARSET CH_SPACE* (CH_STRING|CH_LETTER) CH_SPACE* CH_SEMICOLON SPACE* {
        var quote = '';
        var match;
        if (match = $4.match(/^(['"]).*\1/)) {
            quote = match[1];
        }
        ast.charsets.push({
            type: 'charset',
            originContent: $1 + $2 + $3 + $4 + $5 + $6 + $7,
            content: $3.join('') + $4 + $5.join(''),
            quote: quote,
            before: '',
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @6.last_line,
                firstCol: @1.first_column + 1,
                lastCol: @6.last_column + 1
            }
        });
    }
    | CH_SPACE CH_START CHARSET CH_SPACE* (CH_STRING|CH_LETTER) CH_SPACE* CH_SEMICOLON SPACE* {
        var quote = '';
        var match;
        if (match = $5.match(/^(['"]).*\1/)) {
            quote = match[1];
        }
        ast.charsets.push({
            type: 'charset',
            originContent: $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8,
            content: $4.join('') + $5 + $6.join(''),
            quote: quote,
            before: $1,
            after: '',
            loc: {
                firstLine: @2.first_line,
                lastLine: @7.last_line,
                firstCol: @2.first_column + 1,
                lastCol: @7.last_column + 1
            }
        });
    }
;

import_stmt
    : IM_SPACE IM_START IMPORT IM_OPT* IM_SPACE* (IM_STRING|IM_URL) IM_SPACE* IM_MEDIA* IM_SEMICOLON SPACE* {
        var quote = '';
        var match;
        if (match = $6.match(/(['"]).*\1/)) {
            quote = match[1];
        }

        var importOption = [];
        var imOptStr = $4.join('');
        if (imOptStr) {
            var t = imOptStr.split(',');
            var s;
            for (var i = 0, len = t.length; i < len; i++) {
                s = t[i].replace(/^[\s\(]*/g, '').replace(/[\s\)]*$/, '');
                if (s) {
                    importOption.push(s);
                }
            }
        }

        ast.imports.push({
            type: 'import',
            originContent: $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9 + $10,
            value: $5.join('') + $6 + $7.join(''),
            quote: quote,
            importOption: importOption,
            originImportOption: imOptStr,
            mediaValue: $8.join(''),
            before: $1,
            after: $10.join(''),
            loc: {
                firstLine: @2.first_line,
                lastLine: @9.last_line,
                firstCol: @2.first_column + 1,
                lastCol: @9.last_column + 1
            }
        });
    }
    | IM_START IMPORT IM_OPT* IM_SPACE* (IM_STRING|IM_URL) IM_SPACE* IM_MEDIA* IM_SEMICOLON SPACE* {
        var quote = '';
        var match;
        if (match = $5.match(/(['"]).*\1/)) {
            quote = match[1];
        }

        var importOption = [];
        var imOptStr = $3.join('');
        if (imOptStr) {
            var t = imOptStr.split(',');
            var s;
            for (var i = 0, len = t.length; i < len; i++) {
                s = t[i].replace(/^[\s\(]*/g, '').replace(/[\s\)]*$/, '');
                if (s) {
                    importOption.push(s);
                }
            }
        }

        ast.imports.push({
            type: 'import',
            originContent: $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9,
            value: $4.join('') + $5 + $6.join(''),
            quote: quote,
            importOption: importOption,
            originImportOption: imOptStr,
            mediaValue: $7.join(''),
            before: '',
            after: $9.join(''),
            loc: {
                firstLine: @1.first_line,
                lastLine: @8.last_line,
                firstCol: @1.first_column + 1,
                lastCol: @8.last_column + 1
            }
        });
    }
;


// blocks
//     : charset_stmt
//     | blocks charset_stm
//     | import_stmt
//     | blocks import_stmt
//     | single_comment
//     | blocks single_comment
//     | mulit_comment
//     | blocks mulit_comment
// ;

// mulit_comment
//     : MC {
//         ast.mComments.push({
//             type: 'mComment',
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
//     | SPACE MC {
//         ast.mComments.push({
//             type: 'mComment',
//             content: $2,
//             before: $1,
//             after: '',
//             loc: {
//                 firstLine: @1.first_line,
//                 lastLine: @2.last_line,
//                 firstCol: @1.first_column + 1 + $1.length,
//                 lastCol: @2.last_column + 1,
//                 originContent: $2
//             }
//         });
//     }
//     | mulit_comment (SPACE|N) {
//         $$ = $1;
//     }
// ;

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
//                 lastCol: @2.last_column= + 1,
//                 originContent: $2
//             }
//         });
//     }
//     | single_comment (SPACE|N) {
//         $$ = $1;
//     }
// ;

// charset_stmt
//     : charset_stmt_start CH_STRING CH_SEMICOLON {
//         var quote = '';
//         var match;
//         if (match = $2.match(/^(['"]).*\1/)) {
//             quote = match[1];
//         }
//         $$ = {
//             type: 'charset',
//             content: $2,
//             quote: quote,
//             before: $1.before,
//             after: '',
//             loc: {
//                 firstLine: @1.first_line,
//                 lastLine: @2.last_line,
//                 firstCol: @1.first_column + 1 + $1.before.length,
//                 lastCol: @3.last_column + 1,
//                 originContent: $1.content + $2 + $3
//             }
//         };
//         ast.charsets.push($$);
//         // console.warn(yy.prepareProgram);
//     }
//     | charset_stmt (SPACE|N) {
//         $1.after = $2 || '';
//     }
// ;

// charset_stmt_start
//     : CHARSET {
//         $$ = {
//             before: '',
//             content: $1
//         }
//     }
//     | CHARSET (SPACE|N) {
//         $$ = {
//             before: '',
//             content: $1 + $2
//         }
//     }
//     | (SPACE|N) charset_stmt_start {
//         $$ = {
//             before: $1,
//             content: $2.content
//         }
//     }
// ;

// import_stmt
//     : IMPORT (SPACE|N)* IM_OPT SPACE IM_STRING IM_SEMICOLON {
//     }
//     | SPACE IMPORT (SPACE|N)* IM_OPT SPACE IM_STRING IM_SEMICOLON {
//         console.warn(13123);
//     }
//     | IMPORT (SPACE|N)* IM_OPT IM_STRING IM_SEMICOLON {
//     }
//     | SPACE IMPORT (SPACE|N)* IM_OPT IM_STRING IM_SEMICOLON {
//         console.warn(13123);
//     }
//     | import_stmt (SPACE|N) {
//         $1.after = $2 || '';
//     }
// ;
