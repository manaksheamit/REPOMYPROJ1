import { LightningElement, api, wire } from 'lwc';
import L_VIEWJOB from '@salesforce/label/c.AEHC_ViewJobRun';
import L_VERSIONHISTORY from '@salesforce/label/c.AEHC_VersionHistory';
import showHideButton from '@salesforce/apex/AEHC_RoleBaseBtnVisibility.ButtonVisibility';
export default class AehcSubscriptionPageHeader extends LightningElement {

    @api subscriptionName;
    labels = {
        viewjob: L_VIEWJOB,
        versionhistory: L_VERSIONHISTORY
    };

    isHideButton = false;

    @wire(showHideButton)
    wiredData({ data, error }) {
        if (data !== undefined) {
            this.isHideButton = data;
        } else if (error) {
            this.isShowButton = false;
            console.error('Button visibility error:', error);
        }
    }

    handleVersionHistory() {
        this.dispatchEvent(new CustomEvent('versionhistory'));
    }

    handleJobHistory() {
        this.dispatchEvent(new CustomEvent('jobhistory'));

    }
    
    

}