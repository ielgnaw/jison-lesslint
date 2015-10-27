%lex

n                           \n+
space                       [ \t\s]+
semicolon                   \;+
string1                     \"([^\n\r\f\\"])*\"
string2                     \'([^\n\r\f\\'])*\'
string                      {string1}|{string2}
charset                     '@charset'


import                      \s*'@import'
singlecomment               \/\/.*
// singlecomment               (['"]).*\1.*(\/\/.*)

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


%options backtrack_lexer

%x s sc mc b sb p im ch str
%%

<s>{space} {
    return 'SPACE';
};

<s>{n} {
    return 'N';
};

<s>{charset} {
    this.begin('ch');
    return 'CHARSET';
};

// 正常状态下遇到 `//`
<s>{singlecomment} {
    this.begin('sc');
    return 'SC';
};

<sc>{n} {
    this.popState();
};

<ch>{space} {
    return 'SPACE';
};

<ch>{string} {
    return 'CH_STRING';
};

<ch>{semicolon} {
    this.popState();
    return 'CH_SEMICOLON';
};

<INITIAL> {
    this.begin('s');
};

<INITIAL,s><<EOF>> {
    if (this.topState() === 's') {
        this.popState();
    }
    return 'EOF';
};

/lex

%{
    var variables = [];
    var ast = {
        variables: [],
        imports: [],
        selectors: [],
        charsets: [],
        sComments: []
    };
%}

%nonassoc charset_stmt single_comment
%nonassoc SPACE N

%start root
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
