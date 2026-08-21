import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import getVersions from '@salesforce/apex/AEHC_APISubscriptionCustViewController.getVersions';
import getApprovalHistory from '@salesforce/apex/AEHC_APISubscriptionCustViewController.getApprovalHistory';
const FIELDS = [
    'Subscription__c.Name',
    'Subscription__c.Status__c',
    'Subscription__c.API_Name__c',
    'Subscription__c.AEHC_AssetType__c',
    'Subscription__c.AEHC_Consumming_Application__c',
    'Subscription__c.AEHC_Consuming_Application_Name__c',
    'Subscription__c.Community_Asset__c',
    'Subscription__c.AEHC_APM_Number__c',
    'Subscription__c.AEHC_Data_Classification__c',
    'Subscription__c.AEHC_PII_Information__c',
    'Subscription__c.AEHC_API_Asset_Owner_Email__c',
    'Subscription__c.AEHC_Environment_Name__c',
    'Subscription__c.AEHC_IP_Address_of_the_Application__c',
    'Subscription__c.AEHC_Purpose_of_Use__c',
    'Subscription__c.AEHC_Projected_Transaction_Volume__c',
    'Subscription__c.AEHC_TAP_document_URL__c',
    'Subscription__c.AEHC_SNow_Request__c',
    'Subscription__c.AEHC_SNow_Status__c',
    'Subscription__c.RecordType.DeveloperName',
    'Subscription__c.AEHC_API_Asset_Owner__c',
    'Subscription__c.AEHC_Business_Unit_Optional__c',    
    'Subscription__c.Security_Reviewer__r.Name',
    'Subscription__c.CreatedBy.Name',
    'Subscription__c.CreatedDate',
    'Subscription__c.LastModifiedDate',
    'Subscription__c.AEHC_Is_GraphQL_Request__c',
    'Subscription__c.AEHC_Director_Name__c',
    'Subscription__c.AEHC_Intra_Request__c',
    'Subscription__c.AEHC_App_Registration_RITM_Status__c'
];

export default class Aehcapisubscriptioncustview extends NavigationMixin(LightningElement) {

    @api recordId;
    record;

    @track versions = [];
    activeVersion;

    // ✅ Pagination
    pageSize = 5;
    currentPage = 1;
    totalPages = 0;
    pagedData = [];

    
    @track approvalData = [];
    isModalOpenApproval = false;
    selectedVersion;   // currently selected version
    columns = [
        { label: 'Version', fieldName: 'AEHC_Schema_Version__c' },
        //{ label: 'Active', fieldName: 'AEHC_Is_Active__c', type: 'boolean' },
        //{ label: 'GraphQL Fields', fieldName: 'AEHC_GraphQL_Fields__c' },
        //{ label: 'Data Elements Required', fieldName: 'AEHC_Data_Elements_Required__c' },
        { label: 'Signed Token', fieldName: 'AEHC_GraphQL_SignedToken__c',wrapText: true }
    ];

    columnsapproval = [
        { label: 'Step Name', fieldName: 'stepName' },
        {
            label: 'Date',
            fieldName: 'date',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        { label: 'Status', fieldName: 'status' },
        { label: 'Assigned To', fieldName: 'assignedTo' }
    ];

    // ✅ RecordId support for Site + Record Page
    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef && !this.recordId) {
            this.recordId =
                pageRef.state?.recordId ||
                pageRef.state?.id ||
                pageRef.attributes?.recordId ||
                pageRef.state.subscriptionId;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getVersions, { subId: '$recordId' })
    wiredVersions({ data, error }) {
        if (data) {
            this.versions = data;

            // ✅ Active version
            this.activeVersion = data.find(v => v.AEHC_Is_Active__c);

            // ✅ Set default selected version
            this.selectedVersion = this.activeVersion;

            // ✅ Existing logic
            this.inactiveVersions = data.filter(v => !v.AEHC_Is_Active__c);
            this.totalPages = Math.ceil(this.inactiveVersions.length / this.pageSize);
            this.updatePagedData();

        } else if (error) {
            console.error(error);
        }
    }

    @wire(getApprovalHistory, { recordId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.approvalData = data.map(item => ({
                id: item.Id,
                stepName: item.StepStatus, // fallback
                date: item.CreatedDate,
                status: item.StepStatus,
                assignedTo: item.Actor?.Name || item.OriginalActor?.Name
            }));
        } else if (error) {
            console.error(error);
        }
    }
    
