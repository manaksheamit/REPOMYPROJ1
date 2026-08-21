import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getSubscriptionData from '@salesforce/apex/AEHC_SubscriptionApprovalController.getSubscriptionData';
import handleApproval from '@salesforce/apex/AEHC_SubscriptionApprovalController.handleApproval';

export default class SubscriptionApproval extends NavigationMixin(LightningElement) {

    @api recordId;

    @track subscription;
    @track status = '';
    @track comment = '';

    @track isAssetOwnerApprover = false;
    @track showApprovalActions = false;

    @track isLoading = false;
    @track isSaving = false;
    @track isLoaded = false;
    @track hasError = false;
    @track errorMessage = '';
    @track commentError = false;

    /* ---------------------------------------------
       RECORD ID
    ----------------------------------------------*/
    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (!this.recordId && pageRef) {
            this.recordId =
                pageRef.attributes?.recordId ||
                pageRef.state?.recordId ||
                pageRef.state?.c__recordId ||
                this.getRecordIdFromUrl();
        }

        if (this.recordId) {
            this.loadSubscriptionData();
        }
    }

    getRecordIdFromUrl() {
        const match = window.location.href.match(/\/([a-zA-Z0-9]{15,18})(\/|$|\?)/);
        return match ? match[1] : null;
    }

    /* ---------------------------------------------
       LOAD DATA
    ----------------------------------------------*/
    loadSubscriptionData() {
        this.isLoading = true;
        this.hasError = false;

        getSubscriptionData({ recordId: this.recordId })
            .then(data => {
                console.log('RESPONSE:', data);

                this.subscription = data.subscription;
                this.status = data.subscription.Status__c;
                this.comment = data.subscription.Comment__c || '';

                this.isAssetOwnerApprover = data.isAssetOwnerApprover;
                this.showApprovalActions = data.showApprovalActions;

                this.isLoaded = true;
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage =
                    error?.body?.message || 'Failed to load data';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ---------------------------------------------
       COMMENT HANDLING
    ----------------------------------------------*/
    handleCommentChange(event) {
        this.comment = event.target.value;
        this.commentError = false;
    }

    /* ---------------------------------------------
       APPROVE / REJECT
    ----------------------------------------------*/
    action(event) {
        const actionType = event.target.label;
        const textarea = this.template.querySelector('lightning-textarea');

        if (actionType === 'Reject') {
            if (!this.comment || !this.comment.trim()) {
                if (textarea) {
                    textarea.setCustomValidity('Comment is mandatory to reject.');
                    textarea.reportValidity();
                }
                this.commentError = true;
                this.showToast('Error', 'Comment is mandatory to reject.', 'error');
                return;
            }
        }

        if (textarea) {
            textarea.setCustomValidity('');
            textarea.reportValidity();
        }

        if (this.isSaving) return;

        this.isSaving = true;

        handleApproval({
            recordId: this.recordId,
            action: actionType,
            comments: this.comment
        })
            .then(() => {
                this.showToast(
                    'Success',
                    `Subscription ${actionType}ed successfully`,
                    'success'
                );

                this.showApprovalActions = false;
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || 'Action failed',
                    'error'
                );
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}