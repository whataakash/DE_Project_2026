"""Render a dependency-free SVG from the CP1 schema. Run from the repo root."""
from pathlib import Path
import re
from html import escape
schema = Path('sql/01_schema.sql').read_text()
entities = {}
for name, body in re.findall(r'CREATE TABLE (\w+) \((.*?)\n\);', schema, re.S):
    fields=[]
    composite=re.search(r'PRIMARY KEY \(([^)]+)\)',body)
    keys=composite.group(1).split(', ') if composite else []
    for line in body.splitlines():
        m=re.match(r'    (\w+) (bigint|integer|smallint|varchar\(\d+\)|text|date|timestamptz|boolean)(.*)',line)
        if not m: continue
        col,typ,rest=m.groups()
        flags=[]
        if 'PRIMARY KEY' in rest or col in keys: flags.append('PK')
        if 'REFERENCES' in rest: flags.append('FK')
        if 'UNIQUE' in rest: flags.append('UQ')
        fields.append((' '.join(flags)+' ' if flags else '')+col+' : '+typ)
    entities[name]=fields
positions={'languages':(35,100),'courses':(435,100),'units':(835,100),'lessons':(1235,100),
 'learners':(35,450),'enrollments':(435,450),'lesson_attempts':(1235,450),
 'daily_activity':(35,1010),'league_memberships':(435,1010),
 'achievements':(835,1010),'learner_achievements':(1235,1010)}
w=330
heights={name:54+len(fields)*23 for name,fields in entities.items()}
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1600" viewBox="0 0 1600 1600">',
 '<rect width="1600" height="1600" fill="#f5f8fc"/>',
 '<style>text{font-family:Menlo,monospace;fill:#183046} .field{font-size:13px} .edge{fill:none;stroke:#4f7191;stroke-width:2} .label{font-size:11px;paint-order:stroke;stroke:#f5f8fc;stroke-width:5;stroke-linejoin:round}</style>',
 '<text x="35" y="35" font-size="25" font-weight="bold">Duolingo • CP1 entity relationship diagram</text>',
 '<text x="35" y="65" font-size="11">1 / 0..N = cardinality · FK labels are on the child · optional referral is 0..1 parent; languages → courses has two roles: from_lang and learning_lang</text>']
def edge(points,label,x,y):
 parts.append('<polyline class="edge" points="'+points+'"/>')
 parts.append(f'<text class="label" x="{x}" y="{y}">{escape(label)}</text>')
edge('365,170 435,170','1:0..N',365,153)
edge('765,170 835,170','1 : 0..N',765,205)
edge('1165,170 1235,170','1 : 0..N',1165,153)
edge('600,269 600,450','1 : 0..N',610,380)
edge('365,510 435,510','1 : 0..N',365,495)
edge('1400,269 1400,450','1 : 0..N',1410,380)
edge('365,660 910,660 910,510 1235,510','1 : 0..N — attempts',700,645)
edge('110,688 110,1010','1 : 0..N',120,860)
edge('260,688 260,930 600,930 600,1010','1 : 0..N',410,915)
edge('365,675 800,675 800,950 1400,950 1400,1010','1 : 0..N — badges',960,935)
edge('1165,1080 1235,1080','1 : 0..N',1165,1063)
edge('35,540 15,540 15,745 65,745 65,688','0..1 : 0..N referral',40,770)
for name,fields in entities.items():
 x,y=positions[name];h=heights[name]
 parts.extend([f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="white" stroke="#96adbf"/>',f'<path d="M{x+8},{y} H{x+w-8} Q{x+w},{y} {x+w},{y+8} V{y+38} H{x} V{y+8} Q{x},{y} {x+8},{y}" fill="#183f5a"/>',f'<text x="{x+12}" y="{y+25}" style="fill:white" font-size="17" font-weight="bold">{name}</text>'])
 for j,field in enumerate(fields): parts.append(f'<text class="field" x="{x+12}" y="{y+59+j*23}">{escape(field)}</text>')
parts.append('<text x="35" y="1340" font-size="14">M:N bridges: enrollments (learners ↔ courses); learner_achievements (learners ↔ achievements).</text></svg>')
Path('diagrams/er_diagram.svg').write_text('\n'.join(parts))
