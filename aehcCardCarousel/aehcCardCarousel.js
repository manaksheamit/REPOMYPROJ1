import { LightningElement, api } from 'lwc';
import QUICKLINK_2 from '@salesforce/contentAssetUrl/ms_aeh__quicklink_2';

export default class AehcCardCarousel extends LightningElement {
    @api title;
    @api desc;
    @api url;
    @api category;
    @api imageUrl;
    imageUrl = QUICKLINK_2;

    get safeTitle() {
        return this.title || 'Business Domain';
    }

    get overlayStyle() {
        return `background:${this.overlayColor}`;
    }

    get overlayColor() {
        switch (this.category) {
            case 'Domain A': return 'rgba(63, 70, 200, 0.85)';
            case 'Domain B': return 'rgba(8, 87, 99, 0.85)';
            case 'Domain C': return 'rgba(98, 0, 234, 0.85)';
            default: return 'rgba(0, 0, 0, 0.7)';
        }
    }

    handleClick() {
        if (!this.url) return;
        window.open(this.url, '_self');
    }
}