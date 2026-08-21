import { createElement } from 'lwc';
import Aehcsubscriptionsummaryaopie
    from 'c/aehcsubscriptionsummaryaopie';
import getSubscriptionSummary
    from '@salesforce/apex/AEHC_SubscriptionControllerAO.getSubscriptionSummary';

describe('c-aehcsubscriptionsummaryaopie', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders total subscribers and legend items when wire returns status 200', async () => {
        const element = createElement(
            'c-aehcsubscriptionsummaryaopie',
            { is: Aehcsubscriptionsummaryaopie }
        );
        document.body.appendChild(element);

        getSubscriptionSummary.emit({
            status: 200,
            data: {
                Production: 50,
                UAT: 30,
                Sandbox: 20
            }
        });

        await Promise.resolve();

        // ✅ total subscribers
        const subtitle =
            element.shadowRoot.querySelector(
                '.leftPanel__card1-subtitle'
            );
        expect(subtitle.textContent)
            .toContain('Total Subscribers : 100');

        // ✅ legend rows
        const legendRows =
            element.shadowRoot.querySelectorAll('.legend-row');
        expect(legendRows.length).toBe(3);

        expect(legendRows[0].textContent)
            .toContain('Production');
        expect(legendRows[0].textContent)
            .toContain('50');
    });

    it('generates unique colors for segments', () => {
        const element = createElement(
            'c-aehcsubscriptionsummaryaopie',
            { is: Aehcsubscriptionsummaryaopie }
        );

        const c1 = element.generateColor(0, 3);
        const c2 = element.generateColor(1, 3);
        const c3 = element.generateColor(2, 3);

        expect(c1).not.toBe(c2);
        expect(c2).not.toBe(c3);
        expect(c1).toContain('hsl');
    });
});