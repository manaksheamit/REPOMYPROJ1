/**
 * Component: aehcPublicationDetailsStep
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Step 1 of publication wizard handling application selection,
 * schema validation, field loading, and schedule configuration.
 */
import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import getSubscriptionPicklistOptions from '@salesforce/apex/AEHC_SubscriptionController_DP.getSubscriptionPicklistOptions';
import getApplications from '@salesforce/apex/AEHC_PublicationController.getApplications';
import validateEligibility from '@salesforce/apex/AEHC_PublicationController.validateEligibility';
import getTableSchemaForPublicationCreation from '@salesforce/apex/AEHC_PublicationController.getTableSchemaForPublicationCreation';
import validatePublicationBeforePreview from '@salesforce/apex/AEHC_PublicationController.validatePublicationBeforePreview';
import getDescriptionMaxLimit from '@salesforce/apex/AEHC_PublicationController.getDescriptionMaxLimit';
import logError from '@salesforce/apex/AEHC_Logger.logError';
import LABEL_ENV_NAME from '@salesforce/label/c.AEHC_Environment_Name';
// Reused labels
import L_APP_NAME from '@salesforce/label/c.AEHC_DP_AppName';
import L_PUB_NAME from '@salesforce/label/c.AEHC_DP_PubName';
import L_DESC from '@salesforce/label/c.AEHC_DP_Description';
import L_NEXT from '@salesforce/label/c.AEHC_DP_Next';
// New labels
import L_SEARCH_APP from '@salesforce/label/c.AEHC_DP_Search_Application';
import L_NO_APP from '@salesforce/label/c.AEHC_DP_No_Applications';
import L_PUB_DETAILS from '@salesforce/label/c.AEHC_DP_Publication_Details';
import L_SCHEMA_TABLE from '@salesforce/label/c.AEHC_DP_Schema_Table';
import L_SCHEMA_NAME from '@salesforce/label/c.AEHC_DP_Schema_Name';
import L_TABLE_NAME from '@salesforce/label/c.AEHC_DP_Table_Name';
import L_VALIDATE from '@salesforce/label/c.AEHC_DP_Validate';
import L_FIELDS from '@salesforce/label/c.AEHC_DP_Fields';
import L_LOAD_MORE from '@salesforce/label/c.AEHC_DP_Load_More';
import L_NO_FIELDS from '@salesforce/label/c.AEHC_DP_No_Fields';
import L_DEFINE_SCHEDULE from '@salesforce/label/c.AEHC_DP_Define_Schedule';
import L_CLOSE from '@salesforce/label/c.AEHC_DP_Close';
import L_FIELD_NAME from '@salesforce/label/c.AEHC_DP_FieldName';
import L_DATA_TYPE from '@salesforce/label/c.AEHC_DP_DataType';
import L_REQUIRED from '@salesforce/label/c.AEHC_DP_Required';
// Error labels
import L_ERR_SEARCH from '@salesforce/label/c.AEHC_DP_Error_Search';
import L_ERR_SCHEMA from '@salesforce/label/c.AEHC_DP_Error_Schema_Required';
import L_ERR_APP_REQUIRED from '@salesforce/label/c.AEHC_DP_Error_Application_Required';
import L_ERR_VALIDATE from '@salesforce/label/c.AEHC_DP_Error_Publication_Validate';

export default class AehcPublicationDetailsStep extends NavigationMixin(LightningElement) {

    @api schedulerModeOptions = [];
    @api frequencyOptions = [];
    @api weekdayOptions = [];
    @api weekOptions = [];
    @api monthDayOptions = [];
    //@api wizardData = {};
    @api isReturning = false;

    @wire(getDescriptionMaxLimit) descLimit;

