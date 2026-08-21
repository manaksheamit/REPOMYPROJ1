import { createElement } from 'lwc';
import Aehcapidashboardao from 'c/aehcapidashboardao';
import getPublishedAPIMatrix
    from '@salesforce/apex/AEHC_APIDashboardCtrl.getPublishedAPIMatrix';

// Mock Apex
jest.mock(
    '@salesforce/apex/AEHC_APIDashboardCtrl.getPublishedAPIMatrix',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

// Utility to flush promises
const flushPromises = () => new Promise(setImmediate);

describe('c-aehcapidashboardao', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders total count, legend rows, and bars correctly', async () => {
        // Mock Apex response
        getPublishedAPIMatrix.mockResolvedValue({
            status: 200,
            data: {
                API_A: 10,
                API_B: 20,
                API_C: 30
            }
        });

        const element = createElement('c-aehcapidashboardao', {
            is: Aehcapidashboardao
        });
        document.body.appendChild(element);

        await flushPromises();

        // ✅ Total Published count
        const subtitle = element.shadowRoot.querySelector(
            '.leftPanel__card1-subtitle'
        );
        expect(subtitle.textContent).toContain('Total Published : 60');

        // ✅ Legend rows
        const legendRows =
            element.shadowRoot.querySelectorAll('.legend-row');
        expect(legendRows.length).toBe(3);

        expect(legendRows[0].textContent).toContain('API_A');
        expect(legendRows[0].textContent).toContain('10');

        // ✅ SVG bars
        const rects =
            element.shadowRoot.querySelectorAll('svg rect');
        expect(rects.length).toBe(3);

        rects.forEach(rect => {
            expect(rect.getAttribute('height')).not.toBe('0');
            expect(rect.getAttribute('fill')).toBeTruthy();
        });
    });

    it('does not render bars when Apex returns non-200 status', async () => {
        getPublishedAPIMatrix.mockResolvedValue({
            status: 500,
            data: {}
        });

        const element = createElement('c-aehcapidashboardao', {
            is: Aehcapidashboardao
        });
        document.body.appendChild(element);

        await flushPromises();

        const rects =
            element.shadowRoot.querySelectorAll('svg rect');
        expect(rects.length).toBe(0);
    });

    it('handles Apex error gracefully', async () => {
        getPublishedAPIMatrix.mockRejectedValue(
            new Error('Apex failure')
        );

        const element = createElement('c-aehcapidashboardao', {
            is: Aehcapidashboardao
        });
        document.body.appendChild(element);

        await flushPromises();

        // Component should still exist without crashing
        expect(element).toBeTruthy();

        const rects =
            element.shadowRoot.querySelectorAll('svg rect');
        expect(rects.length).toBe(0);
    });
});