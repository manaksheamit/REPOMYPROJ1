/**
 * Component: aehcReviewSubmitStep
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Review and Submit step for Publication/Subscription wizard.
 * Displays summary data and triggers final submission event.
 */
import { LightningElement, api } from 'lwc';
import L_APP_NAME from '@salesforce/label/c.AEHC_DP_AppName';
import L_PUB_NAME from '@salesforce/label/c.AEHC_DP_PubName';
import L_PUB_ID from '@salesforce/label/c.AEHC_DP_PubId';
import L_ENVIRONMENT from '@salesforce/label/c.AEHC_DP_Environment';
import L_SCHEMA_VERSION from '@salesforce/label/c.AEHC_DP_SchemaVersion';
import L_PURPOSE_USE from '@salesforce/label/c.AEHC_DP_PurposeUse';
import L_TRANSFORM_REQ from '@salesforce/label/c.AEHC_DP_TransformReq';

import L_SELECTED_FIELDS_ORDER from '@salesforce/label/c.AEHC_DP_SelectedFieldsOrder';
import L_SCHEDULE_DETAILS from '@salesforce/label/c.AEHC_DP_ScheduleDetails';
import L_MODE from '@salesforce/label/c.AEHC_DP_Mode';
import L_FREQUENCY from '@salesforce/label/c.AEHC_DP_Frequency';
import L_TIME24 from '@salesforce/label/c.AEHC_DP_Time24';
import L_WEEKDAYS from '@salesforce/label/c.AEHC_DP_Weekdays';
import L_MULTI_WEEKS from '@salesforce/label/c.AEHC_DP_MultiWeeks';
import L_DAY_OF_MONTH from '@salesforce/label/c.AEHC_DP_DayOfMonth';
import L_ONE_TIME_DATE from '@salesforce/label/c.AEHC_DP_OneTimeDate';
import L_SCHEDULE_SUMMARY from '@salesforce/label/c.AEHC_DP_ScheduleSummary';
import L_CRON from '@salesforce/label/c.AEHC_DP_Cron';

import L_DEST_DETAILS from '@salesforce/label/c.AEHC_DP_DestDetails';
import L_DEST_TYPE from '@salesforce/label/c.AEHC_DP_DestType';
import L_STORAGE_ACCOUNT from '@salesforce/label/c.AEHC_DP_StorageAccount';
import L_CONTAINER_PATH from '@salesforce/label/c.AEHC_DP_ContainerPathShort';
import L_OUTPUT_FORMAT from '@salesforce/label/c.AEHC_DP_OutputFormat';

import L_DB_TYPE from '@salesforce/label/c.AEHC_DP_DbType';
import L_HOST_NAME from '@salesforce/label/c.AEHC_DP_HostName';
import L_PORT from '@salesforce/label/c.AEHC_DP_Port';
import L_JDBC_URL from '@salesforce/label/c.AEHC_DP_JdbcUrl';
import L_OTHER_PROPS from '@salesforce/label/c.AEHC_DP_OtherProps';

import L_SFTP_HOST from '@salesforce/label/c.AEHC_DP_SftpHost';
import L_SFTP_PORT from '@salesforce/label/c.AEHC_DP_SftpPort';
import L_SFTP_REMOTE_PATH from '@salesforce/label/c.AEHC_DP_SftpRemotePath';
import L_FILE_NAME from '@salesforce/label/c.AEHC_DP_FileName';
import L_INCLUDE_HEADER from '@salesforce/label/c.AEHC_DP_IncludeHeader';
import L_CUSTOM_HEADER_FLAG from '@salesforce/label/c.AEHC_DP_CustomHeaderFlag';
import L_DELIMITER from '@salesforce/label/c.AEHC_DP_Delimiter';

import L_STORED_PROCEDURE from '@salesforce/label/c.AEHC_DP_StoredProcedure';
import L_ON_INIT from '@salesforce/label/c.AEHC_DP_OnInit';
import L_ON_LOAD from '@salesforce/label/c.AEHC_DP_OnLoad';
import L_ON_SUCCESS from '@salesforce/label/c.AEHC_DP_OnSuccess';
import L_ON_ERROR from '@salesforce/label/c.AEHC_DP_OnError';
import L_MUTE_ERR_FLAG from '@salesforce/label/c.AEHC_DP_MuteErrFlag';
import L_BATCH_FLAG from '@salesforce/label/c.AEHC_DP_BatchFlag';
import L_BATCH_SIZE from '@salesforce/label/c.AEHC_DP_BatchSize';

import L_FIELD_NAME from '@salesforce/label/c.AEHC_DP_FieldName';
import L_DATA_TYPE from '@salesforce/label/c.AEHC_DP_DataType';
import L_REQUIRED from '@salesforce/label/c.AEHC_DP_Required';
import L_DESC from '@salesforce/label/c.AEHC_DP_Description';

import L_BACK from '@salesforce/label/c.AEHC_DP_Back';
import L_SUBMIT from '@salesforce/label/c.AEHC_DP_Submit';

