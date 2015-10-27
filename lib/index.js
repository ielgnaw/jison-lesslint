var path = require('path');
var fs = require('fs');
var chalk = require('chalk');
var less = require('less');
var safeStringify = require('json-stringify-safe');

var content = fs.readFileSync(
    // path.join(__dirname, '..') + path.sep + 'test/charset.less',
    // path.join(__dirname, '..') + path.sep + 'test/singlecomment.less',
    path.join(__dirname, '..') + path.sep + 'test/mulitcomment.less',
    'utf8'
);

content = content.replace(/\r\n?/g, '\n');
var lessParser = new (less.Parser)({
    paths: [
        path.join(__dirname, '..') + path.sep + 'test'
    ],
    includePath: [],
    relativeUrls: true
});
lessParser.parse(
    content,
    function (err, tree) {
        if (err) {
            console.warn(chalk.red('less err: '));
            console.warn(err);
            console.warn();
        }
        else {
            console.warn('less compile result: ');
            console.warn(tree.toCSS());
            console.warn();
            // console.warn(tree);
            // console.warn(safeStringify(tree, null, 4));
            console.warn(chalk.green('less compile success'));
        }
        console.warn('-----------------------------------');
        console.warn();
    }
);

var parser = require('./parser/');
var parserRet = safeStringify(parser.parse(content), null, 4);
// console.warn(parserRet, '---result');
var outputFilename = __dirname + path.sep + 'test.json';

fs.writeFile(outputFilename, parserRet, function (err) {
    if (err) {
        console.log(err);
    }
    else {
        console.log('JSON saved to ' + outputFilename);
    }
});

// console.warn(parser.parse(content));
// console.warn(parser.generate);
// console.warn();
// console.log(require('util').inspect(parser.parse(content), { showHidden: true, depth: null }), '---result');

// var circularJSON = require('circular-json');
// console.warn(circularJSON.stringify(parser.parse(content), null, 4));