    @track applications = [];
    searchKey = '';
    selectedApplication = null;
    @track picklistOptions = {
        schedulerModeOptions: [],
        frequencyOptions: [],
        weekdayOptions: [],
        weekOptions: [],
        monthDayOptions: []
    };
    labels = {
        appName: L_APP_NAME,
        searchPlaceholder: L_SEARCH_APP,
        noApplications: L_NO_APP,
        pubDetails: L_PUB_DETAILS,
        schemaTable: L_SCHEMA_TABLE,
        schemaName: L_SCHEMA_NAME,
        tableName: L_TABLE_NAME,
        validate: L_VALIDATE,
        fields: L_FIELDS,
        loadMore: L_LOAD_MORE,
        noFields: L_NO_FIELDS,
        defineSchedule: L_DEFINE_SCHEDULE,
        close: L_CLOSE,
        next: L_NEXT,
        desc: L_DESC,
        pubName: L_PUB_NAME
    };
    publicationType = '';
    isPicklistLoading = false;
    publicationValidationError = '';
    publicationDescriptionError = '';
    publicationTypeError = '';
    schemaError = '';
    tableError = '';
    isPublicationValid = true;
    isDetailsValidated = false;
    applicationOwner = '';
    dataClassification = '';
    isEligible = false;
    applicationError = '';
    isSearchLoading = false;
    debounceTimeout;
    hasSearched = false;
    pubName = '';
    pubDesc = '';
    schema = '';
    table = '';
    isSchemaLoading = false;
    fields = [];
    selectedFields = [];
    selectedFieldsJson = [];
    @track visibleFields = [];
    fieldPageSize = 50;
    fieldDisplayLimit = 50;
    hasValidatedSchema = false;
    @api isEditMode = false;
    @api publicationId;

    _wizardData;

    _hasLoadedSchemaForEdit = false;

    @api
    set wizardData(value) {

        this._wizardData = value;

        if (
            value &&
            this.isEditMode &&
            value.schema?.schema &&
            !this._hasLoadedSchemaForEdit
        ) {
            this._hasLoadedSchemaForEdit = true;
            this.restorePreviousData();
            this.loadSchemaForEdit();
        }
    }

    get wizardData() {
        return this._wizardData;
    }


    publicationTypeOptions = [
        { label: 'Full', value: 'Full' },
        { label: 'Incremental', value: 'Incremental' }
    ];

    columns = [
        { label: L_FIELD_NAME, fieldName: 'name' },
        { label: L_DATA_TYPE, fieldName: 'dataType' },
        { label: L_DESC, fieldName: 'description' },
        { label: 'PII Level', fieldName: 'piiLevel' }, // optional label later
        { label: L_REQUIRED, fieldName: 'requiredText' }
    ];

    schedule = {
        schedulerMode: 'Scheduler (Time-Based)',
        frequency: '',
        scheduleTime: '',
        weekdays: [],
        multiWeekWeeks: [],
        multiWeekDays: [],
        monthlyDay: '',
        oneTimeDate: '',
        oneTimeTime: '',
        annualMonth: '',
        annualDay: '',
        annualDate: '',
        scheduleSummary: '',
        cronExpression: ''
    };


    async loadSchemaForEdit() {

        try {
            this.isSchemaLoading = true;
            const result = await getTableSchemaForPublicationCreation({
                applicationName: this.selectedApplication.name,
                schemaName: this.schema,
                tableName: this.table
            });

            this.fields =
                (result || []).map((f, i) => ({
                    id: f.id || String(i),
                    name: f.name || '',
                    dataType: f.dataType || '',
                    description: f.description || '',
                    piiLevel: f.piiLevel || '',
                    cciLevel: f.cciLevel || '',
                    required:
                        f.required === true
                            ? 'YES'
                            : 'NO'
                }));

                const selectedFieldNames = new Set(
    (this.selectedFieldsJson || [])
        .map(f => f.fieldName)
);

this.selectedFields =
    this.fields.filter(
        f => selectedFieldNames.has(f.name)
    );

            this.visibleFields = [...this.fields];

            this.hasValidatedSchema = true;

            this.isDetailsValidated = true;

        } finally {
            this.isSchemaLoading = false;
        }
    }

    get showApplicationResults() {
        return this.applications && this.applications.length > 0;
    }

    get showNoResults() {
        return (
            this.hasSearched &&
            !this.isSearchLoading &&
            this.searchKey &&
            this.searchKey.length >= 3 &&
            (!this.applications || this.applications.length === 0)
        );
    }

