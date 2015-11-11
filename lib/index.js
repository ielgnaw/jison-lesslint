var path = require('path');
var fs = require('fs');
var chalk = require('chalk');
var less = require('less');
var safeStringify = require('json-stringify-safe');

var debug = require('debug')('jison-lesslint: index');

var content = fs.readFileSync(
    path.join(__dirname, '..') + path.sep + 'test/test.less',
    // path.join(__dirname, '..') + path.sep + 'test/charset.less',
    // path.join(__dirname, '..') + path.sep + 'test/singlecomment.less',
    // path.join(__dirname, '..') + path.sep + 'test/mulitcomment.less',
    // path.join(__dirname, '..') + path.sep + 'test/import.less',
    // path.join(__dirname, '..') + path.sep + 'test/variable.less',
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
            debug(chalk.red('less err: '));
            debug(chalk.red(err.toString()));
        }
        else {
            var ast = safeStringify(tree, null, 4);
            var lessAstJsonFile = __dirname + path.sep + 'less-ast.json';
            fs.writeFileSync(lessAstJsonFile, ast);
            debug('Less Parse AST JSON saved to %s', lessAstJsonFile);
            debug('Less compile css result: \n' + tree.toCSS({}));
        }

        var parser = require('./parser').parser;
        parser.yy = {
            test: function () {
                console.warn(1);
            }
        };

        var parserRet = safeStringify(parser.parse(content), null, 4);
        var jisonAstFile = __dirname + path.sep + 'jison-ast.json';
        require('fs').writeFileSync(jisonAstFile, parserRet);
        debug('JISON Parse AST JSON saved to %s', jisonAstFile);
    }
);
