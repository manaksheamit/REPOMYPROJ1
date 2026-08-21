import { LightningElement, api, wire, track } from 'lwc';
import getJobRuns from '@salesforce/apex/AEHC_ViewJobHistoryController.getJobRuns';
import getAuditDetails from '@salesforce/apex/AEHC_ViewJobHistoryController.getAuditDetails';
import { CurrentPageReference } from 'lightning/navigation'

export default class AehcPublicationJobHistory extends LightningElement {

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
    
    
        @wire(CurrentPageReference)
        getStateParameters(currentPageReference) {
            if (currentPageReference) {
                const idFromUrl = currentPageReference.state?.id;

                console.log('✅ recordId from URL:', idFromUrl);

                // ✅ Only run when value changes OR first load
                if (idFromUrl && idFromUrl !== this._recordId) {
                    this._recordId = idFromUrl;
                    this.loadRuns();
                }
            }
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

    // ✅ Default stays DEV
    selectedEnv = 'DEV';

    envOptions = [
        { label: 'DEV', value: 'DEV' },
        { label: 'QA', value: 'QA' },
        { label: 'UAT', value: 'UAT' },
        { label: 'PROD', value: 'Production' }
    ];
   


    // ✅ UPDATED: reload data on env change
    handleChange(event) {
        this.selectedEnv = event.detail.value;

        // ✅ Re-call Apex with new env (only if recordId exists)
        if (this._recordId) {
            this.loadRuns();
        }
    }

    // ✅ UPDATED: pass env to Apex
    loadRuns() {
        getJobRuns({
            recordId: this._recordId,
            env: this.selectedEnv
        })
            .then(result => {
                if (result && result.runs && result.runs.length > 0) {
                    this.runData = result.runs;
                    this.intId = result.intId;
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
        getAuditDetails({ intId: this.intId, runId: runId, env : this.selectedEnv })
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

}