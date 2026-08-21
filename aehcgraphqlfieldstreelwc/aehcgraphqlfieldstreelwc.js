import { LightningElement, track, api,wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getGqlschemaTreeFormat from "@salesforce/apex/AEHC_UpdateGqlFieldonRequest.getGqlschemaTreeFormat";
//import getvaluesfromSchema from "@salesforce/apex/AEHC_UpdateGqlFieldonRequest.getvaluesfromSchema";
import encrypt from '@salesforce/apex/AEHC_UpdateGqlFieldonRequest.encrypt';

// ---- helpers
function unwrapType(t) {
    if (!t) return { name: null, kind: null };
    let cur = t;
    // If ofType is missing (seen in your sample), we best-effort fallback.
    while (cur && !cur.name && cur.ofType) cur = cur.ofType;
    return { name: cur?.name || null, kind: cur?.kind || t.kind || null, ofType: cur?.ofType || t.ofType || null };
}

function deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
}



export default class Aehcgraphqlfieldstreelwc extends NavigationMixin(LightningElement) {
    @api recordId;
    @api selectedFieldsJson;
    @api selectedFieldsActual;
    @api serverResponse;
    @track isLoading = true;
    //Output back to Flow
    @api encryptedText;

// Tree data
    @track rootNodes = [];
    typeMap = new Map();           // OBJECT types excluding __* and Query
    queryReturnMap = new Map();    // returnTypeName -> [{ name, args:[{name,typeSig}] }]

    // Selection (field paths only: Type.field.subfield)
    selectedSet = new Set();

    // UI
    @track searchText = '';

