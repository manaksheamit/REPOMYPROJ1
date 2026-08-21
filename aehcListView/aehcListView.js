import { LightningElement, api, wire } from 'lwc';

export default class AehcListView extends LightningElement {

    // @wire(EnclosingTabId) enclosingTabId;

    // global vars
    @api recordId;
    @api sObjectNames;
    @api title;
    @api skipFields;
    @api columns;
    @api keyField = 'Id';
    @api actions;

    @api reset({ records, columns, isLoading = null, actions }) {
        // console.log(`AehcListView`, records, this.isLoading)
        if (records) {
            this.records = records;

            this.sortFn();
            this.evaluatePagination(); // call helper method to update pagination logic 
        }
        if (columns) this.columns = columns;
        if (actions) this.actions = actions;

        if (isLoading != null) this.isLoading = isLoading;
    }
    // local vars
    isLoading = true;
    field_RecordLink = 'recordLink';

    // pagination
    pageSizeOptions = [5, 10, 25, 50, 75, 100]; //Page size options
    records = []; //All records available in the data table

    recordsToDisplay = []; // Records to be displayed on the page
    pagination = {
        pageSize: 1,
        totalCount: 0, //Total no.of records
        startCount: 0,
        endCount: 0,
        currentPage: 1, //Page number    
        pageCount: 1, //Total no.of pages
        pageSizes: [
            { label: 20, value: "20" },
            { label: 50, value: "50" },
            { label: 100, value: "100" }
        ]
    }

    // filter
    whereClause = {
        dateFrom: null,
        dateTo: null
    }
    isVisible = {
        btn_Search: false,
        btn_Reset: false
    }
    isFilterApplied = false;
    showFilter() {
        const dateFromMilis = this.inputs.dateFrom ? new Date(this.inputs.dateFrom).getTime() : 0;
        const dateToMilis = this.inputs.dateTo ? new Date(this.inputs.dateTo).getTime() : 0;
        this.isVisible = {
            btn_Search: (dateFromMilis && dateToMilis && dateFromMilis <= dateToMilis) ? true : false,
            btn_Reset: dateFromMilis || dateToMilis ? true : false
        }
    }

    // pagination
    get isLeftBtnDisabled() {
        if (this.isLoading) return true;
        return this.pagination.currentPage == 1;
    }
    get isRightBtnDisabled() {
        if (this.isLoading) return true;
        return this.pagination.currentPage == this.pagination.pageCount;
    }

    connectedCallback() {

        this.isLoading = false;
        this.init();
    }

    errorCallback(error, stack) {
        this.error = error;

        console.log(`errorCallback`, this.error)
    }

    // openAnotherSubTab() {
    //     console.log(`this.enclosingTabId`, this.enclosingTabId)
    //     if (!this.enclosingTabId) {
    //         // return;
    //     }
    //     const res = openSubtab(this.enclosingTabId, {
    //         pageReference: {
    //             type: 'standard__objectPage',
    //             attributes: {
    //                 recordId: '003J100000AiACHIA3',
    //                 objectApiName: 'Contact',
    //                 actionName: 'view'
    //             }
    //         }
    //     });
    //     console.log(`res`, res)
    // }

    async init() {
        this.initializePagination();
        await this.getRecords();
    }

    async initializePagination() {
        this.pagination.currentPage = 1;
        this.pagination.pageSize = this.pagination.pageSizes[0].value;
    }

    async getRecords() {
        this.isLoading = true;
        this.dispatchEvent(new CustomEvent('reload'));

        // try {
        //     const result = await getHistory({
        //         parentId: this.recordId,
        //         sObjectNames: this.sObjectNames,
        //         skipFields: this.skipFields,
        //         filter: JSON.stringify(this.whereClause)
        //     });
        //     console.log('result ', result);
        //     if (result.status == 200 || result.status == 404) {
        //         const records = result.data ? result.data : [];
        //         for (const item of records) {
        //             if (!item.recordName) item.recordName = item.entityName;
        //             item.recordURL = window.location.origin + '/' + item.recordId;
        //         }
        //         this.records = records;
        //         this.sortFn();
        //         this.evaluatePagination(); // call helper method to update pagination logic 
        //     }
        // } catch (error) {
        //     console.error(error)
        // }
        // this.isLoading = false;

    }

