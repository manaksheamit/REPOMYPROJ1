/**
 * Component: aehcPublicationCreationWizard
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Handles multi-step publication creation flow including submission
 * and redirect to publication detail page.
 */

import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import createPublication from '@salesforce/apex/AEHC_PublicationController.createPublication';
import editPublication from '@salesforce/apex/AEHC_PublicationController.editPublication';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import L_CREATE from '@salesforce/label/c.AEHC_DP_Create_Publication';
import L_SUCCESS from '@salesforce/label/c.AEHC_DP_Success_Message';
import L_ERR_TITLE from '@salesforce/label/c.AEHC_DP_Error_Title';
import L_ERR_CREATE from '@salesforce/label/c.AEHC_DP_Error_Create_Publication';
import logError from '@salesforce/apex/AEHC_Logger.logError';
import LABEL_ENV_NAME from '@salesforce/label/c.AEHC_Environment_Name';
import basePath from '@salesforce/community/basePath';
import getPublicationForEdit from '@salesforce/apex/AEHC_PublicationController.getPublicationForEdit';
import getTableSchemaForPublicationCreation from '@salesforce/apex/AEHC_PublicationController.getTableSchemaForPublicationCreation';

export default class AehcPublicationCreationWizard extends LightningElement {

    currentStep = '1';
    isReturningToStepOne = false;
    @track wizardData = {
        application: {},
        metadata: {},
        schema: {},
        schedule: {},
        selectedFields: [],
        selectedFieldsJson: []
    };
    publicationId;
    isEditMode = false;
    labels = {
        success: L_SUCCESS,
        errorTitle: L_ERR_TITLE,
        errorCreate: L_ERR_CREATE
    };

    isSubmitSuccess = false;
    submittedPublicationRecordId;
    submittedPublicationId;
    submittedPublicationName;
    publicationeditmesg;
    isSubmitting = false;

    /* -------- STEP CONTROL -------- */

    get isStepOne() { return this.currentStep === '1'; }
    get isStepThree() { return this.currentStep === '3'; }
    get isStepFour() { return this.currentStep === '4'; }
    goToStepFour() { this.currentStep = '4'; }
    goToStepOne() { this.currentStep = '1'; }
    goToStepThree() { this.currentStep = '3'; }

    goToPreviousStep(event) {
        const fromStep = event?.detail?.fromStep || '3';
        if (fromStep === '4') {
            this.currentStep = '3';
        } else if (fromStep === '3') {
            this.isReturningToStepOne = true;
            this.currentStep = '1';
        }
    }

    @wire(CurrentPageReference)
    setPageReference(pageRef) {

        if (pageRef?.state?.id) {
            this.publicationId = pageRef.state.id;
            this.isEditMode = true;
            this.loadPublication();
        }
    }

    async loadPublication() {
        try {
            const result = await getPublicationForEdit({ publicationId: this.publicationId });
            if (result) {
                const parsedJson = result.selectedFieldsJson ? JSON.parse(result.selectedFieldsJson) : [];
                    // normalize parsed fields so downstream components have consistent keys
                    parsedJson.forEach(field => {
                        field.fieldName = field.fieldName || field.name || field.id || '';
                        field.labelName = field.labelName || field.label || field.alias || field.fieldName || field.name;
                        field.alias = field.alias || field.labelName || field.fieldName || field.name;
                        field.id = field.fieldName || field.name || field.id || '';
                        field.dataType = field.dataType || '';
                        field.description = field.description || '';
                        field.cciLevel = field.cciLevel || field.cci || '';
                        field.cci = field.cciLevel || field.cci || '';
                        field.piiLevel = field.piiLevel || field.pii || '';
                        field.pii = field.piiLevel || field.pii || '';
                        field.required = (field.required === true) || (typeof field.required === 'string' && (field.required.toLowerCase() === 'yes' || field.required.toLowerCase() === 'true'));
                    });
                    try {
                        const schemaFields = await getTableSchemaForPublicationCreation({
                            applicationName: result.applicationName,
                            schemaName: result.schemaName,
                            tableName: result.tableName
                        });

                        const schemaByName = new Map((schemaFields || []).map(f => [f.name, f]));

                        parsedJson.forEach(f => {
                            const sf = schemaByName.get(f.fieldName || f.name);
                            if (sf) {
                                f.dataType = f.dataType || sf.dataType || '';
                                f.description = f.description || sf.description || '';
                                f.cciLevel = f.cciLevel || f.cci || sf.cciLevel || sf.cci || '';
                                f.piiLevel = f.piiLevel || sf.piiLevel || '';
                            }
                        });
                    } catch (e) {
                        // if enrichment fails, continue with parsedJson as-is
                        console.warn('Schema enrichment failed', e);
                    }

                    this.wizardData = {
                        application: {id: result.applicationId, name: result.applicationName, owner: result.applicationOwner, dataClassification: result.dataClassification},
                        metadata: { name: result.publicationName, description: result.description, publicationType: result.publicationType},
                        schema: {schema: result.schemaName, table: result.tableName, fields: []},
                        schedule: {...(result.schedule || {})},
                        selectedFields: parsedJson.map((f, i) => ({
                            // components expect `name` and optionally `alias`
                            name: f.fieldName || f.name,
                            alias: f.labelName || f.alias || f.fieldName || f.name,
                            id: f.id || f.fieldName || f.name || `${f.fieldName || f.name}-${i}`,
                            order: f.order || i + 1,
                            dataType: f.dataType || '',
                            description: f.description || '' ,
                            cciLevel: f.cciLevel || '',
                            cci: f.cciLevel || f.cci || '',
                            piiLevel: f.piiLevel || '',
                            pii: f.piiLevel || '',
                            required: f.required === true
                        })),
                        selectedFieldsJson: parsedJson.map((f, i) => ({
                            id: f.id || f.fieldName || f.name || `${f.fieldName || f.name}-${i}`,
                            fieldName: f.fieldName || f.name,
                            labelName: f.labelName || f.alias || f.fieldName || f.name,
                            alias: f.alias || f.labelName || f.fieldName || f.name,
                            dataType: f.dataType || '',
                            description: f.description || '',
                            cciLevel: f.cciLevel || f.cci || '',
                            cci: f.cciLevel || f.cci || '',
                            piiLevel: f.piiLevel || '',
                            pii: f.piiLevel || '',
                            required: f.required === true,
                            order: f.order || i + 1
                        }))
                    };
            }
            console.log('wizarddata'+JSON.stringify(this.wizardData));
        } catch (e) {
            this.logException(e, 'loadPublication');
        }
    }

