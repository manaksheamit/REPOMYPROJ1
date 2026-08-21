import { api, LightningElement, wire } from 'lwc';
import AEHC_getApprovals from '@salesforce/apex/AEHC_HandleSubscriptionApproval.AEHC_getApprovals';
import AEHC_processApproval from '@salesforce/apex/AEHC_HandleSubscriptionApproval.AEHC_processApproval';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AehcSubscriptionApprovalList extends LightningElement {

    @api recordId;
    aehc_subscriptionId;
    aehc_records = [];
    showUI = false;
    uatToggle = false;

    // ✅ Get Subscription Id from URL
    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef) {
            console.log(pageRef);

            this.recordId = pageRef.state.subscriptionId;
            console.log('recordId:', this.recordId);

            if (!this.recordId && pageRef.attributes && pageRef.attributes.recordId) {
                this.recordId = pageRef.attributes.recordId;
            }

            console.log(26, this.recordId);
        }
    }

    // ✅ Fetch approvals
    @wire(AEHC_getApprovals, { aehc_subscriptionId: '$recordId' })
    wiredData({ data, error }) {
        console.log('wire', this.recordId);
        console.log('data', data);
        if (data)
            console.log('data length', data.length);
        if (data && data.length > 0) {
            //this.aehc_records = data;
            console.log('queueName'+JSON.stringify(data));
            this.aehc_records = data.map(rec => {
                const isBO = rec.aehc_queueName === 'Publication Business Owner';

                // check if DDH Admin AND the flag is true
                const isDDHAdminFlagged = rec.aehc_queueName === 'DDH Admin' && rec.aehc_transformationFlag === true;

                return {
                    ...rec,
                    isPublicationBO: isBO,
                    uatToggle: false,
                    isDDHAdminWithFlag: isDDHAdminFlagged,
                    transformationId: rec.aehc_transformationId || ''
                };
            });

            this.showUI = true;
        } else {
            this.showUI = false;
        }
        console.log(this.showUI);
    }

    // ✅ Approve / Reject handler

    aehc_commentsMap = {};

    handleCommentChange(event) {
        const id = event.target.dataset.id;
        this.aehc_commentsMap[id] = event.target.value;
        event.target.setCustomValidity('');
        event.target.reportValidity();

    }

    handleAction(event) {
        const workItemId = event.target.dataset.id;
        const action = event.target.dataset.action;
        const comment = this.aehc_commentsMap[workItemId];
        

    if (action === 'Reject' && (!comment || !comment.trim())) {

        const textarea = this.template.querySelector(
            `lightning-textarea[data-id="${workItemId}"]`
        );

        if (textarea) {
            textarea.setCustomValidity(
                'Please fill the comment.'
            );
            textarea.reportValidity();
        }

        return;
    }

    // Clear previous error if any
    const textarea = this.template.querySelector(
        `lightning-textarea[data-id="${workItemId}"]`
    );

    if (textarea) {
        textarea.setCustomValidity('');
        textarea.reportValidity();
    }


        
const rec = this.aehc_records.find(
        r => r.aehc_workItemId === workItemId
    );

    const uatToggle = rec?.uatToggle === true;
    const transId = rec?.transformationId;

    if (rec.isDDHAdminWithFlag && action === 'Approve') {

        const input = this.template.querySelector(
            `lightning-input[data-id="${workItemId}"]`
        );
        if (input && !input.checkValidity()) {
            input.reportValidity();
            return;
        }        
    }

        console.log('workItemId', workItemId);
        console.log('action', action);
        console.log('comment', comment);
        AEHC_processApproval({
            aehc_workItemId: workItemId,
            aehc_action: action,
            aehc_comments: comment,
            uatToggle: uatToggle,
            transformationId: transId

        })
            .then(result => {
                if(result === 'Success')
                {
                    this.showToast('Success!', `Record ${action === 'Approve' ? 'Approved' : 'Rejected'} Successfully`, 'success');
                    console.log('success');
                    location.reload();
                }
                else if(result === 'Failed')
                {
                    this.showToast('Approval Failed Contact System Admin');
                    location.reload();
                    
                }else
                {
                    this.showToast(result);  
                    location.reload();                  
                }
            });
    }
    
    showToast(title, message, variant) {
        // Dispatch toast event
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
    
get showUatColumn() {
    return this.aehc_records?.some(rec => rec.isPublicationBO);
}

handleRowToggle(event) {

    const id = event.target.dataset.id;
    const value = event.detail.checked;

    this.aehc_records = this.aehc_records.map(rec => {
        if (rec.aehc_workItemId === id) {
            return { ...rec, uatToggle: value };
        }
        return rec;
    });
}

get showTransformationColumn(){
    return this.aehc_records?.some(rec => rec.isDDHAdminWithFlag);
}

handleTransformationChange(event) {

    const id = event.target.dataset.id;
    const value = event.target.value?.trim();

    this.aehc_records = this.aehc_records.map(rec => {
        if (rec.aehc_workItemId === id) {
            return {...rec, transformationId: value};
        }
        return rec;
    });
}


}