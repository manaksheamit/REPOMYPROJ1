import { LightningElement, api, track } from 'lwc';

export default class AehcPublicationFieldSelection extends LightningElement {

    @track fullSchema = [];
    @track displayedSchema = [];
    @track selectedSchema = [];
    draggedRowId;
dragOverRowId;

    _wizardData;

    searchKey = '';
    sortedBy = 'name';
    sortedDirection = 'asc';
    _submitHandler = null;

    availableColumns = [
    {
        label: 'Field Name',
        fieldName: 'name',
        sortable: true,
        initialWidth: 180
    },
    {
        label: 'Data Type',
        fieldName: 'dataType',
        sortable: true,
        initialWidth: 120
    },
    {
        label: 'PII',
        fieldName: 'piiLevel',
        sortable: true,
        initialWidth: 120
    },
    {
        label: 'CCI',
        fieldName: 'cciLevel',
        sortable: true,
        initialWidth: 120
    },
    {
    label: 'Required',
    fieldName: 'required',
    type: 'boolean',
    initialWidth: 100
},
    {
        label: 'Description',
        fieldName: 'description',
        wrapText: true
    }
];

    @api
    set wizardData(value) {

        this._wizardData = value;

        if (!value) {
            return;
        }
        const existingJsonByFieldName =
            new Map(
                (value.selectedFieldsJson || [])
                    .map(field => [
                        field.fieldName,
                        field
                    ])
            );

            const editFields = value.selectedFieldsJson || [];

        this.selectedSchema =
            value.selectedFields
                ? value.selectedFields.map(
                    (row, index) => {

                        const existingField =
                            existingJsonByFieldName.get(
                                row.name
                            );

                        return {
                            ...row,

                            alias:
    existingField?.labelName ??
    existingField?.alias ??
    row.alias ??
    '',

                            order:
                                row.order ||
                                existingField?.order ||
                                index + 1
                            ,
                            required: (existingField?.required === true) || (row.required === true) || (typeof existingField?.required === 'string' && (existingField.required.toLowerCase() === 'yes' || existingField.required.toLowerCase() === 'true')) || (typeof row.required === 'string' && (row.required.toLowerCase() === 'yes' || row.required.toLowerCase() === 'true'))
                        };
                    })
                : [];
             this.syncSelectedRows();
    }

    syncSelectedRows() {

    const selectedNames =
        new Set(
            this.selectedSchema.map(
                row => row.name
            )
        );

    this.fullSchema =
        this.fullSchema.map(row => ({
            ...row,
            isSelected:
                selectedNames.has(row.name)
        }));

    this.applySearchFilter();
}

    get wizardData() {
        return this._wizardData;
    }

    @api
    set schemaData(value) {

        if (!value) {
            return;
        }

        const selectedNames =
            new Set(
                this.selectedSchema.map(
                    row => row.name
                )
            );

       this.fullSchema =
    value.map(row => {

        const existingSelected =
            this.selectedSchema.find(
                sel => sel.name === row.name
            );

        return {
            ...row,

            required:
    row.required === true ||
    row.required === 'YES' ||
    row.required === 'Yes' ||
    row.required === 'yes',

            alias:
                existingSelected?.alias ??
                row.alias ??
                '',

            isSelected:
                selectedNames.has(row.name)
        };
    });

        this.applySearchFilter();
    }

    get schemaData() {
        return this.fullSchema;
    }

    handleSearch(event) {

        this.searchKey =
            (event.target.value || '')
                .trim()
                .toLowerCase();

        this.applySearchFilter();
    }

    applySearchFilter() {

        if (!this.searchKey) {

            this.displayedSchema =
                [...this.fullSchema];

            return;
        }

        this.displayedSchema =
            this.fullSchema.filter(row => {

                const name =
                    String(
                        row.name || ''
                    ).toLowerCase();

                const dataType =
                    String(
                        row.dataType || ''
                    ).toLowerCase();

                const description =
                    String(
                        row.description || ''
                    ).toLowerCase();

                return (
                    name.includes(this.searchKey) ||
                    dataType.includes(this.searchKey) ||
                    description.includes(this.searchKey)
                );
            });
    }

