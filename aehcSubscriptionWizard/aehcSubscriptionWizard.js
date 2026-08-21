/**
 * Component: aehcSubscriptionWizard
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Main controller for subscription wizard.
 * Handles multi-step flow, schema loading, and submission.
 * 
 * 
 *  
 */
import { LightningElement, wire, track, api } from 'lwc';
import getFieldValues from '@salesforce/apex/AEHC_SubscriptionController_DP.getFieldValues';
import getTableSchema from '@salesforce/apex/AEHC_SubscriptionController_DP.getTableSchema';
import getSubscriptionDetails from '@salesforce/apex/AEHC_SubscriptionController_DP.getSubscriptionDetails';
import saveSubscription from '@salesforce/apex/AEHC_PublicationSubRequestController.saveSubscription';
import getSubscriptionPicklistOptions from '@salesforce/apex/AEHC_SubscriptionController_DP.getSubscriptionPicklistOptions';
import getPublisherScheduleDetails from '@salesforce/apex/AEHC_SubscriptionController_DP.getPublisherScheduleDetails';
import validateEligibility from '@salesforce/apex/AEHC_PublicationController.validateEligibility';
import updatePublication from '@salesforce/apex/AEHC_PublicationController.updatePublication';
import isUserPublicationBO from '@salesforce/apex/AEHC_SubscriptionController_DP.isUserPublicationBO';
import { NavigationMixin } from 'lightning/navigation';
import getSubscriptionVersionByEnv from '@salesforce/apex/AEHC_SubscriptionController_DP.getSubscriptionVersionByEnv';
import { refreshApex } from '@salesforce/apex';
import logError from "@salesforce/apex/AEHC_Logger.logError";
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import communityBasePath from '@salesforce/community/basePath';

// Custom Labels
import L_STEP_SELECT_FIELDS from '@salesforce/label/c.AEHC_DP_Step_SelectFields';
import L_STEP_SCHEDULE from '@salesforce/label/c.AEHC_DP_Step_Schedule';
import L_STEP_DESTINATION from '@salesforce/label/c.AEHC_DP_Step_Destination';
import L_STEP_REVIEW_SUBMIT from '@salesforce/label/c.AEHC_DP_Step_ReviewSubmit';

import L_SUCCESS from '@salesforce/label/c.AEHC_DP_Success';
import L_SUBMIT_SUCCESS from '@salesforce/label/c.AEHC_DP_SubmitSuccess';
import L_ERROR from '@salesforce/label/c.AEHC_DP_Error';
import L_LOAD_SCHEMA_ERROR from '@salesforce/label/c.AEHC_DP_LoadSchemaError';

import L_NO_FILTERED_DATA from '@salesforce/label/c.AEHC_DP_NoFilteredData';
import L_SEARCH_PLACEHOLDER from '@salesforce/label/c.AEHC_DP_SearchPlaceholder';
import L_ADJUST_FILTERS from '@salesforce/label/c.AEHC_DP_AdjustFilters';
import L_SEARCH_FIELDS from '@salesforce/label/c.AEHC_DP_SearchFields';
import LABEL_ENV_NAME from '@salesforce/label/c.AEHC_Environment_Name';

export default class AehcSubscriptionWizard extends NavigationMixin(LightningElement) {

    isSubscribed = false;
    currentStep = '1';
    urlRecordId;

    @track schemaData = [];
    isSchemaLoading = false;
    schemaLoadError = false;
    schemaLoadRequested = false;
    isSubmitting = false;
    isSubmitSuccess = false;
    submittedSubscriptionId;
    submittedRequestNumber;
    isVersionHistory = false;
    showPromoteComponent = false;
    @track isPromoteFlow = false;
    @track publisherScheduleData = {};
    @track picklistOptions = {
        schedulerModeOptions: [],
        frequencyOptions: [],
        weekdayOptions: [],
        weekOptions: [],
        monthDayOptions: [],
        destinationTypeOptions: [],
        databaseTypeOptions: [],
        outputFormatOptions: [],
        environmentOptions: []
    };

    isPicklistLoading = false;
    isJobRunHistory = false;


    @api editMode = false;
    @api subscriptionId;
    @api selectedEnvironment;
    @api selectedVersion;
    @api isDraft;
    descriptionChange = false;


