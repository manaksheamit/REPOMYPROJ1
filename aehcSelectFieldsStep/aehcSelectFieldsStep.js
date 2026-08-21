import { LightningElement, api, track } from 'lwc';
import logError from '@salesforce/apex/AEHC_Logger.logError';
import getUserAppsApex from '@salesforce/apex/AEHC_PublicationSubRequestController.getUserApps';
import LABEL_ENV_NAME from '@salesforce/label/c.AEHC_Environment_Name';

import L_APP_NAME from '@salesforce/label/c.AEHC_DP_AppName';
import L_PUB_NAME from '@salesforce/label/c.AEHC_DP_PubName';
import L_PUB_ID from '@salesforce/label/c.AEHC_DP_PubId';
import L_ENVIRONMENT from '@salesforce/label/c.AEHC_DP_Environment';
import L_SCHEMA_VERSION from '@salesforce/label/c.AEHC_DP_SchemaVersion';
import L_PURPOSE_USE from '@salesforce/label/c.AEHC_DP_PurposeUse';
import L_TRANSFORM_REQ from '@salesforce/label/c.AEHC_DP_TransformReq';

import L_AVAILABLE_FIELDS from '@salesforce/label/c.AEHC_DP_AvailableFields';
import L_SEARCH_FIELDS from '@salesforce/label/c.AEHC_DP_SearchFields';
import L_SEARCH_PLACEHOLDER from '@salesforce/label/c.AEHC_DP_SearchPlaceholder';
import L_SELECTED_ORDER from '@salesforce/label/c.AEHC_DP_SelectedOrder';
import L_NO_FILTERED_DATA from '@salesforce/label/c.AEHC_DP_NoFilteredData';
import L_ADJUST_FILTERS from '@salesforce/label/c.AEHC_DP_AdjustFilters';

import L_FIELD_NAME from '@salesforce/label/c.AEHC_DP_FieldName';
import L_DATA_TYPE from '@salesforce/label/c.AEHC_DP_DataType';
import L_DESCRIPTION from '@salesforce/label/c.AEHC_DP_Description';
import L_REQUIRED from '@salesforce/label/c.AEHC_DP_Required';
import L_LOADING_SCHEMA_FIELDS from '@salesforce/label/c.AEHC_DP_LoadingSchemaFields';

import L_BACK from '@salesforce/label/c.AEHC_DP_Back';
import L_NEXT from '@salesforce/label/c.AEHC_DP_Next';
import L_REMOVE from '@salesforce/label/c.AEHC_DP_Remove';
import L_LOAD_SCHEMA_ERROR from '@salesforce/label/c.AEHC_DP_LoadSchemaError';

export default class AehcSelectFieldsStep extends LightningElement {

    @track localWizardData = {};
    @track fullSchema = [];
    @track displayedSchema = [];
    @track selectedSchema = [];
    @api isPublicationBo;

    searchKey = '';
    sortedBy;
    sortedDirection = 'asc';
    draggedRowId;
    dragOverRowId;
    @api isUnauthorized = false;
    @api hasSchemaError = false;
    @api isLoading = false;
    @api editMode = false;

    isRowSelectionProcessing = false;
    lastSelectedCount = 0;
    lastSelectionSignature = '';

    get isReadOnly() {
        return this.editMode === true;
    }

    connectedCallback() {
        this.init();
    }

    async init() {
        try {
            // get data
            const response = await getUserAppsApex();
            this.subscriberApplication.allRecords = response.status == 200 ? response.data : [];

        } catch (err) {

        }
    }
 
