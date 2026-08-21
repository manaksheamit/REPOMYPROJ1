/**
 * Component: aehcDestinationStep
 * Author: Umang Rohitbhai Fofariya
 * Date: 24-May-2026
 *
 * Description:
 * Handles destination configuration in the wizard, supporting Blob,
 * Database, and SFTP targets with validations, custom header mapping,
 * and XML template preview for database configurations.
 */
import { LightningElement, api, track } from 'lwc';
import AEHC_RESOURCE from '@salesforce/resourceUrl/AEHC_Resource';
import logError from '@salesforce/apex/AEHC_Logger.logError';
import LABEL_ENV_NAME from '@salesforce/label/c.AEHC_Environment_Name';
import L_DEST_TYPE from '@salesforce/label/c.AEHC_DP_DestType';
import L_DB_TARGET_CONFIG from '@salesforce/label/c.AEHC_DP_DbTargetConfig';
import L_DB_TYPE from '@salesforce/label/c.AEHC_DP_DbType';
import L_HOST_SERVER from '@salesforce/label/c.AEHC_DP_HostServer';
import L_PORT from '@salesforce/label/c.AEHC_DP_Port';
import L_OTHER_PROPS from '@salesforce/label/c.AEHC_DP_OtherProps';
import L_JDBC_URL from '@salesforce/label/c.AEHC_DP_JdbcUrl';
import L_JDBC_HELP from '@salesforce/label/c.AEHC_DP_JdbcHelp';
import L_JDBC_CREDENTIAL_ERR from '@salesforce/label/c.AEHC_DP_JdbcCredentialErr';

import L_STORED_PROC from '@salesforce/label/c.AEHC_DP_StoredProc';
import L_ON_INIT from '@salesforce/label/c.AEHC_DP_OnInit';
import L_ON_LOAD from '@salesforce/label/c.AEHC_DP_OnLoad';
import L_ON_SUCCESS from '@salesforce/label/c.AEHC_DP_OnSuccess';
import L_ON_ERROR from '@salesforce/label/c.AEHC_DP_OnError';
import L_MUTE_ERR_FLAG from '@salesforce/label/c.AEHC_DP_MuteErrFlag';
import L_BATCH_FLAG from '@salesforce/label/c.AEHC_DP_BatchFlag';
import L_BATCH_SIZE from '@salesforce/label/c.AEHC_DP_BatchSize';

import L_XML_TEMPLATE from '@salesforce/label/c.AEHC_DP_XmlTemplate';
import L_XML_UNAVAILABLE from '@salesforce/label/c.AEHC_DP_XmlUnavailable';

import L_SFTP_CONFIG from '@salesforce/label/c.AEHC_DP_SftpConfig';
import L_HOST_NAME from '@salesforce/label/c.AEHC_DP_HostName';
import L_REMOTE_PATH from '@salesforce/label/c.AEHC_DP_RemotePath';
import L_FILE_NAME from '@salesforce/label/c.AEHC_DP_FileName';
import L_OUTPUT_FORMAT from '@salesforce/label/c.AEHC_DP_OutputFormat';
import L_INCLUDE_HEADER from '@salesforce/label/c.AEHC_DP_IncludeHeader';
import L_CUSTOM_HEADER_FLAG from '@salesforce/label/c.AEHC_DP_CustomHeaderFlag';
import L_SELECTED_FIELDS from '@salesforce/label/c.AEHC_DP_SelectedFields';
import L_CUSTOM_HEADER_NAME from '@salesforce/label/c.AEHC_DP_CustomHeaderName';
import L_DELIMITER from '@salesforce/label/c.AEHC_DP_Delimiter';

import L_BLOB_CONFIG from '@salesforce/label/c.AEHC_DP_BlobConfig';
import L_STORAGE_BUCKET from '@salesforce/label/c.AEHC_DP_StorageBucket';
import L_CONTAINER_PATH from '@salesforce/label/c.AEHC_DP_ContainerPath';

