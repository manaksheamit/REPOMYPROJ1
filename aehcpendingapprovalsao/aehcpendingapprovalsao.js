import { LightningElement, track } from 'lwc';
import getPendingSubscriptions from '@salesforce/apex/AEHC_PendingSubscriptionsCtrlAO.getPendingSubscriptions';
import AEHC_PendingApprovalsView from '@salesforce/label/c.AEHC_PendingApprovalsView';

export default class Aehcpendingapprovalsao extends LightningElement {

    // Holds full dataset returned from Apex
    @track data = [];

    // Holds paginated / visible data for UI
    @track displayData = [];

    // Label binding for UI dropdown (comma-separated values)
    label = {
        AEHC_PendingApprovalsView
    };

    // Flag to toggle between API Product / Data Product
    isDataProduct = false;

    // Parsed label values (converted into array)
    parsedLabelArray = [];

    // Currently selected label from dropdown
    @track selectedLabel = '';

    /* =========================================================
       PAGINATION CONFIGURATION
    ========================================================== */

    pageSize = 10;   // records per page
    page = 1;        // current page
    totalPages = 1;  // total pages

    /* =========================================================
       DATATABLE COLUMN CONFIGURATION
    ========================================================== */

    @track columns = [
        { label: 'Name', fieldName: 'Name', sortable: true },
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

    // Sorting properties
    sortedBy;
    sortedDirection = 'asc';

    /* =========================================================
       LIFECYCLE HOOK
    ========================================================== */

    connectedCallback() {
        // Parse label values (comma-separated string → array)
        this.parsePendingApprovalsViewLabel();

        
        // Set default selection
        this.selectedLabel = 'API Product Pending Approvals';

        // Set flag based on default selection
        this.isDataProduct = false;


        // Fetch data from Apex
        this.initialize();
    }

    /* =========================================================
       FETCH DATA FROM APEX
    ========================================================== */

    async initialize() {
        try {
            const result = await getPendingSubscriptions();

            // Success response
            if (result.status == 200) {
                this.renderData(result.data);
            }

        } catch (err) {
            console.log(err);
        }
    }

    /* =========================================================
       PREPARE DATA FOR UI
    ========================================================== */

    renderData(subs) {

        // Add additional fields for UI (URL + label for link)
        this.data = subs.map(row => {
            return {
                ...row,
                subscriptionUrl: '/detail/' + row.Id,       // clickable link
                subscriptionLabel: row.SubscriptionName    // display label
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
        const start = (this.page - 1) * this.pageSize;
        const end = this.page * this.pageSize;

        // Slice dataset for current page
        this.displayData = this.data.slice(start, end);
    }

    // Handle Previous button
    handlePrevious() {
        if (this.page > 1) {
            this.page--;
            this.updatePage();
        }
    }

    // Handle Next button
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

        // Extract field and direction
        const { fieldName, sortDirection } = event.detail;

        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        const reverse = sortDirection === 'asc' ? 1 : -1;

        // Sort data dynamically
        this.data = [...this.data].sort((a, b) => {
            a = a[fieldName] || '';
            b = b[fieldName] || '';

            return a > b ? 1 * reverse : -1 * reverse;
        });

        // Reset to first page
        this.page = 1;
        this.updatePage();
    }

    /* =========================================================
       PAGINATION HELPERS (UI DISPLAY)
    ========================================================== */

    get showingFrom() {
        return this.data.length
            ? ((this.page - 1) * this.pageSize + 1)
            : 0;
    }

    get showingTo() {
        return Math.min(this.page * this.pageSize, this.data.length);
    }

    get totalRecords() {
        return this.data.length;
    }

    /* =========================================================
       LABEL PARSING (Comma-separated → Array)
    ========================================================== */

    parsePendingApprovalsViewLabel() {
        try {
            const raw = AEHC_PendingApprovalsView || '';

            // Split label into array of values
            const items = raw
                .split(',')
                .map(s => s.trim())
                .filter(s => s.length > 0);

            this.parsedLabelArray = items;

        } catch (e) {
            // Reset safely if error occurs
            this.parsedLabels = {};
            this.parsedLabelArray = [];
        }
    }

    /* =========================================================
       COMBOBOX OPTIONS (Derived from parsed labels)
    ========================================================== */

    get comboboxOptions() {
        return (this.parsedLabelArray || []).map(item => {
            return { label: item, value: item };
        });
    }

    /* =========================================================
       PAGINATION BUTTON STATES
    ========================================================== */

    get isFirstPage() {
        return this.page === 1;
    }

    get isLastPage() {
        return this.page === this.totalPages;
    }

    /* =========================================================
       LABEL SELECTION HANDLER
    ========================================================== */

    handleLabelChange(event) {

        // Store selected value
        this.selectedLabel = event.detail.value;

        // Toggle flags based on selection
        if (this.selectedLabel == 'API Product Pending Approvals') {
            this.isDataProduct = false;

        } else if (this.selectedLabel == 'Data Product Pending Approvals') {
            this.isDataProduct = true;
        }
    }
}