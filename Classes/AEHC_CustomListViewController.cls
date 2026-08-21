public with sharing class AEHC_CustomListViewController {

    @TestVisible private static  Boolean forceException = false;

    // Method for My Publications 
    @AuraEnabled(cacheable = true)
    public static List<AEHC_Asset__c> getMyPublications(){
        try {

            if(Test.isRunningTest() && forceException){
                throw new IllegalArgumentException('Forced Test Exception');
            }

            return [
                SELECT Id, Name, AEHC_Publication_Type__c, AEHC_Publication_Id__c, CreatedDate, AEHC_Environment__c, AEHC_Application__r.Name, CreatedBy.Name
                FROM AEHC_Asset__c
                WHERE RecordType.DeveloperName = 'AEHC_Publication'
                AND AEHC_Application__c 
                IN ( 
                    SELECT AEHC_Asset__c FROM AEHC_AssetMember__c 
                    WHERE AEHC_User__c = :UserInfo.getUserId() 
                    AND AEHC_Role__c IN ('Developer','Business Owner')
                    )
                ORDER BY CreatedDate DESC    
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Method for My Subscriptions 
    @AuraEnabled(cacheable = true)
    public static List<Subscription__c> getMySubscriptions(String viewName){
        try {

            if(Test.isRunningTest() && forceException){
                throw new IllegalArgumentException('Forced Test Exception');
            }

            String query = 'SELECT Id, Name, AEHC_Publication_ID__c, AEHC_Publication_ID__r.Id, AEHC_Publication_ID__r.Name, '+
            'AEHC_Publicaiton_Name_Formula__c, Community_Asset__r.Id, Community_Asset__r.Name, AEHC_AssetType__c, AEHC_Application_Name__r.Name, '+
            'AEHC_Consumming_Application__r.Name, AEHC_Environment__c, AEHC_Environment_Name__c, Status__c, LastModifiedDate, CreatedBy.Name, '+
            'RecordType.DeveloperName FROM Subscription__c '+
            'WHERE RecordType.DeveloperName IN (\'Data_Publication\',\'API_Asset\') ';
            String userId = UserInfo.getUserId();


            if (viewName == 'My Subscriptions'){
                query += ' AND CreatedById = :userId';
            }else if (viewName == 'My Applications Subscriptions'){
                query += ' AND AEHC_Consumming_Application__c IN ('+
                'SELECT AEHC_Asset__c FROM AEHC_AssetMember__c WHERE AEHC_User__c = :userId  '+
                'AND AEHC_Role__c = \'Business Owner\') ';
            }

            query += ' ORDER BY AEHC_Consumming_Application__r.Name ASC NULLS LAST';
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}