    get hasVisibleFields() {
        return this.fields && this.fields.length > 0;
    }

    get showLoadMore() {
        return this.visibleFields.length < this.fields.length;
    }

    get showNoFields() {
        return (
            this.hasValidatedSchema &&
            !this.isSchemaLoading &&
            Array.isArray(this.fields) &&
            this.fields.length === 0
        );
    }

    get disableNext() {
        const hasCore =
            this.selectedApplication &&
            this.pubName &&
            this.pubDesc &&
            this.schema &&
            this.table &&
            this.publicationType &&
            Array.isArray(this.fields) &&
            this.fields.length > 0 &&
            Array.isArray(this.selectedFieldsJson) &&
            this.selectedFieldsJson.length > 0;

        const hasSchedule =
            this.schedule &&
            (
                this.schedule.schedulerMode === 'Submon (Triggered on Publication Completion)' ||
                !!this.schedule.cronExpression
            );

        return !(this.isEligible && hasCore && hasSchedule && this.isDetailsValidated);
    }

    connectedCallback() {
        console.log('[DetailsStep] connectedCallback', this.isReturning, this.wizardData,this.isEditMode,this.publicationId)
        this.loadPicklistOptions();

        // Restore form data if returning from review step
        if (this.isReturning && this.wizardData) {
            this.restorePreviousData();
        }
    }

    restorePreviousData() {
        console.log('[DetailsStep] restorePreviousData', this.wizardData);
        if (!this.wizardData) return;

        // Restore application with all related fields
        if (this.wizardData.application) {
            this.selectedApplication = this.wizardData.application;
            this.applicationOwner = this.wizardData.application.owner || '';
            this.dataClassification = this.wizardData.application.dataClassification || '';
            this.searchKey = this.wizardData.application.name || '';
            this.hasSearched = true;
        }

        // Restore publication details
        if (this.wizardData.metadata) {
            this.pubName = this.wizardData.metadata.name || '';
            this.pubDesc = this.wizardData.metadata.description || '';
            this.publicationType = this.wizardData.metadata.publicationType || '';
        }

        // Restore schema
        if (this.wizardData.schema) {
            this.schema = this.wizardData.schema.schema || '';
            this.table = this.wizardData.schema.table || '';
            this.fields = this.wizardData.schema.fields || [];
            this.visibleFields = this.fields.slice(0, this.fieldPageSize);
            this.hasValidatedSchema = this.isEditMode ? false : true;
            this.isEligible = true;
            this.isDetailsValidated = true;
        }

        // Restore schedule
        if (this.wizardData.schedule) {
            this.schedule = {
                ...this.schedule,
                ...this.normalizeSchedule(this.wizardData.schedule)
            };
        }

        this.selectedFields =
            this.wizardData.selectedFields || [];

        this.selectedFieldsJson =
            this.wizardData.selectedFieldsJson || [];

        // Mark as loaded and dispatch event to reset parent flag
        setTimeout(() => {
            this.dispatchEvent(new CustomEvent('datarestored', {
                detail: { dataLoaded: true }
            }));
        }, 100);
    }

