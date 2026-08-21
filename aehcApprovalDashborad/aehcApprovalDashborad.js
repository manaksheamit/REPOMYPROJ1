import { LightningElement, track } from 'lwc';
import getApprovalData from '@salesforce/apex/AEHC_ApprovalListViewController.getApprovalData';
import getAvailableRequestTypes from '@salesforce/apex/AEHC_ApprovalListViewController.getAvailableRequestTypes';

export default class ApprovalDashboard extends LightningElement {

    selectedType = 'APPROVAL';
    selectedStatus = 'Pending';

    isLoading = false;

    @track tableData = [];
    requestTypeOptions = [];

    approvalColumns = [
        {
            label: 'Pub / Sub ID',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: {
                    fieldName: 'name'
                },
                target: '_self'
            }
        },
        {
            label: 'Product Type',
            fieldName: 'assetType'
        },
        {
            label: 'Environment',
            fieldName: 'environment'
        },
        {
            label: 'Status',
            fieldName: 'approvalStatus'
        },
        {
            label: 'Created Date',
            fieldName: 'createdDate',
            type: 'date'
        },
        {
            label: 'Created By',
            fieldName: 'createdByName'
        }
    ];

    schemaColumns = [
        {
            label: 'Pub ID',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: {
                    fieldName: 'name'
                },
                target: '_self'
            }
        },
        {
            label: 'Schema Name',
            fieldName: 'schemaName'
        },
        {
            label: 'Table Name',
            fieldName: 'tableName'
        },
        {
            label: 'Status',
            fieldName: 'approvalStatus'
        },
        {
            label: 'Created Date',
            fieldName: 'createdDate',
            type: 'date'
        },
        {
            label: 'Created By',
            fieldName: 'createdByName'
        }
    ];

    async connectedCallback() {

        await this.loadRequestTypes();

        if (this.requestTypeOptions.length) {

            this.selectedType =
                this.requestTypeOptions[0].value;

            this.loadData();
        }
    }

    async loadRequestTypes() {

        try {

            const result =
                await getAvailableRequestTypes();
            console.log('data' + result);
            this.requestTypeOptions =
                (result || []).map(type => {

                    return {
                        label:
                            type === 'APPROVAL'
                                ? 'Approval'
                                : type === 'PROMOTION'
                                    ? 'Promotion'
                                    : 'Schema Change',

                        value: type
                    };
                });

        } catch (error) {

            console.error(error);
        }
    }

    get hasOptions() {
        return this.requestTypeOptions &&
            this.requestTypeOptions.length > 0;
    }

    get columns() {

        return this.selectedType === 'SCHEMA'
            ? this.schemaColumns
            : this.approvalColumns;
    }

    get hasData() {
    return this.tableData && this.tableData.length > 0;
}

    handleTypeChange(event) {

        this.selectedType =
            event.detail.value;

        this.loadData();
    }

    handlePending() {

        this.selectedStatus =
            'Pending';

        this.loadData();
    }

    handleApproved() {

        this.selectedStatus =
            'Approved';

        this.loadData();
    }

    handleRejected() {

        this.selectedStatus =
            'Rejected';

        this.loadData();
    }

    async loadData() {

        try {

            this.isLoading = true;

            const result =
                await getApprovalData({
                    requestType: this.selectedType,
                    status: this.selectedStatus
                });

            this.tableData =
                (result.records || [])
                    .map(row => ({
                        ...row,
                        id: row.recordId,
                        recordUrl: row.navigationUrl
                    }));

        }
        catch (error) {

            console.error(
                'Error loading approvals',
                error
            );

            this.tableData = [];
        }
        finally {

            this.isLoading = false;
        }
    }
}