import L_FILE_NAME_ERR from '@salesforce/label/c.AEHC_DP_FileNameErr';
import L_DELIMITER_ERR from '@salesforce/label/c.AEHC_DP_DelimiterErr';
import L_BLOB_FILE_NAME_ERR from '@salesforce/label/c.AEHC_DP_BlobFileNameErr';
import L_BATCH_SIZE_ERR from '@salesforce/label/c.AEHC_DP_BatchSizeErr';

import L_BACK from '@salesforce/label/c.AEHC_DP_Back';
import L_NEXT from '@salesforce/label/c.AEHC_DP_Next';

export default class AehcDestinationStep extends LightningElement {
    @api wizardData;
    @api destinationTypeOptions = [];
    @api dbTypeOptions = [];
    @api outputFormatOptions = [];

    @api hideFooter = false;
    @api readOnly = false;


    xmlTemplatePreview = '';
    @track customHeaderFields = [];
    showDelimiterSection = true;
    @track destination = {
        destinationType: '',
        includeHeader: false,
        provideCustomHeader: false,

        // Blob fields - unchanged
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
        spOnInit: '',
        spOnLoad: '',
        spOnSuccess: '',
        spOnError: '',
        muteErrorFlag: false,
        batchSize: '',


        // SFTP fields
        sftpHostName: '',
        sftpPort: '',
        sftpRemotePath: '',
        sftpFileName: '',
        sftpOutputFormat: '',        
        delimiter: ''

    };

    uiLabels = {
        destinationType: L_DEST_TYPE,
        dbTargetConfig: L_DB_TARGET_CONFIG,
        dbType: L_DB_TYPE,
        hostServer: L_HOST_SERVER,
        port: L_PORT,
        otherProps: L_OTHER_PROPS,
        jdbcUrl: L_JDBC_URL,
        jdbcHelp: L_JDBC_HELP,
        jdbcCredentialError: L_JDBC_CREDENTIAL_ERR,

        storedProc: L_STORED_PROC,
        onInit: L_ON_INIT,
        onLoad: L_ON_LOAD,
        onSuccess: L_ON_SUCCESS,
        onError: L_ON_ERROR,
        muteErrorFlag: L_MUTE_ERR_FLAG,
        batchFlag: L_BATCH_FLAG,
        batchSize: L_BATCH_SIZE,
        batchSizeErr: L_BATCH_SIZE_ERR,

        xmlTemplate: L_XML_TEMPLATE,
        xmlUnavailable: L_XML_UNAVAILABLE,

        sftpConfig: L_SFTP_CONFIG,
        hostName: L_HOST_NAME,
        remotePath: L_REMOTE_PATH,
        fileName: L_FILE_NAME,
        outputFormat: L_OUTPUT_FORMAT,
        includeHeader: L_INCLUDE_HEADER,
        customHeaderFlag: L_CUSTOM_HEADER_FLAG,
        selectedFields: L_SELECTED_FIELDS,
        customHeaderName: L_CUSTOM_HEADER_NAME,
        delimiter: L_DELIMITER,

        blobConfig: L_BLOB_CONFIG,
        blobFileNameErr: L_BLOB_FILE_NAME_ERR,
        storageBucket: L_STORAGE_BUCKET,
        containerPath: L_CONTAINER_PATH,

        fileNameError: L_FILE_NAME_ERR,
        delimiterError: L_DELIMITER_ERR,

        back: L_BACK,
        next: L_NEXT
    };

    @api
getDestinationData() { 
    return {
        destination: { ...this.destination },
        selectedFieldsJson: [...this.customHeaderFields]
    };
}
    

    connectedCallback() {
        
        if (this.wizardData?.destination) {
            this.destination = { ...this.destination, ...this.wizardData.destination };
        }
        
console.log(
        'destination after merge',
        JSON.stringify(this.destination)
    );


        this.initializeCustomHeaderFields();

        if (this.destination.destinationType === 'Database') {
            this.loadDatabaseXmlTemplate();
        }
        if (this.destination?.sftpOutputFormat?.toLowerCase() === 'xml' || this.destination?.outputFormat?.toLowerCase() === 'xml') {
            this.showDelimiterSection = false;
        }
    }

