#!/bin/bash
# Sync dashboard.html to GitHub Pages with PIN gate
SRC=~/Documents/dashboard.html
DEST=~/Documents/command-center/index.html
PIN='1709'

# Read dashboard content
DASH=$(cat "$SRC")

# Extract everything between <body> and </body>
BODY=$(echo "$DASH" | sed -n '/<body>/,/<\/body>/p' | sed '1s/.*<body>//' | sed '$s/<\/body>.*//')

# Extract <head> content
HEAD=$(echo "$DASH" | sed -n '/<head>/,/<\/head>/p')

# Build index.html with PIN gate
python3 - "$SRC" "$DEST" "$PIN" << 'PYEOF'
import sys

src_path = sys.argv[1]
dest_path = sys.argv[2]
pin = sys.argv[3]

with open(src_path, 'r') as f:
    dashboard = f.read()

# Split at <body> to insert PIN gate
parts = dashboard.split('<body>', 1)
if len(parts) != 2:
    print('ERROR: Could not find <body> tag')
    sys.exit(1)

before_body = parts[0]
after_body_parts = parts[1].rsplit('</body>', 1)
body_content = after_body_parts[0]
after_body = after_body_parts[1] if len(after_body_parts) > 1 else ''

pin_gate_css = '''
<style>
#pin-gate {
  position:fixed;top:0;left:0;width:100%;height:100%;background:var(--bg);z-index:9999;
  display:flex;flex-direction:column;align-items:center;justify-content:center;
}
.pin-title{font-size:20px;font-weight:700;color:var(--text);margin-bottom:8px;}
.pin-sub{font-size:13px;color:var(--text-dim);margin-bottom:24px;}
.pin-digits{display:flex;gap:12px;}
.pin-digit{
  width:48px;height:56px;border-radius:10px;border:2px solid var(--border);
  background:var(--card);color:var(--text);font-size:24px;font-weight:700;
  text-align:center;outline:none;-webkit-text-security:disc;
}
.pin-digit:focus{border-color:var(--accent);}
#pin-error{color:var(--red);font-size:12px;margin-top:12px;height:16px;}
@keyframes shake{0%,100%{transform:translateX(0)}25%{transform:translateX(-6px)}75%{transform:translateX(6px)}}
.shake{animation:shake 0.3s ease;}
</style>
'''

pin_gate_html = '''
<div id="pin-gate">
  <div class="pin-title">Command Center</div>
  <div class="pin-sub">Enter PIN to continue</div>
  <div class="pin-digits">
    <input class="pin-digit" type="tel" maxlength="1" inputmode="numeric" autofocus>
    <input class="pin-digit" type="tel" maxlength="1" inputmode="numeric">
    <input class="pin-digit" type="tel" maxlength="1" inputmode="numeric">
    <input class="pin-digit" type="tel" maxlength="1" inputmode="numeric">
  </div>
  <div id="pin-error"></div>
</div>
<div id="dashboard-content" style="display:none">
'''

pin_gate_close = '</div>'

pin_gate_js = f'''
<script>(function(){{
var CORRECT_PIN=\'{pin}\';
if(sessionStorage.getItem(\'cc_authed\')===\'true\'){{document.getElementById(\'pin-gate\').style.display=\'none\';document.getElementById(\'dashboard-content\').style.display=\'\';return;}}
var digits=document.querySelectorAll(\'.pin-digit\');
var errorEl=document.getElementById(\'pin-error\');
digits.forEach(function(input,i){{
  input.addEventListener(\'input\',function(e){{
    var val=e.target.value.replace(/[^0-9]/g,\'\');e.target.value=val;
    if(val&&i<digits.length-1){{digits[i+1].focus();}}
    var pin=Array.from(digits).map(function(d){{return d.value;}}).join(\'\');
    if(pin.length===4){{
      if(pin===CORRECT_PIN){{sessionStorage.setItem(\'cc_authed\',\'true\');document.getElementById(\'pin-gate\').style.display=\'none\';document.getElementById(\'dashboard-content\').style.display=\'\';}}
      else{{errorEl.textContent=\'Incorrect PIN\';digits.forEach(function(d){{d.value=\'\';d.classList.add(\'shake\');}});digits[0].focus();setTimeout(function(){{digits.forEach(function(d){{d.classList.remove(\'shake\');}});}},400);setTimeout(function(){{errorEl.textContent=\'\';}},2000);}}
    }}
  }});
  input.addEventListener(\'keydown\',function(e){{
    if(e.key===\'Backspace\'&&!e.target.value&&i>0){{digits[i-1].focus();}}
  }});
}});
}})();</script>
'''

result = before_body + '<body>\n' + pin_gate_css + pin_gate_html + body_content + pin_gate_close + pin_gate_js + '\n</body>' + after_body

with open(dest_path, 'w') as f:
    f.write(result)

print('OK')
PYEOF
