import { createElement } from 'lwc';
import AehcSectionMyAPIs from 'c/aehcSectionMyAPIs';

describe('c-aehc-section-my-apis', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders title and description from @api properties', async () => {
        const element = createElement('c-aehc-section-my-apis', {
            is: AehcSectionMyAPIs
        });

        element.title = 'My APIs Section';
        element.description = 'Overview of APIs and feedback';

        document.body.appendChild(element);

        await Promise.resolve();

        const titleEl = element.shadowRoot.querySelector('.card__title');
        const descEl =
            element.shadowRoot.querySelector('.card__subTitle');

        expect(titleEl.textContent).toBe('My APIs Section');
        expect(descEl.textContent).toBe('Overview of APIs and feedback');
    });

    it('renders child components', () => {
        const element = createElement('c-aehc-section-my-apis', {
            is: AehcSectionMyAPIs
        });

        document.body.appendChild(element);

        const apiDashboard =
            element.shadowRoot.querySelector('c-aehcapidashboardao');
        const subscriptionSummary =
            element.shadowRoot.querySelector('c-aehcsubscriptionsummaryaopie');
        const feedbackCard =
            element.shadowRoot.querySelector('c-aehcfeedbackcardao');

        expect(apiDashboard).not.toBeNull();
        expect(subscriptionSummary).not.toBeNull();
        expect(feedbackCard).not.toBeNull();
    });

    it('renders three cards layout grid', () => {
        const element = createElement('c-aehc-section-my-apis', {
            is: AehcSectionMyAPIs
        });

        document.body.appendChild(element);

        const columns =
            element.shadowRoot.querySelectorAll(
                '.slds-col.slds-medium-size_1-of-3'
            );

        expect(columns.length).toBe(3);
    });
});