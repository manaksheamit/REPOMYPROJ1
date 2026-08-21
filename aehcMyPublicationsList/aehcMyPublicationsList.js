import { LightningElement, track, wire } from 'lwc';
import getMyPublications from '@salesforce/apex/AEHC_CustomListViewController.getMyPublications';

const COLUMNS = [
    { 
        label: 'Publication', fieldName: 'recordLink', type: 'url', sortable: true,
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_self'
        }

    },
    { label: 'Publication Type', fieldName: 'AEHC_Publication_Type__c', type: 'text',sortable: true },
    { label: 'Publication Id', fieldName: 'AEHC_Publication_Id__c', type: 'text',sortable: true },
    { label: 'Application', fieldName: 'ApplicationName', type: 'text',sortable: true },
    {
        label: 'Created Date', fieldName: 'CreatedDate', type: 'date',sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            timeZone: 'UTC',
            timeZoneName: 'short'
        }
    }
];

export default class AehcMyPublicationsList extends LightningElement {
    columns = COLUMNS;
    publications = [];
    error;
    sortedBy = 'CreatedDate';
    sortedDirection = 'desc';

    @wire(getMyPublications)
    wiredPublications({ error, data }) {
        if (data) {
            let baseUrl = window.location.origin;
            this.publications = data.map( record => {
                let pubUrl = `${baseUrl}/aeh/s/data-publication-details?id=${record.Id}`;
                return {
                    ...record,
                    recordLink: pubUrl,
                    ApplicationName: record.AEHC_Application__r?.Name || ''
                };
            });
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unknown error';
            this.publications = undefined;
            console.error('Error fetching publications:', error);
        }
    }
    handleSort(event) {
    const { fieldName: sortedBy, sortDirection } = event.detail;

    let cloneData = [...this.publications];

    cloneData.sort((a, b) => {
        let x = a[sortedBy] ?? '';
        let y = b[sortedBy] ?? '';

        if (sortedBy === 'CreatedDate') {
            x = new Date(x).getTime();
            y = new Date(y).getTime();
        }

        if (typeof x === 'string') {
            x = x.toLowerCase();
            y = y.toLowerCase();
        }

        return sortDirection === 'asc'
            ? (x > y ? 1 : x < y ? -1 : 0)
            : (x < y ? 1 : x > y ? -1 : 0);
    });

    this.publications = cloneData;
    this.sortedBy = sortedBy;
    this.sortedDirection = sortDirection;
}

}