    get cardTitle() {
        return this.isEditMode ? 'Edit Publication' : this.labels.createPublication;
    }

    handleDataRestored(event) {
        // Reset the returning flag after data has been restored
        if (event.detail?.dataLoaded) {
            this.isReturningToStepOne = false;
        }
    }

    /* -------- DATA FLOW -------- */

    handleStepDataChange(event) {

        const data = event.detail;
        // eslint-disable-next-line no-console
        try {
            console.log('[Wizard] handleStepDataChange received', JSON.stringify(data));
        } catch (e) {
            console.log('[Wizard] handleStepDataChange received (unserializable)', data);
        }

        const normalizeKey = f => f.fieldName || f.name || f.id || '';

        const mergedSelectedFields = data.selectedFields || [];
        const mergedSelectedFieldsJson = data.selectedFieldsJson || [];

        this.wizardData = {
            ...this.wizardData,

            application:
                data.application ||
                this.wizardData.application,

            metadata:
                data.metadata
                    ? {
                        ...this.wizardData.metadata,
                        ...data.metadata
                    }
                    : this.wizardData.metadata,

            schema:
                data.schema
                    ? {
                        ...this.wizardData.schema,
                        ...data.schema
                    }
                    : this.wizardData.schema,

            schedule:
                data.schedule
                    ? {
                        ...this.wizardData.schedule,
                        ...data.schedule
                    }
                    : this.wizardData.schedule,

            selectedFields: mergedSelectedFields,

            selectedFieldsJson: mergedSelectedFieldsJson
        };
    }

    get finalData() {
        return this.wizardData;
    }

    get submittedPublicationUrl() {
        return this.submittedPublicationRecordId
            ? `${basePath}/data-publication-details?id=${this.submittedPublicationRecordId}`
            : '#';
    }

    /* -------- SUBMIT -------- */

    async handleSubmit() {
        this.isSubmitting = true;

        try {
            let result;

            // log final payload for debugging before submit
            // ensure selectedFields exists: prefer normalized selectedFields, but fall back to selectedFieldsJson
            if ((!this.finalData.selectedFields || this.finalData.selectedFields.length === 0)
                && this.finalData.selectedFieldsJson && this.finalData.selectedFieldsJson.length > 0) {
                this.wizardData.selectedFields = this.finalData.selectedFieldsJson.map((f, i) => ({
                    name: f.fieldName || f.name,
                    alias: f.alias || f.labelName || f.fieldName || f.name,
                    id: f.id || `${f.fieldName || f.name}-${i}`,
                    order: f.order || i + 1,
                    dataType: f.dataType || '',
                    description: f.description || '',
                    cciLevel: f.cciLevel || f.cci || '',
                    cci: f.cciLevel || f.cci || '',
                    piiLevel: f.piiLevel || f.pii || '',
                    pii: f.piiLevel || f.pii || '',
                    required: f.required === true
                }));
            }

            // eslint-disable-next-line no-console
            try {
                console.log('[Wizard] submitting finalData', JSON.stringify(this.finalData));
            } catch (e) {
                console.log('[Wizard] submitting finalData (unserializable)', this.finalData);
            }

            if (this.isEditMode) {
                result = await editPublication({ publicationId: this.publicationId, payloadJson: JSON.stringify(this.finalData) });
            } else {
                result = await createPublication({ requestJson: JSON.stringify(this.finalData) });
            }

            if (!result) {
                throw new Error('Empty response from server');
            }

            this.submittedPublicationRecordId = result.publicationRecordId;
            this.submittedPublicationId = result.publicationId;
            this.submittedPublicationName = result.publicationName;
            this.publicationeditmesg = result.message || '' ;

            // MOVE TO SUCCESS STEP
            this.currentStep = '4';
            this.isSubmitSuccess = true;

        } catch (e) {
            this.logException(e, 'handleSubmit');

            this.showToast(
                this.labels.errorTitle,
                e?.body?.message || e?.message || this.labels.errorCreate,
                'error'
            );

        } finally {
            this.isSubmitting = false;
        }
    }

    get successMessage() {
        return this.isEditMode ? this.publicationeditmesg : this.labels.success;
    }
    logException(error, operation) {
        try {
            logError({
                message: error?.message || 'Error',
                componentType: 'LWC',
                componentName: 'aehcPublicationCreationWizard',
                operation,
                recordId: null,
                severity: 'High',
                category: 'UI',
                transactionContext: JSON.stringify(this.wizardData),
                orgEnv: LABEL_ENV_NAME
            }).catch(() => { });
        } catch (e) { }
    }
}