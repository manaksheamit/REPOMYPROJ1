import { createElement } from 'lwc';
import Aehcfeedbackcardao from 'c/aehcfeedbackcardao';
import getLastWeekFeedbackCount
    from '@salesforce/apex/AEHC_FeedbackControllerLWC.getLastWeekFeedbackCount';

describe('c-aehcfeedbackcardao', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders feedback count when Apex returns status 200', async () => {
        const element = createElement('c-aehcfeedbackcardao', {
            is: Aehcfeedbackcardao
        });
        document.body.appendChild(element);

        // Emit wire data
        getLastWeekFeedbackCount.emit({
            status: 200,
            data: 12
        });

        await Promise.resolve();

        const countEl = element.shadowRoot.querySelector('.count');
        expect(countEl).not.toBeNull();
        expect(countEl.textContent).toBe('12');
    });

    it('does not update count when status is 500', async () => {
        const element = createElement('c-aehcfeedbackcardao', {
            is: Aehcfeedbackcardao
        });
        document.body.appendChild(element);

        getLastWeekFeedbackCount.emit({
            status: 500,
            data: null
        });

        await Promise.resolve();

        const countEl = element.shadowRoot.querySelector('.count');
        expect(countEl.textContent).toBe('0'); // default value
    });

    it('handles wire error gracefully', async () => {
        const element = createElement('c-aehcfeedbackcardao', {
            is: Aehcfeedbackcardao
        });
        document.body.appendChild(element);

        getLastWeekFeedbackCount.error(
            new Error('Wire error')
        );

        await Promise.resolve();

        const countEl = element.shadowRoot.querySelector('.count');
        expect(countEl.textContent).toBe('0');
    });

    it('renders static header and icon', () => {
        const element = createElement('c-aehcfeedbackcardao', {
            is: Aehcfeedbackcardao
        });
        document.body.appendChild(element);

        const title = element.shadowRoot.querySelector('.title');
        expect(title.textContent).toBe('Feedback Received in Last Week');

        const icon = element.shadowRoot.querySelector('lightning-icon');
        expect(icon).not.toBeNull();
        expect(icon.iconName).toBe('utility:comments');
    });
});
``