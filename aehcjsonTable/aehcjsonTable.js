import { LightningElement,api } from 'lwc';

export default class AehcjsonTable extends LightningElement {



    _jsonData;
    fieldList = [];

    @api
    set jsonData(value) {
        this._jsonData = value;
        this.processData();
    }

    get jsonData() {
        return this._jsonData;
    }

    processData() {
        if (!this._jsonData) {
            this.fieldList = [];
            return;
        }

        let parsedData;

        // Handle string JSON
        if (typeof this._jsonData === 'string') {
            try {
                parsedData = JSON.parse(this._jsonData);
            } catch (e) {
                console.error('Invalid JSON', e);
                this.fieldList = [];
                return;
            }
        } else {
            parsedData = this._jsonData;
        }

        // ✅ Handle ARRAY format
        if (Array.isArray(parsedData)) {

            this.fieldList = parsedData.map((item, index) => {
                return {
                    key: index,                          // for iteration
                    fieldName: item.fieldName || '',     // ✅ actual field name
                    label: item.label || ''              // ✅ label
                };
            });

        } else {
            this.fieldList = [];
        }
    }
}