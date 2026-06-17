const fs = require('fs');
const path = require('path');

// Cargar Babel Standalone desde el mismo directorio
const babelPath = path.join(__dirname, 'babel.min.js');
const Babel = require(babelPath);

const filePath = process.argv[2];
if (!filePath) {
  console.error("Uso: node ts_parser.js <ruta-del-archivo>");
  process.exit(1);
}

try {
  const code = fs.readFileSync(filePath, 'utf-8');
  const parser = Babel.packages.parser;
  const ast = parser.parse(code, {
    sourceType: 'module',
    plugins: [
      'typescript',
      'jsx',
      ['decorators', { decoratorsBeforeExport: true }],
      'classProperties',
      'objectRestSpread'
    ]
  });
  console.log(JSON.stringify(ast));
} catch (e) {
  console.error("Error al parsear el archivo TypeScript:", e.message);
  process.exit(2);
}
