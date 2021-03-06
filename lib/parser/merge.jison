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
hexcolor                    '#'([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})

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
    
    var s, s2, s3;
    var rv, rv2, e_offset, col, row, len, value;
    var match, match2;

    // console.log("lexer action: ", yy, yy_, this, yytext, YY_START, $avoiding_name_collisions);
    // var parser = yy.parser;
    
%}


// %options flex case-insensitive
// %options backtrack_lexer

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
// vari_start 遇到 @ 且后面是 variable 的状态
// vari 进入 @variable 的状态
// vari_colon_start @variable: 匹配冒号后面，分号前面的状态
%x s sc mc ch_start ch im_start im vari_start vari vari_colon_start

// b 进入选择器内部即块的状态
// sb 进入选择器内部子选择器内部即子块的状态
// p 进入属性的状态，这个状态用来帮助找到属性的值

%%

/**
 * singlecomment
 */
<s>{space}/{singlecomment} {
    yytext = yytext.replace(/^\n+/g, '');
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
 * multicomment
 */
<s>{space}/{multicomment} {
    yytext = yytext.replace(/^\n+/g, '');
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
 * variable
 * 变量定义的时候只能是 @name 而不能是 @{name}，@{name} 是在使用变量的时候使用的
 */
<s>{space}/('@'{letter}\s*\:+) {
    yytext = yytext.replace(/^\n+/g, '');
    return 'VARI_SPACE';
};

<s>'@'/({letter}\s*\:+) {
    this.begin('vari_start');
    return 'VARI_START';
};

<vari_start>{letter} {
    this.popState();
    this.begin('vari');
    return 'VARI_NAME';
};

<vari>\:+ {
    this.begin('vari_colon_start');
    return 'VARI_COLON';
};

// <vari_colon_start>\s*('%'|'@'?[_A-Za-z0-9-]|{string}|{hexcolor})* {
<vari_colon_start>\s*('%'|'@'?[_A-Za-z0-9-]|{string}|{hexcolor}|[\(\)\+\-\*\/\s]*|','\s*)* {
    this.popState();
    return 'VARI_VALUE';
};

<vari>{space} {
    return 'VARI_SPACE';
};

<vari>{semicolon} {
    this.popState();
    return 'VARI_SEMICOLON';
};



/**
 * @charset
 */
<s>{space}/'@charset' {
    yytext = yytext.replace(/^\n+/g, '');
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
<s>{space}/'@import' {
    yytext = yytext.replace(/^\n+/g, '');
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
