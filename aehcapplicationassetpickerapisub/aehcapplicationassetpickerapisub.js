import { LightningElement, api, track, wire } from 'lwc';
import getApplicationAssets from '@salesforce/apex/AEHC_ApplicationAssetControllerApiSub.getApplicationAssets';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class Aehcapplicationassetpickerapisub extends LightningElement {

    @api userId;
    @api defaultSelected;

    @api selectedValue;
    @api selectedLabel;

    @track options = [];
    @track filteredOptions = [];

    inputValue = '';
    showResults = false;
    validationError = '';

    @wire(getApplicationAssets, { userID: '$userId' })
    wiredAssets({ data, error }) {

        if (data) {

            console.log('Applications => ', JSON.stringify(data));

            this.options = [...data];
            this.filteredOptions = [...data];

            if (this.defaultSelected) {

                const selected = this.options.find(
                    item => item.value === this.defaultSelected
                );

                if (selected) {

                    this.selectedValue = selected.value;
                    this.selectedLabel = selected.label;
                    this.inputValue = selected.label;

                    this.updateFlowValues();
                }
            }

        } else if (error) {

            console.error('Error loading assets', JSON.stringify(error));
        }
    }

    handleFocus() {

        this.filteredOptions = [...this.options];
        this.showResults = true;
    }

    handleSearch(event) {

        this.inputValue = event.target.value;

        const searchTerm =
            (this.inputValue || '')
                .trim()
                .toLowerCase();

        this.filteredOptions = [
            ...this.options.filter(item =>
                (item.label || '')
                    .toLowerCase()
                    .includes(searchTerm)
            )
        ];

        this.showResults = true;

        console.log('Search Term:', searchTerm);
        console.log('Filtered Records:', JSON.stringify(this.filteredOptions));
    }

    handleChange(event) {

        this.inputValue = event.target.value;

        if (!this.inputValue) {

            this.selectedValue = null;
            this.selectedLabel = null;

            this.filteredOptions = [...this.options];

            this.updateFlowValues();
        }
    }

    handleSelect(event) {

        this.selectedValue = event.currentTarget.dataset.id;
        this.selectedLabel = event.currentTarget.dataset.label;
        this.inputValue = event.currentTarget.dataset.label;

        this.showResults = false;
        this.validationError = '';

        this.updateFlowValues();
    }

    handleBlur() {

        window.setTimeout(() => {
            this.showResults = false;
        }, 200);
    }

    updateFlowValues() {

        this.dispatchEvent(
            new FlowAttributeChangeEvent(
                'selectedValue',
                this.selectedValue
            )
        );

        this.dispatchEvent(
            new FlowAttributeChangeEvent(
                'selectedLabel',
                this.selectedLabel
            )
        );
    }

    get noRecords() {

        return this.filteredOptions.length === 0;
    }

    @api
    validate() {

        const isValid =
            this.selectedValue &&
            this.selectedValue !== '';

        this.validationError =
            isValid
                ? ''
                : 'Please select a Consuming Application Name';

        return {
            isValid: isValid,
            errorMessage: this.validationError
        };
    }

    @api
    reportValidity() {

        return this.validate();
    }
}