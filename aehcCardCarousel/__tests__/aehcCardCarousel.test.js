import { createElement } from 'lwc';
import AehcCardCarousel from 'c/aehcCardCarousel';

describe('c-aehc-card-carousel', () => {
    let element;

    beforeEach(() => {
        element = createElement('c-aehc-card-carousel', {
            is: AehcCardCarousel
        });

        document.body.appendChild(element);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }

        jest.clearAllMocks();
    });

    it('renders card container', () => {
        const card = element.shadowRoot.querySelector('.card');
        expect(card).not.toBeNull();
    });

    it('renders title, description and category correctly', () => {
        element.title = 'Test Title';
        element.description = 'Test Description';
        element.category = 'API User';

        return Promise.resolve().then(() => {
            expect(element.shadowRoot.querySelector('.title').textContent).toBe('Test Title');
            expect(element.shadowRoot.querySelector('.desc').textContent).toBe('Test Description');
            expect(element.shadowRoot.querySelector('.tag').textContent).toBe('API User');
        });
    });

    it('renders correct icon for API User', () => {
        element.category = 'API User';

        return Promise.resolve().then(() => {
            const icon = element.shadowRoot.querySelector('lightning-icon');
            expect(icon.iconName).toBe('utility:link');
        });
    });

    it('renders correct icon for Data Product User', () => {
        element.category = 'Data Product User';

        return Promise.resolve().then(() => {
            const icon = element.shadowRoot.querySelector('lightning-icon');
            expect(icon.iconName).toBe('utility:database');
        });
    });

    it('renders default icon for unknown category', () => {
        element.category = 'Other';

        return Promise.resolve().then(() => {
            const icon = element.shadowRoot.querySelector('lightning-icon');
            expect(icon.iconName).toBe('utility:apps');
        });
    });

    it('applies correct color styling via icon-box', () => {
        element.category = 'API User';

        return Promise.resolve().then(() => {
            const iconBox = element.shadowRoot.querySelector('.icon-box');
            expect(iconBox.getAttribute('style')).toContain('#2EC4B6');
        });
    });

    it('computes correct color for Data Product User', () => {
        element.category = 'Data Product User';

        return Promise.resolve().then(() => {
            const iconBox = element.shadowRoot.querySelector('.icon-box');
            expect(iconBox.getAttribute('style')).toContain('#3B82F6');
        });
    });

    it('uses default color for unknown category', () => {
        element.category = 'Unknown';

        return Promise.resolve().then(() => {
            const iconBox = element.shadowRoot.querySelector('.icon-box');
            expect(iconBox.getAttribute('style')).toContain('#888');
        });
    });

    it('opens URL with https when missing protocol', () => {
        const openMock = jest.fn();
        window.open = openMock;

        element.url = 'example.com';

        const card = element.shadowRoot.querySelector('.card');
        card.click();

        expect(openMock).toHaveBeenCalledWith('https://example.com', '_self');
    });

    it('opens URL as-is when http already exists', () => {
        const openMock = jest.fn();
        window.open = openMock;

        element.url = 'http://example.com';

        const card = element.shadowRoot.querySelector('.card');
        card.click();

        expect(openMock).toHaveBeenCalledWith('http://example.com', '_self');
    });

    it('does nothing when URL is empty', () => {
        const openMock = jest.fn();
        window.open = openMock;

        element.url = '';

        const card = element.shadowRoot.querySelector('.card');
        card.click();

        expect(openMock).not.toHaveBeenCalled();
    });

    it('applies dynamic CSS variable for card color', () => {
        element.category = 'API User';

        return Promise.resolve().then(() => {
            const card = element.shadowRoot.querySelector('.card');
            expect(card.getAttribute('style')).toContain('--card-color');
        });
    });
});