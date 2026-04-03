public with sharing class PPEOrderConfirmationController {
    
    public String caseNumber { get; set; }
    public String orderStatus { get; set; }
    public String orderDate { get; set; }
    public List<ItemWrapper> items { get; set; }
    
    public PPEOrderConfirmationController() {
        items = new List<ItemWrapper>();
    }
    
    public PageReference loadOrder() {
        String caseId = ApexPages.currentPage().getParameters().get('caseId');
        if (caseId == null) {
            caseId = ApexPages.currentPage().getParameters().get('id');
        }
        
        if (String.isBlank(caseId)) {
            return null;
        }
        
        List<Case> cases = [SELECT Id, CaseNumber, Status, CreatedDate FROM Case WHERE Id = :caseId WITH SECURITY_ENFORCED LIMIT 1];
        if (!cases.isEmpty()) {
            Case c = cases[0];
            caseNumber = c.CaseNumber;
            orderStatus = c.Status;
            orderDate = c.CreatedDate.format('dd/MM/yyyy HH:mm');
        }
        
        List<Articles__c> articles = [
            SELECT Id, Article_Nom1__r.Nom_de_l_article__c, Article_Nom1__r.URL_Image__c, Taille__c, quantite__c
            FROM Articles__c
            WHERE Demande__c = :caseId
            WITH SECURITY_ENFORCED
        ];
        
        for (Articles__c art : articles) {
            ItemWrapper item = new ItemWrapper();
            item.name = art.Article_Nom1__r.Nom_de_l_article__c;
            item.imageUrl = art.Article_Nom1__r.URL_Image__c;
            item.size = art.Taille__c != null ? art.Taille__c : 'N/A';
            item.quantity = art.quantite__c != null ? String.valueOf(art.quantite__c.intValue()) : '1';
            items.add(item);
        }
        
        return null;
    }
    
    public class ItemWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
        @AuraEnabled public String size { get; set; }
        @AuraEnabled public String quantity { get; set; }
    }

    public class OrderDetailsWrapper {
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String contactName { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public List<ItemWrapper> items { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static OrderDetailsWrapper getOrderDetails(String caseId) {
        if (String.isBlank(caseId)) {
            throw new AuraHandledException('Case ID is required.');
        }

        OrderDetailsWrapper result = new OrderDetailsWrapper();
        result.items = new List<ItemWrapper>();

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, CreatedDate, Contact.Name
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('No case found with the provided ID.');
        }

        Case c = cases[0];
        result.caseNumber = c.CaseNumber;
        result.status = c.Status;
        result.createdDate = c.CreatedDate;
        result.contactName = c.Contact != null ? c.Contact.Name : null;

        List<Articles__c> articles = [
            SELECT Id, Article_Nom1__r.Nom_de_l_article__c, Article_Nom1__r.URL_Image__c,
                   Taille__c, quantite__c
            FROM Articles__c
            WHERE Demande__c = :caseId
            WITH SECURITY_ENFORCED
        ];

        for (Articles__c art : articles) {
            ItemWrapper item = new ItemWrapper();
            item.id = art.Id;
            item.name = art.Article_Nom1__r.Nom_de_l_article__c;
            item.imageUrl = art.Article_Nom1__r.URL_Image__c;
            item.size = art.Taille__c != null ? art.Taille__c : 'N/A';
            item.quantity = art.quantite__c != null ? String.valueOf(art.quantite__c.intValue()) : '1';
            result.items.add(item);
        }

        return result;
    }
}