    handleFieldSelectionChange(event) {

        const normalizeSelectedField = f => ({
            ...f,
            id: f.id || f.fieldName || f.name,
            fieldName: f.fieldName || f.name,
            name: f.name || f.fieldName,
            alias: f.alias || f.labelName || f.name || f.fieldName,
            required: (f.required === true) || (typeof f.required === 'string' && (f.required.toLowerCase() === 'yes' || f.required.toLowerCase() === 'true'))
        });

        const uniqueByFieldName = items => {
            const map = new Map();
            items.forEach(item => {
                const key = item.fieldName || item.name;
                if (!key) return;
                if (!map.has(key)) {
                    map.set(key, { ...normalizeSelectedField(item) });
                }
            });
            return Array.from(map.values());
        };

        const selectedFields = uniqueByFieldName((event.detail.selectedFields || []).map(normalizeSelectedField));
        const selectedFieldsJson = uniqueByFieldName((event.detail.selectedFieldsJson || []).map(normalizeSelectedField));

        // eslint-disable-next-line no-console
        console.log('[DetailsStep] received selection update', { selectedFields, selectedFieldsJson });

        this.selectedFields = selectedFields;
        this.selectedFieldsJson = selectedFieldsJson;

        this.wizardData = {
            ...this.wizardData,
            selectedFields: selectedFields,
            selectedFieldsJson: selectedFieldsJson
        };
    }
    async loadPicklistOptions() {
        try {
            this.isPicklistLoading = true;

            const options = await getSubscriptionPicklistOptions();
            console.log('[DetailsStep] Picklist options from Apex', options);

            this.picklistOptions = {
                schedulerModeOptions: options.schedulerModeOptions || [],
                frequencyOptions: options.frequencyOptions || [],
                weekdayOptions: options.weekdayOptions || [],
                weekOptions: options.weekOptions || [],
                monthDayOptions: options.monthDayOptions || []
            };
            console.log('[DetailsStep] Picklist options from Apex', options);

        } catch (error) {
            this.logException(error, 'loadPicklistOptions');

            // fallback if Apex fails
            this.applyPicklistFallbacks();

        } finally {
            this.isPicklistLoading = false;
        }
    }

    applyPicklistFallbacks() {
        console.log('[DetailsStep] Applying picklist fallback options.');
        this.picklistOptions = {
            schedulerModeOptions: [
                { label: 'Scheduler (Time-Based)', value: 'Scheduler (Time-Based)' }
            ],
            frequencyOptions: [
                { label: 'Daily', value: 'Daily' },
                { label: 'Weekly', value: 'Weekly' },
                { label: 'Multi-Weekly', value: 'Multi-Weekly' },
                { label: 'Monthly', value: 'Monthly' },
                { label: 'Annual', value: 'Annual' }
            ],
            weekdayOptions: [
                { label: 'Monday', value: 'Monday' },
                { label: 'Tuesday', value: 'Tuesday' },
                { label: 'Wednesday', value: 'Wednesday' },
                { label: 'Thursday', value: 'Thursday' },
                { label: 'Friday', value: 'Friday' },
                { label: 'Saturday', value: 'Saturday' },
                { label: 'Sunday', value: 'Sunday' }
            ],
            weekOptions: [
                { label: 'Week 1', value: 'Week 1' },
                { label: 'Week 2', value: 'Week 2' },
                { label: 'Week 3', value: 'Week 3' },
                { label: 'Week 4', value: 'Week 4' },
                { label: 'Week 5', value: 'Week 5' }
            ],
            monthDayOptions: Array.from({ length: 31 }, (_, i) => {
                const v = String(i + 1);
                return { label: v, value: v };
            })
        };
    }

    deepClone(value) {
        try {
            return JSON.parse(JSON.stringify(value));
        } catch (error) {
            return value;
        }
    }

    // Telemetry logger (logs non-error actions too)
    logTelemetry(operation, extraContext = {}) {
        const ctx = {
            operation,
            searchKey: this.searchKey,
            selectedApplicationId: this.selectedApplication?.id,
            selectedApplicationName: this.selectedApplication?.name,
            schema: this.schema,
            table: this.table,
            fieldsLoaded: Array.isArray(this.fields) ? this.fields.length : 0,
            ...extraContext
        };

        logError({
            message: 'Telemetry',
            componentType: 'LWC',
            componentName: 'aehcPublicationDetailsStep',
            operation,
            recordId: this.selectedApplication?.id || null,
            severity: 'Info',
            category: 'UI',
            transactionContext: JSON.stringify(ctx),
            orgEnv: LABEL_ENV_NAME
        }).catch(() => { });
    }

    handleSearch(event) {
        const value = event.target.value;
        this.searchKey = value;
        this.applicationError = '';

        if (!value) {
            this.resetAll();
            this.hasSearched = false;
            return;
        }

        clearTimeout(this.debounceTimeout);
        const searchText = value;

        this.debounceTimeout = setTimeout(async () => {
            try {
                if (searchText.length < 3) {
                    this.applications = [];
                    this.hasSearched = false;
                    return;
                }

                this.isSearchLoading = true;
                const result = await getApplications({ searchText });

                if (this.searchKey !== searchText) return;

                this.applications = result || [];
                this.hasSearched = true;

                this.logTelemetry('searchApplications', { resultCount: this.applications.length });

            } catch (e) {
                this.applications = [];
                this.hasSearched = true;
                this.logException(e, 'handleSearch');
                this.applicationError = L_ERR_SEARCH;
            } finally {
                this.isSearchLoading = false;
            }
        }, 300);
    }

