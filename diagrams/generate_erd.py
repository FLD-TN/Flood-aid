import uuid

def row(id_val, parent, name, typ, is_pk=False, is_fk=False):
    style_row = 'shape=tableRow;horizontal=0;startSize=0;swimlaneHead=0;swimlaneBody=0;fillColor=none;collapsible=0;dropTarget=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;fontSize=12;'
    font_b = 'fontStyle=1;' if is_pk else ''
    
    prefix = ''
    if is_pk: prefix = 'PK '
    if is_fk: prefix = 'FK '
    
    res = []
    res.append(f'<mxCell id="{id_val}" value="" style="{style_row}{font_b}" vertex="1" parent="{parent}"><mxGeometry y="0" width="280" height="30" as="geometry" /></mxCell>')
    res.append(f'<mxCell id="{id_val}_name" value="{prefix}{name}" style="shape=partialRectangle;html=1;whiteSpace=wrap;connectable=0;fillColor=none;top=0;left=0;bottom=0;right=0;overflow=hidden;align=left;spacingLeft=6;{font_b}" vertex="1" parent="{id_val}"><mxGeometry width="170" height="30" as="geometry"><mxRectangle width="170" height="30" as="alternateBounds"/></mxGeometry></mxCell>')
    res.append(f'<mxCell id="{id_val}_type" value="{typ}" style="shape=partialRectangle;html=1;whiteSpace=wrap;connectable=0;fillColor=none;top=0;left=0;bottom=0;right=0;overflow=hidden;align=left;spacingLeft=6;{font_b}" vertex="1" parent="{id_val}"><mxGeometry x="170" width="110" height="30" as="geometry"><mxRectangle width="110" height="30" as="alternateBounds"/></mxGeometry></mxCell>')
    return '\n'.join(res)

def table(id_val, name, x, y, cols):
    style_table = 'shape=table;startSize=30;container=1;collapsible=1;childLayout=tableLayout;fixedRows=1;rowLines=0;fontStyle=1;strokeColor=#6c8ebf;fillColor=#dae8fc;'
    h = 30 + 30 * len(cols)
    res = [f'<mxCell id="{id_val}" value="{name}" style="{style_table}" vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="280" height="{h}" as="geometry"/></mxCell>']
    for i, c in enumerate(cols):
        r_id = f"{id_val}_r{i}"
        res.append(row(r_id, id_val, c['name'], c['type'], c.get('is_pk'), c.get('is_fk')))
    return '\n'.join(res)

