public without sharing class CreatePPEArticlesFromJSON {

    // ===== INPUT FROM AGENT ACTION =====
    public class InputWrapper {
        @InvocableVariable(required = true description='JSON array of items with article, size, and quantity')
        public String itemJSON;

        @InvocableVariable(required = true description='Customer email address to find contact')
        public String customerEmail;

        @InvocableVariable(required = false description='Description/comments for the case')
        public String caseDescription;
    }

    // ===== OUTPUT FOR CAROUSEL + CASE =====
    public class OutputWrapper {
        @InvocableVariable(description='Carousel data for V2 Messaging display')
        public AsaCarouselData carouselData;

        @InvocableVariable(description='The created Case record')
        public Case caseRecord;

        @InvocableVariable(description='List of created article records')
        public List<Articles__c> ArticleOutputList;
    }

    // ===== NORMALIZATION MAPS =====
    private static Map<String, String> getArticleNormalization() {
        return new Map<String, String>{
            // Boots variations (English)
            'boots' => 'Bottes de sécurité plastique',
            'boot' => 'Bottes de sécurité plastique',
            'safety boots' => 'Bottes de sécurité plastique',
            'work boots' => 'Bottes de sécurité plastique',
            'plastic boots' => 'Bottes de sécurité plastique',
            'safety boot' => 'Bottes de sécurité plastique',
            
            // Boots variations (French)
            'bottes' => 'Bottes de sécurité plastique',
            'botte' => 'Bottes de sécurité plastique',
            'bottes de sécurité' => 'Bottes de sécurité plastique',
            'bottes de securite' => 'Bottes de sécurité plastique',
            'bottes de sécurité plastique' => 'Bottes de sécurité plastique',
            'bottes de securite plastique' => 'Bottes de sécurité plastique',
            'bottes plastique' => 'Bottes de sécurité plastique',
            
            // Blouse variations (English)
            'blouse' => 'Blouse de travail',
            'blouses' => 'Blouse de travail',
            'work blouse' => 'Blouse de travail',
            'work blouses' => 'Blouse de travail',
            'lab coat' => 'Blouse de travail',
            'lab coats' => 'Blouse de travail',
            'coat' => 'Blouse de travail',
            'work coat' => 'Blouse de travail',
            
            // Blouse variations (French)
            'blouse de travail' => 'Blouse de travail',
            'blouses de travail' => 'Blouse de travail',
            
            // Veste variations (map to blouse)
            'veste' => 'Blouse de travail',
            'veste de travail' => 'Blouse de travail',
            'jacket' => 'Blouse de travail',
            'work jacket' => 'Blouse de travail'
        };
    }

    private static Map<String, String> getSizeNormalization() {
        return new Map<String, String>{
            // Extra small
            'xs' => 'XS',
            'extra small' => 'XS',
            'très petit' => 'XS',
            'tres petit' => 'XS',
            
            // Small
            's' => 'S',
            'small' => 'S',
            'petit' => 'S',
            'petite' => 'S',
            'p' => 'S',
            
            // Medium
            'm' => 'M',
            'medium' => 'M',
            'moyen' => 'M',
            'moyenne' => 'M',
            'med' => 'M',
            
            // Large
            'l' => 'L',
            'large' => 'L',
            'grand' => 'L',
            'grande' => 'L',
            'g' => 'L',
            
            // Extra large
            'xl' => 'XL',
            'extra large' => 'XL',
            'très grand' => 'XL',
            'tres grand' => 'XL',
            'tg' => 'XL',
            
            // One size / Taille unique
            'tu' => 'TU',
            'taille unique' => 'TU',
            'one size' => 'TU',
            'os' => 'TU',
            'unique' => 'TU',
            
            // Shoe sizes
            '37' => '37',
            '38' => '38',
            '39' => '39',
            '40' => '40',
            '41' => '41',
            '42' => '42',
            '43' => '43',
            '44' => '44',
            '45' => '45',
            'pointure 37' => '37',
            'pointure 38' => '38',
            'pointure 39' => '39',
            'pointure 40' => '40',
            'pointure 41' => '41',
            'pointure 42' => '42',
            'pointure 43' => '43',
            'pointure 44' => '44',
            'pointure 45' => '45',
            'size 37' => '37',
            'size 38' => '38',
            'size 39' => '39',
            'size 40' => '40',
            'size 41' => '41',
            'size 42' => '42',
            'size 43' => '43',
            'size 44' => '44',
            'size 45' => '45'
        };
    }

    // ===== MAIN INVOCABLE ENTRYPOINT =====
    @InvocableMethod(label='Create Product Articles from JSON' description='Creates a Case and Article records from a JSON payload, returns carousel data for display')
    public static List<OutputWrapper> createArticles(List<InputWrapper> inputs) {

        List<OutputWrapper> results = new List<OutputWrapper>();
        
        if (inputs == null || inputs.isEmpty()) {
            OutputWrapper emptyResult = new OutputWrapper();
            emptyResult.ArticleOutputList = new List<Articles__c>();
            results.add(emptyResult);
            return results;
        }

        // Process first input (Agentforce typically sends one at a time)
        InputWrapper input = inputs[0];
        OutputWrapper result = new OutputWrapper();
        result.ArticleOutputList = new List<Articles__c>();

        if (input == null || String.isBlank(input.itemJSON) || String.isBlank(input.customerEmail)) {
            results.add(result);
            return results;
        }

        Map<String, String> articleNormalization = getArticleNormalization();
        Map<String, String> sizeNormalization = getSizeNormalization();

        // ===== STEP 1: Get Contact/Account by Email =====
        Account customerAccount = null;
        List<Account> accounts = [
            SELECT Id, PersonContactId, PersonEmail, Name
            FROM Account
            WHERE PersonEmail = :input.customerEmail
            LIMIT 1
        ];
        
        if (!accounts.isEmpty()) {
            customerAccount = accounts[0];
        }

        // If no account found, still proceed but log it
        Id contactId = customerAccount != null ? customerAccount.PersonContactId : null;
        Id accountId = customerAccount != null ? customerAccount.Id : null;

        // ===== STEP 2: Get Queue =====
        Id queueId = null;
        List<Group> queues = [
            SELECT Id 
            FROM Group 
            WHERE Name = 'General' AND Type = 'Queue'
            LIMIT 1
        ];
        
        if (!queues.isEmpty()) {
            queueId = queues[0].Id;
        }

        // ===== STEP 3: Create Case =====
        Case newCase = new Case();
        newCase.Status = 'New';
        newCase.Priority = 'High';
        newCase.Subject = 'Product Order Request';
        newCase.Commentaires__c = input.caseDescription;
        
        if (accountId != null) {
            newCase.AccountId = accountId;
        }
        if (contactId != null) {
            newCase.ContactId = contactId;
        }
        if (queueId != null) {
            newCase.OwnerId = queueId;
        }
        
        insert newCase;
        result.caseRecord = newCase;

        // ===== STEP 4: Parse JSON and collect article names =====
        List<Map<String, Object>> parsedItems = new List<Map<String, Object>>();
        Set<String> normalizedArticleNames = new Set<String>();

        Object parsed = JSON.deserializeUntyped(input.itemJSON);
        if (parsed instanceof List<Object>) {
            for (Object rowObj : (List<Object>)parsed) {
                if (rowObj == null) continue;
                Map<String, Object> item = (Map<String, Object>)rowObj;
                parsedItems.add(item);

                String rawName = extractArticleName(item);
                if (!String.isBlank(rawName)) {
                    String normalized = normalizeArticleName(rawName, articleNormalization);
                    normalizedArticleNames.add(normalized);
                }
            }
        }

        // ===== STEP 5: Query Article__c records =====
        Map<String, Article__c> articleByName = new Map<String, Article__c>();
        if (!normalizedArticleNames.isEmpty()) {
            for (Article__c art : [
                SELECT Id, Nom_de_l_article__c, Image_Type__c, URL_Image__c
                FROM Article__c
                WHERE Nom_de_l_article__c IN :normalizedArticleNames
            ]) {
                articleByName.put(art.Nom_de_l_article__c, art);
            }
        }

        // ===== STEP 6: Create Articles__c (Article demandé) records =====
        List<Articles__c> toInsert = new List<Articles__c>();

        for (Map<String, Object> item : parsedItems) {
            if (item == null) continue;

            String rawArticle = extractArticleName(item);
            Article__c matchedArticle = null;
            
            if (!String.isBlank(rawArticle)) {
                String normalizedArticle = normalizeArticleName(rawArticle, articleNormalization);
                if (articleByName.containsKey(normalizedArticle)) {
                    matchedArticle = articleByName.get(normalizedArticle);
                }
            }

            // Skip if we can't resolve the article
            if (matchedArticle == null) {
                continue;
            }

            String sizeStr = extractSize(item);
            if (!String.isBlank(sizeStr)) {
                sizeStr = normalizeSize(sizeStr, sizeNormalization);
            }

            Integer qtyVal = extractQuantity(item);

            Articles__c rec = new Articles__c();
            rec.Demande__c = newCase.Id;
            rec.Article_Nom1__c = matchedArticle.Id;
            rec.Taille__c = sizeStr;
            rec.quantite__c = qtyVal;

            toInsert.add(rec);
        }

        Set<Id> insertedIds = new Set<Id>();
        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (Articles__c rec : toInsert) {
                insertedIds.add(rec.Id);
            }
        }

        // ===== STEP 7: Build AsaCarouselData for V2 Messaging =====
        if (!insertedIds.isEmpty()) {
            List<Articles__c> createdArticles = [
                SELECT Id, 
                       Article_Nom1__r.Nom_de_l_article__c,
                       Article_Nom1__r.Image_Type__c,
                       Article_Nom1__r.URL_Image__c,
                       Taille__c,
                       quantite__c
                FROM Articles__c
                WHERE Id IN :insertedIds
            ];
            
            result.ArticleOutputList = createdArticles;
            
            // Build products array for carousel JSON
            List<Map<String, String>> products = new List<Map<String, String>>();
            
            for (Articles__c art : createdArticles) {
                Map<String, String> product = new Map<String, String>();
                product.put('title', art.Article_Nom1__r.Nom_de_l_article__c);
                product.put('imageUrl', art.Article_Nom1__r.URL_Image__c != null ? art.Article_Nom1__r.URL_Image__c : '');
                product.put('description', 'Taille: ' + (art.Taille__c != null ? art.Taille__c : 'N/A') + ', Quantité: ' + (art.quantite__c != null ? String.valueOf(art.quantite__c.intValue()) : '1'));
                products.add(product);
            }
            
            // Wrap in expected format and serialize
            Map<String, Object> carouselJSON = new Map<String, Object>();
            carouselJSON.put('products', products);
            
            result.carouselData = new AsaCarouselData(JSON.serialize(carouselJSON));
        }

        results.add(result);
        return results;
    }

    // ===== HELPER METHODS =====

    private static String extractArticleName(Map<String, Object> item) {
        if (item.containsKey('article') && item.get('article') != null) {
            return String.valueOf(item.get('article')).trim();
        } else if (item.containsKey('name') && item.get('name') != null) {
            return String.valueOf(item.get('name')).trim();
        } else if (item.containsKey('nom') && item.get('nom') != null) {
            return String.valueOf(item.get('nom')).trim();
        }
        return null;
    }

    private static String normalizeArticleName(String rawName, Map<String, String> normalizationMap) {
        if (String.isBlank(rawName)) return rawName;
        
        String lowerName = rawName.toLowerCase().trim();
        
        if (normalizationMap.containsKey(lowerName)) {
            return normalizationMap.get(lowerName);
        }
        
        for (String key : normalizationMap.keySet()) {
            if (lowerName.contains(key) || key.contains(lowerName)) {
                return normalizationMap.get(key);
            }
        }
        
        return rawName;
    }

    private static String extractSize(Map<String, Object> item) {
        if (item.containsKey('size') && item.get('size') != null) {
            return String.valueOf(item.get('size'));
        } else if (item.containsKey('taille') && item.get('taille') != null) {
            return String.valueOf(item.get('taille'));
        }
        return null;
    }

    private static String normalizeSize(String rawSize, Map<String, String> normalizationMap) {
        if (String.isBlank(rawSize)) return rawSize;
        
        String lowerSize = rawSize.toLowerCase().trim();
        
        if (normalizationMap.containsKey(lowerSize)) {
            return normalizationMap.get(lowerSize);
        }
        
        return rawSize.toUpperCase();
    }

    private static Integer extractQuantity(Map<String, Object> item) {
        Object qtyRaw = null;

        if (item.containsKey('quantity')) {
            qtyRaw = item.get('quantity');
        } else if (item.containsKey('quantité')) {
            qtyRaw = item.get('quantité');
        } else if (item.containsKey('quantite')) {
            qtyRaw = item.get('quantite');
        } else if (item.containsKey('qty')) {
            qtyRaw = item.get('qty');
        }

        if (qtyRaw == null) {
            return 1; // Default to 1 if not specified
        }

        try {
            if (qtyRaw instanceof Integer) {
                return (Integer)qtyRaw;
            } else if (qtyRaw instanceof Long) {
                return ((Long)qtyRaw).intValue();
            } else if (qtyRaw instanceof Decimal) {
                return ((Decimal)qtyRaw).intValue();
            } else if (qtyRaw instanceof Double) {
                return ((Double)qtyRaw).intValue();
            } else {
                return Integer.valueOf(String.valueOf(qtyRaw));
            }
        } catch (Exception e) {
            return 1;
        }
    }
}