export default class AehcReviewSubmitStep extends LightningElement {
    @api wizardData;
    @api isSubmitting = false;
    @api mode = 'subscription'; // default existing behavior
    @api isPublicationBo;

    uiLabels = {
        appName: L_APP_NAME,
        pubName: L_PUB_NAME,
        pubId: L_PUB_ID,
        environment: L_ENVIRONMENT,
        schemaVersion: L_SCHEMA_VERSION,
        purposeUse: L_PURPOSE_USE,
        transformReq: L_TRANSFORM_REQ,

        selectedFieldsOrder: L_SELECTED_FIELDS_ORDER,
        scheduleDetails: L_SCHEDULE_DETAILS,
        mode: L_MODE,
        frequency: L_FREQUENCY,
        time24: L_TIME24,
        weekdays: L_WEEKDAYS,
        multiWeeks: L_MULTI_WEEKS,
        dayOfMonth: L_DAY_OF_MONTH,
        oneTimeDate: L_ONE_TIME_DATE,
        scheduleSummary: L_SCHEDULE_SUMMARY,
        cron: L_CRON,

        destDetails: L_DEST_DETAILS,
        destinationType: L_DEST_TYPE,
        storageAccount: L_STORAGE_ACCOUNT,
        containerPath: L_CONTAINER_PATH,
        outputFormat: L_OUTPUT_FORMAT,

        dbType: L_DB_TYPE,
        hostName: L_HOST_NAME,
        port: L_PORT,
        jdbcUrl: L_JDBC_URL,
        otherProps: L_OTHER_PROPS,

        sftpHost: L_SFTP_HOST,
        sftpPort: L_SFTP_PORT,
        sftpRemotePath: L_SFTP_REMOTE_PATH,
        fileName: L_FILE_NAME,
        includeHeader: L_INCLUDE_HEADER,
        customHeaderFlag: L_CUSTOM_HEADER_FLAG,
        delimiter: L_DELIMITER,

        storedProcedure: L_STORED_PROCEDURE,
        onInit: L_ON_INIT,
        onLoad: L_ON_LOAD,
        onSuccess: L_ON_SUCCESS,
        onError: L_ON_ERROR,
        muteErrorFlag: L_MUTE_ERR_FLAG,
        batchFlag: L_BATCH_FLAG,
        batchSize: L_BATCH_SIZE,

        back: L_BACK,
        submit: L_SUBMIT,
        description: L_DESC
    };