    async handleSelect(event) {
        try {
            const appId = event.currentTarget.dataset.id;
            const selected = this.applications.find(a => a.id === appId);

            if (!selected) {
                this.applicationError = 'Selected application was not found.';
                return;
            }

            this.selectedApplication = { id: selected.id, name: selected.name };
            this.searchKey = selected.name;

            this.applications = [];
            this.hasSearched = false;

            // show multiple owners
            this.applicationOwner = selected.ownerNamesJoined || '';
            this.dataClassification = selected.dataClassification || '';

            this.applicationError = '';
            this.isEligible = false;
            this.resetDetailsBelowAppOnly();


            this.logTelemetry('selectApplication', {
                ownerNames: selected.ownerNames || [],
                dataClassification: this.dataClassification
            });

            const eligibility = await validateEligibility({ appId: selected.id });

            if (eligibility?.isEligible === true) {
                this.isEligible = true;
                this.applicationError = '';
                this.logTelemetry('eligibilitySuccess', { role: eligibility?.role });
            } else {
                this.isEligible = false;
                this.applicationError = eligibility?.message || 'You are not eligible to create a publication for this application.';
                this.logTelemetry('eligibilityFailed', { message: this.applicationError });
            }

        } catch (e) {
            this.logException(e, 'handleSelect');
            this.isEligible = false;
            this.applicationError = 'Unable to validate eligibility right now. Please try again.';
        }
    }

    handleDesc(event) {
        this.pubDesc = event.target.value;
        this.publicationDescriptionError = '';
    }

    handleName(event) {
        this.pubName = event.target.value?.trim();
        this.publicationValidationError = '';
    }

    handleSchema(event) {
        this.schema = event.target.value?.trim();
        this.schemaError = '';
        this.isDetailsValidated = false;
        this.clearSchemaResults();
    }

    handleTable(event) {
        this.table = event.target.value?.trim();
        this.tableError = '';
        this.isDetailsValidated = false;
        this.clearSchemaResults();
    }

    handlePublicationTypeChange(event) {
        this.publicationType = event.detail.value;
        this.publicationTypeError = '';
        this.isDetailsValidated = false;
    }

    clearValidationErrors() {
        this.applicationError = '';
        this.publicationValidationError = '';
        this.publicationDescriptionError = '';
        this.publicationTypeError = '';
        this.schemaError = '';
        this.tableError = '';
    }

