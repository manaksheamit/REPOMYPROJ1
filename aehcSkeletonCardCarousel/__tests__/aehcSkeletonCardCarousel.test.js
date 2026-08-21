import { createElement } from 'lwc';
import AehcSkeletonCardCarousel from 'c/aehcSkeletonCardCarousel';

describe('c-aehc-skeleton-card-carousel', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders skeleton card container', () => {
        const element = createElement('c-aehc-skeleton-card-carousel', {
            is: AehcSkeletonCardCarousel
        });

        document.body.appendChild(element);

        const card = element.shadowRoot.querySelector('[data-testid="skeleton-card"]');
        expect(card).not.toBeNull();
        expect(card.classList.contains('card')).toBe(true);
        expect(card.classList.contains('skeleton')).toBe(true);
    });

    it('renders shimmer elements for icon, tag, title, and description', () => {
        const element = createElement('c-aehc-skeleton-card-carousel', {
            is: AehcSkeletonCardCarousel
        });

        document.body.appendChild(element);

        const icon = element.shadowRoot.querySelector('[data-testid="icon"]');
        const tag = element.shadowRoot.querySelector('[data-testid="tag"]');
        const title = element.shadowRoot.querySelector('[data-testid="title"]');
        const desc = element.shadowRoot.querySelector('[data-testid="desc"]');

        expect(icon).not.toBeNull();
        expect(tag).not.toBeNull();
        expect(title).not.toBeNull();
        expect(desc).not.toBeNull();

        expect(icon.classList.contains('shimmer')).toBe(true);
        expect(tag.classList.contains('shimmer')).toBe(true);
        expect(title.classList.contains('shimmer')).toBe(true);
        expect(desc.classList.contains('shimmer')).toBe(true);
    });

    it('does not throw runtime errors on render', () => {
        const element = createElement('c-aehc-skeleton-card-carousel', {
            is: AehcSkeletonCardCarousel
        });

        expect(() => {
            document.body.appendChild(element);
        }).not.toThrow();
    });
});