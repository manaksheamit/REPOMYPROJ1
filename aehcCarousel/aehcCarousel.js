import { LightningElement, wire, api, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import communityPath from '@salesforce/community/basePath';

// Apex class
import getCards from '@salesforce/apex/AEHC_CarouselController.getFilteredCards';

import LABEL_TITLE from '@salesforce/label/c.AEHC_Carousel_Title';
import LABEL_DESC from '@salesforce/label/c.AEHC_Carousel_Description';
import LABEL_ERROR_TITLE from '@salesforce/label/c.AEHC_Carousel_Error_Title';
import LABEL_ERROR_DESC from '@salesforce/label/c.AEHC_Carousel_Error_Description';
import LABEL_EMPTY_TITLE from '@salesforce/label/c.AEHC_Carousel_Empty_Title';
import LABEL_EMPTY_DESC from '@salesforce/label/c.AEHC_Carousel_Empty_Description';


// static resources
import AEH_IMAGES from '@salesforce/resourceUrl/aeh_carousel';

// User related fields
import USER_ID from '@salesforce/user/Id';
import PREF_FIELD from '@salesforce/schema/User.AEHC_Preference__c';

export default class AehcCarousel extends LightningElement {
    @api title = LABEL_TITLE;
    @api description = LABEL_DESC;

    @track cards = [];
    isLoading = true;
    @track state = 'loading';
    preference;
    leftDisabled = true;
    rightDisabled = false;
    sliderInitialized = false;

    errorTitle;
    errorDescription;

    dummy = [1, 2, 3, 4];

    @wire(getRecord, {
        recordId: USER_ID,
        fields: [PREF_FIELD]
    })
    wiredUser({ data, error }) {
        if (data) {
            this.cards = [];
            this.isLoading = true;
            this.preference = data.fields.AEHC_Preference__c.value || '';
            console.log(42, this.preference)
        } else if (error) {
            this.state = 'error';
        }
    }

    @wire(getCards, { currUserPreference: '$preference' })
    wiredData({ data, error }) {
        console.log(51, data, error);
        this.isLoading = false;;
        if (data) {
            const result = JSON.parse(JSON.stringify(data));
            if (result.status == 200) {
                const cardData = result.data;
                for (const card of cardData) {
                    if (card.imageUrl) card.imageUrl = AEH_IMAGES + card.imageUrl;
                    if (card.url) card.url = window.location.origin + communityPath + card.url;
                }
                console.log(38, JSON.stringify(cardData));
                this.cards = cardData;
                this.state = 'success';
            } else if (result.status == 404) {
                this.state = 'empty';
            } else if (result.status == 500) {
                this.state = 'error';
                this.errorTitle = LABEL_ERROR_TITLE;
                this.errorDescription = LABEL_ERROR_DESC;
            }

        } else if (error) {
            this.state = 'error';
            this.errorTitle = LABEL_ERROR_TITLE;
            this.errorDescription = LABEL_ERROR_DESC;
        }
    }

    // expose for test + UI
    @api scrollLeft() {
        this.scroll(-320);
    }

    @api scrollRight() {
        this.scroll(320);
    }


    get isSuccess() {
        return this.state === 'success' && this.cards.length > 0;
    }


    scroll(offset) {
        const slider = this.template.querySelector('[data-id="slider"]');

        if (slider) {
            slider.scrollLeft += offset;

            setTimeout(() => {
                this.updateArrowState();
            }, 300);
        }
    }
    updateArrowState() {
        const slider = this.template.querySelector('[data-id="slider"]');

        if (!slider) {
            return;
        }

        this.leftDisabled = slider.scrollLeft <= 0;

        this.rightDisabled =
            slider.scrollLeft + slider.clientWidth >= slider.scrollWidth - 5;
    }

    renderedCallback() {
        const slider = this.template.querySelector('[data-id="slider"]');
        if (slider && !this.sliderInitialized) {
            this.sliderInitialized = true;

            slider.addEventListener('scroll', () => {
                this.updateArrowState();
            });

            this.updateArrowState();
        }
    }
    get isLoading() { return this.state === 'loading'; }
    get isSuccess() { return this.state === 'success'; }
    get isEmpty() { return this.state === 'empty'; }
    get isError() { return this.state === 'error'; }

    get emptyTitle() { return LABEL_EMPTY_TITLE; }
    get emptyDescription() { return LABEL_EMPTY_DESC; }
}