import { LightningElement, track, wire } from 'lwc';
import getMySubscriptions from '@salesforce/apex/AEHC_CustomListViewController.getMySubscriptions';

const COLUMNS = [
    { 
        label: 'Subscription Id', fieldName: 'subscriptionUrl', type: 'url', sortable: true,
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_self'
        }

    },
    {label: 'Consuming Application Name', fieldName: 'consumingAppName', type: 'text', sortable: true},
    {label: 'Publishing Application Name', fieldName: 'publishingAppName', type: 'text', sortable: true},
    { 
        label: 'Product Name', fieldName: 'productUrl', type: 'url', sortable: true,
        typeAttributes: {
            label: { fieldName: 'productName' },
            target: '_self'
        }

    },
    { label: 'Product Type', fieldName: 'AEHC_AssetType__c', type: 'text' , sortable: true},
    { label: 'Environment', fieldName: 'AEHC_Environment_Name__c', type: 'text' , sortable: true},
    { label: 'Status', fieldName: 'Status__c', type: 'text',sortable: true },
    {
        label: 'Last Modified Date', fieldName: 'LastModifiedDate', type: 'date',sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            timeZone: 'UTC',
            timeZoneName: 'short'
        }
    },
    { label: 'Created By', fieldName: 'CreatedByName', type: 'text',sortable: true }
];

export default class AehcMySubscriptionsList extends LightningElement {
    @track selectedView = 'My Applications Subscriptions';
    @track columns = COLUMNS;
    subscriptions = [];
    @track filteredSubscriptions = [];
    error;

    @track isFilterOpen = false;
    @track selectedConsumingApp = 'All';
    @track consumingAppOptions = [];
    @track searchTerm = '';
    
    sortedBy = 'consumingAppName';
    sortedDirection = 'asc';
     // The dropdown options
    get viewOptions() {
        return [
            { label: 'My Applications Subscriptions', value: 'My Applications Subscriptions' },
            { label: 'My Subscriptions', value: 'My Subscriptions' }
        ];
    }
 
    @wire(getMySubscriptions, { viewName: '$selectedView' })
    wiredSubscription({ error, data }) {
        if (data) {

            const baseUrl = window.location.origin;
            let uniqueApps = new Set();

            this.subscriptions = data.map( record => {

                let subUrl = `${baseUrl}/aeh/s/manage-subscriptions?subscriptionId=${record.Id}`;
                let prodUrl = '';
                let prodName = '';
                let consAppName = record.AEHC_Consumming_Application__r ? record.AEHC_Consumming_Application__r.Name : '';
                let pubAppName = record.AEHC_Application_Name__r ? record.AEHC_Application_Name__r.Name : '';

                if(consAppName){
                    uniqueApps.add(consAppName);
                }

                let recType = record.RecordType ? record.RecordType.DeveloperName : '';
                
                if(recType === 'API_Asset') {
                    if (record.Community_Asset__r){
                        prodName = record.Community_Asset__r.Name;
                        prodUrl = `${baseUrl}/aeh/s/communityasset/${record.Community_Asset__r.Id}/${encodeURIComponent(prodName)}`;
                    }
                }else if(recType === 'Data_Publication') {
                    if (record.AEHC_Publication_ID__r){
                        prodName = record.AEHC_Publication_ID__r.Name;
                        prodUrl = `${baseUrl}/aeh/s/data-publication-details?id=${record.AEHC_Publication_ID__r.Id}`;
                    }
                }


                return {
                    ...record,
                    subscriptionUrl: subUrl,
                    productUrl: prodUrl,
                    productName: prodName,
                    consumingAppName: consAppName,
                    publishingAppName: pubAppName,
                    CreatedByName: record.CreatedBy ? record.CreatedBy.Name : ''
                };
            });

            this.buildFilterOptions(uniqueApps);
            this.applyFilters();
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Unknown error';
            this.subscriptions = undefined;
            console.error('Error fetching subscriptions:', error);
        }
    }    

    toggleFilterPanel(){
        this.isFilterOpen = !this.isFilterOpen;
    }
    buildFilterOptions(uniqueAppsSet){
        const appOptions = Array.from(uniqueAppsSet).sort((a, b) => a.localeCompare(b)).map(appName => ({
            label: appName, value: appName
        }));
        this.consumingAppOptions = [ { label: 'All Applications', value: 'All' }, ...appOptions ];
    }
    handleFilterChange(event){
        this.selectedConsumingApp = event.detail.value;
        this.applyFilters();
    }
    clearFilters(){
        this.selectedConsumingApp = 'All';
        this.applyFilters();
    }
    applyFilters() {
        let filteredData = [...this.subscriptions];
        if (this.selectedConsumingApp !== 'All') {
            filteredData = filteredData.filter(
                sub => sub.consumingAppName === this.selectedConsumingApp
            );
        }
        const searchValue = this.searchTerm ? this.searchTerm.trim().toLowerCase() : '';
        if (searchValue) {
            filteredData = filteredData.filter(sub => {
                const searchableValues = [
                    sub.Name,
                    sub.consumingAppName,
                    sub.publishingAppName,
                    sub.productName,
                    sub.AEHC_AssetType__c,
                    sub.AEHC_Environment_Name__c,
                    sub.Status__c,
                    sub.CreatedByName
                ];
                return searchableValues.some(value =>
                    String(value ?? '').toLowerCase().includes(searchValue)
                );
            });
        }
        this.filteredSubscriptions = this.sortData(
            filteredData, this.sortedBy, this.sortedDirection
        );
    }
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }
    
    handleViewChange(event) {
        this.selectedView = event.detail.value;
        this.selectedConsumingApp = 'All';
        this.filteredSubscriptions = [];
        this.searchTerm = '';
    }
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;

        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        // Use the displayed label field for actual sorting
        const sortFieldMap = {
            productUrl : 'productName',
            subscriptionUrl : 'Name'
        };
        const actualSortField = sortFieldMap[fieldName] || fieldName;

        this.filteredSubscriptions = this.sortData(
            this.filteredSubscriptions,
            actualSortField,
            sortDirection
        );
    }
    sortData(data, fieldName, sortDirection) {
        const sortedData = [...data];

        sortedData.sort((a, b) => {
            let x = a[fieldName] ?? '';
            let y = b[fieldName] ?? '';

            if (fieldName === 'LastModifiedDate') {
                x = x ? new Date(x).getTime() : 0;
                y = y ? new Date(y).getTime() : 0;
            } else {
                x = String(x).toLowerCase();
                y = String(y).toLowerCase();
            }

            if (x === y) {
                return 0;
            }
            const comparison = x > y ? 1 : -1;
            return sortDirection === 'asc'
                ? comparison
                : -comparison;
        });
        return sortedData;
    }


}