    // app-search field
    subscriberApplication = {
        name: 'c-aehc-reusable-lookup',
        element: null,
        getElement: function (component) {
            if (!this.element) this.element = component.template.querySelector(this.name);
            return this.element;
        },
        label: 'Consuming Application Name',
        objectLabel: 'Application',
        placeholder: 'Search Application',
        iconName: 'custom:custom24',
        spinnerOnChange: true,
        required: true,
        records: [],
        allRecords: []
    }
    // handlers
    searchAppString;
    searchTimeout;
    async handleChange_SearchApplicationField(event) {

        const searchString = event.detail.value;

        this.subscriberApplication.getElement(this).reset({
            records: searchString ? this.subscriberApplication.allRecords.filter(rec => rec.mainField?.toLowerCase().includes(searchString) || rec.subField?.toLowerCase().includes(searchString)) : this.subscriberApplication.allRecords
        });

        // clear search results
        // window.clearTimeout(this.searchTimeout);
        // this.searchTimeout = setTimeout(async e => {


        // }, 500);

    }
    handleFocus_SearchApplication(event) {
        const searchString = event.detail.value;
        this.subscriberApplication.getElement(this).reset({
            records: searchString ? this.subscriberApplication.allRecords.filter(rec => rec.mainField?.toLowerCase().includes(searchString) || rec.subField?.toLowerCase().includes(searchString)) : this.subscriberApplication.allRecords
        });
    }
    async handleSelect_SearchApplication(event) {
        try {
            const selected = event.detail;
            console.log(85, JSON.stringify(selected));
            // selected.id
            this.localWizardData = {
                ...this.localWizardData,
                subscriberApplication: selected.id,
                subscriberApplicationData: selected
            };

        } catch (err) {
            console.error(err);
        }
    }
    handleDeselect_SearchApplication(event) {
        const deselected = event.detail;
        // deselected.id
        this.localWizardData = {
            ...this.localWizardData,
            subscriberApplication: null,
            subscriberApplicationData: null
        };

        this.init();
    }

    get availableColumns() {
        return [
            {
                label: 'Alias',
                fieldName: 'labelName',
                sortable: true
            },
            {
                label: this.uiLabels.fieldName,
                fieldName: 'fieldName',
                sortable: true
            },
            {
                label: 'CCI',
                fieldName: 'cci',
                sortable: true
            },
            {
                label: 'PII Level',
                fieldName: 'piiLevel',
            sortable: true
            },
            {
                label: this.uiLabels.dataType,
                fieldName: 'dataType',
                sortable: true
            },
            {
                label: this.uiLabels.description,
                fieldName: 'description',
                wrapText: true
            },
            {
                label: this.uiLabels.required,
                fieldName: 'required',
                type: 'boolean',
                fixedWidth: 90
            }
        ];
    }

    uiLabels = {
        appName: L_APP_NAME,
        pubName: L_PUB_NAME,
        pubId: L_PUB_ID,
        environment: L_ENVIRONMENT,
        schemaVersion: L_SCHEMA_VERSION,
        purposeUse: L_PURPOSE_USE,
        transformReq: L_TRANSFORM_REQ,

        availableFields: L_AVAILABLE_FIELDS,
        searchFields: L_SEARCH_FIELDS,
        searchPlaceholder: L_SEARCH_PLACEHOLDER,
        selectedOrder: L_SELECTED_ORDER,
        noFilteredData: L_NO_FILTERED_DATA,
        adjustFilters: L_ADJUST_FILTERS,
        loadingSchemaFields: L_LOADING_SCHEMA_FIELDS,

        fieldName: L_FIELD_NAME,
        dataType: L_DATA_TYPE,
        description: L_DESCRIPTION,
        required: L_REQUIRED,

        back: L_BACK,
        next: L_NEXT,
        remove: L_REMOVE,
        loadSchemaError: L_LOAD_SCHEMA_ERROR
    };

