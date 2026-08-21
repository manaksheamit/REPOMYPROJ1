import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getRecordApex from "@salesforce/apex/AEHC_RecordDetailCtrl.getRecord";

export default class AehcRecordDetail extends LightningElement {

    @api title;
    @api recordId;
    @api fields;
    @api sObjectName;
    @api matchFieldName;
    @track jsonData;
    @track isJSONTable;
    _fields = [];

    /* ---------------------------------------------
       Resolve Record Id
    ----------------------------------------------*/
    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (!this.recordId && pageRef) {
            this.recordId =
                pageRef.attributes?.recordId ||
                pageRef.state?.recordId ||
                pageRef.state?.c__recordId ||
                this.getRecordIdFromUrl();
        }

        if (this.recordId) {
            this.noRecordId = false;
        } else {
            this.noRecordId = true;
        }
    }


    connectedCallback() {
        this.init();
    }

    rec = {}
    async init() {
        if (!this.recordId) return;

        const response = await getRecordApex({
            sObjectName: this.sObjectName,
            fieldNames: this.fields,
            matchFieldName: this.matchFieldName,
            recordId: this.recordId
        });
        if (response.status == 200) {
            this.rec = response.data;

            if (this.rec.AEHC_Selected_Fields_JSON__c) {

                this.jsonData = this.rec.AEHC_Selected_Fields_JSON__c;
                setTimeout(e => this.isJSONTable = true, 0);
            }
        }
    }

}