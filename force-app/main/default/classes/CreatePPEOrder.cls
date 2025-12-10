public class CreatePPEOrder {
    
    private static final Set<String> VALID_BOOT_SIZES = new Set<String>{
        'EU 39', 'EU 40', 'EU 41', 'EU 42', 'EU 43', 'EU 44', 'EU 45', 'EU 46'
    };
    
    private static final Set<String> VALID_STANDARD_SIZES = new Set<String>{
        'S', 'M', 'L', 'XL', 'XXL', 'One Size', 'N/A'
    };
    
    public class OrderRequest {
        @InvocableVariable(required=true label='Product Name')
        public String productName;
        
        @InvocableVariable(required=true label='Quantity')
        public Decimal quantity;
        
        @InvocableVariable(label='Size')
        public String size;
        
        @InvocableVariable(required=true label='Customer Name')
        public String customerName;
    }
    
    public class OrderResult {
        @InvocableVariable
        public String confirmationMessage;
        
        @InvocableVariable
        public String caseNumber;
        
        @InvocableVariable
        public String caseId;
    }
    
    @InvocableMethod(label='Create PPE Order' description='Creates a Case for a PPE order with product, size, quantity, and customer name')
    public static List<OrderResult> createOrder(List<OrderRequest> requests) {
        List<OrderResult> results = new List<OrderResult>();
        
        for (OrderRequest req : requests) {
            OrderResult result = new OrderResult();
            
            try {
                List<PPEProduct__c> products = [
                    SELECT Id, Name, ImageURL__c, Category__c 
                    FROM PPEProduct__c 
                    WHERE Name = :req.productName 
                    LIMIT 1
                ];
                
                if (products.isEmpty()) {
                    result.confirmationMessage = 'Product not found: ' + req.productName;
                    results.add(result);
                    continue;
                }
                
                PPEProduct__c product = products[0];
                
                String sizeValue = String.isNotBlank(req.size) ? req.size.trim() : 'N/A';
                Boolean isFootwear = product.Category__c == 'Footwear' || product.Name.containsIgnoreCase('Boot');
                
                if (isFootwear) {
                    String numericPart = sizeValue.replaceAll('[^0-9]', '');
                    if (String.isNotBlank(numericPart)) {
                        sizeValue = 'EU ' + numericPart;
                    }
                    
                    if (!VALID_BOOT_SIZES.contains(sizeValue)) {
                        result.confirmationMessage = 'Invalid size for ' + product.Name + '. Available sizes: EU 39-46';
                        results.add(result);
                        continue;
                    }
                } else if (sizeValue != 'N/A') {
                    sizeValue = sizeValue.toUpperCase();
                    if (!VALID_STANDARD_SIZES.contains(sizeValue)) {
                        result.confirmationMessage = 'Invalid size for ' + product.Name + '. Available sizes: S, M, L, XL, XXL';
                        results.add(result);
                        continue;
                    }
                }
                
                String description = 'Product: ' + product.Name + '\n' +
                    'Quantity: ' + req.quantity.intValue() + '\n' +
                    'Size: ' + sizeValue;
                
                Case orderCase = new Case(
                    Subject = 'PPE Order: ' + req.quantity.intValue() + 'x ' + product.Name,
                    Type = 'PPE Order',
                    Status = 'New',
                    Origin = 'Chat',
                    Description = description,
                    SuppliedName = req.customerName,
                    PPE_Product__c = product.Name,
                    PPE_Quantity__c = req.quantity,
                    PPE_Size__c = sizeValue,
                    PPE_Product_Image__c = product.ImageURL__c
                );
                insert orderCase;
                
                orderCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :orderCase.Id LIMIT 1];
                
                result.caseId = orderCase.Id;
                result.caseNumber = orderCase.CaseNumber;
                result.confirmationMessage = 'Order confirmed for ' + req.customerName + '! ' + 
                    req.quantity.intValue() + 'x ' + product.Name + 
                    (sizeValue != 'N/A' ? ' (Size: ' + sizeValue + ')' : '') +
                    '. Your case number is ' + orderCase.CaseNumber + '.';
                
            } catch (Exception e) {
                result.confirmationMessage = 'Error creating order: ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
}