    @track wizardData = {
        applicationName: '',
        applicationId: '',
        applicationRecordId: '',
        subscriberApplication: null,
        publicationName: '',
        publicationId: '',
        publicationRecordId: '',
        environment: '',
        description: '',
        schemaVersion: '',
        purposeOfUse: '',
        transformationRequired: false,
        selectedFields: [],
        selectedFieldsJson: [],
        schemaName: '',
        tableName: '',
        schedule: {
            schedulerMode: '',
            frequency: '',
            scheduleTime: '',
            weekdays: [],
            multiWeekWeeks: [],
            multiWeekDays: [],
            monthlyDay: '',
            oneTimeDate: '',
            oneTimeTime: '',
            scheduleSummary: '',
            cronExpression: ''
        },
      destination: {
            destinationType: '',

            includeHeader: false,
            provideCustomHeader: false,

            // Blob fields
            blobFileName: '',
            storageAccount: '',
            containerPath: '',
            outputFormat: '',

            // Database fields
            databaseType: '',
            databaseHost: '',
            databasePort: '',
            jdbcUrl: '',
            otherProperties: '',
            batchFlag: false,
            batchSize: '',
            spOnInit: '',
            spOnLoad: '',
            spOnSuccess: '',
            spOnError: '',
            muteErrorFlag: false,

            // SFTP fields
            sftpHostName: '',
            sftpPort: '',
            sftpRemotePath: '',
            sftpFileName: '',
            sftpOutputFormat: '',
            delimiter: ''
        }
    };

    labels = {
        stepSelectFields: L_STEP_SELECT_FIELDS,
        stepSchedule: L_STEP_SCHEDULE,
        stepDestination: L_STEP_DESTINATION,
        stepReviewSubmit: L_STEP_REVIEW_SUBMIT,

        success: L_SUCCESS,
        submitSuccess: L_SUBMIT_SUCCESS,
        error: L_ERROR,
        loadSchemaError: L_LOAD_SCHEMA_ERROR,

        noFilteredData: L_NO_FILTERED_DATA,
        searchPlaceholder: L_SEARCH_PLACEHOLDER,
        adjustFiltersHelp: L_ADJUST_FILTERS,
        searchFields: L_SEARCH_FIELDS
    };

    environmentValue = 'Dev';

    showEditModal = false;
    editPublicationName = '';
    editDescription = '';
    showSubscribe = false;
    showPromote = false;
    originalName = '';
    originalDescription = '';
    isUpdating = false;
    isPublicationBO = false;

/*
    @wire(validateEligibility, { publicationId: '$urlRecordId' })
    wiredEligibility({ data, error }) {
        if (data) {
            console.log('Eligibility result:', data);
            this.showSubscribe = data.showSubscribe;
            
        } else if (error) {
            console.error('Error loading button visibility', error);
        }
    }
*/
    async loadPageData() {
        
        await refreshApex(this.subscriptionDetailsResult);

        this.descriptionChange = true;

        // optional reset
        setTimeout(() => {
            this.descriptionChange = false;
        }, 100);

    }

    async initializeEditData() {
        try {

            const data = await getSubscriptionVersionByEnv({
                subscriptionId: this.subscriptionId,
                environment: this.selectedEnvironment,
                versionNumber: this.selectedVersion
            });
            console.log(200, `getSubscriptionVersionByEnv`, data);
            console.log('__ selectedFieldsJson ___',JSON.stringify(data.selectedFieldsJson));
            await this.prefillWizard(data);
            this.originalData = JSON.parse(JSON.stringify(this.wizardData));
            this.versionStatus = data.approvalStatus;
            this.versionRecordId = data.versionRecordId;
            this.versionisActive = data.versionisActive;
            this.loadSchemaFields();

        } catch (error) {
            console.log(209, `getSubscriptionVersionByEnv:error`, error);
            this.logExceptionToApex(error, 'initializeEditData');
        }
    }

    handleUpdateSuccess(event) {

        const msg = event.detail?.message;

        this.showToast('Success', msg, 'success');

        // ✅ IMPORTANT → reload page data
        this.loadPageData();
    }

    handleUpdateError(event) {
        this.showToast('Error', event.detail?.message, 'error');
    }

    isDataChanged() {

        if (!this.isEditFlow) {
            return true; // ✅ always allow in create
        }

        return JSON.stringify(this.originalData) !== JSON.stringify(this.wizardData);
    }


