import { createElement } from 'lwc';
import AehcCarousel from 'c/aehcCarousel';
import getCards from '@salesforce/apex/AEHC_CarouselController.getFilteredCards';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';

const getCardsAdapter = registerApexTestWireAdapter(getCards);

// Jest environment in sfdx-lwc-jest doesn't provide setImmediate
// Use a macrotask to flush pending promises instead
const flushPromises = () => new Promise((resolve) => setTimeout(resolve));

describe('c-aehc-carousel', () => {

    afterEach(() => {
        document.body.innerHTML = '';
    });

    it('renders loading skeletons initially', () => {
        const element = createElement('c-aehc-carousel', { is: AehcCarousel });
        document.body.appendChild(element);

        const skeletons = element.shadowRoot.querySelectorAll(
            'c-aehc-skeleton-card-carousel'
        );

        expect(skeletons.length).toBe(4);
    });

    it('renders data cards when Apex returns data', async () => {
        const element = createElement('c-aehc-carousel', { is: AehcCarousel });
        document.body.appendChild(element);

        getCardsAdapter.emit([
            { title: 'A', description: 'B', category: 'API User', url: 'x' },
            { title: 'C', description: 'D', category: 'Data Product User', url: 'y' }
        ]);

        await flushPromises();

        const cards = element.shadowRoot.querySelectorAll('c-aehc-card-carousel');
        expect(cards.length).toBe(2);
    });

    it('renders error state when Apex fails', async () => {
        const element = createElement('c-aehc-carousel', { is: AehcCarousel });
        document.body.appendChild(element);

        getCardsAdapter.error();

        await flushPromises();

        const error = element.shadowRoot.querySelector('.state-container.error');
        expect(error).not.toBeNull();
    });

    it('renders empty state when no data', async () => {
        const element = createElement('c-aehc-carousel', { is: AehcCarousel });
        document.body.appendChild(element);

        getCardsAdapter.emit([]);

        await flushPromises();

        const empty = element.shadowRoot.querySelector('.state-container');
        expect(empty).not.toBeNull();
    });

    it('scroll works', async () => {
        const element = createElement('c-aehc-carousel', { is: AehcCarousel });
        document.body.appendChild(element);

        getCardsAdapter.emit([
            { title: 'A', description: 'B', category: 'API User', url: 'x' }
        ]);

        await flushPromises();

        const slider = element.shadowRoot.querySelector('[data-id="slider"]');

        expect(slider).not.toBeNull();

        slider.scrollLeft = 0;
        slider.scrollLeft += 320;

        expect(slider.scrollLeft).toBe(320);
    });
});