    /*fieldColumns = [
        { label: L_FIELD_NAME, fieldName: 'name' },
        { label: L_DATA_TYPE, fieldName: 'dataType' },
        { label: L_DESC, fieldName: 'description' },
        { label: 'PII Level', fieldName: 'piiLevel' },
        { label: L_REQUIRED, fieldName: 'requiredText' }
    ];*/
    get fieldColumns() {

        if (this.isPublication) {

            return [

                {
                    label: 'Order',
                    fieldName: 'order',
                    type: 'number',
                    initialWidth: 80
                },

                {
                    label: 'Field Name',
                    fieldName: 'fieldName'
                },

                {
                    label: 'Alias',
                    fieldName: 'labelName'
                },

                {
                    label: 'Data Type',
                    fieldName: 'dataType'
                },

                {
                    label: 'PII',
                    fieldName: 'piiLevel'
                },

                {
                    label: 'CCI',
                    fieldName: 'cciLevel'
                },

                {
                    label: 'Required',
                    fieldName: 'required',
                    type: 'boolean'
                },

                {
                    label: 'Description',
                    fieldName: 'description',
                    wrapText: true
                }
            ];
        }

        return [
            { label: L_FIELD_NAME, fieldName: 'name' },
            { label: L_DATA_TYPE, fieldName: 'dataType' },
            { label: L_DESC, fieldName: 'description' },
            { label: 'PII Level', fieldName: 'piiLevel' },
            { label: L_REQUIRED, fieldName: 'requiredText' }
        ];
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', {
            detail: { fromStep: '3' }
        }));
    }

    handleSubmit() {
        if (this.isSubmitting) {
            console.warn('[Review Submit] Duplicate submit ignored.');
            return;
        }
        console.log('hello');
        this.dispatchEvent(new CustomEvent('submit'));
    }

    get showDelimeter(){
        return this.wizardData.destination.sftpOutputFormat.toLowerCase() === 'xml' ? false : true;
    }
    get showBlobDelimeter(){
        return this.wizardData.destination.outputFormat.toLowerCase() === 'xml' ? false : true;
    }
    get showUAT() {
        return this.isSubscription && this.isPublicationBo;
    }

    get isUATEnabled() {
        return this.wizardData?.uatEnabled === true;
    }

    get isPublication() {
        return this.mode === 'publication';
    }
    get isSubscription() {
        return this.mode === 'subscription';
    }
    get showStoredProcedure() {
        return this.isSubscription && this.isDestinationDatabase;
    }
    get fields() {
        if (!this.isPublication) {
            return this.wizardData?.schema?.fields || [];
        }

        const selectedFieldsJson = this.wizardData?.selectedFieldsJson || [];
        const selectedFields = this.wizardData?.selectedFields || [];

        if (selectedFieldsJson.length > 0) {
            return selectedFieldsJson.map((item, index) => {
                const fallback = selectedFields.find(
                    field => field.fieldName === item.fieldName || field.name === item.fieldName
                ) || {};

                return {
                    id: item.id || `${item.fieldName}-${index}`,
                    fieldName: item.fieldName || fallback.fieldName || fallback.name || '',
                    labelName: item.labelName || item.alias || fallback.alias || fallback.labelName || fallback.name || '',
                    alias: item.alias || item.labelName || fallback.alias || fallback.labelName || fallback.name || '',
                    dataType: item.dataType || fallback.dataType || '',
                    description: item.description || fallback.description || '',
                    piiLevel: item.piiLevel || fallback.piiLevel || '',
                    cciLevel: item.cciLevel || item.cci || fallback.cciLevel || fallback.cci || '',
                    required: item.required || fallback.required || false,
                    order: item.order || fallback.order || index + 1
                };
            });
        }

        return selectedFields.map((item, index) => ({
            id: item.id || item.fieldName || item.name || index,
            fieldName: item.fieldName || item.name || '',
            labelName: item.labelName || item.alias || item.name || '',
            alias: item.alias || item.labelName || item.name || '',
            dataType: item.dataType || '',
            description: item.description || '',
            piiLevel: item.piiLevel || '',
            cciLevel: item.cciLevel || item.cci || '',
            required: item.required || false,
            order: item.order || index + 1
        }));
    }
    get hasFields() {
        if (this.isPublication) {
            return (
                (this.wizardData?.selectedFieldsJson && this.wizardData.selectedFieldsJson.length > 0) ||
                (this.wizardData?.selectedFields && this.wizardData.selectedFields.length > 0)
            );
        }

        return (
            this.wizardData?.schema?.fields &&
            this.wizardData.schema.fields.length > 0
        );
    }
    get appName() {
        return this.isPublication
            ? this.wizardData?.application?.name || ''
            : this.wizardData?.applicationName || '';
    }
    get pubName() {
        return this.isPublication
            ? this.wizardData?.metadata?.name || ''
            : this.wizardData?.publicationName || '';
    }
    get submitLabel() {
        return this.isPublication ? 'Submit Publication' : this.uiLabels.submit;
    }
    get backLabel() {
        return this.isPublication ? 'Previous' : this.uiLabels.back;
    }
    get selectedFieldsText() {
        return this.wizardData?.selectedFields?.join(', ');
    }
    get selectedFieldsJson() {
        return JSON.stringify(this.wizardData?.selectedFields || []);
    }
    get selectedFieldsJson1() {
        return JSON.stringify(this.wizardData?.selectedFieldsJson || []);
    }
    get destinationJson() {
        return JSON.stringify(this.wizardData?.destination || {}, null, 2);
    }
    get isTransformationRequired() {
        return this.wizardData?.transformationRequired === true ||
            this.wizardData?.transformationRequired === 'true';
    }
    get muteErrorFlag() {
        return this.wizardData?.destination?.muteErrorFlag === true ||
            this.wizardData?.destination?.muteErrorFlag === 'true';
    }
    get batchFlag() {
        return this.wizardData?.destination?.batchFlag === true ||
            this.wizardData?.destination?.batchFlag === 'true';
    }
    get includeHeader() {
        return this.wizardData?.destination?.includeHeader === true ||
            this.wizardData?.destination?.includeHeader === 'true';
    }
    get provideCustomHeader() {
        return this.wizardData?.destination?.provideCustomHeader === true ||
            this.wizardData?.destination?.provideCustomHeader === 'true';
    }
    get weekdays() {
        return this.wizardData?.schedule?.weekdays?.join(', ');
    }
    get multiWeekWeeks() {
        return this.wizardData?.schedule?.multiWeekWeeks?.join(', ');
    }
    get multiWeekDays() {
        return this.wizardData?.schedule?.multiWeekDays?.join(', ');
    }
    get isDestinationBlob() {
        return this.wizardData?.destination?.destinationType === 'BLOB';
    }
    get isDestinationDatabase() {
        return this.wizardData?.destination?.destinationType === 'Database';
    }
    get isDestinationSFTP() {
        return this.wizardData?.destination?.destinationType === 'SFTP';
    }
    get isFrequencyDaily() {
        return this.wizardData?.schedule?.frequency === 'Daily';
    }
    get isFrequencyWeekly() {
        return this.wizardData?.schedule?.frequency === 'Weekly';
    }
    get isFrequencyMultiWeekly() {
        return this.wizardData?.schedule?.frequency === 'Multi-Weekly';
    }
    get isFrequencyMonthly() {
        return this.wizardData?.schedule?.frequency === 'Monthly';
    }
    get isFrequencyOneTime() {
        return this.wizardData?.schedule?.frequency === 'One-Time Load';
    }
    get isSubmon() {
        return this.wizardData?.schedule?.schedulerMode === 'Submon (Triggered on Publication Completion)';
    }
}