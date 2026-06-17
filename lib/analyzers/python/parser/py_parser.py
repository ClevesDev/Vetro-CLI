import sys
import json
import ast
import tokenize
import io

def main():
    if len(sys.argv) < 2:
        print("Uso: python py_parser.py <ruta-del-archivo>", file=sys.stderr)
        sys.exit(1)
        
    file_path = sys.argv[1]
    
    try:
        with open(file_path, 'r', encoding='utf-8', newline='') as f:
            code = f.read()
    except Exception as e:
        print(f"Error al leer el archivo {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
        
    # Mapear inicios de línea para calcular offsets absolutos
    lines = code.splitlines(keepends=True)
    line_starts = [0]
    for line in lines:
        line_starts.append(line_starts[-1] + len(line))
        
    # Extraer comentarios con tokenize
    comments = []
    try:
        tokens = tokenize.generate_tokens(io.StringIO(code).readline)
        for tok in tokens:
            if tok.type == tokenize.COMMENT:
                line_idx = tok.start[0]
                start_offset = 0
                if line_idx - 1 < len(line_starts):
                    start_offset = line_starts[line_idx - 1] + tok.start[1]
                    
                end_line_idx = tok.end[0]
                end_offset = start_offset
                if end_line_idx - 1 < len(line_starts):
                    end_offset = line_starts[end_line_idx - 1] + tok.end[1]
                    
                comments.append({
                    'value': tok.string,
                    'start': start_offset,
                    'end': end_offset,
                    'line': line_idx
                })
    except Exception:
        pass

    # Función helper para mapear byte col a char col
    def get_char_col(line_idx, byte_col):
        if line_idx - 1 < len(lines):
            line_str = lines[line_idx - 1]
            prefix_bytes = line_str.encode('utf-8')[:byte_col]
            return len(prefix_bytes.decode('utf-8', errors='ignore'))
        return byte_col

    def dump_node(node):
        if node is None:
            return None
        
        node_type = node.__class__.__name__
        
        start = 0
        line = 1
        if hasattr(node, 'lineno') and hasattr(node, 'col_offset'):
            line = node.lineno
            if line - 1 < len(lines):
                char_col = get_char_col(line, node.col_offset)
                start = line_starts[line - 1] + char_col
                
        end = start
        if hasattr(node, 'end_lineno') and hasattr(node, 'end_col_offset') and node.end_lineno is not None and node.end_col_offset is not None:
            end_line = node.end_lineno
            if end_line - 1 < len(lines):
                char_end_col = get_char_col(end_line, node.end_col_offset)
                end = line_starts[end_line - 1] + char_end_col
                
        result = {
            'type': node_type,
            'start': start,
            'end': end,
            'line': line,
        }
        
        # Propiedades clave
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            result['name'] = node.name
        elif isinstance(node, ast.Name):
            result['id'] = node.id
        elif isinstance(node, ast.arg):
            result['arg'] = node.arg
        elif isinstance(node, ast.Constant):
            result['value'] = str(node.value)
        elif isinstance(node, ast.alias):
            result['name'] = node.name
            if node.asname:
                result['asname'] = node.asname
        elif isinstance(node, ast.ImportFrom):
            result['module'] = node.module or ''
            result['level'] = node.level
        elif isinstance(node, ast.Attribute):
            result['attr'] = node.attr
            
        # Serializar recursivamente
        for field, value in ast.iter_fields(node):
            if isinstance(value, list):
                serialized_list = []
                for item in value:
                    if isinstance(item, ast.AST):
                        serialized_list.append(dump_node(item))
                result[field] = serialized_list
            elif isinstance(value, ast.AST):
                result[field] = dump_node(value)
                
        return result

    try:
        tree = ast.parse(code, filename=file_path)
        ast_json = dump_node(tree)
        
        # Formato de respuesta unificado
        response = {
            'ast': ast_json,
            'comments': comments
        }
        
        print(json.dumps(response))
    except Exception as e:
        print(f"Error al parsear el archivo Python: {e}", file=sys.stderr)
        sys.exit(2)

if __name__ == '__main__':
    main()
