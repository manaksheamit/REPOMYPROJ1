import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Subscription__c.Status__c',
    'Subscription__c.AEHC_AssetType__c',
    'Subscription__c.API_Name__c'
];

export default class Aehcschemabrowserlauncher extends LightningElement {

    recordId; // ✅ will be set from URL
    isModalOpen = false;

    status;
    assetType;
    apiName;

    // ✅ Get recordId from Site URL
    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef) {
            // Most common param names
            this.recordId =
                pageRef.state.recordId ||
                pageRef.state.id ||
                pageRef.attributes?.recordId ||
                pageRef.state.subscriptionId;

        }
    }

    // ✅ Fetch record
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.status = data.fields.Status__c.value;
            this.assetType = data.fields.AEHC_AssetType__c.value;
            this.apiName = data.fields.API_Name__c.value;
        } else if (error) {
            console.error(error);
        }
    }

    handleClick() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    get isVisible() {
        return (
            this.recordId && // ✅ ensure recordId exists
            this.assetType === 'graphql' &&
            this.status !== 'Approved' &&
            this.status !== 'Rejected'
        );
    }
}