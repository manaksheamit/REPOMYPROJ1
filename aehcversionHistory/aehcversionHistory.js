import { LightningElement,api,wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getVersionHistory from '@salesforce/apex/AEHC_VersionHistoryController.getVersionHistory';

export default class AehcversionHistory extends LightningElement {  
    
    @api recordId;
    data;
    error;
    @api selectedVersion;
    @api selectedEnv;

    columns = [
        { label: 'Name', fieldName: 'name' },
        //{ label: 'Approval Status', fieldName: 'approvalStatus' },
        { label: 'Environment', fieldName: 'environment' },
        { label: 'Active', fieldName: 'isActive' },
        { label: 'Version Number', fieldName: 'schemaVersion' },
        { label: 'LatModifiedDate', fieldName: 'lastModifieddate' }
    ];
    


    // ✅ Get recordId from Experience Cloud URL
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

    // ✅ Call Apex when recordId is available
    @wire(getVersionHistory, { recordId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.data = undefined;
        }
    }


}