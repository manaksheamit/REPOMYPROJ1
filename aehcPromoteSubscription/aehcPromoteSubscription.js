import { LightningElement, api, wire, track } from 'lwc';
import getSubscription from '@salesforce/apex/AEHC_SubscriptionPromoteController.getSubscription';
import checkEligibility from '@salesforce/apex/AEHC_SubscriptionPromoteController.checkEligibility';
import promoteSubscription from '@salesforce/apex/AEHC_SubscriptionPromoteController.promoteSubscription';
import getSubscriptionPicklistOptions
    from '@salesforce/apex/AEHC_SubscriptionController_DP.getSubscriptionPicklistOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class AehcPromoteSubscription extends NavigationMixin(LightningElement) {

    @api recordId;

    @track subscription;
    @track draft = {};
    @api env;
    @api selectedVersion;
    originalData = {};    

    targetEnvironment;
    sameAsCurrent = true;
    isConfirmMode = false;
    isLoaded = false;

    canPromote = true;
    eligibilityMessage;
    destinationTypeOptions = [];
databaseTypeOptions = [];
outputFormatOptions = [];

    // Approval UI
    @track showApprovalScreen = false;
    @track approvalAction = 'Promote';
    @track approvalComments = '';

    /*@wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef) {
           console.log(pageRef.state.subscriptionId);
            
                    this.recordId = pageRef.state.subscriptionId;
                console.log('recordId:', this.recordId);

                    console.log(this.recordId);
        }
    }*/
    connectedCallback() {
        if (!this.recordId) {
            const params = new URLSearchParams(window.location.search);
            this.recordId = params.get('subscriptionId');
        }
        this.loadPicklistOptions();

    }
    async loadPicklistOptions() {

    try {

        const options =
            await getSubscriptionPicklistOptions();

        this.destinationTypeOptions =
            options.destinationTypeOptions || [];

        this.databaseTypeOptions =
            options.databaseTypeOptions || [];

        this.outputFormatOptions =
            options.outputFormatOptions || [];

    } catch (e) {
        console.error(e);
    }
}

    @wire(getSubscription, { subscriptionId: '$recordId', currentenv: '$env' })
    wiredSubscription({ data }) {
        if (data) {

            this.subscription = data;
             
            if (!data.AEHC_Subscription_Request__r.AEHC_UAT_Approval__c && data.AEHC_Environment__c == 'QA') {
                this.targetEnvironment = 'Production';
            }
            else {
                this.targetEnvironment = this.getNextEnvironment(data.AEHC_Environment__c);
            }
            this.originalData = { ...data };
            this.draft = { ...data };
            console.log(this.subscription);

            this.isLoaded = true;

        }
    }

    @wire(checkEligibility, { subscriptionId: '$recordId', currentenv: '$env', version: '$selectedVersion' })
    wiredEligibility({ data }) {
        if (data) {
            this.canPromote = data.canPromote;
            this.eligibilityMessage = data.message;
        }
    }

    get destinationWizardData() {

        return {

            destination: {

                destinationType:
                    this.draft.AEHC_Destination_Type__c,

                databaseType:
                    this.draft.AEHC_Database_Type__c,

                databaseHost:
                    this.draft.AEHC_Host_Server__c,

                databasePort:
                    this.draft.AEHC_Port__c,

                jdbcUrl:
                    this.draft.AEHC_JDBC_URL__c,

                otherProperties:
                    this.draft.AEHC_Other_Properties__c,

                batchFlag:
                    this.draft.AEHC_Batch_Flag__c,

                batchSize:
                    this.draft.AEHC_BatchSize__c,

                muteErrorFlag:
                    this.draft.AEHC_Mute_Error_Flag__c,

                spOnInit:
                    this.draft.AEHC_On_Initialization__c,

                spOnLoad:
                    this.draft.AEHC_On_Load__c,

                spOnSuccess:
                    this.draft.AEHC_On_Success__c,

                spOnError:
                    this.draft.AEHC_On_Error__c,

                sftpHostName:
                    this.draft.AEHC_Host_Server__c,

                sftpPort:
                    this.draft.AEHC_Port__c,

                sftpRemotePath:
                    this.draft.AEHC_Remote_Directory_Path__c,

                sftpFileName:
                    this.draft.AEHC_Filename__c,

                sftpOutputFormat:
                    this.draft.AEHC_Output_Format__c,

                includeHeader:
                    this.draft.AEHC_Include_Header__c,

                provideCustomHeader:
                    this.draft.AEHC_Provide_Custom_Header__c,

                delimiter:
                    this.draft.AEHC_Delimiter__c,

                storageAccount:
                    this.draft.AEHC_Storage_Account_Bucket__c,

                containerPath:
                    this.draft.AEHC_Container_Folder_Path__c,

                blobFileName:
                    this.draft.AEHC_Blob_FileName__c,

                outputFormat:
                    this.draft.AEHC_Output_Format__c
            },

            selectedFieldsJson:
                JSON.parse(
                    this.draft.AEHC_Selected_Fields_JSON__c || '[]'
                )
        };
    }
    buildOverrideFields() {

    if (this.sameAsCurrent) {
        return {};
    }

    const destinationCmp =
        this.template.querySelector(
            'c-aehc-destination-step'
        );

    if (!destinationCmp) {
        return {};
    }

    const destinationData = destinationCmp.getDestinationData();

    const d = destinationData.destination;
    //Bug fix removed sftp condition (MUL-15884)
    const selectedFieldsJson = destinationData.selectedFieldsJson || [];
    let selectedFieldsJsonString = null;
    if (d.provideCustomHeader) {
        selectedFieldsJsonString = JSON.stringify(selectedFieldsJson);
    }

    return {

        AEHC_Destination_Type__c: d.destinationType,

        AEHC_Database_Type__c: d.databaseType,
        AEHC_Host_Server__c: d.destinationType === 'Database' ? d.databaseHost : d.sftpHostName,
        AEHC_Port__c: d.destinationType === 'Database' ? d.databasePort : d.sftpPort,
        AEHC_JDBC_URL__c: d.jdbcUrl,
        AEHC_Other_Properties__c: d.otherProperties,
        AEHC_Selected_Fields_JSON__c: selectedFieldsJsonString,
        AEHC_On_Initialization__c: d.spOnInit,
        AEHC_On_Load__c: d.spOnLoad,
        AEHC_On_Success__c: d.spOnSuccess,
        AEHC_On_Error__c: d.spOnError,

        AEHC_Mute_Error_Flag__c: d.muteErrorFlag,
        AEHC_Batch_Flag__c: d.batchFlag,
        AEHC_BatchSize__c: d.batchSize,

        AEHC_Remote_Directory_Path__c: d.sftpRemotePath,
        AEHC_Filename__c: d.sftpFileName,

        AEHC_Output_Format__c:
            d.destinationType === 'BLOB'
                ? d.outputFormat
                : d.sftpOutputFormat,

        AEHC_Include_Header__c: d.includeHeader,
        AEHC_Provide_Custom_Header__c: d.provideCustomHeader,
        AEHC_Delimiter__c: d.delimiter,

        AEHC_Storage_Account_Bucket__c: d.storageAccount,
        AEHC_Container_Folder_Path__c: d.containerPath,
        AEHC_Blob_FileName__c: d.blobFileName
    };
}
    get showDestinationComponent() {
        return true;
    }

    get isReadOnly() {
        return this.sameAsCurrent || this.isConfirmMode || !this.canPromote;
    }

    get disableSameAsToggle() {
        return this.isConfirmMode || !this.canPromote;
    }

    get showPromoteButton() {
        return this.canPromote && !this.isConfirmMode && !this.showApprovalScreen;
    }

    get showSubmitButton() {
        return this.canPromote && this.isConfirmMode && !this.showApprovalScreen;
    }

    getNextEnvironment(env) {
        switch (env) {
            case 'Dev': return 'QA';
            case 'QA': return 'UAT';
            case 'UAT': return 'Production';
            default: return null;
        }
    }

    handleChange(e) {
        this.draft[e.target.dataset.field] = e.detail.value;
    }

    handleToggle(e) {
        this.draft[e.target.dataset.field] = e.target.checked;
    }

    handleSameAsToggle(e) {
        this.sameAsCurrent = e.target.checked;
        if (this.sameAsCurrent) {
            this.draft = { ...this.originalData };
        }
    }

    getChangedFields() {
        const c = {};
        Object.keys(this.draft).forEach(f => {
            if (this.draft[f] !== this.originalData[f]) {
                c[f] = this.draft[f];
            }
        });
        return c;
    }


    promoteDisable = false

    handlePromote() {
        let tempvar = true;
        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach(field => {
            if (field.required && !field.value) {
                field.reportValidity();
                tempvar = false;
            }
        });
        if (tempvar) {
            this.promoteDisable = true;
            this.handleSubmit();
        }

    }

    handleSubmit() {
        promoteSubscription({
            parentSubscriptionId: this.recordId,
            overriddenFields: this.buildOverrideFields(),
            currentenv: this.env,
            version: this.selectedVersion
        })
            .then(result => {
                if(!result.success){
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: result.message,
                variant: 'error'
            })
        );
        return;
    }

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Success',
            message: 'Record Promoted',
            variant: 'success'
        })
    );

    this.dispatchEvent(
        new CustomEvent('complete', {
            detail: {
                environment: result.environment,
                version: result.version,
                versionId: result.versionId
            }
        })
    );

})
            .catch(e => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: e.body.message,
                    variant: 'error'
                }));
            });
    }

    handleCancel() {
        this.dispatchEvent(
            new CustomEvent('complete', {
            })
        );

        /*  this[NavigationMixin.Navigate]({
              type: 'standard__recordPage',
              attributes: {
                  recordId: this.recordId,
                  objectApiName: 'AEHC_Subscription__c', 
                  actionName: 'view'
              }
          });*/
        // window.location.href = 'https://kpmg-aeh--aehdevfeb.sandbox.my.site.com/aeh/s/detail/' + this.recordId;
    }

    //  Approval UI

    get approvalOptions() {
        return [
            { label: 'Promote', value: 'Promote' },
            { label: 'Reject / Request Re-Submission', value: 'Reject' }
        ];
    }

    handleApprovalChange(e) {
        this.approvalAction = e.detail.value;
    }

    handleCommentsChange(e) {
        this.approvalComments = e.detail.value;
    }
    hideSubmit = false;
    handleApprovalSubmit() {
    }
}