    get versionOptions() {
        return this.versions.map(v => ({
            label: v.AEHC_Schema_Version__c,
            value: v.Id
        }));
    }

    handleVersionChange(event) {
        const selectedId = event.detail.value;

        this.selectedVersion = this.versions.find(v => v.Id === selectedId);
    }

    get selectedVersionToken() {
        return this.selectedVersion?.AEHC_GraphQL_SignedToken__c;
    }
    
    openModalApproval() {
        this.isModalOpenApproval = true;
    }

    closeModalApproval() {
        this.isModalOpenApproval = false;
    }

    get totalCountApproval() {
        return this.approvalData.length;
    }

    updatePagedData() {
        const start = (this.currentPage - 1) * this.pageSize;
        this.pagedData = this.inactiveVersions.slice(start, start + this.pageSize);
    }

    get showVersionsTable() {
        return this.inactiveVersions && this.inactiveVersions.length > 0;
    }


    nextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePagedData();
        }
    }

    prevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePagedData();
        }
    }

    get disablePrev() { return this.currentPage === 1;  }
    get disableNext() { return this.currentPage === this.totalPages; }
    // ✅ Getters (clean UI binding)
    get recordTypeName() { return this.record?.fields?.RecordType?.value?.fields?.DeveloperName?.value; }
    get isVisible() { return this.recordTypeName === 'API_Asset'; }
    get isGraphQLRequest() { return this.record?.fields?.AEHC_AssetType__c?.value?.toLowerCase() === 'graphql';}

    get name() { return this.record?.fields?.Name?.value; }
    get status() { return this.record?.fields?.Status__c?.value; }
    get apiName() { return this.record?.fields?.API_Name__c?.value; }
    get assetType() { return this.record?.fields?.AEHC_AssetType__c?.value; }
    get consumingApp() { return this.record?.fields?.AEHC_Consumming_Application__c?.value; }
    get appName() { return this.record?.fields?.AEHC_Consuming_Application_Name__c?.value; }
    get communityAsset() { return this.record?.fields?.Community_Asset__c?.value; }
    get apmNumber() { return this.record?.fields?.AEHC_APM_Number__c?.value; }
    get dataClassification() { return this.record?.fields?.AEHC_Data_Classification__c?.value; }
    get piiInfo() { return this.record?.fields?.AEHC_PII_Information__c?.value; }
    get ownerEmail() { return this.record?.fields?.AEHC_API_Asset_Owner_Email__c?.value; }
    get ownerName() { return this.record?.fields?.AEHC_API_Asset_Owner__c?.value; }
    get environment() { return this.record?.fields?.AEHC_Environment_Name__c?.value; }
    get ipAddress() { return this.record?.fields?.AEHC_IP_Address_of_the_Application__c?.value; }
    get purpose() { return this.record?.fields?.AEHC_Purpose_of_Use__c?.value; }
    get volume() { return this.record?.fields?.AEHC_Projected_Transaction_Volume__c?.value; }
    get tapDoc() { return this.record?.fields?.AEHC_TAP_document_URL__c?.value; }
    get bussUnit() { return this.record?.fields?.AEHC_Business_Unit_Optional__c?.value; }
    get snowRequest() { return this.record?.fields?.AEHC_SNow_Request__c?.value; }
    get snowStatus() { return this.record?.fields?.AEHC_SNow_Status__c?.value; }
    get securityReviewer() { return this.record?.fields?.Security_Reviewer__r?.displayValue;}
    get createdBy() { return this.record?.fields?.CreatedBy?.displayValue;}
    get createdDate() { return this.record?.fields?.CreatedDate?.value;}
    get lastModifiedDate() { return this.record?.fields?.LastModifiedDate?.value;}
    get directorName() { return this.record?.fields?.AEHC_Director_Name__c?.value;}
    get entraRequest() { return this.record?.fields?.AEHC_Intra_Request__c?.value;}
    get entraRequestStatus() { return this.record?.fields?.AEHC_App_Registration_RITM_Status__c?.value;}
    get isApproved(){return (this.record?.fields?.Status__c?.value == "Approved");}

    get selectedFieldsList() {
        try {
            const raw = this.selectedVersion?.AEHC_GraphQL_Fields__c;

            if (!raw) return [];

            return raw.split(',').map(item => item.trim());

        } catch (e) {
            return [];
        }
    }

   
    // ✅ Modal control
    isModalOpen = false;

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }
    //Nevigate
    
    navigateToApp(event) {
        const recordId = event.currentTarget.dataset.id;

        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        }
    }


}