
var path = require('path');
var fs = require('fs');

var lexContent = fs.readFileSync(
    path.join(__dirname, '..') + path.sep + 'lib/parser/index.l',
    'utf8'
);

var grammarContent = fs.readFileSync(
    path.join(__dirname, '..') + path.sep + 'lib/parser/index.y',
    'utf8'
);

var mergeContent = ''
    + '%lex\n'
    + lexContent
    + '\n/lex\n'
    + grammarContent;

mergeContent = mergeContent
    .replace('var chalk = require(\'chalk\');', '')
    .replace('var util = require(\'util\');', '')
    .replace('var debug = require(\'debug\')(\'jison-lesslint: lexer\');', '')
    .replace('var debug = require(\'debug\')(\'jison-lesslint: grammar\');', '')
    .replace('debug(YY_START);', '');

var outputFilename = path.join(__dirname, '..') + path.sep + 'lib/parser/merge.jison';

fs.writeFile(outputFilename, mergeContent, function (err) {
    if (err) {
        console.log(err);
    }
    else {
        console.log('Merged lex and grammar content saved to ' + outputFilename + '\n');
    }
});
