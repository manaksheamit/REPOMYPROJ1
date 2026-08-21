import { LightningElement, wire } from 'lwc';
import canViewSubscriberButton from '@salesforce/apex/AEHC_SubscriberButtonHandler.canViewSubscriberButton';

export default class AehcSubscriberButton extends LightningElement {

    showButton = false;
    isSubscriberModal = false;
    assetRecordId;

    connectedCallback() {
        this.assetRecordId = this.extractAssetRecordId();
    }

    @wire(canViewSubscriberButton)
    wiredAccess({ error, data }) {
        console.log('@@@ wiredAccess data', data);
        console.log('@@@ wiredAccess error', error);
        if (data !== undefined) {
            this.showButton = data;
        } else if (error) {
            console.error('Error checking subscriber button access', error);
        }
    }

    extractAssetRecordId() {
        try {
            const pathParts = window.location.pathname.split('/');
            const communityAssetIndex = pathParts.indexOf('communityasset');

            if (
                communityAssetIndex > -1 &&
                pathParts.length > communityAssetIndex + 1
            ) {
                return pathParts[communityAssetIndex + 1];
            }

            return null;
        } catch (e) {
            console.error('Error extracting Asset Record Id', e);
            return null;
        }
    }

    openSubscriberModal() {
        this.isSubscriberModal = true;
    }

    closeSubscriberModal() {
        this.isSubscriberModal = false;
    }
}