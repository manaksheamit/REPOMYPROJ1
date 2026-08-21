import { LightningElement, track, api } from 'lwc';
import executeCallout from '@salesforce/apex/AEHC_GraphQLCallout.executeCallout';
import encrypt from '@salesforce/apex/AEHC_GraphQLCallout.encrypt';
import getSelectedFields from '@salesforce/apex/AEHC_GraphQLCallout.getSelectedFields';
import createVersionUpdateGraph from '@salesforce/apex/AEHC_GraphQLCallout.createVersionUpdateGraph';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class Aehcgraphqlapischemabrowser extends LightningElement {

    @track treeData = [];
    @track selectedMap = {};
    @track selectedList = [];
    @api preSelectedFields = [];
    @api recordId;
    @api selectedFieldsRaw = [];
    @api formattedSelection = '';
    @api actualSelection = '';
    @api apiName;
    @api encryptedText;

    typeMap = new Map();

    // =========================
    // INIT
    // =========================

    connectedCallback() {
        Promise.all([
            this.loadSchema(),
            this.loadSavedSelection()
        ]);
    }


    loadSchema() {
        return executeCallout({ endpointSuffix: this.apiName })
            .then(res => {
                const data = JSON.parse(res);
                this.buildTree(data);

                // ✅ Apply preselection AFTER tree is ready
                this.applyPreselection();
            })
            .catch(err => {
                console.error('Schema load error', err);
            });
    }

    
    loadSavedSelection() {
        if (!this.recordId) return Promise.resolve();

        return getSelectedFields({ recordId: this.recordId })
            .then(result => {
                if (result && result.length > 0) {
                    this.preSelectedFields = result;
                }
            })
            .catch(err => {
                console.error('Error loading saved fields', err);
            });
    }

    applyPreselection() {
        if (!this.preSelectedFields || this.preSelectedFields.length === 0) {
            return;
        }

        // ✅ mark selections in map
        this.preSelectedFields.forEach(field => {
            this.selectedMap[field] = true;

            // ✅ ensure parent is expanded
            const parts = field.split('.');
            if (parts.length > 1) {
                const parent = this.findNode(this.treeData, parts[0]);
                if (parent) {
                    parent.expanded = true;
                }
            }
        });

        // ✅ refresh UI
        this.refresh();
    }

    // =========================
    // BUILD TREE
    // =========================
    buildTree(schema) {
        const types = schema.data.__schema.types;

        this.typeMap = new Map();

        types.forEach(t => {
            if (
                t.kind === 'OBJECT' &&
                !t.name.startsWith('__') &&
                t.name !== 'Query'
            ) {
                this.typeMap.set(t.name, t);
            }
        });

        const queryType = types.find(t => t.name === 'Query');

        if (!queryType || !queryType.fields) return;

        this.treeData = queryType.fields
            .map(field => {
                const actual = this.getActualType(field.type);

                if (actual.kind !== 'OBJECT') return null;

                const objectType = this.typeMap.get(actual.name);

                return {
                    label: field.name,
                    name: field.name,
                    type: actual.name,
                    expanded: false,
                    checked: false,
                    children: objectType
                        ? this.getFields(objectType, field.name)
                        : []
                };
            })
            .filter(Boolean);
    }

    // =========================
    // BUILD FIELDS
    // =========================
    getFields(objectType, parentName) {
        if (!objectType.fields) return [];

        return objectType.fields.map(f => {
            const actual = this.getActualType(f.type);

            return {
                label: f.name,
                name: `${parentName}.${f.name}`,
                type: actual.name || actual.kind,
                checked: false
            };
        });
    }

    // =========================
    // RESOLVE TYPE
    // =========================
    getActualType(type) {
        let t = type;
        while (t.ofType) {
            t = t.ofType;
        }
        return t;
    }

    // =========================
    // CHECKBOX HANDLING
    // =========================
    handleCheck(event) {
        const name = event.target.dataset.name;
        const checked = event.target.checked;

        if (checked) {
            this.selectNode(name);
        } else {
            this.deselectNode(name);
        }

        this.refresh();
    }

    selectNode(name) {
        this.selectedMap[name] = true;

        const node = this.findNode(this.treeData, name);

        if (node?.children) {
            node.children.forEach(child => this.selectNode(child.name));
        }
    }

    deselectNode(name) {
        delete this.selectedMap[name];

        const node = this.findNode(this.treeData, name);

        if (node?.children) {
            node.children.forEach(child => this.deselectNode(child.name));
        }
    }

    // ✅ Remove from RIGHT panel
    handleRemove(event) {
        const name = event.currentTarget.dataset.name;
        this.deselectNode(name);
        this.refresh();
    }

    // =========================
    // ✅ FINAL FIXED REFRESH
    // =========================
    refresh() {

        // ✅ sync checkboxes
        this.updateCheckedState(this.treeData);

        // ✅ reset
        this.selectedList = [];
        this.selectedFieldsRaw = [];
        this.encryptedText = '';
        // ✅ IMPORTANT: derive from selectedMap (correct source)
        this.collectSelectedFields(this.treeData);

        // ✅ sort
        this.selectedFieldsRaw.sort();

        // ✅ build formatted output
        this.formattedSelection = this.buildFormatted();
        if (this.formattedSelection) {
            this.encryptData();
            this.actualSelection = String(this.selectedFieldsRaw);
        }
    }

    // ✅ FINAL FIX FUNCTION
    collectSelectedFields(nodes) {
        nodes.forEach(node => {

            // ✅ check using selectedMap (NOT node.checked)
            if (
                this.selectedMap[node.name] &&
                (!node.children || node.children.length === 0)
            ) {
                this.selectedList.push({
                    name: node.name,
                    type: node.type
                });

                this.selectedFieldsRaw.push(node.name);
            }

            if (node.children) {
                this.collectSelectedFields(node.children);
            }
        });
    }

    // =========================
    // UPDATE CHECKBOX STATE
    // =========================
    updateCheckedState(nodes) {
        nodes.forEach(node => {
            node.checked = !!this.selectedMap[node.name];

            if (node.children) {
                this.updateCheckedState(node.children);
            }
        });

        this.treeData = [...this.treeData];
    }

    // =========================
    // FIND NODE
    // =========================
    findNode(nodes, name) {
        for (let node of nodes) {
            if (node.name === name) return node;

            if (node.children) {
                const found = this.findNode(node.children, name);
                if (found) return found;
            }
        }
        return null;
    }

    // =========================
    // FORMAT OUTPUT
    // =========================
    buildFormatted() {
        let map = {};

        this.selectedFieldsRaw.forEach(value => {
            const parts = value.split('.');
            if (parts.length !== 2) return;

            const parent = parts[0].toUpperCase();
            const field = parts[1].toUpperCase();

            if (!map[parent]) {
                map[parent] = [];
            }

            map[parent].push(field);
        });

        return Object.keys(map)
            .sort()
            .map(obj => `${obj}{${map[obj].sort().join(',')}}`)
            .join(',');
    }

    // =========================
    // ACTIONS
    // =========================
    clearAll() {
        this.selectedMap = {};
        this.refresh();
    }

    expandAll() {
        this.setExpand(this.treeData, true);
    }

    collapseAll() {
        this.setExpand(this.treeData, false);
    }

    setExpand(nodes, value) {
        nodes.forEach(node => {
            node.expanded = value;
        });

        this.treeData = [...this.treeData];
    }

    toggleExpand(event) {
        const name = event.currentTarget.dataset.name;
        const node = this.findNode(this.treeData, name);

        if (node) {
            node.expanded = !node.expanded;
            this.treeData = [...this.treeData];
        }
    }
    encryptData() {
            encrypt({ plainText: this.formattedSelection })
                .then(result => {
                    this.encryptedText = result;
                })
                .catch(error => {
                    console.error(error);
                });
        }

    handleUpdate() {

        createVersionUpdateGraph({
            subId: this.recordId,
            graphQLFields: this.actualSelection,
            graphSignedToken: this.encryptedText,
            graphFormated: this.formattedSelection
        })
        .then(result => {

            // ✅ SUCCESS TOAST
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Schema fields updated successfully',
                    variant: 'success'
                })
            );

            console.log('New Asset Id:', result);

            // ✅ Close modal
            this.isModalOpen = false;
            
            setTimeout(() => {
                window.location.reload();
            }, 1500);

        })
        .catch(error => {

            let errorMessage = 'Unknown error occurred';

            if (error?.body?.message) {
                errorMessage = error.body.message;
            } else if (error?.message) {
                errorMessage = error.message;
            }

            // ✅ ERROR TOAST
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: errorMessage,
                    variant: 'error'
                })
            );

            console.error('Error:', error);
        });
    }
}