tables = [
    {
        'id': 't_victims', 'name': 'victims', 'x': 50, 'y': 50,
        'cols': [
            {'name': 'id', 'type': 'UUID', 'is_pk': True},
            {'name': 'phone_hash', 'type': 'VARCHAR(64)', 'is_fk': False},
            {'name': 'firebase_uid', 'type': 'VARCHAR(128)'},
            {'name': 'created_at', 'type': 'TIMESTAMPTZ'}
        ]
    },
    {
        'id': 't_cases', 'name': 'cases', 'x': 350, 'y': 50,
        'cols': [
            {'name': 'id', 'type': 'UUID', 'is_pk': True},
            {'name': 'phone_hash', 'type': 'VARCHAR(64)', 'is_fk': True},
            {'name': 'coords', 'type': 'GEOMETRY'},
            {'name': 'text_raw', 'type': 'TEXT'},
            {'name': 'urgency_level', 'type': 'SMALLINT'},
            {'name': 'tags', 'type': 'JSONB'},
            {'name': 'summary_1line', 'type': 'TEXT'},
            {'name': 'status', 'type': 'case_status'},
            {'name': 'tnv_distance_m', 'type': 'INT'},
            {'name': 'ai_source', 'type': 'VARCHAR(20)'},
            {'name': 'created_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'resolved_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'updated_at', 'type': 'TIMESTAMPTZ'}
        ]
    },
    {
        'id': 't_case_assignments', 'name': 'case_assignments', 'x': 650, 'y': 50,
        'cols': [
            {'name': 'id', 'type': 'UUID', 'is_pk': True},
            {'name': 'case_id', 'type': 'UUID', 'is_fk': True},
            {'name': 'volunteer_id', 'type': 'UUID', 'is_fk': True},
            {'name': 'initial_distance_m', 'type': 'INT'},
            {'name': 'assigned_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'warned_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'confirmed_en_route', 'type': 'BOOLEAN'},
            {'name': 'arrived_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'completed_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'revoked_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'notif_sent_300m', 'type': 'BOOLEAN'},
            {'name': 'notif_sent_100m', 'type': 'BOOLEAN'}
        ]
    },
    {
        'id': 't_volunteers', 'name': 'volunteers', 'x': 950, 'y': 50,
        'cols': [
            {'name': 'id', 'type': 'UUID', 'is_pk': True},
            {'name': 'phone_hash', 'type': 'VARCHAR(64)', 'is_fk': False},
            {'name': 'firebase_uid', 'type': 'VARCHAR(128)'},
            {'name': 'full_name', 'type': 'VARCHAR(255)'},
            {'name': 'cccd_verified', 'type': 'BOOLEAN'},
            {'name': 'admin_approved', 'type': 'BOOLEAN'},
            {'name': 'skills', 'type': 'JSONB'},
            {'name': 'current_coords', 'type': 'GEOMETRY'},
            {'name': 'last_seen_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'is_available', 'type': 'BOOLEAN'},
            {'name': 'fcm_token', 'type': 'TEXT'},
            {'name': 'flag_count', 'type': 'INT'},
            {'name': 'created_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'phone_encrypted', 'type': 'TEXT'},
            {'name': 'updated_at', 'type': 'TIMESTAMPTZ'},
            {'name': 'notification_radius_km', 'type': 'INT'},
            {'name': 'cccd_number_encrypted', 'type': 'TEXT'}
        ]
    },
    {
        'id': 't_admins', 'name': 'admins', 'x': 50, 'y': 300,
        'cols': [
            {'name': 'id', 'type': 'UUID', 'is_pk': True},
            {'name': 'email', 'type': 'VARCHAR(255)'},
            {'name': 'firebase_uid', 'type': 'VARCHAR(128)'},
            {'name': 'full_name', 'type': 'VARCHAR(255)'},
            {'name': 'created_at', 'type': 'TIMESTAMPTZ'}
        ]
    }
]

edges = [
    # victims to cases (1:N)
    {'id': 'e1', 'src': 't_victims', 'tgt': 't_cases', 'style': 'edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;dashed=1;endArrow=ERmandMany;startArrow=ERmandOne;exitX=1;exitY=0.5;entryX=0;entryY=0.5;'},
    # cases to case_assignments (1:N)
    {'id': 'e2', 'src': 't_cases', 'tgt': 't_case_assignments', 'style': 'edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;dashed=1;endArrow=ERmandMany;startArrow=ERmandOne;exitX=1;exitY=0.5;entryX=0;entryY=0.5;'},
    # volunteers to case_assignments (1:N)
    {'id': 'e3', 'src': 't_volunteers', 'tgt': 't_case_assignments', 'style': 'edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;dashed=1;endArrow=ERmandMany;startArrow=ERmandOne;exitX=0;exitY=0.5;entryX=1;entryY=0.5;'}
]

xml = ['<?xml version="1.0" encoding="UTF-8"?>', '<mxfile host="drawio" version="26.0.0">', '<diagram name="Page-1">', '<mxGraphModel>', '<root>', '<mxCell id="0" />', '<mxCell id="1" parent="0" />']
for t in tables:
    xml.append(table(t['id'], t['name'], t['x'], t['y'], t['cols']))

for e in edges:
    xml.append(f'<mxCell id="{e["id"]}" style="{e["style"]}" edge="1" parent="1" source="{e["src"]}" target="{e["tgt"]}"><mxGeometry relative="1" as="geometry"/></mxCell>')

xml.extend(['</root>', '</mxGraphModel>', '</diagram>', '</mxfile>'])

with open('database_erd.drawio', 'w', encoding='utf-8') as f:
    f.write('\n'.join(xml))
print("Generated database_erd.drawio successfully.")
