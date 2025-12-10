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
        
        List<Case> cases = [SELECT Id, CaseNumber, Status, CreatedDate FROM Case WHERE Id = :caseId LIMIT 1];
        if (!cases.isEmpty()) {
            Case c = cases[0];
            caseNumber = c.CaseNumber;
            orderStatus = c.Status;
            orderDate = c.CreatedDate.format('dd/MM/yyyy HH:mm');
        }
        
        List<Articles__c> articles = [
            SELECT Id, Article_Nom1__r.Nom_de_l_article__c, Article_Nom1__r.URL_Image__c, Taille__c, quantite__c
            FROM Articles__c WHERE Demande__c = :caseId
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
        public String name { get; set; }
        public String imageUrl { get; set; }
        public String size { get; set; }
        public String quantity { get; set; }
    }
}