    handlers
    handleClick_Action(event) {
        const dataset = event.currentTarget.dataset;

        if (!dataset) return;

        this.dispatchEvent(new CustomEvent('action', {
            detail: {
                name: dataset.name
            }
        }));
    }
    handleDataTableRowAction(event) {
        try {
            const actionName = event.detail.action.name;
            const row = event.detail.row;

            this.dispatchEvent(new CustomEvent('action', {
                detail: {
                    name: actionName,
                    detail: row
                }
            }));
        } catch (err) {
            console.error(`handleDataTableRowAction`, err)
        }
    }
    handleClick_Refresh(event) {
        this.getRecords();
    }
    handleClick_Search(event) {
        this.isFilterApplied = true;
        this.getRecords();
    }
    handleClick_Reset(event) {
        this.whereClause = {
            dateFrom: null,
            dateTo: null
        };
        this.inputs = {
            dateFrom: null,
            dateTo: null
        };
        if (this.isFilterApplied) {
            this.getRecords();
            this.isFilterApplied = false;
        }
        this.showFilter();
    }

    timezoneOffset;
    inputs = {
        dateFrom: null,
        dateTo: null
    }
    handleChange_Input(event) {
        try {
            const target = event.target;
            let value = target.value;
            const fieldName = target.name;
            if (fieldName == 'dateFrom' || fieldName == 'dateTo') {

                let date = value;

                // if dateTo field then next day 0AM be there
                if (fieldName == 'dateTo') date = new Date(date.getTime() + 86400 * 1000);

                // converting to standard string to send it to apex
                value = date.toISOString();
            }
            this.whereClause[fieldName] = value;
            this.inputs[fieldName] = target.value;
            this.showFilter();
        } catch (error) {
            saveJSError({ "errorMsg": JSON.stringify(error), "stack": 'csc_input.connectedCallback', "appName": CONSTANT.APP_NAME });
        }
    }

    // pagination
    handleClick_PageSize(event) {
        this.pagination.pageSize = event.target.value;
        this.evaluatePagination();
    }
    handleClick_previousPage() {
        this.pagination.currentPage = this.pagination.currentPage - 1;
        this.evaluatePagination();
    }
    handleClick_nextPage() {
        this.pagination.currentPage = this.pagination.currentPage + 1;
        this.evaluatePagination();
    }
    handleClick_firstPage() {
        this.pagination.currentPage = 1;
        this.evaluatePagination();
    }
    handleClick_lastPage() {
        this.pagination.currentPage = this.pagination.pageCount;
        this.evaluatePagination();
    }
    // JS function to handel pagination logic 
    evaluatePagination() {
        try {
            const recordsToDisplay = [];

            this.pagination.totalCount = this.records.length;

            if (this.pagination.totalCount <= 0) {
                this.pagination.startCount = 0;
                this.pagination.endCount = 0;
            } else {
                // calculate total pages
                this.pagination.pageCount = Math.ceil(this.pagination.totalCount / this.pagination.pageSize);

                // set page number 
                if (this.pagination.currentPage <= 1) {
                    this.pagination.currentPage = 1;
                } else if (this.pagination.currentPage >= this.pagination.pageCount) {
                    this.pagination.currentPage = this.pagination.pageCount;
                }

                // set start / end count of the current page
                this.pagination.startCount = (this.pagination.currentPage - 1) * this.pagination.pageSize + 1;
                const endCount = (this.pagination.currentPage) * this.pagination.pageSize;
                this.pagination.endCount = endCount > this.pagination.totalCount ? this.pagination.totalCount : endCount;
            }

            // set records to display on current page 
            for (let i = (this.pagination.currentPage - 1) * this.pagination.pageSize; i < this.pagination.currentPage * this.pagination.pageSize; i++) {
                if (i === this.pagination.totalCount) {
                    break;
                }
                recordsToDisplay.push(this.records[i]);
            }
            this.recordsToDisplay = recordsToDisplay;
        } catch (error) {
            saveJSError({ "errorMsg": JSON.stringify(error), "stack": 'csc_input.connectedCallback', "appName": CONSTANT.APP_NAME });
        }
    }

    // sorting
    sort = {
        fieldName: 'createdDate',
        direction: 'desc'
    }
    handleClick_sort(event) {
        this.isLoading = true;
        try {
            const eventData = event.detail;
            this.sort = {
                fieldName: eventData.fieldName,
                direction: eventData.sortDirection
            };
            this.sortFn();
            this.evaluatePagination();

        } catch (error) {
            saveJSError({ "errorMsg": JSON.stringify(error), "stack": 'csc_input.connectedCallback', "appName": CONSTANT.APP_NAME });
        }
        this.isLoading = false;
    }

    sortFn() {
        this.records = this.records.sort(this.compareFn(this.sort.fieldName, this.sort.direction));
    }

    compareFn(field, direction) {
        const isReverse = direction === 'asc' ? 1 : -1;
        if (field == this.field_RecordLink) field = 'recordName';
        return function (elem, nextElem) {
            const elemVal = elem[field] ? elem[field] : ''; // handling null values
            const nextElemVal = nextElem[field] ? nextElem[field] : '';

            // sorting values based on direction
            return isReverse * ((elemVal > nextElemVal) - (nextElemVal > elemVal));
        }
    }
}