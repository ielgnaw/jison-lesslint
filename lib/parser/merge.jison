%lex

n                           \n+
space                       [ \t\s]+
semicolon                   \;+
string1                     \"([^\n\r\f\\"])*\"
string2                     \'([^\n\r\f\\'])*\'
string                      {string1}|{string2}
charset                     '@charset'
import                      '@import'
importOpt                   \(('less'|'css'|'multiple'|'once'|'inline'|'reference')\)
// variable                    @.+\:
singlecomment               \/\/.*
// singlecomment               (['"]).*\1.*(\/\/.*)
multicomment                 \/\*[^*]*\*+([^/*][^*]*\*+)*\/

/**/ // 这个注释是为了把 multicomment 的正则所带来的高亮影响给去掉

quote                       ['"]

/*"'*/ // 这个注释是为了把 quote 的正则所带来的高亮影响给去掉

%{
    yy.a = 'aaa';
    var s, s2, s3;
    var rv, rv2, e_offset, col, row, len, value;
    var match, match2;

    // console.log("lexer action: ", yy, yy_, this, yytext, YY_START, $avoiding_name_collisions);
    var parser = yy.parser;
    console.warn(YY_START);
%}


// %options flex case-insensitive
%options backtrack_lexer

// 状态：
// %s 指包容性的状态，%x 指非包容性的状态
// 如果是包容性的状态，那么没有状态的规则也会被激活；如果是非包容的，那么只有声明了相应状态的规则才会被激活。

// s 开始状态
// sc 进入单行注释的状态
// mc 进入多行注释的状态
// b 进入选择器内部即块的状态
// sb 进入选择器内部子选择器内部即子块的状态
// p 进入属性的状态，这个状态用来帮助找到属性的值
// im 进入 @import 语句后的状态
// ch 进入 @charset 语句后的状态
// var 进入 变量定义 语句后的状态
%x s sc mc b sb p im ch var

%%

<s>{space} {
    return 'SPACE';
};

<s>{n} {
    return 'N';
};

/**
 * mc
 */
<s>{multicomment} {
    this.begin('mc');
    return 'MC';
};

<mc>{n} {
    this.popState();
};

/**
 * sc
 */
<s>{singlecomment} {
    this.begin('sc');
    return 'SC';
};

<sc>{n} {
    this.popState();
};

/**
 * ch
 */
<s>{charset} {
    this.begin('ch');
    return 'CHARSET';
};

<ch>{space} {
    return 'SPACE';
};

<ch>{string} {
    return 'CH_STRING';
};

<ch>([^\n\r\f;])+ {
    return 'CH_STRING';
};

<ch>{semicolon} {
    this.popState();
    return 'CH_SEMICOLON';
};

// <s>{variable} {
//     this.begin('var');
//     return 'VAR_KEY';
// };

/**
 * im
 */
<s>{import} {
    this.begin('im');
    return 'IMPORT';
};

<im>{space} {
    return 'SPACE';
};

<im>{string} {
    return 'IM_STRING';
};

<im>{importOpt} {
    return 'IM_OPT';
};

<im>{semicolon} {
    this.popState();
    return 'IM_SEMICOLON';
};



<INITIAL> {
    this.begin('s');
};

<INITIAL,s,sc,mc,im><<EOF>> {
    this.popState();
    return 'EOF';
};

/lex
%{

    

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

    var ast = {
        variables: [],
        imports: [],
        selectors: [],
        charsets: [],
        sComments: [],
        mComments: []
    };


%}

%nonassoc import_stmt charset_stmt single_comment mulit_comment
%nonassoc SPACE N

%start root

/* enable EBNF grammar syntax */
%ebnf

%%

root
    : blocks EOF {
        // ast.imports = yy.imports;
        return {
            root: ast
        };
    }
    | EOF {
        // ast.imports = yy.imports || [];
        return {
            root: ast
        };
    }
;

blocks
    : charset_stmt
    | blocks charset_stmt
    | import_stmt
    | blocks import_stmt
    | single_comment
    | blocks single_comment
    | mulit_comment
    | blocks mulit_comment
;

mulit_comment
    : MC {
        ast.mComments.push({
            type: 'mComment',
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
    | SPACE MC {
        ast.mComments.push({
            type: 'mComment',
            content: $2,
            before: $1,
            after: '',
            loc: {
                firstLine: @1.first_line,
                lastLine: @2.last_line,
                firstCol: @1.first_column + 1 + $1.length,
                lastCol: @2.last_column + 1,
                originContent: $2
            }
        });
    }
    | mulit_comment (SPACE|N) {
        $$ = $1;
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
                lastCol: @2.last_column= + 1,
                originContent: $2
            }
        });
    }
    | single_comment (SPACE|N) {
        $$ = $1;
    }
;

charset_stmt
    : charset_stmt_start CH_STRING CH_SEMICOLON {
        var quote = '';
        var match;
        if (match = $2.match(/^(['"]).*\1/)) {
            quote = match[1];
        }
        $$ = {
            type: 'charset',
            content: $2,
            quote: quote,
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

import_stmt
    : IMPORT (SPACE|N)* IM_OPT SPACE IM_STRING IM_SEMICOLON {
    }
    | SPACE IMPORT (SPACE|N)* IM_OPT SPACE IM_STRING IM_SEMICOLON {
        console.warn(13123);
    }
    | IMPORT (SPACE|N)* IM_OPT IM_STRING IM_SEMICOLON {
    }
    | SPACE IMPORT (SPACE|N)* IM_OPT IM_STRING IM_SEMICOLON {
        console.warn(13123);
    }
    | import_stmt (SPACE|N) {
        $1.after = $2 || '';
    }
;