    // Wire Apex for schema
    @wire(getGqlschemaTreeFormat)
    wiredSchema({ data, error }) {
        if (data) {
            try {
                const raw = typeof data === 'string' ? JSON.parse(data) : data;
                const schema = raw?.data?.__schema || raw?.__schema || raw;
                this.ingestSchema(schema);
                this.expandAll();
                this.collapseAll();
            } catch (e) {
                // eslint-disable-next-line no-console
                console.error('Schema parse error', e);
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Apex error', error);
        }
    }

  connectedCallback() {
    this.isLoading = false;
  }

// ---------- SCHEMA INGEST ----------
ingestSchema(schema) {
    if (!schema || !Array.isArray(schema.types)) return;

    // Build OBJECT type map (exclude __* and Query)
    this.typeMap.clear();
    for (const t of schema.types) {
        if (!t || t.kind !== 'OBJECT') continue;
        if (!t.name || t.name === 'Query' || t.name.startsWith('__')) continue;
        this.typeMap.set(t.name, t);
    }

    // Build returnType -> queryFields map from Query type
    this.queryReturnMap.clear();
    const queryType = schema.types.find(t => t?.name === 'Query' && t.kind === 'OBJECT');
    if (queryType && Array.isArray(queryType.fields)) {
        for (const f of queryType.fields) {
            if (!f?.name) continue;
            const ret = unwrapType(f.type);
            if (!ret.name) continue; // must resolve to a named type
            const args = (f.args || []).map(a => ({
                name: a.name,
                typeSig: this.typeSignature(a.type)
            }));
            const entry = { name: f.name, args };
            if (!this.queryReturnMap.has(ret.name)) this.queryReturnMap.set(ret.name, []);
            this.queryReturnMap.get(ret.name).push(entry);
        }
    }

    // NEW: find all OBJECT types that are referenced as a field type by another OBJECT
    const referencedTypeSet = new Set();
    for (const [typeName, typeObj] of this.typeMap.entries()) {
        const fields = Array.isArray(typeObj.fields) ? typeObj.fields : [];
        for (const f of fields) {
            if (!f || !f.type) continue;
            const unwrapped = unwrapType(f.type);
            if (unwrapped.kind === 'OBJECT' && unwrapped.name && this.typeMap.has(unwrapped.name)) {
                referencedTypeSet.add(unwrapped.name);
            }
        }
    }

    // Root nodes: all object types EXCEPT those that are referenced by other types
    const rootNames = Array.from(this.typeMap.keys())
        .filter(name => !referencedTypeSet.has(name))
        .sort();

    this.rootNodes = rootNames.map(name => this.createTypeNode(name));
}

    // ---------- SCHEMA INGEST ----------
    /* ingestSchema(schema) {
        if (!schema || !Array.isArray(schema.types)) return;

        // Build OBJECT type map (exclude __* and Query)
        this.typeMap.clear();
        for (const t of schema.types) {
            if (!t || t.kind !== 'OBJECT') continue;
            if (!t.name || t.name === 'Query' || t.name.startsWith('__')) continue;
            this.typeMap.set(t.name, t);
        }

        // Build returnType -> queryFields map from Query type
        this.queryReturnMap.clear();
        const queryType = schema.types.find(t => t?.name === 'Query' && t.kind === 'OBJECT');
        if (queryType && Array.isArray(queryType.fields)) {
            for (const f of queryType.fields) {
                if (!f?.name) continue;
                const ret = unwrapType(f.type);
                if (!ret.name) continue; // must resolve to a named type
                const args = (f.args || []).map(a => ({
                    name: a.name,
                    typeSig: this.typeSignature(a.type) // build readable signature for variables
                }));
                const entry = { name: f.name, args };
                if (!this.queryReturnMap.has(ret.name)) this.queryReturnMap.set(ret.name, []);
                this.queryReturnMap.get(ret.name).push(entry);
            }
        }

        // Root nodes = all object types by default
        this.rootNodes = Array.from(this.typeMap.keys())
            .sort()
            .map(name => this.createTypeNode(name));
    }*/

    // Build human-friendly type signature from introspection
    typeSignature(t) {
        if (!t) return 'String';
        // Handle missing ofType gracefully
        if (t.kind === 'NON_NULL') {
            const inner = t.ofType ? this.typeSignature(t.ofType) : (t.name || 'String');
            return `${inner}!`;
        }
        if (t.kind === 'LIST') {
            const inner = t.ofType ? this.typeSignature(t.ofType) : (t.name || 'String');
            return `[${inner}]`;
        }
        return t.name || 'String';
    }

    createTypeNode(typeName) {
        return {
            id: typeName,
            label: typeName,
            kind: 'TYPE',
            targetTypeName: typeName,
            expanded: false,
            caretClass: 'caret',
            hasChildren: true,
            children: [],
            selected: false,
            indeterminate: false
        };
    }

    populateChildren(node) {
        const targetTypeName = node.kind === 'TYPE' ? node.targetTypeName : node.fieldTypeName;
        if (!targetTypeName) return;

        const typeObj = this.typeMap.get(targetTypeName);
        if (!typeObj || !Array.isArray(typeObj.fields)) return;

        const kids = [];
        for (const f of typeObj.fields) {
            if (!f || !f.name || f.name.startsWith('__')) continue;

            const unwrapped = unwrapType(f.type);
            const isObject = unwrapped.kind === 'OBJECT' && !!unwrapped.name && this.typeMap.has(unwrapped.name);

            kids.push({
                id: `${node.id}.${f.name}`,
                label: f.name,
                kind: 'FIELD',
                tooltip: isObject ? `Object → ${unwrapped.name}` : (unwrapped.name || unwrapped.kind || ''),
                typeInfo: unwrapped.name || unwrapped.kind || '',
                hasChildren: isObject,
                fieldTypeName: isObject ? unwrapped.name : null,
                expanded: false,
                caretClass: isObject ? 'caret' : 'no-caret',
                children: [],
                selected: false,
                indeterminate: false
            });
        }

        node.children = kids;

        // Cascade selection if parent was selected
        if (node.selected) {
            for (const c of node.children) {
                this.setNodeSelection(c, true);
            }
        }
    }

    // ---------- FILTERS / GETTERS ----------
    get filteredRootNodes() {
        const q = (this.searchText || '').trim().toLowerCase();
        if (!q) return this.rootNodes;
        return this.rootNodes.filter(n => n.label.toLowerCase().includes(q));
    }

    get visibleRootCount() {
        return this.filteredRootNodes.length;
    }

    get selectedArray() {
        return Array.from(this.selectedSet).sort();
    }

    get selectedCount() {
        return this.selectedSet.size
    }

    handleSearchChange(e) {
        this.searchText = e.target.value || '';
    }

    // ---------- TREE UI ----------
    toggleNode(e) {
        const id = e.currentTarget.dataset.nodeId;
        const { node, parentList } = this.findNodeWithParentList(id);
        if (!node) return;

        node.expanded = !node.expanded;
        node.caretClass = node.expanded ? 'caret caret-down' : 'caret';

        if (node.expanded && node.hasChildren && (!node.children || node.children.length === 0)) {
            this.populateChildren(node);
        }

        this.refresh(parentList);
    }

    handleNodeCheck(e) {
        const id = e.currentTarget.dataset.nodeId;
        const checked = e.target.checked;
        const { node, parentList } = this.findNodeWithParentList(id);
        if (!node) return;

        this.setNodeSelection(node, checked);
        this.updateAncestors(id);

        this.refresh(parentList);
        this.fireQueryChange(); // notify parent flows if needed
    }

    removeSelected(e) {
        const path = e.currentTarget.dataset.path;
        const { node, parentList } = this.findNodeWithParentList(path);
        if (node) {
            this.setNodeSelection(node, false);
            this.updateAncestors(node.id);
            this.refresh(parentList);
        } else {
            this.selectedSet.delete(path);
            this.refresh(this.rootNodes);
        }
        this.fireQueryChange();
    }

    setNodeSelection(node, isSelected) {
        node.selected = isSelected;
        node.indeterminate = false;

        if (node.kind === 'FIELD') {
            if (isSelected) this.selectedSet.add(node.id);
            else this.selectedSet.delete(node.id);
        }

        if (node.hasChildren && node.children && node.children.length > 0) {
            for (const c of node.children) {
                this.setNodeSelection(c, isSelected);
            }
        }
    }

    updateAncestors(nodeId) {
        const parts = nodeId.split('.');
        while (parts.length > 1) {
            parts.pop();
            const parentId = parts.join('.');
            const { node } = this.findNodeWithParentList(parentId);
            if (!node || !node.children || node.children.length === 0) continue;

            const allSelected = node.children.every(c => c.selected);
            const noneSelected = node.children.every(c => !c.selected && !c.indeterminate);

            node.selected = allSelected;
            node.indeterminate = !allSelected && !noneSelected;
        }
    }

    findNodeWithParentList(id) {
        const parents = this.rootNodes;
        for (const root of parents) {
            const found = this.dfsFind(root, id);
            if (found) return { node: found, parentList: parents };
        }
        return { node: null, parentList: parents };
    }

    dfsFind(node, id) {
        if (node.id === id) return node;
        if (node.children && node.children.length > 0) {
            for (const c of node.children) {
                const found = this.dfsFind(c, id);
                if (found) return found;
            }
        }
        return null;
    }

    refresh(parentList) {
        this.rootNodes = deepClone(parentList);
        this.selectedSet = new Set(this.selectedSet);
        Promise.resolve().then(() => this.applyIndeterminate());
        //this.selectedFieldsJson=String(this.combinedQueryText);
        this.selectedFieldsJson=String(this.flatSortedSelectionUpperText);
        this.selectedFieldsActual=String(this.selectedArray);
        if (this.selectedFieldsJson) {
            this.encryptData();
        }

    }

    renderedCallback() {
        this.applyIndeterminate();
        
    }

    applyIndeterminate() {
        const inputs = this.template.querySelectorAll('input[type="checkbox"][data-indeterminate]');
        inputs.forEach(inp => {
            const val = inp.getAttribute('data-indeterminate');
            inp.indeterminate = val === 'true';
        });
    }

    // ---------- HEADER ACTIONS ----------
    expandAll = () => {
        const expandRec = (node) => {
            if (node.hasChildren) {
                if (!node.children || node.children.length === 0) {
                    if (node.kind === 'TYPE' || (node.kind === 'FIELD' && node.fieldTypeName)) {
                        this.populateChildren(node);
                    }
                }
                node.expanded = true;
                node.caretClass = 'caret caret-down';
                node.children.forEach(expandRec);
            }
        };
        this.rootNodes.forEach(expandRec);
        this.refresh(this.rootNodes);
    };

    collapseAll = () => {
        const collapseRec = (node) => {
            node.expanded = false;
            node.caretClass = node.hasChildren ? 'caret' : node.caretClass;
            if (node.children) node.children.forEach(collapseRec);
        };
        this.rootNodes.forEach(collapseRec);
        this.refresh(this.rootNodes);
    };

    clearSelections = () => {
        const clearRec = (node) => {
            node.selected = false;
            node.indeterminate = false;
            if (node.kind === 'FIELD') this.selectedSet.delete(node.id);
            if (node.children) node.children.forEach(clearRec);
        };
        this.rootNodes.forEach(clearRec);
        this.refresh(this.rootNodes);
        this.fireQueryChange();
        this.serverResponse='';
        this.selectedFieldsJson = '';
        this.selectedFieldsActual = '';
        this.encryptedText = '';
    };

    async copySelected() {
        const text = this.selectedArray.join('\n');
        try { await navigator.clipboard.writeText(text); }
        catch (e) { window.prompt('Copy the selected paths:', text); }
    }

    // ---------- QUERY GENERATION ----------
    // Group selected paths by root type name
    get groupedSelections() {
        const map = new Map();
        for (const p of this.selectedSet) {
            const parts = p.split('.');
            const typeName = parts[0];
            (map.get(typeName) || map.set(typeName, []).get(typeName)).push(p);
        }
        return map;
    }

    // Build a nested selection tree from paths like "Type.a.b.c"
    buildSelectionTree(pathsForType) {
        const tree = {};
        for (const p of pathsForType) {
            const parts = p.split('.');
            parts.shift(); // drop type
            let cur = tree;
            for (const segment of parts) {
                if (!cur[segment]) cur[segment] = {};
                cur = cur[segment];
            }
        }
        return tree;
    }

    // Turn the selection tree into GraphQL selection set text
    selectionSetFromTree(tree, indent = 2) {
        const keys = Object.keys(tree).sort();
        if (keys.length === 0) {
            // Fallback to __typename to keep selection set valid
            return `${' '.repeat(indent)}__typename`;
        }
        const lines = [];
        for (const k of keys) {
            const child = tree[k];
            const childKeys = Object.keys(child || {});
            if (childKeys.length > 0) {
                lines.push(`${' '.repeat(indent)}${k} {`);
                lines.push(this.selectionSetFromTree(child, indent + 2));
                lines.push(`${' '.repeat(indent)}}`);
            } else {
                lines.push(`${' '.repeat(indent)}${k}`);
            }
        }
        return lines.join('\n');
    }

    // Choose a Query field that returns this type; prefer names that include the type name
    pickQueryForType(typeName) {
        const arr = this.queryReturnMap.get(typeName) || [];
        if (arr.length === 0) return null;
        const exact = arr.find(q => q.name.toLowerCase().includes(typeName.toLowerCase()));
        return exact || arr[0];
    }

    // Inline args: (arg: "")
    buildInlineArgs(argDefs) {
        if (!argDefs || !argDefs.length) return '';
        const parts = argDefs.map(a => `${a.name}: ""`);
        return `(${parts.join(', ')})`;
    }
    // Build one field block for a type: getXyz(arg:""){ ... }
    buildFieldBlockForType(typeName, pathsForType) {
        const qInfo = this.pickQueryForType(typeName);
        const opField = qInfo ? qInfo.name : `get${typeName}`;
        const inlineArgs = qInfo ? this.buildInlineArgs(qInfo.args) : '';
        const selectionTree = this.buildSelectionTree(pathsForType);
        const selection = this.selectionSetFromTree(selectionTree, 2);

        return `${opField}${inlineArgs} {\n${selection}\n}`;
    }

    // Build combined query from all selected types
    get combinedQueryText() {
        const grouped = this.groupedSelections;
        if (!grouped || grouped.size === 0) return '';

        const blocks = [];
        for (const [typeName, paths] of grouped.entries()) {
            if (!paths || paths.length === 0) continue;
            blocks.push(this.buildFieldBlockForType(typeName, paths));
        }
        if (blocks.length === 0) return '';

        // Wrap with top-level braces
        return `{\n${blocks.map(b => `  ${b}`).join('\n')}\n}`;
    }
    get flatSortedSelectionUpperText() {
        if (!this.selectedSet || this.selectedSet.size === 0) return '';

        const groupMap = new Map();

        for (const path of this.selectedSet) {
            const parts = path.split('.');

            if (parts.length < 2) continue;

            let objectName;
            let fieldName;

            if (parts.length === 2) {
                // Example: hr_segment.etl_mode
                objectName = parts[0];   // HR_SEGMENT
                fieldName = parts[1];   // ETL_MODE
            } else {
                // Example: hr_segment.address.latitude
                objectName = parts[1];  // ADDRESS
                fieldName = parts[parts.length - 1]; // last leaf
            }

            if (!groupMap.has(objectName)) {
                groupMap.set(objectName, new Set());
            }

            groupMap.get(objectName).add(fieldName);
        }

        // Sort objects
        const sortedObjects = Array.from(groupMap.keys())
            .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));

