#!/usr/bin/env python3.14
"""AI Agent Infra v3.10.2 - YashanDB Edition - Schema Deployment Tool

Uses yaspy driver to deploy SQL scripts to YashanDB 23.5+.
Handles PROMPT removal, / block splitting, ; statement splitting.
"""

import re
import sys
import os

def parse_defines(content):
    defines = {}
    for m in re.finditer(r'^DEFINE\s+(\w+)\s*=\s*(.+)$', content, re.MULTILINE):
        val = m.group(2).strip().strip("'\"")
        defines[m.group(1)] = val
    return defines

def substitute_vars(content, defines):
    for key, val in defines.items():
        content = content.replace(f'&{key}', val)
        content = content.replace(f'&&{key}', val)
    return content

def remove_prompts(content):
    return re.sub(r'^PROMPT.*$', '', content, flags=re.MULTILINE)

def is_plsql_block(text):
    """Check if a text block is a PL/SQL block."""
    stripped = text.strip().upper()
    return bool(re.match(r'^(BEGIN|DECLARE|CREATE\s+OR\s+REPLACE\s+(PACKAGE|PROCEDURE|FUNCTION|TRIGGER|TYPE))\b', stripped))

def split_statements(content):
    """Split SQL content into individual statements.
    
    Strategy:
    1. Split by / on its own line (PL/SQL blocks)
    2. For non-PL/SQL blocks, further split by ; at end of line
    3. Strip trailing ; from all statements (yaspy doesn't accept it)
    """
    # Remove PROMPT, WHENEVER, DEFINE lines
    content = re.sub(r'^PROMPT.*$', '', content, flags=re.MULTILINE)
    content = re.sub(r'^WHENEVER\s+.*$', '', content, flags=re.MULTILINE)
    content = re.sub(r'^DEFINE\s+.*$', '', content, flags=re.MULTILINE)
    content = re.sub(r'^SET\s+.*$', '', content, flags=re.MULTILINE)
    content = re.sub(r'^SHOW\s+.*$', '', content, flags=re.MULTILINE)
    
    # Split by / on its own line
    raw_blocks = re.split(r'\n/\s*\n', content)
    
    statements = []
    for block in raw_blocks:
        block = block.strip()
        if not block:
            continue
        
        # Check if it's a PL/SQL block
        if is_plsql_block(block):
            # PL/SQL block - don't split by ;
            # Strip trailing ; 
            block = block.strip()
            if block and not block.startswith('--'):
                statements.append(block)
        else:
            # Regular SQL - split by ; at end of line
            # But be careful with ; inside strings
            lines = block.split('\n')
            current = []
            in_string = False
            
            for line in lines:
                stripped = line.strip()
                
                # Skip pure comment lines when not accumulating
                if not current and (stripped.startswith('--') or not stripped):
                    continue
                
                current.append(line)
                
                # Check if line ends with ; (not inside a string)
                if stripped.endswith(';') and not in_string:
                    stmt = '\n'.join(current).strip().rstrip(';').strip()
                    if stmt and not stmt.startswith('--'):
                        statements.append(stmt)
                    current = []
            
            # Handle any remaining content
            if current:
                stmt = '\n'.join(current).strip().rstrip(';').strip()
                if stmt and not stmt.startswith('--'):
                    statements.append(stmt)
    
    return statements


def main():
    import yaspy
    
    if len(sys.argv) < 5:
        print("Usage: python3.14 deploy_yashandb.py <user> <password> <dsn> <sql_file> [sql_file...]")
        print("Example: python3.14 deploy_yashandb.py aiadmin yashandb123 10.10.10.150:1688/ai_agent scripts/deploy/1_schema.sql")
        sys.exit(1)
    
    user = sys.argv[1]
    password = sys.argv[2]
    dsn = sys.argv[3]
    sql_files = sys.argv[4:]
    
    dsn_str = f"{user}/{password}@{dsn}"
    print(f"[deploy] Connecting to {user}@{dsn}...")
    
    try:
        conn = yaspy.Connection(dsn_str)
    except Exception as e:
        print(f"[deploy] Connection failed: {e}")
        sys.exit(1)
    
    print(f"[deploy] Connected. Processing {len(sql_files)} SQL file(s)...")
    
    cur = conn.cursor()
    
    for sql_file in sql_files:
        print(f"\n[deploy] Executing: {sql_file}")
        
        with open(sql_file) as f:
            content = f.read()
        
        defines = parse_defines(content)
        content = substitute_vars(content, defines)
        content = remove_prompts(content)
        
        statements = split_statements(content)
        print(f"  [{os.path.basename(sql_file)}] {len(statements)} statements to execute")
        
        success = 0
        failed = 0
        
        for i, stmt in enumerate(statements, 1):
            first_line = stmt.split('\n')[0][:80]
            try:
                cur.execute(stmt)
                conn.commit()
                success += 1
            except Exception as e:
                err_msg = str(e)[:120]
                if 'already exists' in err_msg or 'YAS-04207' in err_msg or 'YAS-02013' in err_msg:
                    success += 1
                elif 'has been indexed' in err_msg or 'YAS-02043' in err_msg:
                    success += 1  # Index already exists
                else:
                    failed += 1
                    print(f"    [{i}/{len(statements)}] ERROR: {first_line}")
                    print(f"           {err_msg}")
        
        print(f"  [{os.path.basename(sql_file)}] Done: {success} success, {failed} failed")
    
    cur.close()
    conn.close()
    print(f"\n[deploy] Completed.")


if __name__ == '__main__':
    main()
