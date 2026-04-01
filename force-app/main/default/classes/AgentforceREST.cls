@RestResource(urlMapping='/agentforce/*')
global class AgentforceREST {
    
    private static final Map<String, String> PRODUCT_KEYWORDS = new Map<String, String>{
        'glove' => 'Work Gloves',
        'helmet' => 'Safety Helmet',
        'boot' => 'Safety Boots',
        'glass' => 'Safety Glasses',
        'blouse' => 'Work Blouse'
    };
    
    @HttpPost
    global static String handleRequest() {
        RestRequest req = RestContext.request;
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        String action = (String) body.get('action');
        
        if (action == 'createSession') {
            return createSession();
        } else if (action == 'sendMessage') {
            String sessionId = (String) body.get('sessionId');
            String message = (String) body.get('message');
            String activeProduct = (String) body.get('activeProduct');
            return sendMessage(sessionId, message, activeProduct);
        }
        
        return JSON.serialize(new Map<String, String>{'error' => 'Unknown action'});
    }
    
    private static String createSession() {
        String sessionId = 'sess_' + String.valueOf(Crypto.getRandomInteger());
        return JSON.serialize(new Map<String, String>{'sessionId' => sessionId});
    }
    
    private static String sendMessage(String sessionId, String message, String activeProduct) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Prepend active product context if set and not already in message
            String enhancedMessage = message;
            if (String.isNotBlank(activeProduct) && !message.toLowerCase().contains(activeProduct.toLowerCase())) {
                enhancedMessage = '[Currently ordering: ' + activeProduct + '] ' + message;
            }
            
            Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', 'Product_Catalog_Assistant');
            action.setInvocationParameter('sessionId', sessionId);
            action.setInvocationParameter('userMessage', enhancedMessage);
            List<Invocable.Action.Result> results = action.invoke();
            
            if (results != null && !results.isEmpty() && results[0].isSuccess()) {
                String agentResponse = (String) results[0].getOutputParameters().get('agentResponse');
                
                Map<String, Object> responseObj = (Map<String, Object>) JSON.deserializeUntyped(agentResponse);
                String textValue = (String) responseObj.get('value');

                textValue = textValue.replaceAll('\\(https://[^\\)]+\\)', '');
                textValue = textValue.replaceAll('\\(/lightning/[^\\)]+\\)', '');
                textValue = textValue.replaceAll('"View Details"', '');
                textValue = textValue.replaceAll('"[^"]*"', '');
                textValue = textValue.replaceAll('\\s{2,}', ' ');
                textValue = textValue.trim();
                
                result.put('message', textValue);
                
                String lowerText = textValue.toLowerCase();
                String lowerMessage = message.toLowerCase();
                
                Boolean isConfirmation = lowerText.contains('confirmed') || 
                                        lowerText.contains('case number') || 
                                        lowerText.contains('order has been');
                
                Boolean isProvidingDetails = lowerMessage.contains('size') || 
                                             containsSize(lowerMessage) ||
                                             containsQuantity(lowerMessage);
                
                Boolean userRequestsCatalog = lowerMessage.contains('show me') || 
                                              lowerMessage.contains('catalog') ||
                                              lowerMessage.contains('what do you have') ||
                                              lowerMessage.contains('browse') ||
                                              lowerMessage.contains('see products');
                
                Boolean userSelectsProduct = (lowerMessage.contains('order') || 
                                              lowerMessage.contains('want') || 
                                              lowerMessage.contains('need') ||
                                              lowerMessage.contains('like to')) &&
                                             detectProduct(lowerMessage) != null;
                
                Boolean showProducts = !isConfirmation && 
                                       !isProvidingDetails && 
                                       (userRequestsCatalog || userSelectsProduct);
                
                if (showProducts) {
                    String filterProduct = activeProduct;
                    if (String.isBlank(filterProduct)) {
                        filterProduct = detectProduct(lowerMessage);
                    }
                    
                    if (String.isNotBlank(filterProduct)) {
                        result.put('filterProduct', filterProduct);
                    }
                    result.put('products', true);
                }
                
                String detectedProduct = detectProduct(lowerMessage);
                if (String.isNotBlank(detectedProduct)) {
                    result.put('detectedProduct', detectedProduct);
                }
                
            } else {
                result.put('error', 'Agent failed to respond');
            }
            
        } catch (Exception e) {
            result.put('error', e.getMessage());
        }
        
        return JSON.serialize(result);
    }
    
    private static String detectProduct(String text) {
        for (String keyword : PRODUCT_KEYWORDS.keySet()) {
            if (text.contains(keyword)) {
                return PRODUCT_KEYWORDS.get(keyword);
            }
        }
        return null;
    }
    
    private static Boolean containsSize(String text) {
        return text.contains(' xs') || text.contains(' s ') || text.contains(' m ') || 
               text.contains(' l ') || text.contains(' xl') || text.contains(' xxl') ||
               text.contains('size');
    }
    
    private static Boolean containsQuantity(String text) {
        return text.contains('unit') || text.contains('pair') || text.contains('piece') ||
               text.contains(' 1 ') || text.contains(' 2 ') || text.contains(' 3 ') ||
               text.contains(' 4 ') || text.contains(' 5 ') || text.contains(' 10 ');
    }
}
