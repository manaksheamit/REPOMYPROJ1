import { LightningElement, track } from 'lwc';
import getPendingSubscriptions from '@salesforce/apex/AEHC_PendingSubscriptionsCtrlAO.checkApprovalVisibility';

export default class Aehcpendingapprovalsbo extends LightningElement {

    /* =========================================================
       DATA STATE VARIABLES
    ========================================================== */

    @track data = [];        // Full dataset from Apex
    @track displayData = []; // Paginated data for UI

    /* =========================================================
       PAGINATION CONFIGURATION
    ========================================================== */

    pageSize = 10;  // Records per page
    page = 1;       // Current page
    totalPages = 1; // Total pages

    /* =========================================================
       DATATABLE COLUMN CONFIGURATION
    ========================================================== */

    @track columns = [
        { label: 'Application Name', fieldName: 'ApplicationName', sortable: true },
        { label: 'Type', fieldName: 'Type', sortable: true },
        {
            label: 'Subscription Name',
            fieldName: 'subscriptionUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'subscriptionLabel' },
                target: '_self'
            },
            sortable: true
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'numeric',
                day: 'numeric',
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
            },
            sortable: true
        },
        { label: 'Created By', fieldName: 'CreatedBy', sortable: true },
        { label: 'Environment', fieldName: 'Environment', sortable: true },
        { label: 'Purpose of Use', fieldName: 'Purpose' }
    ];

    /* =========================================================
       SORTING CONFIGURATION
    ========================================================== */

    sortedBy;                 // Field currently sorted
    sortedDirection = 'asc';  // Sort direction

    /* =========================================================
       LIFECYCLE HOOK
    ========================================================== */

    connectedCallback() {

        // Fetch data on component load
        this.initialize();
    }

    /* =========================================================
       FETCH DATA FROM APEX
    ========================================================== */

    async initialize() {
        try {
            const result = await getPendingSubscriptions();

            // Render data directly (response already expected as list)
            this.renderData(result);

        } catch (err) {
            console.log(err);
        }
    }

    /* =========================================================
       PREPARE DATA FOR UI
    ========================================================== */

    renderData(subs) {

        // Enhance data with URL and label for clickable column
        this.data = subs.map(row => {
            return {
                ...row,
                subscriptionUrl: '/detail/' + row.Id,         // Navigation link
                subscriptionLabel: row.SubscriptionName       // Display label
            };
        });

        // Calculate total pages
        this.totalPages = Math.ceil(this.data.length / this.pageSize);

        // Load first page
        this.updatePage();
    }

    /* =========================================================
       PAGINATION LOGIC
    ========================================================== */

    updatePage() {

        // Calculate start and end index
        const start = (this.page - 1) * this.pageSize;
        const end = this.page * this.pageSize;

        // Slice data for current page
        this.displayData = this.data.slice(start, end);
    }

    // Handle previous page navigation
    handlePrevious() {
        if (this.page > 1) {
            this.page--;
            this.updatePage();
        }
    }

    // Handle next page navigation
    handleNext() {
        if (this.page < this.totalPages) {
            this.page++;
            this.updatePage();
        }
    }

    /* =========================================================
       SORTING LOGIC
    ========================================================== */

    handleSort(event) {

        // Extract sorting details
        const { fieldName, sortDirection } = event.detail;

        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        const reverse = sortDirection === 'asc' ? 1 : -1;

        // Perform sorting
        this.data = [...this.data].sort((a, b) => {
            a = a[fieldName] || '';
            b = b[fieldName] || '';
            return a > b ? 1 * reverse : -1 * reverse;
        });

        // Reset pagination to first page
        this.page = 1;
        this.updatePage();
    }

    /* =========================================================
       PAGINATION HELPERS (UI DISPLAY)
    ========================================================== */

    get showingFrom() {

        // Starting record number
        return this.data.length
            ? ((this.page - 1) * this.pageSize + 1)
            : 0;
    }

    get showingTo() {

        // Ending record number
        return Math.min(this.page * this.pageSize, this.data.length);
    }

    get totalRecords() {

        // Total record count
        return this.data.length;
    }
}
