/**
 * @author Asif Ahmad
 * @date 14Apr2026
 * @description to provide reusable methods for all over the app
 * @app AEHC
*/
public class AEHC_Utility {
    
    /**
     * @author Asif Ahmad
     * @date 21Apr2026
     * @description to return the value from the given map, added fallback value if no key in the map
     * @return String value
	*/
    public static String getStringFromMap(Map<String, Object> data, String key, String fallback) {
        Object val = data.get(key);
        return val != null ? String.valueOf(val) : fallback;
    }
    
    /**
     * @author Asif Ahmad
     * @date 23Ma2026
     * @description to return the value from the given map, added fallback value if no key in the map
     * @return Object value
	*/
    public static Object getValueAsObjectFromMap(Map<String, Object> data, String key, Object fallback) {
        Object val = data.get(key);
        return val != null ? val : fallback;
    }
    
    /**
     * @author Asif Ahmad
     * @date 28Apr2026
     * @description to return the value from the global config from custom setting
     * @return AEHC_Global_Config__c custoim setting values
	*/	
	private static AEHC_Global_Config__c cfg;
    public static AEHC_Global_Config__c getConfig() {
        
        if (cfg == null) {
            cfg = AEHC_Global_Config__c.getOrgDefaults();
            if (cfg == null) cfg = new AEHC_Global_Config__c();
        }
        return cfg;
    }
    
    /**
     * @author Asif Ahmad
     * @date 21May2026
     * @description to get the current org environment 
     * @returns String
	*/
    
    private static String ORG_ENV;
    public static String getCurrentEnvironment() {
        if(ORG_ENV == null) ORG_ENV = getCurrentEnvironmentPrivate();
        return ORG_ENV;
    }
    
    static String getCurrentEnvironmentPrivate() {
        String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();
        
        if (domain.contains('sandbox') || domain.contains('--') || domain.contains('cs')) {
            // Try to distinguish by naming conventions if present
            if (domain.contains('dev') || domain.contains('--dev')) return 'Dev';
            if (domain.contains('qa')  || domain.contains('--qa'))  return 'QA';
            if (domain.contains('uat') || domain.contains('--uat')) return 'UAT';
            return 'Sandbox';
        }
        return 'Prod';
    }
    
    public static AEHC_AssetMember__c addUserInAsset(Id assetId, String userId, String role, Boolean isInsert) {
        AEHC_AssetMember__c assetMember = new AEHC_AssetMember__c();
        
        if(!String.isEmpty(assetId)) {
            if (assetId.getSObjectType() == AEHC_Asset__c.sObjectType) assetMember.AEHC_Asset__c = assetId;
            else if (assetId.getSObjectType() == ms_aeh__CommunityAsset__c.sObjectType) assetMember.AEHC_CommunityAsset__c = assetId;
        }
        assetMember.AEHC_User__c = userId;
        assetMember.AEHC_Role__c = role;
        
        if(isInsert) upsertRecs(new List<AEHC_AssetMember__c>{assetMember});
        
        return assetMember;
    }
    
    public static void upsertRecs(List<SObject> recs) {
        if (recs == null || recs.isEmpty()) return;
        
        List<Database.UpsertResult> insertResults = Database.upsert(recs, false);
        
        List<String> logMessages = new List<String>();
        
        for (Integer i = 0; i < insertResults.size(); i++) {
            Database.UpsertResult sr = insertResults[i];
            
            if (!sr.isSuccess()) {
                List<String> errorArr = new List<String>();
                
                for (Database.Error err : sr.getErrors()) errorArr.add( err.getMessage());
                
                String insertMsg = String.join(errorArr, ';');
                
                // Optional: log individually if logger supports bulk safely
                AEHC_Logger.logError(insertMsg,'Apex','AEHC_Utility.createRecs','Create',null,'P3','DML',new Map<String, Object>{'recordIndex' => i,'rec' => recs[i]},AEHC_Utility.getCurrentEnvironment());
            }
       }
    }
    
    static Map<String, AEHC_APIConfig__mdt> configs;
    public static AEHC_APIConfig__mdt getAPIConfig(String apiName) {
        if(configs == null) configs = new Map<String, AEHC_APIConfig__mdt>();
        
        if(configs.containsKey(apiName)) return configs.get(apiName);
        
        AEHC_APIConfig__mdt apiConfig = AEHC_APIConfig__mdt.getInstance(apiName);
        if(apiConfig != null && apiConfig.AEHC_Active__c) {
            configs.put(apiName, apiConfig);
         	return apiConfig;
        }
        
        return null;
    }
    
    public static List<Map<String, String>> getPicklistValues(String sObjectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {

            List<Schema.PicklistEntry> picklistValues = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap().get(fieldName).getDescribe().getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    Map<String, String> option = new Map<String, String>();
                    option.put('label', entry.getLabel());
                    option.put('value', entry.getValue());
                    options.add(option);
                }
            }

        } catch(Exception e) {
            AEHC_Logger.logException(e, 'Apex', 'AEHC_Utility.getPicklistValues', 'query', null, 'P1', null, null, AEHC_Utility.getCurrentEnvironment());
        }
        return options;
    }
    
    public static String getRecordTypeId(String sObjectName, String recTypeName) {
        return Schema.getGlobalDescribe().get(sObjectName).getDescribe().getRecordTypeInfosByDeveloperName().get(recTypeName).getRecordTypeId();
    }
    
    
    public static Boolean isValidRecordId(String val) {
        try {
            Id recordId = (Id)val;
            return true;
        } catch (Exception e) {return false;}
    }
    
    public class LookupField {
        @AuraEnabled public String id;
        @AuraEnabled public String mainField;
        @AuraEnabled public String subField;
        @AuraEnabled public Boolean isSFRecord;
        
        public LookupField() {
            this.isSFRecord = false;
            this.mainField = '';
        }
        
        public LookupField(String id, String mainField, String subField) {
            this.id = id;
            this.mainField = mainField;
            this.subField = subField;
            this.isSFRecord = isValidRecordId(id);
        }
        
        public LookupField(String id, String mainField, String subField, Boolean isSFRecord) {
            this(id, mainField, subField);
            this.isSFRecord = isSFRecord;
        }
    }

}