import { LightningElement, api, track } from 'lwc';
import getSubscribers from '@salesforce/apex/AEHCSubscriberController.getSubscribers';

export default class AehcSubscribersLwc extends LightningElement {

    @api recordId;
    @api environment;
    viewLoadMore = false;

    searchKey = '';
    limitSize = 10;
    offsetVal = 0;


    @track data = [];

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        getSubscribers({
            publicationId: this.recordId,
            environment: this.environment,
            searchKey: this.searchKey,
            limitSize: this.limitSize,
            offsetVal: this.offsetVal
        })
        .then(result => {
            const formatted = result.subscribers.map(row => ({
                ...row,
                createdDate: this.formatDate(row.createdDate),
                approvedDate: this.formatDate(row.approvedDate)
            }));

            if (this.offsetVal === 0) {
                this.data = formatted;
            } else {
                this.data = [...this.data, ...formatted];
            }
                    
            // Show Load More only if more records exist
            this.viewLoadMore = this.data.length < result.totalCount;

        })
        .catch(error => {
            console.error(error);
        });
    }

    handleSearch(event) {
        this.searchKey = event.target.value;
        this.offsetVal = 0;
        this.data = [];
        this.loadData();
    }

    handleLoadMore() {
        this.offsetVal += this.limitSize;
        this.loadData();
    }

    formatDate(dateVal) {
        if (!dateVal) return '';
        const d = new Date(dateVal);
        return d.toLocaleString();
    }
}