    prefillWizard(data) {
        console.log('************ data.selectedFieldsJson  ********* : '+ JSON.stringify(data.selectedFieldsJson));
        const selectedFields = (data.selectedFieldsJson || []).map(f => ({
            fieldName: f.fieldName ,//|| f.name,
            label: f.labelName ,//|| f.fieldName,
            order: f.order,
            dataType: f.dataType || '',
            description: f.description || '',
            nullable: f.nullable ?? null
        }));

        /*
        ✅ MERGE FULL DATA INTO wizardData
        */
        this.wizardData = {
            ...this.wizardData,

            /*
            ✅ BASIC INFO
            */
            applicationName: data.applicationName || '',
            applicationId: data.applicationId || '',
            applicationRecordId: data.applicationRecordId || '',
            publicationName: data.publicationName || '',
            publicationId: data.publicationId || '',
            publicationRecordId: data.publicationRecordId || '',
            subscriberApplication: data.consumingApplication || null,
            subscriberApplicationData: data.consumingApplication ? {
                id: data.consumingApplication,
                mainField: data.consumingApplicationName
            } : null,
            uatEnabled: data.uatEnabled ?? false,

            environment: data.environment,
            schemaVersion: this.isEditFlow
                ? (data.isDraft
                    ? data.versionNumber
                    : data.nextversionNumber)
                : data.versionNumber,

            description: data.description || '',

            /*
            ✅ BUSINESS
            */
            purposeOfUse: data.purposeOfUse || '',
            transformationRequired: data.transformationRequired || false,

            /*
            ✅ SELECTED FIELDS (IMPORTANT)
            */
            selectedFieldsJson: data.selectedFieldsJson || [],
            selectedFields: selectedFields,

            /*
            ✅ SCHEDULE
            */
            schedule: {
                ...this.wizardData.schedule,

                schedulerMode: data.schedule?.schedulerMode || '',
                frequency: data.schedule?.frequency || '',
                scheduleTime: data.schedule?.scheduleTime || '',
                weekdays: data.schedule?.weekdays || [],
                multiWeekWeeks: data.schedule?.multiWeekWeeks || [],
                multiWeekDays: data.schedule?.multiWeekDays || [],
                monthlyDay: data.schedule?.monthlyDay || '',
                oneTimeDate: data.schedule?.oneTimeDate || '',
                oneTimeTime: data.schedule?.oneTimeTime || '',
                scheduleSummary: data.schedule?.scheduleSummary || '',
                cronExpression: data.schedule?.cronExpression || ''
            },

            /*
            ✅ DESTINATION (FULL MAPPING)
            */
            destination: {
                ...this.wizardData.destination,

                destinationType: data.destination?.destinationType || '',

                includeHeader: data.destination?.includeHeader || false,
                provideCustomHeader: data.destination?.provideCustomHeader || false,

                // ✅ BLOB
                storageAccount: data.destination?.storageAccount || '',
                containerPath: data.destination?.containerPath || '',
                outputFormat: data.destination?.outputFormat || '',
                blobFileName: data.destination?.blobFileName || '',

                // ✅ DATABASE
                databaseType: data.destination?.databaseType || '',
                databaseHost: data.destination?.databaseHost || '',
                databasePort: data.destination?.databasePort || '',
                jdbcUrl: data.destination?.jdbcUrl || '',
                otherProperties: data.destination?.otherProperties || '',
                batchFlag: data.destination?.batchFlag || false,
                batchSize: data.destination?.batchSize || '',
                spOnInit: data.destination?.spOnInit || '',
                spOnLoad: data.destination?.spOnLoad || '',
                spOnSuccess: data.destination?.spOnSuccess || '',
                spOnError: data.destination?.spOnError || '',
                muteErrorFlag: data.destination?.muteErrorFlag || false,

                // ✅ SFTP
                sftpHostName: data.destination?.sftpHostName || '',
                sftpPort: data.destination?.sftpPort || '',
                sftpRemotePath: data.destination?.sftpRemotePath || '',
                sftpFileName: data.destination?.sftpFileName || '',
                sftpOutputFormat: data.destination?.sftpOutputFormat || '',
                
                delimiter: data.destination?.delimiter || ''
            }
        };
        console.log('Data' + JSON.stringify(this.wizardData));
    }

    handleCloseModal() {
        this.showEditModal = false;
    }

    getNextVersion(v) {

        if (!v) return '1';

        /*
        ✅ Handle formats:
        1
        v1
        V2
        */
        const numberMatch = v.match(/\d+/);

        if (!numberMatch) {
            return v; // fallback
        }

        const next = parseInt(numberMatch[0], 10) + 1;

        /*
        ✅ Preserve prefix (like v)
        */
        if (v.toLowerCase().startsWith('v')) {
            return `v${next}`;
        }

        return String(next);
    }


