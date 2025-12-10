import { LightningElement, api, wire, track } from 'lwc';
import getOrderDetails from '@salesforce/apex/PPEOrderConfirmationController.getOrderDetails';

export default class PpeOrderConfirmation extends LightningElement {
    @api recordId; // For use on record pages
    @api caseId;   // For URL parameter or manual setting
    
    @track orderData = {};
    @track error;
    @track isLoading = true;

    get effectiveCaseId() {
        return this.caseId || this.recordId || this.getUrlParameter('caseId');
    }

    get hasData() {
        return !this.isLoading && !this.error && this.orderData && this.orderData.items && this.orderData.items.length > 0;
    }

    get formattedDate() {
        if (this.orderData && this.orderData.createdDate) {
            const date = new Date(this.orderData.createdDate);
            return date.toLocaleDateString('fr-FR', { 
                day: 'numeric', 
                month: 'long', 
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        }
        return '';
    }

    connectedCallback() {
        this.loadOrderDetails();
    }

    getUrlParameter(name) {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.get(name);
    }

    loadOrderDetails() {
        const caseIdToUse = this.effectiveCaseId;
        
        if (!caseIdToUse) {
            this.isLoading = false;
            this.error = 'No case ID provided';
            return;
        }

        getOrderDetails({ caseId: caseIdToUse })
            .then(result => {
                this.orderData = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error;
                this.isLoading = false;
                console.error('Error loading order:', error);
            });
    }

    handleImageError(event) {
        // Fallback image if Unsplash fails
        event.target.src = 'https://via.placeholder.com/300x200?text=Image+non+disponible';
    }
}