    initializeCustomHeaderFields() {
        const selectedFieldsJson = this.wizardData?.selectedFieldsJson || [];
        console.log('____________________________ selectedFieldsJson :' +JSON.stringify(selectedFieldsJson));
        this.customHeaderFields = selectedFieldsJson.map((field, index) => ({
            fieldName: field.fieldName,
            label: field.label || field.labelName || field.fieldName,
            order: field.order || index + 1
        }));
        
        console.log('____________________________ customHeaderFields :' +JSON.stringify(this.customHeaderFields));
    }

    /* ===== Getters ===== */

    get isBlob() {
        return this.destination.destinationType === 'BLOB';
    }
    get blobFileName() {
        return this.destination.blobFileName;
    }

    get destinationType() {
        console.log('data'+this.destination.destinationType);
        return this.destination.destinationType;
    }

    get storageAccount() {
        return this.destination.storageAccount;
    }

    get containerPath() {
        return this.destination.containerPath;
    }

    get outputFormat() {
        return this.destination.outputFormat;
    }

    get isDatabase() {
        return this.destination.destinationType === 'Database';
    }

    get databaseType() {
        return this.destination.databaseType;
    }

    get databaseHost() {
        return this.destination.databaseHost;
    }

    get databasePort() {
        return this.destination.databasePort;
    }

    get jdbcUrl() {
        return this.destination.jdbcUrl;
    }

    get otherProperties() {
        return this.destination.otherProperties;
    }

    get batchFlag() {
        return this.destination.batchFlag;
    }

    get batchSize() {
        return this.destination.batchSize;
    }

    get spOnInit() {
        return this.destination.spOnInit;
    }

    get spOnLoad() {
        return this.destination.spOnLoad;
    }

    get spOnSuccess() {
        return this.destination.spOnSuccess;
    }

    get spOnError() {
        return this.destination.spOnError;
    }

    get muteErrorFlag() {
        return this.destination.muteErrorFlag;
    }

    get isSftp() {
        return this.destination.destinationType === 'SFTP';
    }

    get sftpHostName() {
        return this.destination.sftpHostName;
    }

    get sftpPort() {
        return this.destination.sftpPort;
    }

    get sftpRemotePath() {
        return this.destination.sftpRemotePath;
    }

    get sftpFileName() {
        return this.destination.sftpFileName;
    }

    get sftpOutputFormat() {
        return this.destination.sftpOutputFormat;
    }
    

    get includeHeader() {
        return this.destination.includeHeader;
    }

    get provideCustomHeader() {
        return this.destination.provideCustomHeader;
    }

    get delimiter() {
        return this.destination.delimiter;
    }

    get showCustomHeaderTable() {
        return  this.destination.provideCustomHeader;
    }

    get hasXmlTemplatePreview() {
        return !!this.xmlTemplatePreview;
    }

    notifyParent() {
    this.dispatchEvent(
        new CustomEvent('stepdatachange', {
            detail: {
                destination: { ...this.destination },
                selectedFieldsJson: this.customHeaderFields
            }
        })
    );
}

    /* ===== Change handlers ===== */

    handleDestinationTypeChange(event) {
        try {
            const newValue = event.detail.value;

           this.destination = {
                ...this.destination,
                destinationType: newValue,
                includeHeader: false,
                provideCustomHeader: false
            };
                this.initializeCustomHeaderFields();
            //this.customHeaderFields = this.customHeaderFields.map(field => ({...field, label: field.Label}));

        console.log('____________________________ 343 customHeaderFields :' +JSON.stringify(this.customHeaderFields));
            // Existing Blob behavior - unchanged
            if (newValue !== 'BLOB') { 
                this.clearBlobFields();
            }

            if (newValue !== 'Database') {
                this.clearDatabaseFields();
            }

            if (newValue !== 'SFTP') {
                this.clearSftpFields();

                initializeCustomHeaderFields(); 
                const resetFields = this.customHeaderFields ;//this.customHeaderFields.map(field => ({
                   // ...field,
                  //  label: field.fieldName
              //  }));
                
                
        console.log('____________________________363 customHeaderFields :' +JSON.stringify(this.customHeaderFields));
              //  this.customHeaderFields = resetFields;

                this.dispatchEvent(
                    new CustomEvent('stepdatachange', {
                        detail: {
                            selectedFieldsJson: resetFields
                        }
                    })
                );

            }

            if (newValue === 'Database') {
                this.loadDatabaseXmlTemplate();
            }


            if (newValue === 'SFTP') {
                this.initializeCustomHeaderFields();
            }

        } catch (error) {
            this.logExceptionToApex(error, 'handleDestinationTypeChange');
        }
    }

