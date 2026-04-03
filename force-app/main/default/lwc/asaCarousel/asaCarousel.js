/**
 * @description ASA Product Carousel Component
 * Displays products in a carousel format with navigation
 * Receives data from Flow via Lightning Type
 */
import { LightningElement, api } from 'lwc';

export default class AsaCarousel extends LightningElement {
    @api value; // Receives AsaCarouselData object from Lightning Type
    
    currentIndex = 0;
    errorMessage = '';
    products = [];
    
    /**
     * Lifecycle hook - parses JSON data from Flow
     */
    connectedCallback() {
        try {
            if (this.value && this.value.productCarouselJSON) {
                const data = JSON.parse(this.value.productCarouselJSON);
                
                if (data.products && Array.isArray(data.products) && data.products.length > 0) {
                    this.products = data.products.map(product => ({
                        title: product.title || 'Untitled Product',
                        imageUrl: product.imageUrl || '',
                        description: product.description || '',
                        time: this.mapTimeToSymbol(product.time), // Convert AM/PM to symbols
                        stage: product.stage || '' // PREP, TREAT, or SEAL
                    }));
                } else {
                    this.errorMessage = 'No products available';
                }
            } else {
                this.errorMessage = 'No data provided';
            }
        } catch (error) {
            this.errorMessage = 'Error loading products';
        }
    }
    
    /**
     * Get current product to display
     */
    get currentProduct() {
        return this.products[this.currentIndex] || {};
    }
    
    /**
     * Check if we have products to display
     */
    get hasProducts() {
        return this.products.length > 0;
    }
    
    /**
     * Check if navigation should be shown
     */
    get showNavigation() {
        return this.products.length > 1;
    }
    
    /**
     * Check if we're on the first card
     */
    get isFirstCard() {
        return this.currentIndex === 0;
    }
    
    /**
     * Check if we're on the last card
     */
    get isLastCard() {
        return this.currentIndex === this.products.length - 1;
    }
    
    /**
     * Map time text to symbols
     */
    mapTimeToSymbol(timeText) {
        if (!timeText) return '';
        const normalized = timeText.toUpperCase().trim();
        if (normalized === 'AM') return '☼';
        if (normalized === 'PM') return '☽';
        if (normalized === 'AM/PM' || normalized === 'AM PM') return '☼☽';
        return timeText; // Return original if no match
    }
    
    /**
     * Get products with index for dot indicators
     */
    get productsWithIndex() {
        return this.products.map((product, index) => ({
            key: `dot-${index}`,
            index: index,
            isActive: index === this.currentIndex,
            dotClass: index === this.currentIndex ? 'dot active' : 'dot'
        }));
    }
    
    /**
     * Handle previous button click
     */
    handlePrevious() {
        if (this.currentIndex > 0) {
            this.currentIndex--;
        }
    }
    
    /**
     * Handle next button click
     */
    handleNext() {
        if (this.currentIndex < this.products.length - 1) {
            this.currentIndex++;
        }
    }
    
    /**
     * Handle dot indicator click
     */
    handleDotClick(event) {
        const index = parseInt(event.target.dataset.index, 10);
        if (!isNaN(index) && index >= 0 && index < this.products.length) {
            this.currentIndex = index;
        }
    }
}