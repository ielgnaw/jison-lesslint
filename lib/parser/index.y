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
    | variable_stmt
    | rules variable_stmt
;

single_comment
    : SC {
        ast.sComments.push({
            type: 'sComment',
            originContent: $1,
            value: $1,
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
            value: $2,
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
        // yy.test();
        ast.mComments.push({
            type: 'mComment',
            value: $1 + $2,
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
            value: $2 + $3,
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
            value: $3.join('') + $4 + $5.join(''),
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
            value: $4.join('') + $5 + $6.join(''),
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

variable_stmt
    : VARI_SPACE VARI_START VARI_NAME VARI_SPACE* VARI_COLON VARI_VALUE VARI_SPACE* VARI_SEMICOLON SPACE* {
        var valueBefore = '';
        var match = /^(\s+)/.exec($6);
        if (match) {
            valueBefore = match[0];
        }

        var pureValue = $6.replace(/^(\s+)/, '');

        ast.variables.push({
            type: 'variable',
            originContent: $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9,
            variableName: $3,
            variableNameBefore: $1,
            variablenameAfter: $4.join(''),
            variableValue: pureValue,
            variableValueBefore: valueBefore,
            variableValueAfter: $7.join(''),
            value: pureValue,
            before: $1,
            after: $9.join(''),
            loc: {
                firstLine: @2.first_line,
                lastLine: @8.last_line,
                firstCol: @2.first_column + 1,
                lastCol: @8.last_column + 1
            }
        });
    }
    | VARI_START VARI_NAME VARI_SPACE* VARI_COLON VARI_VALUE VARI_SPACE* VARI_SEMICOLON SPACE* {
        var valueBefore = '';
        var match = /^(\s+)/.exec($5);
        if (match) {
            valueBefore = match[0];
        }

        var pureValue = $5.replace(/^(\s+)/, '');

        ast.variables.push({
            type: 'variable',
            originContent: $1 + $2 + $3 + $4 + $5 + $6 + $7 + $8,
            variableName: $2,
            variableNameBefore: '',
            variablenameAfter: $3.join(''),
            variableValue: pureValue,
            variableValueBefore: valueBefore,
            variableValueAfter: $6.join(''),
            value: pureValue,
            before: '',
            after: $8.join(''),
            loc: {
                firstLine: @1.first_line,
                lastLine: @7.last_line,
                firstCol: @1.first_column + 1,
                lastCol: @7.last_column + 1
            }
        });
    }
;
