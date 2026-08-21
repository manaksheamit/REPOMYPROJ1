import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getRequestDetails from '@salesforce/apex/AEHC_ReqIdAndStatusStampingSNOW.getRequestDetails';

export default class AehcSubscriptionSnowStatus extends LightningElement {
    @api recordId;

    isCalled = false;

    @wire(CurrentPageReference)
    handlePageRef(ref) {
        if (ref) {
            this.recordId = ref.state?.subscriptionId;
            console.log('recordId --->>>', this.recordId);

            if (this.recordId && !this.isCalled) {
                this.isCalled = true;

                setTimeout(() => {
                    this.loadRequestDetail();
                }, 3000);
            }
        }
    }

    loadRequestDetail() {

        getRequestDetails({ recordId: this.recordId })
            .then(result => {
                console.log('Result:', result);
            })
            .catch(error => {
                console.error('Error:', error);
            });
    }
}