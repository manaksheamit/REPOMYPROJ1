import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods for approval handling
import handleApproval from '@salesforce/apex/AEHC_PublicationApprovalController.handleApproval';
import checkApprovalVisibility from '@salesforce/apex/AEHC_PublicationApprovalController.checkApprovalVisibility';
import getTableSchemaForPublicationCreation from '@salesforce/apex/AEHC_PublicationController.getTableSchemaForPublicationCreation';
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


export default class AehcApprovals extends LightningElement {

    /* =========================================================
       INPUT / STATE VARIABLES
    ========================================================== */

    @api recordId; // Record Id from page context


    _env;

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
    @api
    get env() {
        return this._env;
    }

    set env(value) {
        this._env = value;
        console.log('ENV updated:', value);
        this.loadApprovalVisibility();
    }


    @track subscription;
    showFieldsTable = false;
    tabledata ;
    scheduleChange = false;
    scheduleSummary = '';
    cronExpression = '';

    @track comment = ''; // User comment input
    @track commentError = false; // Comment validation flag

    recordVisibility = false; // Controls visibility of approval section

    @track isApprover = true;
    @track requireIAApproval = false;
    @track showApprovalActions = false;
    schema = '';
    table = '';
    isADL = false;
    description = '';
    createdByName = '';
    createdDate = null;
    typeOfChange = '';
    adlReviewRequired = false;
    @track isLoading = false; // Loader indicator
    isActionInProgress = false;

    /* =========================================================
       LIFECYCLE HOOK
    ========================================================== */

    @wire(CurrentPageReference)
    handlePageRef(ref) {
        if (ref?.state?.id) {
            console.log(this.env);
            this.recordId = ref.state.id;
            this.loadApprovalVisibility();
        }
    }
    loadApprovalVisibility() {
        
        // Prevent call if required values are missing
        if (!this.recordId || !this._env) {
            return;
        }

        console.log('Calling Apex with:', this.recordId, this._env);

        checkApprovalVisibility({
            recordId: this.recordId,
            env: this._env
        })

            .then(result => {

                this.recordVisibility = result.showapproval;
                this.table = result.table;
                this.isADL = result.adl;
                this.schema = result.schema
                this.selectedApplication = result.selectedApplication;

                this.description = result.description;
                this.createdByName = result.createdByName;
                this.createdDate = result.createdDate;
                this.typeOfChange = result.typeOfChange;
                this.adlReviewRequired = result.adlReviewRequired;
                this.tabledata = result.tabledata ;

                console.log('_______datd:____________________ ' 
                    , JSON.stringify(this.tabledata)
                );
                console.log('_______result datd:____________________ ' 
                    , JSON.stringify(result.tabledata)
                );
                if(result.schemaChange)
                {
                    this.showFieldsTable = true;
                }

                this.scheduleChange = result.scheduleChange;
                this.scheduleSummary = result.scheduleSummary;
                this.cronExpression = result.cronExpression;
                if(result.scheduleChange){
                this.scheduleChange = true;
                }
                console.log(' this.recordVisibility :', this.recordVisibility);
                console.log(' this.isAdl :', this.isADL);
                console.log(' this.schema :', this.schema);
                console.log(' this.table :', this.table);
                console.log(' this.selectedApplication :', this.selectedApplication);
            })
            .catch(error => {
                console.log('ERROR:', error);
                this.recordVisibility = undefined;
            });
    }

    get formattedCreatedDate() {
        return this.createdDate
            ? new Intl.DateTimeFormat('en-US', {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }).format(new Date(this.createdDate))
            : '';
    }

    connectedCallback() { }

    /* =========================================================
       PAGE REFRESH HANDLER
    ========================================================== */

    refreshPage() {

        // Small delay so the success toast is visible before reload
        setTimeout(() => {
            window.location.reload();
        }, 500);
    }

    /* =========================================================
       APPROVE / REJECT ACTION HANDLER
    ========================================================== */

    action(event) {

        if (this.isActionInProgress) {
            return;
        }

        // Get selected action (Approve / Reject)
        let result = event.target.label;

        let textarea = this.template.querySelector('[data-id="commentBox"]');

        // Validation: Comment is mandatory when rejecting
        if (result === 'Reject' && (!this.comment || !this.comment.trim())) {
 
           textarea.setCustomValidity('Comment is mandatory to reject.');
           textarea.reportValidity();
          
            return;
            // Proceed with backend call (as per original logic)
           // this.handletAction(this.recordId, result, this.comment);

        } else {

            // Clear validation errors
            textarea.setCustomValidity('');
            textarea.reportValidity();
            console.log('____ result ', result);
            if (result == 'Complete Review') {
                result = 'Approve';
                console.log('____ result ', result);
            }
            // Call approval action
            this.handletAction(this.recordId, result, this.comment);


        }
    }

