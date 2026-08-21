import { LightningElement, api } from 'lwc';

const DEFAULT_PAGE_SIZE = 10;

export default class AehcPublicationFieldDataTable extends LightningElement {

    _fieldData;

    @api tableTitle = 'Schema Fields';
    @api emptyMessage = 'No Fields Selected';
    @api pageSize = DEFAULT_PAGE_SIZE;
    @api columns = [        
        {
            label: 'Name',
            fieldName: 'fieldName',
            type: 'text',
            initialWidth: 220
        },
        {
            label: 'Label',
            fieldName: 'labelName',
            type: 'text',
            initialWidth: 220
        },
        {
            label: 'CCI',
            fieldName: 'cciLevel',
            type: 'text',
            initialWidth: 220
        },
        {
            label: 'PII Level',
            fieldName: 'piiLevel',
            type: 'text',
            initialWidth: 220
        },
        {
            label: 'Data Type',
            fieldName: 'dataType',
            type: 'text',
            initialWidth: 150
        },
        {
            label: 'Required',
            fieldName: 'required',
            type: 'text',
            initialWidth: 120
        },
        {
            label: 'Description',
            fieldName: 'description',
            type: 'text',
            wrapText: true,
            initialWidth: 700
        }
    ];

    allRows = [];
    displayRows = [];
    visibleCount = DEFAULT_PAGE_SIZE;

    @api
    get fieldData() {
        return this._fieldData;
    }

    set fieldData(value) {

        this._fieldData = value;
        this.visibleCount = Number(this.pageSize);
        this.processData();
    }

    processData() {

        this.allRows = [];
        this.displayRows = [];

        if (!this._fieldData || this._fieldData === '[]' ) {
            return;
        }

        try {

            const parsedData = JSON.parse(this._fieldData);
            console.log('Amit fielddatatable',this._fieldData);            
            if (!Array.isArray(parsedData)) {
                return;
            }

            this.allRows = parsedData.map((row, index) => ({id: row.id || row.name || index,...row}));

            this.displayRows =this.allRows.slice( 0, this.visibleCount);

        } catch (error) {

            console.error('Error parsing publication field JSON',error);
            this.allRows = [];
            this.displayRows = [];
        }
    }

    loadMore() {

        this.visibleCount += Number(this.pageSize);

        this.displayRows = this.allRows.slice( 0,this.visibleCount);
    }

    get datatableColumns() {
        return this.columns;
    }

    get totalRecords() {
        return this.allRows.length;
    }

    get hasFields() {
        return this.totalRecords > 0;
    }

    get showLoadMore() {
        return this.displayRows.length < this.allRows.length;
    }

    get accordionLabel() {
        return `${this.tableTitle} (${this.totalRecords})`;
    }

    get loadMoreLabel() {

        const remaining =
            this.totalRecords -
            this.displayRows.length;

        return remaining > 0
            ? `Load More (${remaining} Remaining)`
            : 'Load More';
    }
}