    @api
    set wizardData(value) { 
        if (value) {
            this.localWizardData = {
                ...value,
                uatEnabled: value?.uatEnabled !== undefined ? value.uatEnabled : false
            };

            const existingJsonByFieldName = new Map(
                (value.selectedFieldsJson || []).map(field => [
                    field.fieldName,
                    field 
                ])
            );

            this.selectedSchema = value.selectedFields
                ? value.selectedFields.map((row, index) => {
                    const existingField = existingJsonByFieldName.get(row.fieldName);

                    return {
                        ...row,
                        label: existingField?.label || row.label || row.fieldName,
                        order: row.order || existingField?.order || index + 1
                    };
                })
                : [];

            if (value.subscriberApplicationData) {
                setTimeout(() => {
                    this.subscriberApplication.getElement(this)?.reset({
                        value: value.subscriberApplicationData
                    })
                }, 0)
            }

        }
    }
    handleUATToggle(event) {
        this.localWizardData = {
            ...this.localWizardData,
            uatEnabled: event.target.checked
        };

        this.notifyParent();
    }


    get wizardData() {
        return this.localWizardData;
    }

    @api
    set schemaData(value) {
        if (value) {
            const selectedNames = new Set(
                this.selectedSchema.map(row => row.fieldName)
            );
            this.searchKey = '';
            this.fullSchema = value.map(row => ({
                ...row,
                isSelected: selectedNames.has(row.fieldName) || row.isSelected === true
            }));

            this.applySearchFilter();
        }
    }

    get schemaData() {
        return this.fullSchema;
    }

    get selectedSchemaForDisplay() {
        return this.selectedSchema.map(row => {
            let rowClass = 'preview-row';

            if (row.fieldName === this.draggedRowId) {
                rowClass += ' preview-row-dragging';
            }

            if (row.fieldName === this.dragOverRowId && row.fieldName !== this.draggedRowId) {
                rowClass += ' preview-row-drop-target';
            }

            return {
                ...row,
                rowClass
            };
        });
    }

    get showSchemaError() {
        return !this.isLoading && this.hasSchemaError;
    }

    handlePurposeOfUseChange(event) {
        this.localWizardData = {
            ...this.localWizardData,
            purposeOfUse: event.detail.value
        };

        this.notifyParent();
    }

    handleTransformationChange(event) {
        this.localWizardData = {
            ...this.localWizardData,
            transformationRequired: event.target.checked
        };

        this.notifyParent();
    }

    handleSearch(event) {
        try {
            const value = event.target.value || '';
            this.searchKey = value.trim().toLowerCase();

            this.applySearchFilter();
        } catch (error) {
            this.logExceptionToApex(error, 'handleSearch');
        }

    }

    applySearchFilter() {
        if (!this.searchKey) {
            this.displayedSchema = [...this.fullSchema];
            return;
        }

        this.displayedSchema = this.fullSchema.filter(row => {
            const name = row.fieldName ? String(row.fieldName).toLowerCase() : '';
            const dataType = row.dataType ? String(row.dataType).toLowerCase() : '';
            const description = row.description ? String(row.description).toLowerCase() : '';

            return (
                name.includes(this.searchKey) ||
                dataType.includes(this.searchKey) ||
                description.includes(this.searchKey)
            );
        });
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;

        const data = [...this.fullSchema];

        data.sort((a, b) => {
            const v1 = a[this.sortedBy] === null || a[this.sortedBy] === undefined
                ? ''
                : String(a[this.sortedBy]).toLowerCase();

            const v2 = b[this.sortedBy] === null || b[this.sortedBy] === undefined
                ? ''
                : String(b[this.sortedBy]).toLowerCase();

            return this.sortedDirection === 'asc'
                ? v1.localeCompare(v2)
                : v2.localeCompare(v1);
        });

        this.fullSchema = data;
        this.applySearchFilter();
    }



