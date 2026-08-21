/*
 * LWC component to manage publication promotion UI
 * Handles status retrieval, validation, and promotion action
 */ 

import { LightningElement, api, wire, track } from 'lwc';
import getPromotionStatus from '@salesforce/apex/AEHC_PublicationPromoteController.getPromotionStatus';
import promotePublication from '@salesforce/apex/AEHC_PublicationPromoteController.promotePublication';

import isRecordPendingApproval from '@salesforce/apex/AEHC_PublicationPromoteController.isRecordPendingApproval';
import processApprovalAction from '@salesforce/apex/AEHC_PublicationPromoteController.processApprovalAction';

export default class AehcPublicationPromote extends LightningElement {

    @api publicationId;
    @api environmentValue;

    publication;
    hasPendingVersion = false;
    hasAccess = false;
    hasSameVersion = false;
    isLoading = false;

    // ✅ Approval UI
    @track showApprovalScreen = false;
    @track approvalAction = 'Promote';
    @track approvalComments = '';

    @wire(getPromotionStatus, { recordId: '$publicationId' ,env : '$environmentValue' })
    wiredStatus({ data, error }) {
        console.log('promote lwc : '+this.environmentValue);
        if (data) {
            this.publication = data.publication;
            this.hasPendingVersion = data.hasPendingVersion;
            this.hasAccess = data.hasAccess; 
            this.hasSameVersion = data.hasSameVersion;
             isRecordPendingApproval({ subscriptionId: this.publicationId,env : this.environmentValue })
        .then(isPending => {

            if (isPending) {
               
                this.showApprovalScreen = this.publication.approvalPermission ;
            } else {
                
               
            }

        })
        .catch(() => {
           
        });
        } else if (error) {
            this.showToast('Error', error.body?.message, 'error');
        }
    }

    get isApproved() {
        return this.publication?.Approval_Status__c === 'Active';
    }

    get canPromote() {
        return this.hasAccess && this.isApproved && !this.hasPendingVersion;
    }

    get sourceEnv() {
        return this.publication?.AEHC_Environment__c;
    }

    get destinationEnv() {
        switch (this.sourceEnv) {
            case 'Dev': return 'QA';
            case 'QA': return 'UAT';
            case 'UAT': return 'Production';
            default: return '';
        }
    }

    get message() {
        if (!this.hasAccess) {
            return "User don't have access to promote the record";
        }
        if (!this.isApproved) {
            return 'Current record is not approved yet.';
        }
        if (this.hasPendingVersion) {
            return 'Already promoted record is sent for approval.';
        }
        if (this.hasSameVersion) {
            return 'Already promoted record for this version.';
        }
        if(this.sourceEnv == 'Production') {
            return 'Already promoted prod.';
        }
        return '';
    }

    // ✅ MODIFIED ENTRY (NO LOGIC BREAK)
    handlePromote() {
        console.log(this.publication.Id);
        console.log(this.publication);
          this.executePromotion();
           
    }

    //  ORIGINAL LOGIC MOVED (UNCHANGED)
    executePromotion() {
        this.isLoading = true;

        promotePublication({ recordId: this.publicationId, env: this.environmentValue })
            .then(newVersionId => {
                this.dispatchEvent(
                    new CustomEvent('promotesuccess', {
                        detail: { newVersionId }
                    })
                );
            })
            .catch(error => {
                console.error('Promote error', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close',{
            detail:this.environmentValue
        }));
    }

    // ✅ Approval UI

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

    // ✅ APPROVE / REJECT FLOW
    handleApprovalSubmit() {

        processApprovalAction({
            recordId: this.publicationId,
            action: this.approvalAction,
            comments: this.approvalComments,env : this.environmentValue 
        })
        .then(res => {

            if (res === 'SUCCESS') {

                // ✅ If approved → continue ORIGINAL promote
                if (this.approvalAction === 'Promote') {
                    this.showApprovalScreen = false;
                    this.executePromotion();
                } 
                // ✅ If rejected → just close approval UI
                else {
                    this.showApprovalScreen = false;
                }

            } else {
                throw new Error('Approval failed');
            }

        })
        .catch(error => {
            console.error('Approval error', error);
        });
    }
}