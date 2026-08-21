import { LightningElement, track, wire, api } from 'lwc';
import getApprovalHistory from '@salesforce/apex/AEHC_ApprovalHistoryController.getApprovalHistory';
import { CurrentPageReference } from 'lightning/navigation';
import L_APPROVALHISTORY from '@salesforce/label/c.AEHC_ApprovalHistory';
export default class AehcApprovalHistory extends LightningElement {
    
    @api recordId;  // automatically passed on record pages

    data = [];
    error;
    @api selectedEnvironment;
    @api selectedVersion;
    columns = [
        { label: 'Step Name', fieldName: 'stepName' },
        { label: 'Date', fieldName: 'datefield', type: 'date' },
        { label: 'Status', fieldName: 'status' },
        { label: 'Assigned To', fieldName: 'assignedTo' },
        { label: 'Actual Approver', fieldName: 'actualApprover' },
        { label: 'Comments', fieldName: 'comments' }
    ];
    labels = {
        approvalhistory: L_APPROVALHISTORY
    };
    //${this.labels?.approvalhistory || ''} | 
    get cardTitle() {
        return `Environment- ${this.selectedEnvironment || ''} | Version - ${this.selectedVersion || ''}`;
    }

    
    
@wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef) {
            console.log('@@@@ pageRef', JSON.stringify(pageRef));

            // Try all possible keys used by community
            this.recordId =
                this.recordId ||
                pageRef.state?.recordId ||
                pageRef.state?.id ||
                pageRef.attributes?.recordId;

            // ✅ LAST fallback: parse from URL manually
            if (!this.recordId && window.location.pathname) {
                const pathParts = window.location.pathname.split('/');
                this.recordId = pathParts[pathParts.length - 1];
            }

            console.log('@@@@ resolved recordId', this.recordId);
        }
    }

    // ✅ Call Apex only when recordId exists
    @wire(getApprovalHistory, { recordId: '$recordId' })
    wiredHistory({ error, data }) {
        console.log('@@@@ wire recordId', this.recordId);

        if (!this.recordId) {
            console.warn('RecordId still not available');
            return;
        }

        if (data) {
            console.log('@@@@ data', data);
            this.data = data;
            this.error = undefined;
        } else if (error) {
            console.error('@@@@ error', error);
            this.error = error;
            this.data = [];
        }
    }


}