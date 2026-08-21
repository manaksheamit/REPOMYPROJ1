public without sharing class AEHC_EnableDisableSubJob {
    private static final String LOAD_JOB = 'LoadJob';
    @AuraEnabled
    public static boolean enableDisableSubMonJob(String recordId, Boolean activeFlag){
        
        try {
            Map<String, Object> payload;
            payload = AEHC_PublicationSubscriptionMapper.subScriptionMapping(recordId,activeFlag);
            String finalPayload = JSON.serialize(payload);
            System.debug('Final Payload: ' + finalPayload);
            
            // ✅ Fetch environment from record
            AEHC_Asset__c assetRec = [
                SELECT AEHC_Environment__c
                FROM AEHC_Asset__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            string env = assetRec.AEHC_Environment__c;
            
            Map<String, JobHistoryEndpointConfig__mdt> configMap = JobHistoryEndpointConfig__mdt.getAll();
            
            JobHistoryEndpointConfig__mdt config;
            
            // ✅ Find matching config
            for (JobHistoryEndpointConfig__mdt cfg : configMap.values()) {
                if (cfg.Environment__c == env && cfg.JobType__c == LOAD_JOB) {
                    config = cfg;
                    break;
                }
            }
            
            // ✅ Safety check
            if (config == null) {
                throw new AuraHandledException('No endpoint config found for env: ' + env);
            }
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            
            req.setEndpoint(config.Endpoint_URL__c);
            req.setMethod('POST');
            
            // ✅ Headers
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            
            req.setBody(finalPayload);
            
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            
            // ✅ Process response
            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                
                Map<String, Object> resp =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (resp.containsKey('status') && String.valueOf(resp.get('status')) == 'SUCCESS') {
                    
                    List<AEHC_Asset__c> assetsToUpdate = [
                        SELECT Id, AEHC_IsJobEnable__c 
                        FROM AEHC_Asset__c
                        WHERE Id = :recordId
                        LIMIT 1
                    ];
                    
                    if (!assetsToUpdate.isEmpty()) {
                        AEHC_Asset__c asset = assetsToUpdate[0];
                        
                        // ✅ Update Job Enable field with activeFlag
                        asset.AEHC_IsJobEnable__c = activeFlag;
                        
                        // ✅ Perform DML update
                        update asset;
                    }
                    
                    // ✅ Return true on SUCCESS
                    return true;
                }
            }
            
            // ✅ Default return false if any condition fails
            return false;
        } catch (Exception e) {
            System.debug('Error in enableDisableSubMonJob: ' + e.getMessage());
            throw e;
        }
        
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getJobSubmonStatus(String recordId) {
        
        Map<String, Boolean> result = new Map<String, Boolean>{
            'isSubmon' => false,
                'isEnabled' => false
                };
                    
                    List<AEHC_Asset__c> assetList = [
                        SELECT AEHC_IsJobEnable__c, AEHC_VSchedule__c
                        FROM AEHC_Asset__c
                        WHERE Id = :recordId
                        LIMIT 1
                    ];
        
        if (!assetList.isEmpty()) {
            AEHC_Asset__c asset = assetList[0];
            
            result.put(
                'isSubmon',
                asset.AEHC_VSchedule__c == 'Submon (Triggered on Publication Completion)'
            );
            
            result.put(
                'isEnabled',
                asset.AEHC_IsJobEnable__c
            );
        }
        
        return result;
    }
    
    
    
    
}