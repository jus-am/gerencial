#!/usr/bin/env python3
"""Preparação local. Não publica, não conecta ao Supabase e não cria commits."""
import re
from pathlib import Path
import subprocess
import tempfile
import json

def replace(s, pattern, replacement):
    s,n=re.subn(pattern,lambda _:replacement,s,count=1,flags=re.M|re.S)
    if n!=1: raise RuntimeError("Trecho esperado ausente")
    return s

def patch(s, agenda):
    s=replace(s,r'^[^\n]*<button onclick="authSignUp\(\)"[^\n]*</button>[^\n]*$', '')
    s=replace(s,r'async function authSignUp\(\) \{.*?\n\}', '')
    if agenda:
        s=replace(s,r'^const SEED_DATA = [^\n]*$', '')
        s=replace(s,r'function seedLocalData\(\) \{.*?(?=async function initApp\(\))','')
        s=replace(s,r'        if \(!rows \|\| rows.length === 0\) \{.*?(?=        const \{ data: salsData \})', '''        audiencias = (rows || []).map(fromSupabaseRow);
        const { data: mags, error: magError } = await sb.from('magistrados').select('*').order('id');
        const { data: pros, error: proError } = await sb.from('promotores').select('*').order('id');
        if (magError || proError) throw magError || proError;
        magistrados = (mags || []).map(m => ({nome: m.nome, ativo: m.ativo}));
        promotores = (pros || []).map(p => ({nome: p.nome, ativo: p.ativo}));
''')
        s=replace(s,r"const \{ data: salsData \} = await sb.from\('salas'\).select\('\*'\).order\('id'\);","const { data: salsData, error: salasError } = await sb.from('salas').select('*').order('id');\n        if (salasError) throw salasError;")
    reset='audiencias = []; magistrados = []; promotores = []; salas = [];' if agenda else 'idosos = []; cartas = [];'
    s=replace(s,r"console.error\('Supabase init error, falling back to local storage', e\);.*?showToast\('Modo offline — sincronização indisponível', 'error'\);",f"console.error('Falha ao carregar dados', e);\n        {reset}\n        showToast('Não foi possível carregar os dados. Recarregue a página.', 'error');\n        return;")
    if re.search(r'authSignUp|\.signUp\s*\(|SEED_DATA|seedLocalData|falling back to local storage',s): raise RuntimeError('Referência residual')
    return s

def main():
    branch=subprocess.check_output(['git','branch','--show-current'],text=True).strip()
    if branch!='seguranca/benjamin-constant': raise SystemExit('Branch incorreta')
    root=Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],text=True).strip())
    outputs={}
    for name in ['audiencias','controle-processual']:
        p=root/name/'index.html'
        s=patch(p.read_text(encoding='utf-8'),name=='audiencias')
        for js in re.findall(r'<script\b[^>]*>(.*?)</script>',s,re.S|re.I):
            if js.strip():
                subprocess.run(['node','-e','new Function('+json.dumps(js)+')'],check=True)
        outputs[p]=s
    import sys
    if '--apply' in sys.argv:
        for p,s in outputs.items(): p.write_text(s,encoding='utf-8')
        print('Arquivos locais corrigidos; sem commit ou publicação.')
    else: print('Verificação concluída; nenhuma alteração. Use --apply para gravar localmente.')
if __name__=='__main__': main()