    get isEditFlow() {
        return this.editMode === true || this.editMode === 'true';
    }


    get effectiveRecordId() {
        return this.isEditFlow ? this.subscriptionId : this.urlRecordId;
    }

    assetStatus = false;
    handleEnvironmentChange(event) {
        this.environmentValue = event.detail.selectedEnvironment;
        this.showPromote = event.detail.active === 'Active' ;
        console.log('this.showPromote'+this.showPromote);
        this.showSubscribe =this.showPromote ;
        console.log('wizard : ' + event.detail);
        console.log(this.environmentValue);
    }
    handleStatus(event)
    {
        
        console.log('this.showPromote'+this.showPromote);
        this.showPromote = event.detail.active === 'Active' ; 
               
        console.log('this.showPromote'+this.showPromote);
        
        console.log('this.showSubscribe : '+this.showSubscribe);
    
        this.showSubscribe =  this.showPromote ;
        console.log('this.showSubscribe : '+this.showSubscribe);
    }

    connectedCallback() {

        this.loadPicklistOptions();

        if (this.editMode) {

            this.isSubscribed = true;
            this.currentStep = '1';

            this.initializeEditData();
        }

    }

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        try {
            console.log('___________ Test : ');
            if (pageRef?.state?.env) {
                console.log('___________ : ' + pageRef.state.env);
                this.environmentValue = pageRef.state.env;
            }
            if (pageRef?.state?.id) {
                this.urlRecordId = pageRef.state.id;
                this.loadPublicationRole();
                if (!this.schemaLoadRequested) {
                    this.schemaLoadRequested = true;
                    this.loadSchemaFields();
                    this.loadPublisherSchedule();
                    this.loadButtonVisibility();
                }
            }


        } catch (error) {

            console.log(error);
            this.logExceptionToApex(error, 'getPageReference');
        }
    }

    @wire(getSubscriptionDetails, { recordId: '$urlRecordId' })
    wiredData(result) {
        this.subscriptionDetailsResult = result;
        const { data, error } = result;
        if (data) { 
            this.wizardData = {
                ...this.wizardData,
                applicationName: data.applicationName,
                applicationId: data.applicationId,
                applicationRecordId: data.applicationRecordId,
                publicationName: data.publicationName,
                publicationId: data.publicationId,
                publicationRecordId: data.publicationRecordId,
                environment: data.environment,
                schemaVersion: '1',
                purposeOfUse: data.purposeOfUse || '',
                schemaName: data.schemaName || '',
                tableName: data.tableName || '',
                description: data.description || ''
            };
        } else if (error) {
            this.logExceptionToApex(
                error,
                'wiredData',
                this.urlRecordId,
                {
                    source: 'getSubscriptionDetails'
                }
            );
        }
    }

    async loadPublicationRole() {
        try {
            this.isPublicationBO = await isUserPublicationBO({
                publicationId: this.urlRecordId
            });

            console.log('isPublicationBO:', this.isPublicationBO);

        } catch (error) {
            console.error('error' + error);
        }
    }

    async loadPublisherSchedule() {
        try {
            const data = await getPublisherScheduleDetails({
                recordId: this.urlRecordId
            });

            this.publisherScheduleData = data;

        } catch (error) {
            this.logExceptionToApex(error, 'loadPublisherSchedule');
        }
    }

    async loadSchemaFields() {
        try {
            console.log('editmode' + this.editMode);
            console.log('this.wizardData.publicationRecordId' + this.wizardData.publicationRecordId);


            const recordId = this.editMode
                ? this.wizardData.publicationRecordId
                : this.urlRecordId;

            if (!recordId) {
                return;
            }


            console.log('data inside method');
            this.isSchemaLoading = true;
            this.schemaLoadError = false;

            const data = await getFieldValues({
                recordId: recordId, env : this.environmentValue
            });
            console.log('data' + JSON.stringify(data));
            this.schemaData = data.map((row) => ({
                ...row,
                isSelected: false
            }));

        } catch (error) {
            console.log('error' + JSON.stringify(error));
            this.logExceptionToApex(
                error,
                'loadSchemaFields',
                this.urlRecordId,
                {
                    source: 'getTableSchema',
                    action: 'Schema metadata load'
                }
            );
            console.log(error);
            this.schemaData = [];
            this.schemaLoadError = true;

        } finally {
            this.isSchemaLoading = false;
        }
    }

    async loadPicklistOptions() {
        try {
            this.isPicklistLoading = true;

            const options = await getSubscriptionPicklistOptions();

            this.picklistOptions = {
                schedulerModeOptions: options.schedulerModeOptions || [],
                frequencyOptions: options.frequencyOptions || [],
                weekdayOptions: options.weekdayOptions || [],
                weekOptions: options.weekOptions || [],
                monthDayOptions: options.monthDayOptions || [],
                destinationTypeOptions: options.destinationTypeOptions || [],
                databaseTypeOptions: options.databaseTypeOptions || [],
                outputFormatOptions: options.outputFormatOptions || [],
                environmentOptions: options.environmentOptions || []
            };

            this.applyDefaultScheduleValues();

        } catch (error) {
            this.logExceptionToApex(
                error,
                'loadPicklistOptions',
                this.urlRecordId,
                {
                    source: 'getSubscriptionPicklistOptions'
                }
            );

            this.applyPicklistFallbacks();

        } finally {
            this.isPicklistLoading = false;
        }
    }

    applyPicklistFallbacks() {
        this.picklistOptions = {
            schedulerModeOptions: [
                {
                    label: 'Scheduler (Time-Based)',
                    value: 'Scheduler (Time-Based)'
                },
                {
                    label: 'Submon (Triggered on Publication Completion)',
                    value: 'Submon (Triggered on Publication Completion)'
                }
            ],
            frequencyOptions: [
                { label: 'Daily', value: 'Daily' },
                { label: 'Weekly', value: 'Weekly' },
                { label: 'Multi-Weekly', value: 'Multi-Weekly' },
                { label: 'Monthly', value: 'Monthly' },
                { label: 'One-Time Load', value: 'One-Time Load' }
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
            monthDayOptions: Array.from({ length: 31 }, (_, index) => {
                const value = String(index + 1);
                return { label: value, value: value };
            }),
            destinationTypeOptions: [
                { label: 'Database', value: 'Database' },
                { label: 'SFTP', value: 'SFTP' },
                { label: 'BLOB', value: 'BLOB' }
            ],
            databaseTypeOptions: [
                { label: 'SQL Server', value: 'SQL Server' },
                { label: 'Oracle', value: 'Oracle' }
            ],
            outputFormatOptions: [
                { label: 'CSV', value: 'CSV' },
                { label: 'XML', value: 'XML' }
            ],
            environmentOptions: [
                { label: 'Dev', value: 'Dev' },
                { label: 'QA', value: 'QA' },
                { label: 'UAT', value: 'UAT' },
                { label: 'Production', value: 'Production' }
            ]
        };

        this.applyDefaultScheduleValues();
    }

    applyDefaultScheduleValues() {
        const schedulerModeDefault =
            this.picklistOptions.schedulerModeOptions?.[0]?.value ||
            'Scheduler (Time-Based)';

        const frequencyDefault =
            this.picklistOptions.frequencyOptions?.[0]?.value ||
            'Daily';

        this.wizardData = {
            ...this.wizardData,
            schedule: {
                ...this.wizardData.schedule,
                schedulerMode: this.wizardData.schedule.schedulerMode || schedulerModeDefault,
                frequency: this.wizardData.schedule.frequency || frequencyDefault
            }
        };
    }

    get isStepOne() {
        return this.isSubscribed && this.currentStep === '1';
    }

    get isStepTwo() {
        return this.isSubscribed && this.currentStep === '2';
    }

    get isStepThree() {
        return this.isSubscribed && this.currentStep === '3';
    }

    get isStepFour() {
        return this.isSubscribed && this.currentStep === '4';
    }

    get submittedSubscriptionUrl() {
        return this.submittedSubscriptionId
            ? `${communityBasePath}/manage-subscriptions?subscriptionId=${this.submittedSubscriptionId}&env=${this.savedEnvironment}&ver=${this.savedVersion}`
            : '#';
    }

    // Handle promote action    

    handlePromote() {
        console.log('promote called insubscription wizard');
        this.isSubscribed = false;
        this.showPromoteComponent = true;
        this.isPromoteFlow = true;
    }
    isSubscriberModal = false;
    // handle promote success 
    handleSubscribers() {

        if (this.isEditFlow) {


            const isRejected = this.versionStatus === 'Rejected';

            if (isRejected) {
                console.log('✅ UPDATE existing version');
            } else {
                console.log('✅ CREATE new version');
            }
        }
        this.isSubscribed = false;
        this.isSubscriberModal = true;
        this.showPromoteComponent = false;
        this.isPromoteFlow = false;
    }

    closeSubscriberModal() {
        console.log('close modal called');
        this.isSubscriberModal = false;
    }

    handleJobHistory() {
        this.isJobRunHistory = true;
    }
    closeJobHistoryModal() {
        console.log('close modal called');
        this.isJobRunHistory = false;
    }


    handlePromoteSuccess() {
        this.showPromoteComponent = false;
        this.isPromoteFlow = false;
    }
    selectedEnv;
    handlePromoteClose(event) {
        this.showPromoteComponent = false;
        this.isPromoteFlow = false;
        this.environmentValue = event.detail;
        this.selectedEnv = event.detail;
        if (this.editMode) {
            this.isSubscribed = false;
        }
    }

    handleSubscribe() {
        this.isSubscribed = true;
        this.currentStep = '1';
        this.isSubmitSuccess = false;
        this.submittedSubscriptionId = null;
        this.submittedRequestNumber = null;
    }

    handleStepDataChange(event) {
        try {
            console.log('event.detail.selectedFieldsJson  ______________: ',JSON.stringify(event.detail.selectedFieldsJson));
            this.wizardData = {
                ...this.wizardData,
                ...event.detail,

                schedule: event.detail.schedule
                    ? {
                        ...this.wizardData.schedule,
                        ...event.detail.schedule
                    }
                    : this.wizardData.schedule,

                destination: event.detail.destination
                    ? {
                        ...this.wizardData.destination,
                        ...event.detail.destination
                    }
                    : this.wizardData.destination,

                selectedFieldsJson: event.detail.selectedFieldsJson
                    ? [...event.detail.selectedFieldsJson]
                    : this.wizardData.selectedFieldsJson
            };
        } catch (error) {
            this.logExceptionToApex(
                error,
                'handleStepDataChange',
                this.urlRecordId,
                {
                    eventDetailPresent: !!event?.detail
                }
            );
        }
    }

    handleEditPublication() {
        this.editPublicationName = this.wizardData.publicationName;
        this.editDescription = this.wizardData.description;

        this.originalName = this.wizardData.publicationName;
        this.originalDescription = this.wizardData.description;

        this.showEditModal = true;
    }
    handleNameChange(event) {
        this.editPublicationName = event.target.value;
    }

    handleDescChange(event) {
        this.editDescription = event.target.value;
    }

    closeModal() {
        console.log('closemodal called');
        this.showEditModal = false;
    }
    get isSubmitDisabled() {
        return (
            this.isUpdating ||
            !this.editPublicationName?.trim() ||
            !this.editDescription?.trim() ||
            (
                this.editPublicationName === this.originalName &&
                this.editDescription === this.originalDescription
            )
        );
    }
    async handleUpdate() {

        if (this.isSubmitDisabled) {
            return;
        }

        this.isUpdating = true;

        try {
            await updatePublication({
                publicationId: this.wizardData.publicationRecordId,
                newName: this.editPublicationName.trim(),
                newDescription: this.editDescription.trim()
            });

            // ✅ Sync UI
            await this.loadPageData();
            this.wizardData = {
                ...this.wizardData,
                publicationName: this.editPublicationName,
                description: this.editDescription
            };


            this.showEditModal = false;

            this.showToast('Success', 'Publication updated successfully', 'success');

        } catch (error) {
            this.showToast('Error', this.normalizeErrorMessage(error), 'error');
        } finally {
            this.isUpdating = false;
        }
    }


    goToStepOne() {
        this.currentStep = '1';
    }

    goToStepTwo() {
        this.currentStep = '2';
    }

    goToStepThree() {
        this.currentStep = '3';
    }

    goToStepFour() {
        this.currentStep = '4';
    }

    handleCancel() {
        if (this.isEditFlow) {
            this.dispatchEvent(new CustomEvent('close'));
            return;
        }

        this.isSubscribed = false;
        this.currentStep = '1';
        this.isSubmitSuccess = false;
        this.submittedSubscriptionId = null;
        this.submittedRequestNumber = null;
    }



    handleSubmit() {
        if (this.isSubmitting) {
            console.warn('[Subscription Submit] Duplicate submit ignored. Submit already in progress.');
            return;
        }
        if (!this.isEditFlow) {
            return this.executeCommonSave();
        }
        if (!this.isDataChanged()) {
            this.showToast('Info', 'No changes detected', 'info');
            return;
        }


        const isRejected = this.versionStatus === 'Rejected';
        const isApproved = this.versionStatus === 'Active';
        const isActive = this.versionisActive === true;


        let editAction;

        if (isRejected) {
            editAction = 'UPDATE';
        } else if (isApproved && isActive) {
            editAction = 'CREATE_NEW_VERSION';
        }

        this.cleanupScheduleData();
        this.cleanupDestinationData();



        /*if (editAction === 'CREATE_NEW_VERSION') {
                this.wizardData.schemaVersion = this.getNextVersion(this.wizardData.schemaVersion);
            }*/

        this.wizardData.editMode = true;
        this.wizardData.editAction = editAction;
        this.wizardData.versionRecordId = this.versionRecordId;
        console.log('Datathis.wizardData.editMode' + this.wizardData.editMode);
        console.log('this.wizardData.editAction' + this.wizardData.editAction);
        console.log('this.wizardData.versionRecordId' + this.wizardData.versionRecordId);
        this.executeCommonSave();
    }

    cleanupScheduleData() {

        const s = this.wizardData.schedule;

        if (s.schedulerMode === 'Submon (Triggered on Publication Completion)') {

            this.wizardData.schedule = {
                schedulerMode: s.schedulerMode,
                frequency: '',
                scheduleTime: '',
                weekdays: [],
                multiWeekWeeks: [],
                multiWeekDays: [],
                monthlyDay: '',
                oneTimeDate: '',
                oneTimeTime: '',
                annualDate: '',
                scheduleSummary: 'Triggered on publisher completion.',
                cronExpression: ''
            };

            return;
        }

        this.wizardData.schedule = {
            schedulerMode: s.schedulerMode,
            frequency: s.frequency,
            scheduleTime: s.scheduleTime,
            weekdays: s.frequency === 'Weekly' ? (s.weekdays || []) : [],
            multiWeekWeeks: s.frequency === 'Multi-Weekly' ? (s.multiWeekWeeks || []) : [],
            multiWeekDays: s.frequency === 'Multi-Weekly' ? (s.multiWeekDays || []) : [],
            monthlyDay: s.frequency === 'Monthly' ? (s.monthlyDay || '') : '',
            oneTimeDate: s.frequency === 'One-Time Load' ? (s.oneTimeDate || '') : '',
            oneTimeTime: s.frequency === 'One-Time Load' ? (s.oneTimeTime || '') : '',
            annualDate: s.frequency === 'Annual' ? (s.annualDate || '') : '',
            scheduleSummary: s.scheduleSummary || '',
            cronExpression: s.cronExpression || ''
        };
    }

    cleanupDestinationData() {

        const d = this.wizardData.destination;

        this.wizardData.destination = {
            destinationType: d.destinationType,

            /*
            ✅ BLOB
            */
            storageAccount: d.destinationType === 'BLOB' ? (d.storageAccount || '') : '',
            containerPath: d.destinationType === 'BLOB' ? (d.containerPath || '') : '',
            outputFormat: d.destinationType === 'BLOB' ? (d.outputFormat || '') : '',
            blobFileName: d.destinationType === 'BLOB' ? (d.blobFileName || '') : '',

            /*
            ✅ DATABASE
            */
            databaseType: d.destinationType === 'Database' ? (d.databaseType || '') : '',
            databaseHost: d.destinationType === 'Database' ? (d.databaseHost || '') : '',
            databasePort: d.destinationType === 'Database' ? (d.databasePort || '') : '',
            jdbcUrl: d.destinationType === 'Database' ? (d.jdbcUrl || '') : '',
            otherProperties: d.destinationType === 'Database' ? (d.otherProperties || '') : '',
            batchFlag: d.destinationType === 'Database' ? (d.batchFlag || false) : false,
            batchSize: d.destinationType === 'Database' ? (d.batchSize || '') : '',
            spOnInit: d.destinationType === 'Database' ? (d.spOnInit || '') : '',
            spOnLoad: d.destinationType === 'Database' ? (d.spOnLoad || '') : '',
            spOnSuccess: d.destinationType === 'Database' ? (d.spOnSuccess || '') : '',
            spOnError: d.destinationType === 'Database' ? (d.spOnError || '') : '',
            muteErrorFlag: d.destinationType === 'Database' ? (d.muteErrorFlag || false) : false,

            /*
            ✅ SFTP
            */
            sftpHostName: d.destinationType === 'SFTP' ? (d.sftpHostName || '') : '',
            sftpPort: d.destinationType === 'SFTP' ? (d.sftpPort || '') : '',
            sftpRemotePath: d.destinationType === 'SFTP' ? (d.sftpRemotePath || '') : '',
            sftpFileName: d.destinationType === 'SFTP' ? (d.sftpFileName || '') : '',
            sftpOutputFormat: d.destinationType === 'SFTP' ? (d.sftpOutputFormat || '') : '',
            includeHeader: d.includeHeader || false,
            provideCustomHeader: d.provideCustomHeader || false,
            delimiter: d.destinationType === 'SFTP' ? (d.delimiter || '') : ''
        };
    }

    executeCommonSave() {
        this.isSubmitting = true;
        this.isSubmitSuccess = false;

        const requestJson = JSON.stringify(this.wizardData);
        console.log('[Subscription Submit] Started', {
            publicationRecordId: this.wizardData.publicationRecordId,
            applicationRecordId: this.wizardData.applicationRecordId,
            publicationId: this.wizardData.publicationId,
            applicationId: this.wizardData.applicationId,
            currentStep: this.currentStep
        });
        saveSubscription({
            requestJson: requestJson,
            publicationRecordId: this.wizardData.publicationRecordId,
            applicationRecordId: this.wizardData.applicationRecordId
        })
            .then((result) => {

                this.submittedSubscriptionId = result?.subscriptionId;
                this.submittedRequestNumber = result?.requestNumber;

                this.savedEnvironment = result?.environment;
                this.savedVersion = result?.schemaVersion;
                this.actionType = result?.actionType;


                console.log('[Subscription Submit] Success', {
                    subscriptionId: this.submittedSubscriptionId,
                    requestNumber: this.submittedRequestNumber
                });

                this.isSubmitSuccess = true;
                this.currentStep = '4';


                let message;

                if (this.actionType === 'CREATE') {
                    message = `Subscription created successfully (Env: ${this.savedEnvironment}, Version: ${this.savedVersion})`;
                }
                else if (this.actionType === 'UPDATE') {
                    message = `Subscription updated successfully`;
                }
                else if (this.actionType === 'NEW_VERSION') {
                    message = `New version ${this.savedVersion} created in ${this.savedEnvironment}`;
                }

                this.showToast('Success', message, 'success');

            })
            .catch(error => {
                console.error('[Subscription Submit] Failed', {
                    message: this.normalizeErrorMessage(error),
                    error: error,
                    publicationRecordId: this.wizardData?.publicationRecordId,
                    applicationRecordId: this.wizardData?.applicationRecordId,
                    publicationId: this.wizardData?.publicationId,
                    applicationId: this.wizardData?.applicationId
                });

                this.logExceptionToApex(
                    error,
                    'handleSubmit',
                    this.urlRecordId,
                    {
                        source: 'AEHC_PublicationSubRequestController.saveSubscription',
                        publicationRecordId: this.wizardData?.publicationRecordId,
                        applicationRecordId: this.wizardData?.applicationRecordId,
                        publicationId: this.wizardData?.publicationId,
                        applicationId: this.wizardData?.applicationId
                    }
                );

                this.showToast(
                    this.labels.error,
                    this.normalizeErrorMessage(error),
                    'error'
                );
            })
            .finally(() => {
                this.isSubmitting = false;

                console.log('[Subscription Submit] Completed', {
                    isSubmitting: this.isSubmitting,
                    isSubmitSuccess: this.isSubmitSuccess
                });
            });
    }

    logExceptionToApex(error, operation = 'unknown', recordId = null, extraContext = {}) {
        try {
            const transactionContext = {
                currentStep: this.currentStep,
                isSubscribed: this.isSubscribed,
                publicationId: this.wizardData?.publicationId,
                publicationName: this.wizardData?.publicationName,
                applicationName: this.wizardData?.applicationName,
                selectedFieldsCount: this.wizardData?.selectedFields?.length || 0,
                scheduleMode: this.wizardData?.schedule?.schedulerMode,
                scheduleFrequency: this.wizardData?.schedule?.frequency,
                ...extraContext
            };

            logError({
                message: this.normalizeErrorMessage(error),
                componentType: 'LWC',
                componentName: 'aehcSubscriptionWizard',
                operation: operation,
                recordId: recordId,
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

        if (Array.isArray(error?.body)) {
            return error.body.map(item => item.message).join(', ');
        }

        return 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
    handleEditSuccess(event) {
        const updatedData = event.detail;

        this.wizardData = {
            ...this.wizardData,
            ...updatedData
        };

        this.showEditModal = false;

        this.showToast('Success', 'Publication updated successfully', 'success');
    }
    handleVersionHistory() {
        this.isVersionHistory = true;
    }

    closeVersionHistoryModal() {
        this.isVersionHistory = false;
    }

}