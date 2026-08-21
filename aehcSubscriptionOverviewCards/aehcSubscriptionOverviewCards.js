import { LightningElement, api } from 'lwc';

export default class AehcSubscriptionOverviewCards extends LightningElement {

    @api applicationName;
    @api applicationId;

    @api publicationName;
    @api publicationId;
    @api publicationRecordId;
    @api purposeOfUse;

    get hasApplicationId() {
        return this.applicationId && this.applicationId.trim() !== '';
    }

    get hasPublicationId() {
        return this.publicationId && this.publicationId.trim() !== '';
    }
    
get hasPublicationRecordId() {
    return this.publicationRecordId && this.publicationRecordId.trim() !== '';
}


    get applicationNameWithId() {
        return this.hasApplicationId
            ? `${this.applicationName} (${this.applicationId})`
            : this.applicationName;
    }

    get publicationNameWithId() {
        return this.hasPublicationId
            ? `${this.publicationName} (${this.publicationId})`
            : this.publicationName;
    }

    get baseUrl() {
        return window.location.origin;
    }


    get applicationUrl() {
        return `${this.baseUrl}/aeh/s/data-publications-catalog?application=${encodeURIComponent(this.applicationName || '')}`;
    }

    get publicationUrl() {
        return `${this.baseUrl}/aeh/s/data-publication-details?id=${this.publicationRecordId}`;
    }
}