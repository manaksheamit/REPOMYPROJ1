import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import hasPendingApproval from '@salesforce/apex/Aehcapprovesubs.hasPendingApproval';
import approveRecord from '@salesforce/apex/Aehcapprovesubs.approveRecord';
import rejectRecord from '@salesforce/apex/Aehcapprovesubs.rejectRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class aehcapprovesubs extends LightningElement {

    @api recordId;
    @track remarks = '';
    @track showActions = false;

    // Get recordId from URL
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.attributes?.recordId;

            if (!this.recordId && currentPageReference.state?.id) {
                this.recordId = currentPageReference.state.id;
            }

            if (!this.recordId && currentPageReference.state?.recordId) {
                this.recordId = currentPageReference.state.recordId;
            }

            if (this.recordId) {
                this.checkApproval();
            }
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this.checkApproval();
        }
    }

    checkApproval() {
    hasPendingApproval({ recordId: this.recordId })
        .then(result => {
            console.log('checkApproval FULL:', result);

            this.showActions = result.data;

            console.log('Message:', result.message);
            console.log('Data:', result.data);

            this.showToast(
                result.success ? 'Success' : 'Info',
                result.message,
                result.success ? 'success' : 'info'
            );
        })
        .catch(error => {
            console.error('checkApproval ERROR:', error);
            this.showToast('Error', error?.body?.message || error, 'error');
        });
}

handleApprove() {
    if (!this.validate()) return;

    approveRecord({ recordId: this.recordId, remarks: this.remarks })
        .then(result => {
            console.log('Approve FULL:', result);

            this.showToast(
                result.success ? 'Success' : 'Error',
                result.message,
                result.success ? 'success' : 'error'
            );

            if (result.success) {
                this.showActions = false;
            }
        })
        .catch(error => {
            console.error('Approve ERROR:', error);
            this.showToast('Error', error?.body?.message || error, 'error');
        });
}

handleReject() {
    if (!this.validate()) return;

    rejectRecord({ recordId: this.recordId, remarks: this.remarks })
        .then(result => {
            console.log('Reject FULL:', result);

            this.showToast(
                result.success ? 'Success' : 'Error',
                result.message,
                result.success ? 'success' : 'error'
            );

            if (result.success) {
                this.showActions = false;
            }
        })
        .catch(error => {
            console.error('Reject ERROR:', error);
            this.showToast('Error', error?.body?.message || error, 'error');
        });
}

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    validate() {
        if (!this.remarks || this.remarks.trim() === '') {
            this.showToast('Error', 'Remarks are required', 'error');
            return false;
        }
        return true;
    }

    handleApprove() {
        if (!this.validate()) return;

        approveRecord({ recordId: this.recordId, remarks: this.remarks })
            .then(result => {
                // ✅ Full debug logging
                console.log('Approve Full Response:', result);
                console.log('Approve Message:', result.message);
                console.log('Approve Data:', result.data);

                this.showToast(
                    result.success ? 'Success' : 'Error',
                    result.message,
                    result.success ? 'success' : 'error'
                );

                if (result.success) {
                    this.showActions = false;
                }
            })
            .catch(error => {
                console.error('Approve Error:', error);
                this.showToast('Error', error?.body?.message || error, 'error');
            });
    }

    handleReject() {
        if (!this.validate()) return;

        rejectRecord({ recordId: this.recordId, remarks: this.remarks })
            .then(result => {
                // ✅ Full debug logging
                console.log('Reject Full Response:', result);
                console.log('Reject Message:', result.message);
                console.log('Reject Data:', result.data);

                this.showToast(
                    result.success ? 'Success' : 'Error',
                    result.message,
                    result.success ? 'success' : 'error'
                );

                if (result.success) {
                    this.showActions = false;
                }
            })
            .catch(error => {
                console.error('Reject Error:', error);
                this.showToast('Error', error?.body?.message || error, 'error');
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