    handleRowSelection(event) {

        const selectedRows = event.detail.selectedRows || [];
        const currentSelectedCount = selectedRows.length;

        // Create a selection signature to distinguish
        // real user changes from datatable rerender events.
        const currentSignature = selectedRows
            .map(row => row.fieldName)
            .sort()
            .join('|');

        if (
            this.isRowSelectionProcessing &&
            currentSignature === this.lastSelectionSignature
        ) {
            return;
        }

        this.lastSelectedCount = currentSelectedCount;
        this.lastSelectionSignature = currentSignature;

        this.isRowSelectionProcessing = true;

        try {
            const selectedRows = event.detail.selectedRows || [];

            const visibleNames = new Set(
                this.displayedSchema.map(row => row.fieldName)
            );

            const selectedNames = new Set(
                selectedRows.map(row => row.fieldName)
            );

            // Update selection state only for visible rows
            this.fullSchema.forEach(row => {
                if (visibleNames.has(row.fieldName)) {
                    row.isSelected = selectedNames.has(row.fieldName);
                }
            });

            // Build selected schema efficiently
            const selectedMap = new Map();

            // Retain previously selected rows that are not currently visible

            this.selectedSchema.forEach(row => {
                if (!visibleNames.has(row.fieldName)) {
                    selectedMap.set(row.fieldName, row);
                }
            });

            // Add newly selected rows
            selectedRows.forEach(row => {
                if (!selectedMap.has(row.fieldName)) {
                    selectedMap.set(row.fieldName, {
                        ...row,
                        isSelected: true
                    });
                }
            });

            this.selectedSchema = Array.from(
                selectedMap.values(),
                (row, index) => ({
                    ...row,
                    order: index + 1
                })
            );

            // Run after current event cycle completes
            setTimeout(() => {
                this.applySearchFilter();
                this.isRowSelectionProcessing = false;
            }, 0);

        } catch (error) {
            this.isRowSelectionProcessing = false;
            this.logExceptionToApex(error, 'handleRowSelection');
        }
    }


    removeRow(event) {
        try {
            const name = event.currentTarget.dataset.id;

            this.fullSchema = this.fullSchema.map(row =>
                row.fieldName === name
                    ? { ...row, isSelected: false }
                    : row
            );

            this.selectedSchema = this.selectedSchema
                .filter(row => row.fieldName !== name)
                .map((row, index) => ({
                    ...row,
                    order: index + 1
                }));

            this.applySearchFilter();
            this.syncDatatableSelection();

        } catch (error) {
            this.logExceptionToApex(error, 'removeRow');
        }
    }

