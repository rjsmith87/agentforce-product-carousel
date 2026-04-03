/**
 * @description Lightning Type backing class for ASA Carousel
 * Holds product carousel data as JSON string
 * Used with Agentforce and Enhanced Chat
 * 
 * JSON Format Expected:
 * {
 *   "products": [
 *     {"title": "...", "imageUrl": "...", "description": "..."},
 *     {"title": "...", "imageUrl": "...", "description": "..."}
 *   ]
 * }
 */
@JsonAccess(serializable='always' deserializable='always')
global with sharing class AsaCarouselData {
    
    @AuraEnabled
    global String productCarouselJSON;
    
    /**
     * Constructor with JSON string
     */
    global AsaCarouselData(String productCarouselJSON) {
        this.productCarouselJSON = productCarouselJSON;
    }
    
    /**
     * Default constructor
     */
    global AsaCarouselData() {
        this.productCarouselJSON = '';
    }
}