    // Blob: FileName
    handleBlobFileNameChange(event) {
        try {
            this.destination = {
                ...this.destination,
                blobFileName: event.detail.value
            };

            this.validateBlobFileNameField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleBlobFileNameChange');
        }
    }
    validateBlobFileNameField() {
        const fileNameInput = this.template.querySelector('.blob-file-name-input');

        if (!fileNameInput) {
            return true;
        }

        const value = this.destination.blobFileName || '';


        // Regex:
        // Allows alphabets, numbers, underscore, hyphen
        const isValid = /^[A-Za-z0-9_-]+$/.test(value);

        if (!isValid) {
            fileNameInput.setCustomValidity(this.uiLabels.blobFileNameErr);
            fileNameInput.reportValidity();
            return false;
        }

        fileNameInput.setCustomValidity('');
        fileNameInput.reportValidity();
        return true;
    }

    async loadDatabaseXmlTemplate() {
        try {
            const xmlTemplateUrl = `${AEHC_RESOURCE}/AEHC_Database_XML_Template/AEHC_Database_XML_Template.xml`;

            const response = await fetch(xmlTemplateUrl);

            if (!response.ok) {
                this.xmlTemplatePreview = '';

                this.logExceptionToApex(
                    new Error(`XML template fetch failed with status ${response.status}`),
                    'loadDatabaseXmlTemplate',
                    {
                        xmlTemplateUrl,
                        status: response.status,
                        statusText: response.statusText
                    }
                );

                return;
            }

            this.xmlTemplatePreview = await response.text();

        } catch (error) {
            this.xmlTemplatePreview = '';

            this.logExceptionToApex(
                error,
                'loadDatabaseXmlTemplate',
                {
                    staticResource: 'AEHC_Resource',
                    filePath: 'AEHC_Database_XML_Template/AEHC_Database_XML_Template.xml'
                }
            );
        }
    }