        const result = [];

        for (const obj of sortedObjects) {
            const sortedFields = Array.from(groupMap.get(obj))
                .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }))
                .map(f => f.toUpperCase());

            if (sortedFields.length > 0) {
                result.push(`${obj.toUpperCase()}{${sortedFields.join(',')}}`);
            }
        }

        return result.join(',');
    }
    
    encryptData() {
        encrypt({ plainText: this.selectedFieldsJson })
            .then(result => {
                this.encryptedText = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    // Build a field-only GraphQL snippet wrapped with top-level braces
    buildQueryForType(typeName, pathsForType) {
        const qInfo = this.pickQueryForType(typeName);
        const selectionTree = this.buildSelectionTree(pathsForType);
        const selection = this.selectionSetFromTree(selectionTree, 2);

        const opField = qInfo ? qInfo.name : `get${typeName}`;
        const inlineArgs = qInfo ? this.buildInlineArgs(qInfo.args) : '';

        // Top-level wrapped snippet
        const wrapped =
    `{${opField}${inlineArgs} {
    ${selection}
    }}`;

        // Variables template still available if you need it later
        const variables = {};
        if (qInfo) {
            for (const a of qInfo.args) variables[a.name] = "";
        }

        return { operationName: opField, queryText: wrapped, variables };
    }
    // Cards for UI
    get queryCards() {
        const res = [];
        const grouped = this.groupedSelections;
        for (const [typeName, paths] of grouped.entries()) {
            const built = this.buildQueryForType(typeName, paths);
            res.push({
                key: `${typeName}__${built.operationName}`,
                typeName,
                operationName: built.operationName,
                queryText: built.queryText,
                variablesText: JSON.stringify(built.variables, null, 2)
            });
        }
        // Keep deterministic order
        return res.sort((a, b) => a.typeName.localeCompare(b.typeName));
    }

    // Emit to parent if needed (you can listen to this)
    // Emit to parent if needed (combined only)
    fireQueryChange() {
        this.dispatchEvent(new CustomEvent('querychange', {
            detail: { combinedQuery: this.combinedQueryText }
        }));
    }

    // Copy combined query
    async copyCombinedQuery() {
        const text = this.combinedQueryText || '';
        if (!text) return;
        try { await navigator.clipboard.writeText(text); }
        catch (err) { window.prompt('Copy query:', text); }
    }
    // Copy helpers
    async copyOneQuery(e) {
        const key = e.currentTarget.dataset.key;
        const card = (this.queryCards || []).find(c => c.key === key);
        if (!card) return;
        try { await navigator.clipboard.writeText(card.queryText); }
        catch (err) { window.prompt('Copy query:', card.queryText); }
    }

    async copyOneVariables(e) {
        const key = e.currentTarget.dataset.key;
        const card = (this.queryCards || []).find(c => c.key === key);
        if (!card) return;
        try { await navigator.clipboard.writeText(card.variablesText); }
        catch (err) { window.prompt('Copy variables:', card.variablesText); }
    }

    async copyAllQueries() {
        const all = (this.queryCards || [])
            .map(c => `${c.queryText}\n\nVariables:\n${c.variablesText}`)
            .join('\n\n---\n\n');
        try { await navigator.clipboard.writeText(all); }
        catch (err) { window.prompt('Copy all queries:', all); }
    }
    
  /*async fetchValuesGQuery() {
    
    this.serverResponse = '';
    
    try {
      const result = await getvaluesfromSchema({ schemafields: String(this.combinedQueryText) });
      this.serverResponse = result;
      console.log('this.serverResponse: '+result);
      console.log('this.serverResponse: '+this.serverResponse);
    } catch (error) {

    } finally {

    }
  }*/

}