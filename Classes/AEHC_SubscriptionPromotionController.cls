public with sharing class AEHC_SubscriptionPromotionController {

    public class PromotionDTO {
        @AuraEnabled public Subscription__c subscription;
        @AuraEnabled public Map<String, List<String>> picklists;
        @AuraEnabled public String targetEnvironment;
        @AuraEnabled public Boolean showDatabase;
    }

    @AuraEnabled(cacheable=true)
    public static PromotionDTO loadPromotionData(Id subscriptionId) {

        PromotionDTO dto = new PromotionDTO();

        dto.subscription = [
            SELECT
                Id,
                Name,
                AEHC_Environment__c,
                Status__c,
                AEHC_Destination_Type__c,
                AEHC_Database_Type__c,
                AEHC_JDBC_Url__c,
                AEHC_On_Initalization__c,
                AEHC_On_Load__c,
                AEHC_On_Success__c,
                AEHC_On_Error__c,
                AEHC_Mute_Error_Flag__c,
                AEHC_Batch_Flag__c,
                Duration__c,
                AEHC_Other_Properties__c,
                AEHC_Information_Architect_Approval__c,
                AEHC_Security_Architect_Approved__c
            FROM Subscription__c
            WHERE Id = :subscriptionId
            LIMIT 1
        ];

        dto.targetEnvironment = deriveTargetEnvironment(dto.subscription.AEHC_Environment__c);
        dto.picklists = loadPicklists();
        dto.showDatabase = dto.subscription.AEHC_Destination_Type__c == 'Database';

        return dto;
    }

    @AuraEnabled
    public static void submitPromotion(Subscription__c updatedSubscription) {

        Subscription__c current = [
            SELECT Status__c
            FROM Subscription__c
            WHERE Id = :updatedSubscription.Id
        ];

        if (current.Status__c != 'Approved') {
            throw new AuraHandledException(
                'Subscription is not eligible for promotion.'
            );
        }

        update updatedSubscription;
    }

    private static String deriveTargetEnvironment(String env) {
        if (env == 'Dev') return 'QA';
        if (env == 'QA') return 'UAT';
        if (env == 'UAT') return 'PROD';
        return null;
    }

    private static Map<String, List<String>> loadPicklists() {

        Map<String, List<String>> result = new Map<String, List<String>>();
        Schema.DescribeSObjectResult d = Subscription__c.SObjectType.getDescribe();

        result.put(
            'DestinationType',
            getPicklistValues(d.fields.getMap().get('AEHC_Destination_Type__c'))
        );

        result.put(
            'DatabaseType',
            getPicklistValues(d.fields.getMap().get('AEHC_Database_Type__c'))
        );

        return result;
    }

    private static List<String> getPicklistValues(Schema.SObjectField field) {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry p : field.getDescribe().getPicklistValues()) {
            values.add(p.getValue());
        }
        return values;
    }
}