public with sharing class PPECarouselAction {
    
    public class CarouselRequest {
        @InvocableVariable(label='Search Term' description='Optional search term to filter products' required=false)
        public String searchTerm;
        
        @InvocableVariable(label='Category' description='Optional category filter' required=false)
        public String category;
    }
    
    public class CarouselResponse {
        @InvocableVariable(label='Carousel Output' description='Product carousel data')
        public List<String> carouselData;
    }
    
    @InvocableMethod(
        label='Get PPE Products Carousel' 
        description='Returns PPE products as a visual carousel with images and names.'
    )
    public static List<CarouselResponse> getProducts(List<CarouselRequest> requests) {
        CarouselRequest req = (requests != null && !requests.isEmpty()) ? requests[0] : new CarouselRequest();
        
        String query = 'SELECT Id, Name, Description__c, Category__c, ImageURL__c, MIMEType__c FROM PPEProduct__c WHERE InStock__c = true';
        
        if (String.isNotBlank(req.category)) {
            query += ' AND Category__c = \'' + String.escapeSingleQuotes(req.category) + '\'';
        }
        
        if (String.isNotBlank(req.searchTerm)) {
            // Normalize search term - remove trailing 's' for plural handling
            String normalizedTerm = req.searchTerm.trim().toLowerCase();
            if (normalizedTerm.endsWith('s') && normalizedTerm.length() > 3) {
                normalizedTerm = normalizedTerm.substring(0, normalizedTerm.length() - 1);
            }
            String searchPattern = '%' + String.escapeSingleQuotes(normalizedTerm) + '%';
            query += ' AND (Name LIKE \'' + searchPattern + '\' OR Description__c LIKE \'' + searchPattern + '\')';
        }
        
        query += ' ORDER BY Category__c, Name LIMIT 20';
        
        List<PPEProduct__c> products = Database.query(query);
        
        List<String> carouselItems = new List<String>();
        
        for (PPEProduct__c product : products) {
            carouselItems.add(String.isNotBlank(product.MIMEType__c) ? product.MIMEType__c : 'image/jpeg');
            carouselItems.add('/lightning/r/PPEProduct__c/' + product.Id + '/view');
            carouselItems.add(String.isNotBlank(product.ImageURL__c) ? product.ImageURL__c : '');
            carouselItems.add(product.Name);
        }
        
        if (carouselItems.isEmpty()) {
            carouselItems.add('text/plain');
            carouselItems.add('');
            carouselItems.add('');
            carouselItems.add('No products found.');
        }
        
        CarouselResponse response = new CarouselResponse();
        response.carouselData = carouselItems;
        
        List<CarouselResponse> responses = new List<CarouselResponse>();
        responses.add(response);
        return responses;
    }
}