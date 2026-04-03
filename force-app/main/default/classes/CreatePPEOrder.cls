public with sharing class CreatePPEOrder {
    
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
    
    @InvocableMethod(label='Create Product Order' description='Creates a Case for a product order with product, size, quantity, and customer name')
    public static List<OrderResult> createOrder(List<OrderRequest> requests) {
        List<OrderResult> results = new List<OrderResult>();

        // Step 1: Collect all product names for a single bulk query
        Set<String> productNames = new Set<String>();
        for (OrderRequest req : requests) {
            if (String.isNotBlank(req.productName)) {
                productNames.add(req.productName);
            }
        }

        // Step 2: Query all products in ONE SOQL query
        Map<String, PPEProduct__c> productsByName = new Map<String, PPEProduct__c>();
        if (!productNames.isEmpty()) {
            for (PPEProduct__c p : [
                SELECT Id, Name, ImageURL__c, Category__c
                FROM PPEProduct__c
                WHERE Name IN :productNames
                WITH SECURITY_ENFORCED
            ]) {
                productsByName.put(p.Name, p);
            }
        }

        // Step 3: Build Case records in a list, tracking which index maps to which request
        List<Case> casesToInsert = new List<Case>();
        // Parallel list to track the index in results and the resolved size per case
        List<Integer> caseToResultIndex = new List<Integer>();
        List<String> caseSizeValues = new List<String>();

        for (OrderRequest req : requests) {
            OrderResult result = new OrderResult();
            results.add(result);
            Integer resultIndex = results.size() - 1;

            if (String.isBlank(req.productName) || !productsByName.containsKey(req.productName)) {
                result.confirmationMessage = 'Product not found: ' + req.productName;
                continue;
            }

            PPEProduct__c product = productsByName.get(req.productName);

            String sizeValue = String.isNotBlank(req.size) ? req.size.trim() : 'N/A';
            Boolean isFootwear = product.Category__c == 'Footwear' || product.Name.containsIgnoreCase('Boot');

            if (isFootwear) {
                String numericPart = sizeValue.replaceAll('[^0-9]', '');
                if (String.isNotBlank(numericPart)) {
                    sizeValue = 'EU ' + numericPart;
                }

                if (!VALID_BOOT_SIZES.contains(sizeValue)) {
                    result.confirmationMessage = 'Invalid size for ' + product.Name + '. Available sizes: EU 39-46';
                    continue;
                }
            } else if (sizeValue != 'N/A') {
                sizeValue = sizeValue.toUpperCase();
                if (!VALID_STANDARD_SIZES.contains(sizeValue)) {
                    result.confirmationMessage = 'Invalid size for ' + product.Name + '. Available sizes: S, M, L, XL, XXL';
                    continue;
                }
            }

            String description = 'Product: ' + product.Name + '\n' +
                'Quantity: ' + req.quantity.intValue() + '\n' +
                'Size: ' + sizeValue;

            Case orderCase = new Case(
                Subject = 'Product Order: ' + req.quantity.intValue() + 'x ' + product.Name,
                Type = 'Product Order',
                Status = 'New',
                Origin = 'Chat',
                Description = description,
                SuppliedName = req.customerName,
                PPE_Product__c = product.Name,
                PPE_Quantity__c = req.quantity,
                PPE_Size__c = sizeValue,
                PPE_Product_Image__c = product.ImageURL__c
            );

            casesToInsert.add(orderCase);
            caseToResultIndex.add(resultIndex);
            caseSizeValues.add(sizeValue);
        }

        // Step 4: ONE bulk insert
        if (!casesToInsert.isEmpty()) {
            if (!Schema.sObjectType.Case.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Case records.');
            }
            insert casesToInsert;

            // Step 5: ONE bulk query to get CaseNumbers
            Set<Id> caseIds = new Set<Id>();
            for (Case c : casesToInsert) {
                caseIds.add(c.Id);
            }
            Map<Id, Case> casesWithNumbers = new Map<Id, Case>([
                SELECT Id, CaseNumber
                FROM Case
                WHERE Id IN :caseIds
                WITH SECURITY_ENFORCED
            ]);

            // Step 6: Populate results
            for (Integer i = 0; i < casesToInsert.size(); i++) {
                Case insertedCase = casesToInsert[i];
                Integer resultIndex = caseToResultIndex[i];
                OrderResult result = results[resultIndex];
                OrderRequest req = requests[resultIndex];
                String sizeValue = caseSizeValues[i];
                PPEProduct__c product = productsByName.get(req.productName);

                Case caseWithNumber = casesWithNumbers.get(insertedCase.Id);
                result.caseId = insertedCase.Id;
                result.caseNumber = caseWithNumber.CaseNumber;
                result.confirmationMessage = 'Order confirmed for ' + req.customerName + '! ' +
                    req.quantity.intValue() + 'x ' + product.Name +
                    (sizeValue != 'N/A' ? ' (Size: ' + sizeValue + ')' : '') +
                    '. Your case number is ' + caseWithNumber.CaseNumber + '.';
            }
        }

        return results;
    }
}