    handleSort(event) {

        this.sortedBy =
            event.detail.fieldName;

        this.sortedDirection =
            event.detail.sortDirection;

        const clone =
            [...this.fullSchema];

        clone.sort((a, b) => {

            const v1 =
                String(
                    a[this.sortedBy] || ''
                ).toLowerCase();

            const v2 =
                String(
                    b[this.sortedBy] || ''
                ).toLowerCase();

            return this.sortedDirection === 'asc'
                ? v1.localeCompare(v2)
                : v2.localeCompare(v1);

        });

        this.fullSchema = clone;

        this.applySearchFilter();
    }

    handleRowSelection(event) {

        const selectedRows =
            event.detail.selectedRows || [];

        const selectedNames =
            new Set(
                selectedRows.map(
                    row => row.name
                )
            );

        const visibleNames =
            new Set(
                this.displayedSchema.map(
                    row => row.name
                )
            );

        this.fullSchema = this.fullSchema.map(row => ({
            ...row,
            isSelected: visibleNames.has(row.name)
                ? selectedNames.has(row.name)
                : row.isSelected
        }));

        const selectedMap = new Map();

        // preserve existing selected order for rows that remain selected
        this.selectedSchema.forEach(row => {
            if (selectedNames.has(row.name)) {
                selectedMap.set(row.name, row);
            }
        });

        // append any newly selected rows at the end
        selectedRows.forEach(row => {
            if (!selectedMap.has(row.name)) {
                selectedMap.set(row.name, {
                    ...row,
                    alias: row.alias || row.name,
                    id: row.id || row.name,
                    name: row.name,
                    fieldName: row.fieldName || row.name
                });
            }
        });

        this.selectedSchema = Array.from(selectedMap.values()).map((row, index) => ({
            ...row,
            order: row.order || index + 1
        }));

        this.notifyParent();
    }

    handleAliasChange(event) {

    const fieldName = event.target.dataset.name;
    const alias = event.target.value;

    this.selectedSchema = this.selectedSchema.map(row => {
        if (row.name === fieldName) {
            return { ...row, alias };
        }
        return row;
    });

    // debounce notify to avoid excessive parent updates that can trigger heavy processing
    if (this._aliasChangeTimeout) {
        clearTimeout(this._aliasChangeTimeout);
    }

    this._aliasChangeTimeout = setTimeout(() => {
        this.notifyParent();
        this._aliasChangeTimeout = null;
    }, 300);
}

handleAliasBlur() {
    this.notifyParent();
}

    handleAliasKeyDown(event) {
        // prevent Enter from submitting any surrounding form
        if (event.key === 'Enter') {
            event.preventDefault();
            event.stopPropagation();
            // commit alias change immediately
            this.notifyParent();
        }
    }

    renderedCallback() {
        // Add a capture submit handler to prevent any accidental form submissions
        if (!this._submitHandler) {
            this._submitHandler = (e) => {
                // Prevent form submit originating from inputs inside this component
                // we check if the active element is inside this component
                const active = document.activeElement;
                if (this.template.contains(active)) {
                    e.preventDefault();
                    e.stopPropagation();
                }
            };
            window.addEventListener('submit', this._submitHandler, true);
        }
    }

    disconnectedCallback() {
        if (this._submitHandler) {
            window.removeEventListener('submit', this._submitHandler, true);
            this._submitHandler = null;
        }
    }

    removeRow(event) {

        const fieldName =
            event.currentTarget.dataset.name;

        this.selectedSchema =
            this.selectedSchema
                .filter(
                    row => row.name !== fieldName
                )
                .map((row, index) => ({
                    ...row,
                    order: index + 1
                }));

        this.fullSchema =
            this.fullSchema.map(row => {

                if (row.name === fieldName) {

                    return {
                        ...row,
                        isSelected: false
                    };
                }

                return row;
            });

        this.applySearchFilter();

        this.notifyParent();
    }

