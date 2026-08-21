import { createElement } from 'lwc';
import Aehcpendingapprovalsao from 'c/aehcpendingapprovalsao';
import getPendingSubscriptions
    from '@salesforce/apex/AEHC_PendingSubscriptionsCtrlAO.getPendingSubscriptions';

const mockData = Array.from({ length: 15 }, (_, i) => ({
    Id: `00P${i}`,
    Name: `Request ${i}`,
    Type: 'API',
    SubscriptionName: `Sub ${i}`,
    CreatedDate: '2024-01-01T10:00:00.000Z',
    CreatedBy: 'Admin',
    Environment: 'UAT',
    Purpose: 'Testing'
}));

describe('c-aehcpendingapprovalsao', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders datatable with first page records', async () => {
        const element = createElement('c-aehcpendingapprovalsao', {
            is: Aehcpendingapprovalsao
        });
        document.body.appendChild(element);

        getPendingSubscriptions.emit({
            status: 200,
            data: mockData
        });

        await Promise.resolve();

        const datatable =
            element.shadowRoot.querySelector('lightning-datatable');
        expect(datatable).not.toBeNull();

        expect(element.displayData.length).toBe(10);
    });

    it('updates footer showing text correctly', async () => {
        const element = createElement('c-aehcpendingapprovalsao', {
            is: Aehcpendingapprovalsao
        });
        document.body.appendChild(element);

        getPendingSubscriptions.emit({
            status: 200,
            data: mockData
        });

        await Promise.resolve();

        const footerText =
            element.shadowRoot.querySelector('.left-text');
        expect(footerText.textContent)
            .toContain('Showing 1 - 10 of 15 requests');
    });
});