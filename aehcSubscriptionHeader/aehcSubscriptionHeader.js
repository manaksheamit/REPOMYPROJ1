import { LightningElement, api, wire } from 'lwc';
import L_SUBSCRIBE from '@salesforce/label/c.AEHC_DP_Subscribe';
import L_DATABASE from '@salesforce/label/c.AEHC_DP_Database';
import showHideButton from '@salesforce/apex/AEHC_RoleBaseBtnVisibility.ButtonVisibility';
import hasUserRoleForApplication from '@salesforce/apex/AEHCSubscriptionHeaderController.hasUserRoleForApplication';
import isUserDeveloperOrBusinessOwner from '@salesforce/apex/AEHC_SubscriptionController_DP.checkEligibilityBasedOnRole';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import canEditPublication from '@salesforce/apex/AEHC_SubscriptionController_DP.canEditPublication';


export default class AehcSubscriptionHeader extends LightningElement {
    @api applicationName;
    @api publicationName;
    @api isPromoteFlow = false;
    @api isSubscribed = false;
    @api showSubscribe;
    @api showPromote;
    @api showEditPublication;
    @api recordId; 
    isShowJobHistory = false;
    isHideButton = false;
    
    labels = {
        subscribe: L_SUBSCRIBE,
        database: L_DATABASE
    };
    hasRequiredRole = false;
    
/**
     * Gets current page reference and extracts record Id from URL.
     * Example URL:
     * /lightning/r/AEHC_Asset__c/{recordId}/view
     */
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef) {

            console.log('wire recordid',this.recordId);
            console.log('pagereference Id',pageRef.state?.id);

            this.recordId = pageRef.state?.id;
            console.log('Subscriber record id',this.recordId);
            if (this.recordId) {
                this.checkUserRolePublication();
            }
            this.checkUserRole();
        }
    }
    /**
     * Calls Apex to verify whether the current user
     * has the required role for Edit Publication.
     */
    async checkUserRolePublication() {
    try {

        const result = await canEditPublication({
            publicationId: this.recordId
        });

        //this.hasRequiredRole = result === true;

        console.log('✅ isDeveloperOrOwner:', this.hasRequiredRole);

        // ✅ control edit button
        this.showEditPublication = result === true;

    } catch (error) {
        console.error('Error checking role:', error);
    
        this.showEditPublication = false;
    }
}


    /**
     * Calls Apex to verify whether the current user
     * has the required role for the Application Asset.
     */
    async checkUserRole() {
        try {
            this.hasRequiredRole = await hasUserRoleForApplication({
                recordId: this.recordId,
                roleValue: 'Enterprise Architect' 
            });

        } catch (error) {
            console.error('Error checking role:', error);
        }
    }

    
    

    @wire(showHideButton)
    wiredData({ data, error }) {
        if (data !== undefined) {
            this.isHideButton = data;
        } else if (error) {
            this.isShowButton = false;
            console.error('Button visibility error:', error);
        }
    }
    


    handleSubscribers() {
        this.dispatchEvent(new CustomEvent('subscribers'));
    }
    handleSubscribe() {
        this.dispatchEvent(new CustomEvent('subscribe'));
    }
    handlePromoteClick() {
        this.dispatchEvent(new CustomEvent('promote'));
    }
    handleEditClick() {
        window.location.href = `${basePath}/manage-publication?id=${this.recordId}`;
    }
    get hideButtons() {
        return this.isPromoteFlow || this.isSubscribed;
    }
    handleRunClick(){
        this.dispatchEvent(new CustomEvent('jobhistory'));
    }
    handleVersionHistory() {
    this.dispatchEvent(
        new CustomEvent('versionhistory')
    );
}
    


}