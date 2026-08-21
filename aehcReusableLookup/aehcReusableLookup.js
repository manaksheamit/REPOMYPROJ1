import { LightningElement, api } from 'lwc';
const DELAY = 500;

export default class AehcReusableLookup extends LightningElement {
    @api detail;
    @api helpText;
    @api label;
    @api required;
    @api selectedIconName;
    @api objectLabel;
    @api placeholder;
    @api records = [];
    @api value;
    @api readOnly = false;
    @api spinnerOnChange = false;

    @api objectApiName;
    @api fieldApiName;
    @api otherFieldApiName;
    @api searchString = "";
    // @api parentRecordId;
    // @api parentFieldApiName;

    // selected record name and Id
    @api selectedRecord = {
        id: '',
        mainField: '',
        subField: ''
    }
    @api selectedRecordId;
    @api reset(data) {
        if (data.records) this.records = data.records;

        if (data.isLoading != null) this.isLoading = data.isLoading;
        if (data.readOnly != null) this.readOnly = data.readOnly;

        if (data.value) {
            this.selectedRecord = data.value;
            this.selectedRecordId = this.selectedRecord.id;
        }
    }

    preventClosingOfSearchPanel = false;

    get methodInput() {
        return {
            objectApiName: this.objectApiName,
            fieldApiName: this.fieldApiName,
            otherFieldApiName: this.otherFieldApiName,
            searchString: this.searchString,
            selectedRecordId: this.selectedRecordId,
            // parentRecordId: this.parentRecordId,
            // parentFieldApiName: this.parentFieldApiName
        };
    }

    get showRecentRecords() {
        if (!this.records) {
            return false;
        }
        return this.records.length > 0;
    }

    //getting the default selected record
    connectedCallback() {

        if (this.value) {
            this.selectedRecord = this.value;
        }
        if (this.selectedRecord.id) {
            this.selectedRecordId = this.selectedRecord.id
        }
    }

    renderedCallback() {

        const style = document.createElement('style');

        style.innerText = ".clshelptexthide div.slds-form-element__icon { display: none; }";
        let qs = this.template.querySelectorAll('.clshelptexthide');
        for (let i = 0; i < qs.length; i++) {
            const element = qs[i];
            element.appendChild(style);
        }

    }

    //call the apex method
    fetchSobjectRecords(loadEvent) {
        // fetchRecords({
        //     inputWrapper: this.methodInput
        // }).then(result => {
        //     if (loadEvent && result) {
        //         this.selectedRecord.mainField = result[0].mainField;
        //     } else if (result) {
        //         this.records = JSON.parse(JSON.stringify(result));
        //     } else {
        //         this.records = [];
        //     }
        // }).catch(error => {
        //     console.log(error);
        // })
    }

    get isValueSelected() {
        return this.selectedRecordId;
    }

    //handler for calling search when user change the value in lookup
    handleChange(event) {
        this.searchString = event.target.value;
        // this.fetchSobjectRecords(false);

        // clear previous timer
        this.dispatchEvent(new CustomEvent('changevalue', {
            detail: {
                value: this.searchString
            }
        }));
    }

    handleFocus(event) {
        this.searchString = event.target.value;
        // clear previous timer
        this.dispatchEvent(new CustomEvent('focus', {
            detail: {
                value: this.searchString
            }
        }));
    }

    //handler for clicking outside the selection panel
    handleBlur() {
        // this.records = [];
        // this.preventClosingOfSearchPanel = false;
    }

    //handle the click inside the search panel to prevent it getting closed
    handleDivClick() {
        // this.preventClosingOfSearchPanel = true;
    }

    //handler for deselection of the selected item
    handleDeselect() {
        this.dispatchEvent(new CustomEvent('valuedeselected', {
            detail: this.selectedRecord
        }));
        this.selectedRecordId = null;
        this.selectedRecord = {
            id: '',
            mainField: '',
            subField: ''
        }
    }

    //handler for selection of records from lookup result list
    handleSelect(event) {
        try {
            const dataset = event.currentTarget.dataset;

            this.selectedRecord.id = dataset.id;
            this.selectedRecord.mainField = dataset.mainfield;
            this.selectedRecord.subField = dataset.subfield;
            this.selectedRecordId = this.selectedRecord.id;
            this.records = [];

            // dispatching the custom event
            this.dispatchEvent(new CustomEvent('valueselected', {
                detail: this.selectedRecord
            }));
        } catch (err) {
            console.error(err);
        }
    }

    //to close the search panel when clicked outside of search input
    handleInputBlur(event) {
        // Debouncing this method: Do not actually invoke the Apex call as long as this function is
        // being called within a delay of DELAY. This is to avoid a very large number of Apex method calls.
        // window.clearTimeout(this.delayTimeout);
        // // eslint-disable-next-line @lwc/lwc/no-async-operation
        // this.delayTimeout = setTimeout(() => {
        //     if (!this.preventClosingOfSearchPanel) {
        //         // this.records = [];
        //     }
        //     this.preventClosingOfSearchPanel = false;
        // }, DELAY);
    }

}