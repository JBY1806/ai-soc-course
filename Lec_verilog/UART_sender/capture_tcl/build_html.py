# 캡처_순서.md → 캡처_순서.html (왼쪽 고정 목차). 사용 : py -3.10 -X utf8 build_html.py
import os, re, markdown
HERE = os.path.dirname(os.path.abspath(__file__))
md = open(os.path.join(HERE, '캡처_순서.md'), encoding='utf-8').read()
conv = markdown.Markdown(extensions=['tables', 'fenced_code', 'toc'], extension_configs={'toc': {'toc_depth': '2-3'}})
body = conv.convert(md)
toc = conv.toc
css = '''
:root{--ink:#111;--sub:#555;--line:#d0d4da;--bg:#fbfcfe}
*{box-sizing:border-box}
body{margin:0;font-family:"Malgun Gothic",sans-serif;color:var(--ink);background:var(--bg);line-height:1.7;font-size:15px}
#side{position:fixed;top:0;left:0;width:270px;height:100vh;overflow-y:auto;background:#f1f4f9;border-right:1px solid var(--line);padding:12px 8px;font-size:13px}
#side ul{list-style:none;padding-left:10px;margin:2px 0}
#side a{color:var(--ink);text-decoration:none;display:block;border-radius:5px;padding:2px 6px}
#side a:hover,#side a.on{background:#dfe7f3}
main{margin-left:270px;max-width:1150px;padding:18px 30px 90px}
h1{font-size:23px}h2{font-size:20px;margin-top:36px;padding-top:10px;border-top:3px solid #9fb3d1}h3{font-size:17px;margin-top:26px;color:#1f3864}
table{border-collapse:collapse;margin:8px 0;font-size:14px}th,td{border:1px solid var(--line);padding:4px 8px;vertical-align:top}th{background:#e9eef6}
code{font-family:Consolas,monospace;background:#eef1f6;border-radius:4px;padding:1px 4px}
pre{background:#1e2430;color:#e6edf3;border-radius:6px;padding:10px 12px;overflow-x:auto}pre code{background:none;color:inherit;user-select:all}
blockquote{margin:8px 0;padding:6px 14px;background:#fff7e0;border-left:5px solid #e8b64a}
@media (max-width:900px){#side{position:static;width:auto;height:auto}main{margin-left:0;padding:14px}}
'''
js = '''<script>(function(){var L=[].slice.call(document.querySelectorAll('#side a')).map(function(a){return{a:a,el:document.getElementById(decodeURIComponent(a.getAttribute('href').slice(1)))}}).filter(function(x){return x.el});
function s(){var y=window.scrollY+90,c=null;L.forEach(function(l){if(l.el.getBoundingClientRect().top+window.scrollY<=y)c=l});L.forEach(function(l){l.a.classList.toggle('on',l===c)})}
window.addEventListener('scroll',s,{passive:true});s()})();</script>'''
html = f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>sender 캡처 순서</title><style>{css}</style></head><body><aside id="side"><b>목차</b>{toc}</aside><main>{body}</main>{js}</body></html>'
open(os.path.join(HERE, '캡처_순서.html'), 'w', encoding='utf-8').write(html)
print('ok', len(html))