    async handleValidate() {
        this.clearValidationErrors();
        this.isDetailsValidated = false;

        const validationErrors = {};

        if (!this.selectedApplication?.name) {
            validationErrors.application = L_ERR_APP_REQUIRED;
        }
        if (!this.pubName) {
            validationErrors.publicationName = 'Publication Name is required.';
        }
        if (!this.pubDesc) {
            validationErrors.description = 'Publication Description is required.';
        }
        if (!this.publicationType) {
            validationErrors.publicationType = 'Publication Type is required.';
        }
        if (!this.schema) {
            validationErrors.schema = L_ERR_SCHEMA;
        }
        if (!this.table) {
            validationErrors.table = L_ERR_SCHEMA;
        }

        if (Object.keys(validationErrors).length > 0) {
            this.applicationError = validationErrors.application || '';
            this.publicationValidationError = validationErrors.publicationName || '';
            this.publicationDescriptionError = validationErrors.description || '';
            this.publicationTypeError = validationErrors.publicationType || '';
            this.schemaError = validationErrors.schema || '';
            this.tableError = validationErrors.table || '';
            return;
        }

        try {
            this.isSchemaLoading = true;
            this.hasValidatedSchema = true;

            const result = await getTableSchemaForPublicationCreation({
                applicationName: this.selectedApplication.name,
                schemaName: this.schema,
                tableName: this.table
            });

            console.log('umang' + JSON.stringify(result));

            const mapped = (result || []).map((f, i) => ({
                id: f.id || String(i),
                name: f.name || '',
                dataType: f.dataType || '',
                description: f.description || '',
                piiLevel: f.piiLevel || '',
                cciLevel: f.cciLevel || '',
                required: f.required === true ||
                    f.required === 'YES' ||
                    f.required === 'Yes'
                    ? 'YES'
                    : 'NO'
            }));

            this.fields = mapped;
            const selectedFieldNames = new Set((this.selectedFieldsJson || []).map(f => f.fieldName));
            this.selectedFields = this.fields.filter(f => selectedFieldNames.has(f.name));
            this.selectedFieldsJson = (this.selectedFieldsJson || []).map(field => ({ ...field, labelName: field.labelName || field.fieldName }));

            if (!this.fields.length) {
                this.schemaError = 'No fields available for selected schema/table.';
                return;
            }

            const publicationResult = await validatePublicationBeforePreview({
                applicationId: this.selectedApplication.id,
                publicationName: this.pubName,
                schemaName: this.schema,
                tableName: this.table
            });
            console.log('data' + publicationResult);

            if (publicationResult?.isValid === false || publicationResult?.isValid === 'false') {
                this.publicationValidationError = publicationResult.message || 'Publication validation failed.';
                return;
            }

            this.publicationValidationError = '';
            this.isDetailsValidated = true;
            //this.logTelemetry('validateSchemaSuccess', { totalFields: this.fields.length });

        } catch (e) {
            this.logException(e, 'handleValidate');
            this.fields = [];
            this.visibleFields = [];
            this.hasValidatedSchema = true;
            this.schemaError = 'Unable to load schema fields. Please try again later.';
        } finally {
            this.isSchemaLoading = false;
        }
    }

    get showValidateButton() {
        return !this.isEditMode;
    }

    handleLoadMore() {
        this.fieldDisplayLimit += this.fieldPageSize;
        this.visibleFields = this.fields.slice(0, this.fieldDisplayLimit);
        this.logTelemetry('loadMoreFields', { visibleCount: this.visibleFields.length });
    }

    normalizeSchedule(value) {
        return {
            ...value,
            weekdays: this.normalizeScheduleList(value?.weekdays),
            multiWeekWeeks: this.normalizeScheduleList(value?.multiWeekWeeks || value?.weeks),
            multiWeekDays: this.normalizeScheduleList(value?.multiWeekDays || value?.weekdays)
        };
    }

    normalizeScheduleList(value) {
        if (Array.isArray(value)) {
            return value;
        }

        if (typeof value === 'string') {
            return value
                .split(';')
                .map(item => item.trim())
                .filter(item => item);
        }

        return [];
    }

    handleScheduleChange(event) {
        try {
            const incoming = event.detail?.schedule;
            if (!incoming) return;

            this.schedule = {
                ...this.schedule,
                ...this.normalizeSchedule(incoming)
            };
            this.logTelemetry('scheduleUpdated', { frequency: this.schedule.frequency });

        } catch (e) {
            this.logException(e, 'handleScheduleChange');
        }
    }

    async handleNext() {
        this.logTelemetry('nextClicked');

        const payload = {
            application: {
                ...this.selectedApplication,
                owner: this.applicationOwner,
                dataClassification: this.dataClassification
            },

            metadata: {
                name: this.pubName,
                description: this.pubDesc,
                publicationType: this.publicationType
            },

            schema: {
                schema: this.schema,
                table: this.table,
                fields: this.fields
            },

            selectedFields: (this.selectedFields || []).map(f => ({
                ...f,
                required: (f.required === true) || (typeof f.required === 'string' && (f.required.toLowerCase() === 'yes' || f.required.toLowerCase() === 'true'))
            })),

            selectedFieldsJson: (this.selectedFieldsJson || []).map(f => ({
                ...f,
                required: (f.required === true) || (typeof f.required === 'string' && (f.required.toLowerCase() === 'yes' || f.required.toLowerCase() === 'true'))
            })),

            schedule: {
                ...this.schedule
            }
        };

        // eslint-disable-next-line no-console
        console.log('[DetailsStep] dispatching stepdatachange', { selectedFields: this.selectedFields, selectedFieldsJson: this.selectedFieldsJson });
        console.log('[DetailsStep] outgoing payload', payload);

        try {
            this.dispatchEvent(new CustomEvent('stepdatachange', {
                detail: this.deepClone(payload)
            }));
        } catch (error) {
            console.error('[DetailsStep] stepdatachange dispatch failed', error);
        }

        //  Step 3: Go to next step
        this.dispatchEvent(new CustomEvent('next'));
    }

