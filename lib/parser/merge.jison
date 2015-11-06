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
singlecomment               \/\/[^\n]*
// singlecomment               (['"]).*\1.*(\/\/.*)
// multicomment                 \/\*[^*]*\*+([^][^*]*\*+)*\/
// multicomment                 \/\*(?:[^*]|\*+[^\/*])*\*+\/\n?
multicomment                 \/\*(?:[^*]|\*+[^\/*])*\n?

/* // 这个注释是为了把 multicomment 的正则所带来的高亮影响给去掉

quote                       ['"]

/*"'*/ // 这个注释是为了把 quote 的正则所带来的高亮影响给去掉

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
// b 进入选择器内部即块的状态
// sb 进入选择器内部子选择器内部即子块的状态
// p 进入属性的状态，这个状态用来帮助找到属性的值
// im 进入 @import 语句后的状态
// ch 进入 @charset 语句后的状态
// var 进入 变量定义 语句后的状态
%x s sc mc b sb p im ch var

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



<s>{space} {
    return 'SPACE';
};

<s>{n} {
    return 'N';
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
    // 1. 一行变量定义
    // 2. 一个选择器块
    // 3. 一行单行注释
    // 4. 一个多行注释块
    // 5. 一行 @charset 语句
    // 6. 一行 @import 语句
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
    | single_comment
    | rules single_comment
    | rules mulit_comment
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
    | S_SPACE SC {
        ast.sComments.push({
            type: 'sComment',
            content: $2,
            before: $1,
            after: '',
            loc: {
                firstLine: @2.first_line,
                lastLine: @2.last_line,
                firstCol: @2.first_column + 1,
                lastCol: @2.last_column + 1,
                originContent: $2
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
