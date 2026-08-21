/* @Author : Parvej Alam
   @FileName : AehcapiViewJobHistory
   Description : This LWC will show all the jobrun history on UI

*/
import { LightningElement, track, api, wire } from 'lwc';
import getJobRuns from '@salesforce/apex/AEHC_ViewJobHistoryController.getJobRuns';
import getAuditDetails from '@salesforce/apex/AEHC_ViewJobHistoryController.getAuditDetails';
import requestSnapshot from '@salesforce/apex/AEHC_ViewJobHistoryController.requestSnapshot';
import requestAdhoc from '@salesforce/apex/AEHC_ViewJobHistoryController.requestAdhoc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AehcapiViewJobHistory extends LightningElement {

    @track runData = [];
    @track auditData = [];
    @track showAudit = false;
    @track selectedRunId;
    @track intId;
    executionStatus;
    runCompletionTime;
    runRecordCount;
    _recordId;
    showTable = false;
    errorMessage = '';
    showPrompt = false;
    showNoJobIdPrompt = false;

    @api
    set recordId(value) {
        this._recordId = value;

        if (this._recordId) {
            this.loadRuns();
        }
    }

    get recordId() {
        return this._recordId;
    }
    columns = [
        {
            label: 'Run ID',
            fieldName: 'runId',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'runId' },
                name: 'view',
                variant: 'base'
            }
        },
        { label: 'Previous Run ID', fieldName: 'snapshotId' },
        { label: 'Run Start Time', fieldName: 'startTime' },
        { label: 'Run End Time', fieldName: 'endTime' },
        { label: 'Records Processed', fieldName: 'recordCount' },
        { label: 'Status', fieldName: 'status' }
    ];

    auditColumns = [
        { label: 'Run Stage', fieldName: 'stage' },
        { label: 'Run Start Time', fieldName: 'startTime' },
        { label: 'Status', fieldName: 'status' },
        { label: 'Message', fieldName: 'message' },
    ];

    @api selectedVersion;
    _selectedEnv;

    @api
    get selectedEnv() {
        return this._selectedEnv;
    }

    set selectedEnv(value) {
        // Normalize incoming value
        const newValue = value ? value.toUpperCase() : 'DEV';

        // Prevent unnecessary reloads
        if (this._selectedEnv === newValue) {
            return;
        }

        this._selectedEnv = newValue;

        // ✅ Trigger data reload when value comes from parent
        if (this._recordId) {
            this.loadRuns();
        }
    }


    envOptions = [
        { label: 'DEV', value: 'DEV' },
        { label: 'QA', value: 'QA' },
        { label: 'UAT', value: 'UAT' },
        { label: 'PROD', value: 'PRODUCTION' }
    ];


    handleChange(event) {
        this.intId = null; // clear previous environment Job ID
        this.selectedEnv = event.detail.value;

        if (this._recordId) {
            this.loadRuns();
        }
    }


    loadRuns() {
        getJobRuns({
            recordId: this._recordId,
            env: this.selectedEnv
        })
            .then(result => {
                // Always reset first
                this.intId = null;

                if (result) {
                    this.intId = result.intId || null;
                }

                if (result?.runs?.length > 0) {
                    this.runData = result.runs;
                    this.showTable = true;
                    this.showAudit = false;
                    this.errorMessage = '';
                } else {
                    this.runData = [];
                    this.errorMessage = 'No job run data available.';
                    this.showTable = false;
                    this.showAudit = false;
                }
            })
            .catch(error => {
                this.intId = null;
                this.errorMessage = 'No job run data available.';
                this.showTable = false;
                this.showAudit = false;
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view') {
            this.selectedRunId = row.runId;
            this.executionStatus = row.status;
            this.runCompletionTime = row.endTime;
            this.runRecordCount = row.recordCount;
            this.loadAudit(row.runId);
        }
    }

    loadAudit(runId) {
        getAuditDetails({ intId: this.intId, runId: runId, env: this.selectedEnv })
            .then(result => {
                this.auditData = result;
                this.showAudit = true;
                this.showTable = false;
            })
            .catch(error => {
                console.error('Error loading audit:', JSON.stringify(error));
            });
    }

    handleBack() {
        this.showAudit = false;
        this.showTable = true;
    }

    handleRun() {
        if (!this.intId) {
            this.showNoJobIdPrompt = true;
            return;
        }

        this.showPrompt = true;
    }

    handleNoJobIdClose() {
        this.showNoJobIdPrompt = false;
    }

    handleCancel() {
        this.showPrompt = false;
    }


    handleContinue() {
        requestAdhoc({ intId: this.intId, env: this.selectedEnv })
            .then(result => {
                if (result === true) {
                    this.showToast('Success', 'Run request submitted successfully.', 'success');
                } else {
                    this.showToast('Error', 'Run request failed.', 'error');
                }
                this.loadRuns();
                this.showPrompt = false;
                this.showAudit = false;
                this.showTable = true;
            })
            .catch(error => {
                console.error('Error loading audit:', JSON.stringify(error));
                this.showToast('Error', 'Something went wrong.', 'error');
            });
    }


    showSnapshotPrompt = false;
    handleRequestSnapshot() {
        this.showSnapshotPrompt = true;
        this.showAudit = false;
        this.showTable = true;
    }

    handleSnapshotCancel() {
        this.showSnapshotPrompt = false;
        this.showAudit = true;
        this.showTable = false;
    }

    handleSnapshotContinue() {
        this.adhocRun(this.intId, this.selectedRunId);

    }

    adhocRun(intId, runId) {
        requestSnapshot({ intId: intId, runId: runId, env: this.selectedEnv })
            .then(result => {
                if (result === true) {
                    this.showToast('Success', 'Run request submitted successfully.', 'success');
                } else {
                    this.showToast('Error', 'Run request failed.', 'error');
                }
                this.loadRuns();
                this.showAudit = false;
                this.showSnapshotPrompt = false;
                this.showTable = true;
            })
            .catch(error => {
                console.error('Error loading audit:', JSON.stringify(error));
                this.showToast('Error', 'Something went wrong.', 'error');
            });
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


}