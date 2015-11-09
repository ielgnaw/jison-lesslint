%lex

n                           \n+
space                       [ \t\s]+
semicolon                   \;+
string1                     \"([^\n\r\f\\"])*\"
/*"*/ // 这个注释是为了把 string1 的正则所带来的高亮影响给去掉

string2                     \'([^\n\r\f\\'])*\'
/*'*/ // 这个注释是为了把 string2 的正则所带来的高亮影响给去掉

string                      {string1}|{string2}

letter                      [\w-]+

import                      '@import'
// importOpt                   ('less'|'css'|'multiple'|'once'|'inline'|'reference')
importOpt                   \s*(''|'less'|'css'|'multiple'|'once'|'inline'|'reference')\s*(\,\s*(''|'less'|'css'|'multiple'|'once'|'inline'|'reference')*\s*)*

// variable                    @.+\:
singlecomment               \/\/[^\n]*
// singlecomment               (['"]).*\1.*(\/\/.*)
// multicomment                 \/\*[^*]*\*+([^][^*]*\*+)*\/
// multicomment                 \/\*(?:[^*]|\*+[^\/*])*\*+\/\n?
multicomment                 \/\*(?:[^*]|\*+[^\/*])*\n?
/* // 这个注释是为了把 multicomment 的正则所带来的高亮影响给去掉 */

%{
    
    yy.a = 'aaa';
    var s, s2, s3;
    var rv, rv2, e_offset, col, row, len, value;
    var match, match2;

    // console.log("lexer action: ", yy, yy_, this, yytext, YY_START, $avoiding_name_collisions);
    var parser = yy.parser;
    
%}


// %options flex case-insensitive
%options backtrack_lexer

// 状态：
// %s 指包容性的状态，%x 指非包容性的状态
// 如果是包容性的状态，那么没有状态的规则也会被激活；如果是非包容的，那么只有声明了相应状态的规则才会被激活。

// s 开始状态
// sc 进入单行注释的状态
// mc 进入多行注释的状态
// ch_start 遇到 @ 且后面是 charset 的状态
// ch 进入 @charset 语句后的状态
// im_start 遇到 @ 且后面是 import 的状态
// im 进入 @import 语句后的状态
%x s sc mc ch_start ch im_start im

// b 进入选择器内部即块的状态
// sb 进入选择器内部子选择器内部即子块的状态
// p 进入属性的状态，这个状态用来帮助找到属性的值
// im 进入 @import 语句后的状态
// var 进入 变量定义 语句后的状态
//b sb p im ch var

%%

/**
 * sc
 */
<s>\s+/{singlecomment} {
    // this.begin('sc');
    return 'S_SPACE';
};

<s,sc>{singlecomment} {
    if (this.topState() !== 'sc') {
        this.begin('sc');
    }
    return 'SC';
};

<sc>{n} {
    this.popState();
};

/**
 * mc
 */
<s>\s+/{multicomment} {
    // this.begin('mc');
    return 'M_SPACE';
};

<s,mc>{multicomment} {
    if (this.topState() !== 'mc') {
        this.begin('mc');
    }
    return 'MC';
};

<mc>\*+\/[\s\n]? {
    this.popState();
    return 'MC_END';
};

<mc>{n} {
    this.popState();
};

/**
 * @charset
 */
<s>\s+/'@charset' {
    return 'CH_SPACE';
};

<s>'@'/'charset' {
    this.begin('ch_start');
    return 'CH_START';
};

<ch_start>'charset' {
    this.popState();
    this.begin('ch');
    return 'CHARSET';
};

<ch>{space} {
    return 'CH_SPACE';
};

<ch>{string} {
    return 'CH_STRING';
};

<ch>{letter} {
    return 'CH_LETTER';
};

<ch>{semicolon} {
    this.popState();
    return 'CH_SEMICOLON';
};

/**
 * @import
 * @import 语句必须有引号
 * @import importOptions 必须在小括号内
 */
<s>\s+/'@import' {
    return 'IM_SPACE';
};

<s>'@'/'import' {
    this.begin('im_start');
    return 'IM_START';
};

<im_start>'import' {
    this.popState();
    this.begin('im');
    return 'IMPORT';
};

<im>{space}'('{importOpt}')' {
    return 'IM_OPT';
};

<im>{space} {
    return 'IM_SPACE';
};

<im>{string} {
    return 'IM_STRING';
};

<im>'url('[^\)]+')' {
    console.warn(yytext + '---');
    return 'IM_URL';
};

<im>[\w-\s\:\(\)]+ {
    return 'IM_MEDIA';
};

<im>{semicolon} {
    this.popState();
    return 'IM_SEMICOLON';
};



<s>{space} {
    return 'SPACE';
};

<s>{n} {
    return 'N';
};

<INITIAL> {
    this.begin('s');
};

<INITIAL,s,sc,mc><<EOF>> {
    this.popState();
    return 'EOF';
};

/lex
%{

    // 

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
