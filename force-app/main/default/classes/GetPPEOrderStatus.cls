public with sharing class GetPPEOrderStatus {
    
    public class StatusRequest {
        @InvocableVariable(label='Case Number')
        public String caseNumber;
        
        @InvocableVariable(label='Customer Name')
        public String customerName;
    }
    
    public class StatusResult {
        @InvocableVariable
        public String orderStatusMessage;
    }
    
    @InvocableMethod(label='Get Product Order Status' description='Looks up product order status by case number or customer name')
    public static List<StatusResult> getStatus(List<StatusRequest> requests) {
        List<StatusResult> results = new List<StatusResult>();
        
        for (StatusRequest req : requests) {
            StatusResult result = new StatusResult();
            
            try {
                List<Case> cases;
                
                if (String.isNotBlank(req.caseNumber)) {
                    cases = [SELECT CaseNumber, Subject, Status, SuppliedName, CreatedDate
                             FROM Case
                             WHERE CaseNumber = :req.caseNumber
                             AND Type = 'Product Order'
                             WITH SECURITY_ENFORCED
                             LIMIT 1];
                    
                    if (cases.isEmpty()) {
                        result.orderStatusMessage = 'No product order found with case number ' + req.caseNumber + '.';
                    } else {
                        Case c = cases[0];
                        result.orderStatusMessage = 'Order ' + c.CaseNumber + ' for ' + c.SuppliedName + ': ' + c.Subject + ' - Status: ' + c.Status;
                    }
                } else if (String.isNotBlank(req.customerName)) {
                    cases = [SELECT CaseNumber, Subject, Status, SuppliedName, CreatedDate
                             FROM Case
                             WHERE SuppliedName = :req.customerName
                             AND Type = 'Product Order'
                             WITH SECURITY_ENFORCED
                             ORDER BY CreatedDate DESC
                             LIMIT 5];
                    
                    if (cases.isEmpty()) {
                        result.orderStatusMessage = 'No product orders found for ' + req.customerName + '.';
                    } else if (cases.size() == 1) {
                        Case c = cases[0];
                        result.orderStatusMessage = 'Order ' + c.CaseNumber + ' for ' + c.SuppliedName + ': ' + c.Subject + ' - Status: ' + c.Status;
                    } else {
                        String msg = 'Found ' + cases.size() + ' orders for ' + req.customerName + ':\n';
                        for (Case c : cases) {
                            msg += '• ' + c.CaseNumber + ': ' + c.Subject + ' - ' + c.Status + '\n';
                        }
                        result.orderStatusMessage = msg;
                    }
                } else {
                    result.orderStatusMessage = 'Please provide a case number or customer name.';
                }
                
            } catch (Exception e) {
                result.orderStatusMessage = 'Error looking up order: ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
}