    //  Close: redirect to Data Publication Catalog
    handleClose() {
        this.logTelemetry('closeClicked');

        const targetUrl = `${basePath}/data-publications-catalog`;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: targetUrl }
        });
    }

    resetAll() {
        this.applications = [];
        this.selectedApplication = null;

        this.applicationOwner = '';
        this.dataClassification = '';
        this.publicationType = '';
        this.isEligible = false;
        this.applicationError = '';
        this.publicationValidationError = '';
        this.publicationDescriptionError = '';
        this.publicationTypeError = '';
        this.schemaError = '';
        this.tableError = '';
        this.isDetailsValidated = false;

        this.pubName = '';
        this.pubDesc = '';

        this.schema = '';
        this.table = '';
        this.clearSchemaResults();

        this.schedule = {
            schedulerMode: 'Scheduler (Time-Based)',
            frequency: '',
            scheduleTime: '',
            weekdays: [],
            multiWeekWeeks: [],
            multiWeekDays: [],
            monthlyDay: '',
            oneTimeDate: '',
            oneTimeTime: '',
            annualMonth: '',
            annualDay: '',
            annualDate: '',
            scheduleSummary: '',
            cronExpression: ''
        };

        this.hasSearched = false;
    }

    resetDetailsBelowAppOnly() {
        this.pubName = '';
        this.pubDesc = '';

        this.schema = '';
        this.table = '';
        this.clearSchemaResults();
        this.publicationType = '';
        this.publicationValidationError = '';
        this.publicationDescriptionError = '';
        this.publicationTypeError = '';
        this.schemaError = '';
        this.tableError = '';
        this.isDetailsValidated = false;
        this.schedule = {
            ...this.schedule,
            frequency: '',
            scheduleTime: '',
            weekdays: [],
            multiWeekWeeks: [],
            multiWeekDays: [],
            monthlyDay: '',
            oneTimeDate: '',
            oneTimeTime: '',
            annualMonth: '',
            annualDay: '',
            annualDate: '',
            scheduleSummary: '',
            cronExpression: ''
        };
    }

    clearSchemaResults() {
        this.fields = [];
        this.visibleFields = [];
        this.selectedFields = [];
        this.selectedFieldsJson = [];
        this.fieldDisplayLimit = this.fieldPageSize;
        this.hasValidatedSchema = false;
    }

    logException(error, operation, extraContext = {}) {
        try {
            const ctx = {
                operation,
                searchKey: this.searchKey,
                selectedApplicationId: this.selectedApplication?.id,
                selectedApplicationName: this.selectedApplication?.name,
                schema: this.schema,
                table: this.table,
                fieldsLoaded: Array.isArray(this.fields) ? this.fields.length : 0,
                ...extraContext
            };

            logError({
                message: this.normalizeErrorMessage(error),
                componentType: 'LWC',
                componentName: 'aehcPublicationDetailsStep',
                operation,
                recordId: this.selectedApplication?.id || null,
                severity: 'High',
                category: 'UI',
                transactionContext: JSON.stringify(ctx),
                orgEnv: LABEL_ENV_NAME
            }).catch(() => { });
        } catch (e) {
            // eslint-disable-next-line no-console
        }
    }

    normalizeErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (Array.isArray(error?.body)) return error.body.map(i => i.message).join(', ');
        if (error?.message) return error.message;
        return 'Unknown error';
    }

}