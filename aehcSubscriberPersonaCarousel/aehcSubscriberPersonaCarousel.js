import { LightningElement, track, api,wire } from 'lwc';
import getCards from '@salesforce/apex/AEHC_CarouselController.getFilteredCards';
import getPublications from '@salesforce/apex/AEHC_CarouselController.getPublications';
import LABEL_ERROR_TITLE from '@salesforce/label/c.AEHC_Carousel_Error_Title';
import LABEL_ERROR_DESC from '@salesforce/label/c.AEHC_Carousel_Error_Description';
import LABEL_EMPTY_TITLE from '@salesforce/label/c.AEHC_Carousel_Empty_Title';
import LABEL_EMPTY_DESC from '@salesforce/label/c.AEHC_Carousel_Empty_Description';
import Recently_Modified_Publications from '@salesforce/label/c.Recently_Modified_Publications';

export default class AehcSubscriberPersonaCarousel extends LightningElement {


    get color() {
        return "#2EC4B6";
    }

    get iconName() {
        return "utility:apps";
    }

    @track publications = [];

     @track cards = [];
    @track state = 'loading';

        // Public properties for UI labels (configurable in Lightning App Builder)
    @api title = Recently_Modified_Publications;
    @api description = '';

    // wire publications Apex method and handle response
    @wire(getPublications)
    wiredPublications({ data, error }) {
        if (data) {
            // data is List<PublicationWrapper> from Apex
            this.publications = data;
        } else if (error) {
            // Keep publications empty on error and surface via state if needed
            this.publications = [];
            // Optionally log or set an error state; reuse existing errorTitle/Description if desired
            this.errorTitle = LABEL_ERROR_TITLE;
            this.errorDescription = LABEL_ERROR_DESC;
        }
    }

    errorTitle;
    errorDescription;

    dummy = [1, 2, 3, 4];

    @wire(getCards)
    wiredData({ data, error }) {
        if (data) {
            this.cards = data.data;
            this.state = this.cards.length ? 'success' : 'empty';
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

    // Handlers used by arrow buttons in template to prevent clicks from
    // propagating to underlying clickable cards/anchors which may trigger navigation.
    handleScrollLeft(event) {
        if (event) {
            event.stopPropagation();
            event.preventDefault();
        }
        this.scrollLeft();
    }

    handleScrollRight(event) {
        if (event) {
            event.stopPropagation();
            event.preventDefault();
        }
        this.scrollRight();
    }

    scroll(offset) {
        const slider = this.template.querySelector('[data-id="slider"]');
        if (slider) slider.scrollLeft += offset;
    }

    get isLoading() { return this.state === 'loading'; }
    get isSuccess() { return this.state === 'success'; }
    get isEmpty() { return this.state === 'empty'; }
    get isError() { return this.state === 'error'; }

    get emptyTitle() { return LABEL_EMPTY_TITLE; }
    get emptyDescription() { return LABEL_EMPTY_DESC; }

   
}