    handleDatabaseTypeChange(event) {
        try {
            this.destination = {
                ...this.destination,
                databaseType: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleDatabaseTypeChange');
        }
    }

    handleDatabaseHostChange(event) {
        try {
            this.destination = {
                ...this.destination,
                databaseHost: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleDatabaseHostChange');
        }
    }

    handleDatabasePortChange(event) {
        try {
            this.destination = {
                ...this.destination,
                databasePort: event.detail.value
            };
            this.validateDatabasePortField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleDatabasePortChange');
        }
    }

    handleJdbcUrlChange(event) {
        try {
            this.destination = {
                ...this.destination,
                jdbcUrl: event.detail.value
            };

            //this.validateJdbcUrlField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleJdbcUrlChange');
        }
    }

    handleOtherPropertiesChange(event) {
        try {
            this.destination = {
                ...this.destination,
                otherProperties: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleOtherPropertiesChange');
        }
    }

    handleBatchFlagChange(event) {
        try {
            const isBatchEnabled = event.target.checked;

            this.destination = {
                ...this.destination,
                batchFlag: isBatchEnabled
            };

            if (isBatchEnabled && !this.xmlTemplatePreview) {
                this.loadDatabaseXmlTemplate();
            }
        } catch (error) {
            this.logExceptionToApex(error, 'handleBatchFlagChange');
        }
    }

    handleBatchSizeChange(event) {
        try {
            const value = event.target.value;

            this.destination = {
                ...this.destination,
                batchSize: value
            };

            this.validateBatchSizeField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleBatchSizeChange');
        }
    }

    validateBatchSizeField() {
        const inputField = this.template.querySelector('.batch-size-input');

        if (!inputField) {
            return true;
        }

        const value = this.destination.batchSize || '';


        // Validation:
        // Numeric value between 1000 and 5000
        if (
            !value ||
            isNaN(value) ||
            Number(value) < 1000 ||
            Number(value) > 5000
        ) {
            inputField.setCustomValidity(this.uiLabels.batchSizeErr);
            inputField.reportValidity();
            return false;
        }

        inputField.setCustomValidity('');
        inputField.reportValidity();
        return true;
    }

    handleSpOnInitChange(event) {
        try {
            this.destination = {
                ...this.destination,
                spOnInit: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleSpOnInitChange');
        }
    }

    handleSpOnLoadChange(event) {
        try {
            this.destination = {
                ...this.destination,
                spOnLoad: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleSpOnLoadChange');
        }
    }

    handleSpOnSuccessChange(event) {
        try {
            this.destination = {
                ...this.destination,
                spOnSuccess: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleSpOnSuccessChange');
        }
    }

    handleSpOnErrorChange(event) {
        try {
            this.destination = {
                ...this.destination,
                spOnError: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleSpOnErrorChange');
        }
    }

    handleMuteErrorFlagChange(event) {
        try {
            this.destination = {
                ...this.destination,
                muteErrorFlag: event.target.checked
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleMuteErrorFlagChange');
        }
    }
    validateJdbcUrlField() {
        const jdbcInput = this.template.querySelector('.jdbc-url-input');

        if (!jdbcInput) {
            return true;
        }

        const jdbcValue = (this.destination.jdbcUrl || '').trim();

        /*
         * Required JDBC format:
         * jdbc:mysql://<host>:<port>/<database>[?properties]
         *
         * Examples:
         * jdbc:mysql://localhost:3306/testdb
         * jdbc:mysql://localhost:3306/testdb?useSSL=false
         */

        const jdbcPattern =
            /^jdbc:[a-zA-Z0-9]+:\/\/[a-zA-Z0-9.-]+:\d+\/[a-zA-Z0-9_-]+(\?.*)?$/i;

        // Reject HTTP/HTTPS URLs
        const invalidHttpPattern = /^https?:\/\//i;

        // Existing credential validation
        const hasCredential =
            /(^|[;&?\s])user\s*=/i.test(jdbcValue) ||
            /(^|[;&?\s])username\s*=/i.test(jdbcValue) ||
            /(^|[;&?\s])userid\s*=/i.test(jdbcValue) ||
            /(^|[;&?\s])user\s+id\s*=/i.test(jdbcValue) ||
            /(^|[;&?\s])uid\s*=/i.test(jdbcValue) ||
            /(^|[;&?\s])password\s*=/i.test(jdbcValue) ||
            /(^|[;&?\s])pwd\s*=/i.test(jdbcValue) ||
            /\/\/[^/\s:@]+:[^/\s:@]+@/i.test(jdbcValue);

        // Required validation
        if (!jdbcValue) {
            jdbcInput.setCustomValidity('JDBC URL is required.');
            jdbcInput.reportValidity();
            return false;
        }

        // HTTP/HTTPS not allowed
        if (invalidHttpPattern.test(jdbcValue)) {
            jdbcInput.setCustomValidity(
                'Invalid URL format. JDBC URL must start with "jdbc:".'
            );
            jdbcInput.reportValidity();
            return false;
        }

        // JDBC format validation
        if (!jdbcPattern.test(jdbcValue)) {
            jdbcInput.setCustomValidity(
                'Invalid JDBC URL format. Example: jdbc:mysql://host:3306/database?properties'
            );
            jdbcInput.reportValidity();
            return false;
        }

        // Credential validation
        if (hasCredential) {
            jdbcInput.setCustomValidity(this.uiLabels.jdbcCredentialError);
            jdbcInput.reportValidity();
            return false;
        }

        jdbcInput.setCustomValidity('');
        jdbcInput.reportValidity();

        return true;
    }

    handleSftpHostNameChange(event) {
        try {
            this.destination = {
                ...this.destination,
                sftpHostName: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleSftpHostNameChange');
        }
    }

    handleSftpPortChange(event) {
        try {
            this.destination = {
                ...this.destination,
                sftpPort: event.detail.value
            };
            this.validateSftpPortField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleSftpPortChange');
        }
    }

    

    handleSftpRemotePathChange(event) {
        try {
            this.destination = {
                ...this.destination,
                sftpRemotePath: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleSftpRemotePathChange');
        }
    }

    handleSftpFileNameChange(event) {
        try {
            this.destination = {
                ...this.destination,
                sftpFileName: event.detail.value
            };

            this.validateSftpFileNameField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleSftpFileNameChange');
        }
    }
    validateSftpFileNameField() {
        const fileNameInput = this.template.querySelector('.sftp-file-name-input');

        if (!fileNameInput) {
            return true;
        }

        const value = this.destination.sftpFileName || '';

        const hasInvalidCharacters = /[\\/:*?"<>|]/.test(value);

        if (hasInvalidCharacters) {
            fileNameInput.setCustomValidity(this.uiLabels.fileNameError);
            fileNameInput.reportValidity();
            return false;
        }

        fileNameInput.setCustomValidity('');
        fileNameInput.reportValidity();
        return true;
    }

    handleSftpOutputFormatChange(event) {
        try {
            const selectedOutputFormat = event.detail.value;
            this.destination = {
                ...this.destination,
                sftpOutputFormat: selectedOutputFormat,
                delimiter : selectedOutputFormat.toLowerCase() === 'xml' ? '' : this.destination.delimiter
            };
            this.showDelimiterSection = selectedOutputFormat.toLowerCase() === 'xml' ? false : true;
        } catch (error) {
            this.logExceptionToApex(error, 'handleSftpOutputFormatChange');
        }
    }

    handleIncludeHeaderChange(event) {
        try {
            this.destination = {
                ...this.destination,
                includeHeader: event.target.checked
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleIncludeHeaderChange');
        }
    }

    handleProvideCustomHeaderChange(event) {
        try {
            const isChecked = event.target.checked;

            this.destination = {
                ...this.destination,
                provideCustomHeader: isChecked,
                includeHeader: isChecked ? true : this.destination.includeHeader
            };

            if (isChecked) {
                this.initializeCustomHeaderFields();
            }
        } catch (error) {
            this.logExceptionToApex(error, 'handleProvideCustomHeaderChange');
        }
    }

    handleDelimiterChange(event) {
        try {
            const value = event.detail.value || '';

            this.destination = {
                ...this.destination,
                delimiter: value
            };

            this.validateDelimiterField();
        } catch (error) {
            this.logExceptionToApex(error, 'handleDelimiterChange');
        }
    }

    validateDelimiterField() {
        const delimiterInput = this.template.querySelector('.delimiter-input');

        if (!delimiterInput) {
            return true;
        }

        const value = this.destination.delimiter || '';

        if (value && value.length !== 1) {
            delimiterInput.setCustomValidity(this.uiLabels.delimiterError);
            delimiterInput.reportValidity();
            return false;
        }

        delimiterInput.setCustomValidity('');
        delimiterInput.reportValidity();
        return true;
    }

    handleCustomHeaderNameChange(event) {
        try {
            const fieldName = event.currentTarget.dataset.fieldName;
            const newLabel = event.detail.value;

            this.customHeaderFields = this.customHeaderFields.map(field => {
                if (field.fieldName === fieldName) {
                    return {
                        ...field,
                        label: newLabel
                    };
                }

        console.log('____________________________ 869 customHeaderFields :' +JSON.stringify(this.customHeaderFields));
                return field;
            });

        } catch (error) {
            this.logExceptionToApex(error, 'handleCustomHeaderNameChange');
        }
    }

    validateCustomHeaderFields() {
        if (!this.destination.provideCustomHeader) {
            return true;
        }

        const selectedFieldsCount = this.wizardData?.selectedFieldsJson?.length || 0;
        const customHeaderCount = this.customHeaderFields?.length || 0;

        if (selectedFieldsCount !== customHeaderCount) {
            return false;
        }

        return this.customHeaderFields.every(field =>
            field.fieldName && field.label
        );
    }

    handleStorageAccountChange(event) {
        try {
            this.destination = {
                ...this.destination,
                storageAccount: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleStorageAccountChange');
        }
    }

    handleContainerPathChange(event) {
        try {
            this.destination = {
                ...this.destination,
                containerPath: event.detail.value
            };
        } catch (error) {
            this.logExceptionToApex(error, 'handleContainerPathChange');
        }
    }

    handleOutputFormatChange(event) {
        try {
            const selectedOutputFormat = event.detail.value;
            this.destination = {
                ...this.destination,
                outputFormat: selectedOutputFormat,
                delimiter : selectedOutputFormat.toLowerCase() === 'xml' ? '' : this.destination.delimiter
            };
            this.showDelimiterSection = selectedOutputFormat.toLowerCase() === 'xml' ? false : true;
        } catch (error) {
            this.logExceptionToApex(error, 'handleOutputFormatChange');
        }
    }

    /* ===== Validation ===== */

    validate() {
        try {
            let isValid = true;

            if (!this.destination.destinationType) {
                const destinationTypeInput = this.template.querySelector('.destination-type-combobox');

                if (destinationTypeInput) {
                    destinationTypeInput.reportValidity();
                }

                isValid = false;
            }

            if (this.isBlob || this.isDatabase || this.isSftp) {
                const inputs = this.template.querySelectorAll(
                    'lightning-input, lightning-combobox, lightning-textarea'
                );

                inputs.forEach(input => {
                    if (!input.checkValidity()) {
                        input.reportValidity();
                        isValid = false;
                    }
                });
            }

            if (this.isDatabase) {
                const okPort = this.validateDatabasePortField();
                if (!okPort) isValid = false;
            }

            if (this.isSftp) {
                const okPort = this.validateSftpPortField();
                if (!okPort) isValid = false;
            }


            // if (this.isDatabase) {
            //    // const isJdbcValid = this.validateJdbcUrlField();

            //     if (!isJdbcValid) {
            //         isValid = false;
            //     }
            // }

            if (this.isSftp) {
                const isFileNameValid = this.validateSftpFileNameField();
                const isDelimiterValid = this.validateDelimiterField();

                if (!isFileNameValid || !isDelimiterValid) {
                    isValid = false;
                }
            }

            const isCustomHeaderValid = this.validateCustomHeaderFields();

            if (!isCustomHeaderValid) {
                isValid = false;
            }

            return isValid;

        } catch (error) {
            this.logExceptionToApex(error, 'validate');
            return false;
        }
    }

    clearDatabaseFields() {
        this.destination = {
            ...this.destination,
            databaseType: '',
            databaseHost: '',
            databasePort: '',
            jdbcUrl: '',
            otherProperties: '',
            batchFlag: false,
            spOnInit: '',
            spOnLoad: '',
            spOnSuccess: '',
            spOnError: '',
            muteErrorFlag: false,
            batchSize: ''
        };

        this.xmlTemplatePreview = '';
    }

    clearSftpFields() {
        this.destination = {
            ...this.destination,
            sftpHostName: '',
            sftpPort: '',
            sftpRemotePath: '',
            sftpFileName: '',
            sftpOutputFormat: '',            
            delimiter: ''
        };

        const selectedFieldsJson =
            this.wizardData?.selectedFieldsJson || [];
        initializeCustomHeaderFields();
       /* this.customHeaderFields = selectedFieldsJson.map(
            (field, index) => ({
                fieldName: field.fieldName,
                label: field.label || field.labelName || field.fieldName,
                order: index + 1
            })
        );*/
        
        console.log('____________________________  1041 customHeaderFields :' +JSON.stringify(this.customHeaderFields));
    }

    clearBlobFields() {
        this.destination = {
            ...this.destination,
            blobFileName: '',
            storageAccount: '',
            containerPath: '',
            outputFormat: ''
        };

        const inputs = this.template.querySelectorAll(
            'lightning-input, lightning-combobox'
        );

        inputs.forEach(input => input.setCustomValidity(''));
    }



    /* ===== Navigation ===== */

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleNext() {
        try {
            if (!this.validate()) {
                return;
            }

            const detail = {
                destination: { ...this.destination }
            };
           
            //if (this.destination.provideCustomHeader)
                 {
                detail.selectedFieldsJson = this.customHeaderFields.map((field, index) => ({
                    fieldName: field.fieldName,
                    label: field.label,
                    order: index + 1
                }));
            }
           
            this.dispatchEvent(
                new CustomEvent('stepdatachange', {
                    detail
                })
            );

            this.dispatchEvent(new CustomEvent('next'));

        } catch (error) {
            this.logExceptionToApex(error, 'handleNext');
        }
    }

    logExceptionToApex(error, operation = 'unknown', extraContext = {}) {
        try {
            const transactionContext = {
                destinationType: this.destination?.destinationType,
                databaseType: this.destination?.databaseType,
                databaseHostProvided: !!this.destination?.databaseHost,
                databasePortProvided: !!this.destination?.databasePort,
                jdbcUrlProvided: !!this.destination?.jdbcUrl,
                batchFlag: this.destination?.batchFlag,
                muteErrorFlag: this.destination?.muteErrorFlag,
                storageAccountProvided: !!this.destination?.storageAccount,
                containerPathProvided: !!this.destination?.containerPath,
                outputFormat: this.destination?.outputFormat,
                ...extraContext
            };

            logError({
                message: this.normalizeErrorMessage(error),
                componentType: 'LWC',
                componentName: 'aehcDestinationStep',
                operation,
                recordId: null,
                severity: 'High',
                category: 'UI',
                transactionContext: JSON.stringify(transactionContext),
                orgEnv: LABEL_ENV_NAME
            }).catch((loggingError) => {
                // Logging failure should not break user flow.
                // eslint-disable-next-line no-console
                console.error('Failed to log error in Apex', loggingError);
            });

        } catch (localLoggingError) {
            // eslint-disable-next-line no-console
            console.error('Local logging failed', localLoggingError);
        }
    }

    normalizeErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body)) {
            return error.body.map(item => item.message).join(', ');
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unknown error';
    }
    validateDatabasePortField() {
        const portInput = this.template.querySelector('.db-port-input');
        if (!portInput) return true;

        const raw = this.destination.databasePort;

        // Required message
        if (raw === null || raw === undefined || raw === '') {
            portInput.setCustomValidity('Port is required.');
            portInput.reportValidity();
            return false;
        }

        // Number/decimal validation
        const num = Number(raw);
        if (Number.isNaN(num)) {
            portInput.setCustomValidity('Port must be a valid number.');
            portInput.reportValidity();
            return false;
        }

        // Range validation (keep or adjust if you want to allow higher values)
        if (num < 0 || num > 65535) {
            portInput.setCustomValidity('Port must be between 0 and 65535.');
            portInput.reportValidity();
            return false;
        }

        portInput.setCustomValidity('');
        portInput.reportValidity();
        return true;
    }

    validateSftpPortField() {
        const portInput = this.template.querySelector('.sftp-port-input');
        if (!portInput) return true;

        const raw = this.destination.sftpPort;

        if (raw === null || raw === undefined || raw === '') {
            portInput.setCustomValidity('Port is required.');
            portInput.reportValidity();
            return false;
        }

        const num = Number(raw);
        if (Number.isNaN(num)) {
            portInput.setCustomValidity('Port must be a valid number.');
            portInput.reportValidity();
            return false;
        }

        if (num < 0 || num > 65535) {
            portInput.setCustomValidity('Port must be between 0 and 65535.');
            portInput.reportValidity();
            return false;
        }

        portInput.setCustomValidity('');
        portInput.reportValidity();
        return true;
    }
}