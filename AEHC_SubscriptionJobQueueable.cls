/**
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
* Class Name      : SubscriptionJobQueueable
* Author          : Parvej Alam
* Created Date    : May 23, 2026
* Last Modified By: <YourName>
* Last Modified On: May 23, 2026
* Description     : This class implements for load data to DDH system
*  **
* Change History  :
*  Date          │   Author     │   Change
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*  May 23, 2026  │ <YourName>   │ Initial version
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*/

public without sharing class AEHC_SubscriptionJobQueueable implements Queueable, Database.AllowsCallouts {
    
    private static final String LOAD_JOB = 'LoadJob';
    
    private Set<Id> assetVerIds;
    
    public AEHC_SubscriptionJobQueueable(Set<Id> assetVerIds) {
        this.assetVerIds = assetVerIds;
    }
    
    public void execute(QueueableContext context) {
        
        Map<String, Object> payload;
        List<Id> recIds = new List<Id>();
        String env;
        String finalPayload = null;
        try {
            if (assetVerIds == null || assetVerIds.isEmpty()) {
                throw new AuraHandledException('No record Ids provided');
            }
            
            for (Id recId : assetVerIds) {
                payload = AEHC_PublicationSubscriptionMapper.subScriptionMapping(recId,true);
                recIds.add(recId);
                
                // ✅ Fetch environment from record
                AEHC_Asset__c assetRec = [
                    SELECT AEHC_Environment__c
                    FROM AEHC_Asset__c
                    WHERE Id = :recId
                    LIMIT 1
                ];
                
                env = assetRec.AEHC_Environment__c;
                break; 
            }
            // ✅ Serialize SINGLE object (NO list, NO wrapper)
            finalPayload = JSON.serialize(payload);
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
            // ✅ Process response
            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                Map<String, Object> resp =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (resp.containsKey('status') &&
                    String.valueOf(resp.get('status')) == 'SUCCESS') {
                        
                        String intId = resp.containsKey('IntId') ? String.valueOf(resp.get('IntId')): '';
                        
                        List<AEHC_Asset__c> assetsToUpdate = new List<AEHC_Asset__c>();
                        List<Id> recIdSet = recIds;
                        Set<String> envSet = new Set<String>();
                        
                        // ✅ Get current records
                        List<AEHC_Asset__c> inputAssets = [
                            SELECT Id, AEHC_IntId__c, Approval_Status__c,AEHC_IsJobEnable__c,
                            AEHC_Is_Active__c, AEHC_Subscription_Request__c, AEHC_Environment__c,
                            AEHC_Is_Subscription__c, AEHC_Publication__c
                            FROM AEHC_Asset__c
                            WHERE Id IN :recIdSet
                        ];
                        
                        // ✅ Collect environments
                        for (AEHC_Asset__c a : inputAssets) {
                            if (a.AEHC_Environment__c != null) {
                                envSet.add(a.AEHC_Environment__c);
                            }
                        }
                        
                        // ✅ Get all other records in same environments
                        List<AEHC_Asset__c> allOtherAssets = [
                            SELECT Id, AEHC_Is_Active__c, AEHC_Environment__c,
                            AEHC_Subscription_Request__c, AEHC_Is_Subscription__c,
                            AEHC_Publication__c
                            FROM AEHC_Asset__c
                            WHERE AEHC_Environment__c IN :envSet
                            AND Id NOT IN :recIdSet
                        ];
                        
                        // ✅ Map to avoid duplicates
                        Map<Id, AEHC_Asset__c> assetsToUpdateMap = new Map<Id, AEHC_Asset__c>();
                        
                        for (AEHC_Asset__c asset : inputAssets) {
                            
                            // ✅ Set current record as active
                            asset.AEHC_IntId__c = intId;
                            asset.AEHC_Is_Active__c = true;
                            asset.AEHC_IsJobEnable__c = true;
                            for (AEHC_Asset__c other : allOtherAssets) {
                                
                                // ✅ Environment match
                                if (other.AEHC_Environment__c != asset.AEHC_Environment__c) {
                                    continue;
                                }
                                
                                // ✅ Match Subscription vs Publication
                                if (other.AEHC_Is_Subscription__c != asset.AEHC_Is_Subscription__c) {
                                    continue;
                                }
                                
                                // ✅ Parent matching
                                Boolean isSameParent = false;
                                
                                if (asset.AEHC_Is_Subscription__c) {
                                    // Subscription case
                                    if (other.AEHC_Subscription_Request__c == asset.AEHC_Subscription_Request__c) {
                                        isSameParent = true;
                                    }
                                } else {
                                    // Publication case
                                    if (other.AEHC_Publication__c == asset.AEHC_Publication__c) {
                                        isSameParent = true;
                                    }
                                }
                                
                                // ✅ Deactivate old versions
                                if (isSameParent) {
                                    other.AEHC_Is_Active__c = false;
                                    assetsToUpdateMap.put(other.Id, other);
                                }
                            }
                            
                            // ✅ Update current record
                            asset.Approval_Status__c = 'Active';
                            assetsToUpdateMap.put(asset.Id, asset);
                        }
                        
                        // ✅ Final update
                        if (!assetsToUpdateMap.isEmpty()) {
                            update assetsToUpdateMap.values();
                        }
                        
                        
                    }
            }
            else {
                String errorMessage;
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (responseMap.containsKey('errorDetails')) {
                    
                    Map<String, Object> errorDetails = (Map<String, Object>) responseMap.get('errorDetails');
                    
                    if (errorDetails.containsKey('errorMessage')) {
                        errorMessage = String.valueOf(errorDetails.get('errorMessage'));
                    } else if (errorDetails.containsKey('errorElement')) {
                        errorMessage = String.valueOf(errorDetails.get('errorElement'));
                    }
                    
                } 
                
                if (String.isBlank(errorMessage)) {
                    errorMessage = String.isNotBlank(res.getBody()) ? res.getBody() : 'HTTP Error. Status Code: ' + res.getStatusCode();
                }
                
                List<AEHC_Asset__c> assetsToUpdate = new List<AEHC_Asset__c>();
                
                for (Id recId : recIds) {
                    assetsToUpdate.add(
                        new AEHC_Asset__c(
                            Id = recId,
                            AEHC_DDH_Error_Message__c = errorMessage
                        )
                    );
                }
                if (!assetsToUpdate.isEmpty()) {
                    Database.update(assetsToUpdate, false);
                }
                
            }
        }
        
        
        catch (Exception e) {
            safeLogException(e, 'SubscriptionJobQueueable', recIds);
            //throw new AuraHandledException('Error fetching audit details'+e);
        }
        finally {
            try {
                if (String.isNotBlank(finalPayload) &&
                    assetVerIds != null &&
                    !assetVerIds.isEmpty()) {
                        
                        List<AEHC_Asset__c> payloadUpdates = new List<AEHC_Asset__c>();
                        
                        for (Id assetId : assetVerIds) {
                            payloadUpdates.add(
                                new AEHC_Asset__c(
                                    Id = assetId,
                                    DDH_Job_Payload__c = finalPayload
                                )
                            );
                        }
                        
                        if (!payloadUpdates.isEmpty()) {
                            update payloadUpdates;
                        }
                    }
                
            } catch (Exception ignore) {
                System.debug('Failed to save payload: ' + ignore.getMessage());
            }
        }
        
    }
    
    private static void safeLogException(Exception ex,
                                         String operation,
                                         List<Id> recordId) {
                                             try {
                                                 AEHC_Logger.logException(
                                                     ex,
                                                     'Apex',
                                                     'SubscriptionJobQueueable',
                                                     operation,
                                                     recordId != null ? String.valueOf(recordId) : null,
                                                     'High',
                                                     'execute',
                                                     null,
                                                     'UAT'
                                                 );
                                             } catch (Exception ignore) {}
                                         }
    
}