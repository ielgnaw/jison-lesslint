%{
    yy.a = 'aaa';
    var s, s2, s3;
    var rv, rv2, e_offset, col, row, len, value;
    var match, match2;

    // console.log("lexer action: ", yy, yy_, this, yytext, YY_START, $avoiding_name_collisions);
    var parser = yy.parser;
    console.warn(YY_START);
%}

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
%x s sc mc b sb p im ch

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

<INITIAL,s,sc><<EOF>> {
    this.popState();
    return 'EOF';
};

%%