    notifyParent() {

    const orderedSelectedFields =
        this.selectedSchema.map(
            (row, index) => ({
                ...row,
                fieldName: row.name,
                order: index + 1
            })
        );

    const selectedFieldsJson =
    orderedSelectedFields.map(
        (row, index) => ({
            id: row.fieldName || row.name,
            fieldName: row.name,
            labelName:
                row.alias !== undefined
                    ? row.alias.trim()
                    : row.name,
            alias:
                row.alias || row.name,
            dataType:
                row.dataType || '',
            description:
                row.description || '',
            piiLevel:
                row.piiLevel || '',
            cciLevel:
                row.cciLevel || row.cci || '',
            required:
                row.required,
            order:
                index + 1
        })
    );

    // log payload for debugging reload/refresh issues
    // eslint-disable-next-line no-console
    console.log('[FieldSelection] dispatching stepdatachange', { selectedFields: orderedSelectedFields, selectedFieldsJson });

    this.dispatchEvent(
        new CustomEvent('stepdatachange', {
            detail: {
                selectedFields: orderedSelectedFields,
                selectedFieldsJson: selectedFieldsJson
            }
        })
    );
}

    get selectedCount() {
        return this.selectedSchema.length;
    }

    get visibleSelectedRowNames() {

        return this.displayedSchema
            .filter(
                row => row.isSelected
            )
            .map(
                row => row.name
            );
    }
    get selectedSchemaForDisplay() {

    return this.selectedSchema.map(row => {

        let rowClass = 'preview-row';

        if (row.name === this.draggedRowId) {
            rowClass += ' preview-row-dragging';
        }

        if (
            row.name === this.dragOverRowId &&
            row.name !== this.draggedRowId
        ) {
            rowClass += ' preview-row-drop-target';
        }

        return {
            ...row,
            rowClass
        };
    });
}

handleDragStart(event) {

    this.draggedRowId =
        event.currentTarget.dataset.id;

    this.dragOverRowId = null;

    event.dataTransfer.effectAllowed =
        'move';
}

handleDragOver(event) {

    event.preventDefault();

    const targetId =
        event.currentTarget.dataset.id;

    if (
        targetId &&
        targetId !== this.draggedRowId
    ) {

        this.dragOverRowId =
            targetId;
    }

    event.dataTransfer.dropEffect =
        'move';
}

handleDragLeave(event) {

    const targetId =
        event.currentTarget.dataset.id;

    if (
        this.dragOverRowId === targetId
    ) {

        this.dragOverRowId = null;
    }
}

handleDrop(event) {

    try {

        event.preventDefault();

        const targetId =
            event.currentTarget.dataset.id;

        if (
            !this.draggedRowId ||
            !targetId ||
            this.draggedRowId === targetId
        ) {

            this.clearDragState();
            return;
        }

        const items =
            [...this.selectedSchema];

        const fromIndex =
            items.findIndex(
                row =>
                    row.name ===
                    this.draggedRowId
            );

        const toIndex =
            items.findIndex(
                row =>
                    row.name ===
                    targetId
            );

        if (
            fromIndex === -1 ||
            toIndex === -1
        ) {

            this.clearDragState();
            return;
        }

        const [moved] =
            items.splice(
                fromIndex,
                1
            );

        items.splice(
            toIndex,
            0,
            moved
        );

        this.selectedSchema =
            items.map(
                (row, index) => ({
                    ...row,
                    order: index + 1
                })
            );

        this.notifyParent();

        this.clearDragState();

    } catch (error) {

        this.clearDragState();
    }
}
handleDragEnd() {
    this.clearDragState();
}
clearDragState() {

    this.draggedRowId = null;
    this.dragOverRowId = null;
}
}