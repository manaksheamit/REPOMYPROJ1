import { LightningElement } from 'lwc';
import searchApplicationApex from "@salesforce/apex/AEHC_ManageApplicationCtrl.searchApplication";
import getApplicationDetailApex from "@salesforce/apex/AEHC_ManageApplicationCtrl.getApplicationDetail";
import createApplicationApex from "@salesforce/apex/AEHC_ManageApplicationCtrl.createApplication";

export default class AehcManageApplication extends LightningElement {

    // is-states
    isDisabled_Btn_Search;
    isDisabled_Btn_Reset;
    isVisible_Btn_Reset;
    isDisabled_Btn_CreateApplication;
    isLoading_Search;
    isLoading_Detail;
    isVisible_Success;
    isVisible_Warning;
    isLoading_CreateApp;
    hasApplicationData;
    isSFRecord;
    records;
    appRec;
    recordId;

    // app-search field
    applicationSearchFieldDetail = {
        label: 'Application Name or CMDB ID',
        objectLabel: 'Application',
        placeholder: 'Search Application',
        iconName: 'custom:custom24',
        searchElement: null,
        records: []
    }
    getSearchElement() {
        if (!this.applicationSearchFieldDetail.searchElement) {
            this.applicationSearchFieldDetail.searchElement = this.template.querySelector('c-aehc-reusable-lookup');
        }
        return this.applicationSearchFieldDetail.searchElement;
    }

    // init
    connectedCallback() {
        this.init();
    }

    init() {
        this.isVisible_Btn_Reset = false;
        this.isDisabled_Btn_Search = true;
        this.isDisabled_Btn_Reset = true;
        this.hideAlert();
        this.isLoading_CreateApp = false;
        this.isLoading_Detail = false;
        this.isLoading_Search = false;
        this.hasApplicationData = false;
        this.isSFRecord = false;
        this.records = [];
    }

    // handlers
    searchAppString;
    searchTimeout;
    handleChange_SearchApplicationField(event) {
        this.searchAppString = event.detail.value;

        if (this.searchAppString) {
            this.isDisabled_Btn_Search = false;
        } else {
            this.isDisabled_Btn_Search = true;
        }

        // clear search results
        window.clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(e => {
            this.getSearchElement().reset({
                records: []
            });
        }, 500);

        this.hideAlert();
    }

    handleBlur_SearchDiv() {
        this.getSearchElement().reset({
            records: []
        });
    }

    async handleClick_Search() {
        if (!this.searchAppString) return;
        if (this.isDisabled_Btn_Search) return;

        try {
            this.isLoading_Search = true
            this.isDisabled_Btn_Search = true;
            this.isVisible_Warning = false;
            this.hasApplicationData = false;

            this.hideAlert();

            const response = await searchApplicationApex({
                applicationIdentifier: this.searchAppString
            });
            this.isLoading_Search = false;
            this.isDisabled_Btn_Search = false;

            if (response.status == 200) {
                this.applicationSearchFieldDetail.records = response.data.apps.map(app => {
                    return {
                        ...app,
                        id: app.id,
                        mainField: app.name || app.mainField,
                        subField: app.apmNumber || app.subField,
                    }
                });

            } else if (response.status == 404) {
                this.applicationSearchFieldDetail.records = [];
                this.hasApplicationData = false;
                this.message = response.message;
                this.isVisible_Warning = true;
            }
            this.getSearchElement().reset({
                records: this.applicationSearchFieldDetail.records
            });
        } catch (err) {
            console.error(err);
        }
    }

    hideAlert(delaySecs = 0) {
        setTimeout(() => {
            this.isVisible_Warning = false;
            this.isVisible_Success = false;
        }, delaySecs * 1000)
    }

    async handleSelect_SearchApplication(event) {
        try {
            const selected = event.detail;

            this.isDisabled_Btn_Search = true;
            this.hasApplicationData = true;


            if (selected.id) {
                await this.displayAppDetail(selected.id);
            }
        } catch (err) {
            console.error(err);
        }
    }

    async displayAppDetail(appId) {
        try {
            const app = this.applicationSearchFieldDetail.records.find(app => app.id == appId);
            if (!app) {
                this.hasApplicationData = false;
                return;
            }
            if (!app.businessOwner) app.businessOwner = {};
            if (!app.ITOwner) app.ITOwner = {};
            this.appRec = { ...app };

            this.isSFRecord = app.isSFRecord;
            this.isDisabled_Btn_CreateApplication = this.isSFRecord;

            // initiate Apex Call
            this.isLoading_Search = true;
            this.isLoading_Detail = true;
            this.hasApplicationData = true;

            // get detail from apex
            const response = await getApplicationDetailApex({
                appDetailStr: JSON.stringify(app)
            });
            this.isLoading_Detail = false;
            this.isLoading_Search = false;
            // console.log(`displayAppDetail`, response)
            if (response.status == 200) {
                this.appRec = response.data;
                this.isSFRecord = response.data.isSFRecord;
            }
        } catch (err) {
            console.error(err);
        }
    }

    handleDeselect_SearchApplication(event) {
        const deselected = event.detail;

        this.init();
    }

    async handleClick_CreateApplication() {
        try {
            this.hideAlert();
            this.isLoading_CreateApp = true;
            this.isDisabled_Btn_CreateApplication = true;

            // create using Apex
            const response = await createApplicationApex({
                payload: JSON.stringify(this.appRec)
            });
            if (response.status == 200) {
                this.isVisible_Success = true;
                this.isVisible_Warning = false;
                this.message = response.message;
                this.appRec.id = response.data.Id;
                this.hideAlert(3);
                this.isSFRecord = true;
            } else {
                this.isDisabled_Btn_CreateApplication = false;
                if (response.message) {
                    this.isVisible_Success = false;
                    this.isVisible_Warning = true;
                    this.message = response.message;
                }
            }

        } catch (err) {
            this.isDisabled_Btn_CreateApplication = false;
            console.error(err);
        }
        this.isLoading_CreateApp = false;
    }
}