    /* =========================================================
       APEX APPROVAL CALL
    ========================================================== */

    handletAction(recordId, res, comment) {

        this.isActionInProgress = true;
        console.log('data inside');
        handleApproval({
            recordId: recordId,
            action: res,
            comments: comment, env: this.env
        })
            .then(result => {
                console.log('data'+result);

                if (result == 'Success') {
                    // Show success toast
                    
                    console.log('inside sucess');
                    this.showToast('Success!', 'Record '+res+' Successfully', 'success');
                    this.recordVisibility = false;

                }
                else if (result == 'Already Approved')
                {
                    console.log('inside already');
                    this.showToast('Record already Approved');
                    this.recordVisibility = false;
                }

            })
            .catch(error => {

                // Show error toast
                this.showToast('error!', error, 'error');
            })
            .finally(() => {
                this.isActionInProgress = false;
            });

    }

    /* =========================================================
       COMMENT INPUT HANDLER
    ========================================================== */

    handleCommentChange(event) {

        // Update comment value from textarea
        this.comment = event.target.value;

        // Validate empty or whitespace comment
        this.commentError = (!this.comment || !this.comment.trim()) ? true : false;
    }

    /* =========================================================
       TOAST UTILITY
    ========================================================== */

    showToast(title, message, variant) {
        // Dispatch toast event
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
    disconnectedCallback() {
        console.log('Test disconnected');
    }
    /* === 
    validate function
    */
    get hasVisibleFields() {
        return this.visibleFields && this.visibleFields.length > 0;
    }

    get showLoadMore() {
        return this.visibleFields.length < this.fields.length;
    }
    fields = [];
    get showNoFields() {
        return (
            this.hasValidatedSchema &&
            !this.isSchemaLoading &&
            Array.isArray(this.fields) &&
            this.fields.length === 0
        );
    }
    @track visibleFields = [];
    columns = [
        { label: L_FIELD_NAME, fieldName: 'name' },
        { label: L_DATA_TYPE, fieldName: 'dataType' },
        { label: L_DESC, fieldName: 'description' },
        { label: 'PII Level', fieldName: 'piiLevel' }, // optional label later
        { label: L_REQUIRED, fieldName: 'requiredText' }
    ];
    isSchemaLoading = false;
    selectedApplication = '';
    applicationError = '';
    hasValidatedSchema = false;
    fieldDisplayLimit = 10;
    fieldPageSize = 10;
    async handleValidate() {
        console.log(this.schema);
        console.log(this.table);
        console.log(this.selectedApplication);
        console.log(this.selectedApplication);
        this.selectedApplication = 'Commerce Application';
        try {
            if (!this.schema || !this.table) {
                this.applicationError = L_ERR_SCHEMA;
                return;
            }
            if (!this.selectedApplication) {
                this.applicationError = L_ERR_APP_REQUIRED;
                return;
            }

            this.applicationError = '';
            this.isSchemaLoading = true;
            this.hasValidatedSchema = true;


            console.log('validate called');
            const result = await getTableSchemaForPublicationCreation({
                applicationName: this.selectedApplication,
                schemaName: this.schema,
                tableName: this.table
            });
            console.log('validate called result', result);
            const mapped = (result || []).map((f, i) => ({
                id: f.id || String(i),
                name: f.name || '',
                dataType: f.dataType || '',
                description: f.description || '',
                piiLevel: f.piiLevel || '',
                requiredText: f.required ? 'YES' : 'NO'
            }));

            this.fields = mapped;
            this.fieldDisplayLimit = this.fieldPageSize;
            this.visibleFields = this.fields.slice(0, this.fieldDisplayLimit);


        } catch (e) {
            this.logException(e, 'handleValidate');
            this.fields = [];
            this.visibleFields = [];
            this.hasValidatedSchema = true;
            this.applicationError = 'Unable to load schema fields. Please try again later.';
        } finally {
            this.isSchemaLoading = false;
        }
    }
}