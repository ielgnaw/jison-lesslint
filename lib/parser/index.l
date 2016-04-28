
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

leftbrace                   \{
rightbrace                  \}

universalSelector           \*
selector                    {universalSelector}

%{
    var debug = require('debug')('jison-lesslint: lexer');
    var s, s2, s3;
    var rv, rv2, e_offset, col, row, len, value;
    var match, match2;

    // console.log('lexer action: ', yy, yy_, this, yytext, YY_START, $avoiding_name_collisions);
    // var parser = yy.parser;
    debug(YY_START);
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
// sel_start 进入选择器的状态，进入选择器后，后面应该是 {
// sel 选择器的状态，sel_start 之后，就开始 sel 的状态
// block 进入块的状态，1. 选择器可以进入
%x s sc mc ch_start ch im_start im vari_start vari vari_colon_start sel_start sel block

// b 进入选择器内部即块的状态
// sb 进入选择器内部子选择器内部即子块的状态
// p 进入属性的状态，这个状态用来帮助找到属性的值

%%

/**
 * singlecomment
 */
<s>{space}/{singlecomment} {
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
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
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
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
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
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
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
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
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
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


/**
 * selector
 */
<s>{space}*/{selector} {
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
    yytext = yytext.replace(/^\n+/g, '');
    this.begin('sel_start');
    return 'SEL_SPACE_BEFORE_SELECTOR';
};

<sel_start>{selector} {
    this.begin('sel');
    return 'SEL_SELECTOR';
};

<sel>{space} {
    return 'SEL_SPACE';
};

<sel>{leftbrace} {
    this.begin('block');
    return 'LEFT_BRACE';
};


<block>{space} {
    return 'BLOCK_SPACE';
};

<block>{semicolon} {
    return 'BLOCK_SEMICOLON';
};

<block>{rightbrace} {
    this.popState();
    return 'RIGHT_BRACE';
};




<s>{space}/<<EOF>> {
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
    this.popState();
    return 'EOF';
};

<s>{space} {
    return 'SPACE';
};

<s>{n}/<<EOF>> {
    /* // 这个注释是为了把上面一行的 / 所带来的高亮影响给去掉 */
    return 'EOF';
};

<s>{n} {
    return 'N';
};

<s,sc,mc,sel><<EOF>> {
    this.popState();
    return 'EOF';
};

<INITIAL><<EOF>> {
    return 'EOF';
};

<INITIAL> {
    this.begin('s');
};