    syncDatatableSelection() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = this.visibleSelectedRowNames;
        }
    }


    handleDragStart(event) {
        this.draggedRowId = event.currentTarget.dataset.id;
        this.dragOverRowId = null;

        event.dataTransfer.effectAllowed = 'move';
    }


    handleDragOver(event) {
        event.preventDefault();

        const targetId = event.currentTarget.dataset.id;

        if (targetId && targetId !== this.draggedRowId) {
            this.dragOverRowId = targetId;
        }

        event.dataTransfer.dropEffect = 'move';
    }

    handleDragLeave(event) {
        const targetId = event.currentTarget.dataset.id;

        if (this.dragOverRowId === targetId) {
            this.dragOverRowId = null;
        }
    }

    handleDrop(event) {
        try {
            event.preventDefault();

            const targetId = event.currentTarget.dataset.id;

            if (!this.draggedRowId || !targetId || this.draggedRowId === targetId) {
                this.clearDragState();
                return;
            }

            const items = [...this.selectedSchema];

            const fromIndex = items.findIndex(row => row.fieldName === this.draggedRowId);
            const toIndex = items.findIndex(row => row.fieldName === targetId);

            if (fromIndex === -1 || toIndex === -1) {
                this.clearDragState();
                return;
            }

            const [moved] = items.splice(fromIndex, 1);
            items.splice(toIndex, 0, moved);

            this.selectedSchema = items.map((row, index) => ({
                ...row,
                order: index + 1
            }));

            this.clearDragState();

        } catch (error) {
            this.clearDragState();

            this.logExceptionToApex(error, 'handleDrop', {
                draggedRowId: this.draggedRowId
            });
        }
    }


    handleDragEnd() {
        this.clearDragState();
    }


    clearDragState() {
        this.draggedRowId = null;
        this.dragOverRowId = null;
    }



    notifyParent() {
        const existingJsonByFieldName = new Map(
            (this.localWizardData.selectedFieldsJson || []).map(field => [
                field.fieldName,
                field
            ])
        );

        const orderedSelectedFields = this.selectedSchema.map((row, index) => ({
            ...row,
            order: index + 1
        }));

        const selectedFieldsJson = orderedSelectedFields.map((row, index) => {
            const existingField = existingJsonByFieldName.get(row.fieldName);
            console.log('______row________',JSON.stringify(row));
            console.log('______row existingField________',JSON.stringify(existingField));
            
            return {
                fieldName: row.fieldName,
                labelName: existingField?.labelName || row.label || row.labelName || row.alias || row.fieldName,
                alias: row.alias || existingField?.alias || row.labelName || row.fieldName,
                order: index + 1,
                dataType: row.dataType || existingField?.dataType || '',
                description: row.description || existingField?.description || '',
                cciLevel: row.cci || row.cciLevel || existingField?.cciLevel || existingField?.cci || '',
                piiLevel: row.piiLevel || existingField?.piiLevel || '',
                required: row.required === true || row.required === 'YES' || row.required === 'Yes' || row.required === 'yes' || existingField?.required === true || existingField?.required === 'YES' || existingField?.required === 'Yes' || existingField?.required === 'yes'
            };
        });

        this.dispatchEvent(
            new CustomEvent('stepdatachange', {
                detail: {
                    purposeOfUse: this.localWizardData.purposeOfUse,
                    transformationRequired: this.localWizardData.transformationRequired,
                    uatEnabled: this.localWizardData.uatEnabled,
                    selectedFields: orderedSelectedFields,
                    selectedFieldsJson: selectedFieldsJson,
                    subscriberApplication: this.localWizardData.subscriberApplication,
                    subscriberApplicationData: this.localWizardData.subscriberApplicationData
                }
            })
        );
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleNext() {
        this.notifyParent();
        this.dispatchEvent(new CustomEvent('next'));
    }

    get selectedCount() {
        return this.selectedSchema.length;
    }

    get disableNext() {
        return this.isLoading ||
            this.hasSchemaError ||
            this.selectedSchema.length === 0 ||
            !this.localWizardData.subscriberApplication ||
            this.isUnauthorized;
    }

    get noSchemaData() {
        return !this.isLoading &&
            !this.hasSchemaError &&
            (!this.fullSchema || this.fullSchema.length === 0);
    }

    get showNoFilteredSchema() {
        return !this.isLoading &&
            !this.hasSchemaError &&
            this.searchKey !== '' &&
            this.fullSchema.length > 0 &&
            this.displayedSchema.length === 0;
    }

    get showSchemaTable() {
        return !this.isLoading &&
            !this.hasSchemaError &&
            this.fullSchema.length > 0 &&
            this.displayedSchema.length > 0;
    }

    get visibleSelectedRowNames() {
        return this.displayedSchema
            .filter(row => row.isSelected)
            .map(row => row.fieldName);
    }
    logExceptionToApex(error, operation = 'unknown', extraContext = {}) {
        try {
            const transactionContext = {
                searchKey: this.searchKey,
                fullSchemaCount: this.fullSchema?.length || 0,
                displayedSchemaCount: this.displayedSchema?.length || 0,
                selectedFieldsCount: this.selectedSchema?.length || 0,
                purposeOfUse: this.localWizardData?.purposeOfUse,
                transformationRequired: this.localWizardData?.transformationRequired,
                ...extraContext
            };

            logError({
                message: this.normalizeErrorMessage(error),
                componentType: 'LWC',
                componentName: 'aehcSelectFieldsStep',
                operation: operation,
                recordId: null,
                severity: 'High',
                category: 'UI',
                transactionContext: JSON.stringify(transactionContext),
                orgEnv: LABEL_ENV_NAME
            }).catch((loggingError) => {
                console.error('Failed to log error in Apex', loggingError);
            });

        } catch (localLoggingError) {
            console.error('Local logging failed', localLoggingError);
        }
    }

    normalizeErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unknown error';
    }
}