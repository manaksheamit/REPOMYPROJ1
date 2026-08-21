import { LightningElement } from 'lwc';
import getLastWeekFeedbackCount from '@salesforce/apex/AEHC_FeedbackControllerLWC.getLastWeekFeedbackCount';

export default class Aehcfeedbackcardao extends LightningElement {
    feedbackCount = 0;

    connectedCallback() {

        this.initialize();
    }

    async initialize() {
        try {
            const result = await getLastWeekFeedbackCount();

            if (result.status == 200) {
                this.feedbackCount = result.data;
            }
        } catch (err) {
            console.log(err);
        }
    }
}