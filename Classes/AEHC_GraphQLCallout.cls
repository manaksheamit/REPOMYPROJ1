public without sharing class AEHC_GraphQLCallout {

    @AuraEnabled
    public static String executeCallout(String endpointSuffix) {
        try {
            ms_aeh__CommunityAsset__c communityAsset = [SELECT Id,Name,AEHC_API_Introspection_URL__c,AEHC_API_Introspection_Body__c  from ms_aeh__CommunityAsset__c where Name=:endpointSuffix AND ms_aeh__AssetType__c ='graphql' AND AEHC_API_Introspection_URL__c!=null  LIMIT 1];
            if(communityAsset == null) {
                throw new AuraHandledException('No IntrospectionURL for : ' + endpointSuffix);
            }
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            // Dynamic endpoint
            req.setEndpoint('callout:AEHC_GraphSchema_CalloutNC/'+communityAsset.AEHC_API_Introspection_URL__c);
            req.setMethod('POST');
            req.setTimeout(120000);
            // GraphQL body
            /*String requestBody = '{' +
                '"query": "query IntrospectionQuery { __schema { queryType { name } mutationType { name } subscriptionType { name } types { name kind description fields { name description args { name description defaultValue type { ...TypeRef } } type { ...TypeRef } } inputFields { name description defaultValue type { ...TypeRef } } interfaces { name kind } enumValues { name description } possibleTypes { name kind } } directives { name description locations args { name description defaultValue type { ...TypeRef } } } } } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name } } } }"' +
            '}';*/
            String requestBody = communityAsset.AEHC_API_Introspection_Body__c;
            req.setBody(requestBody);

            HttpResponse res = http.send(req);

            // Return ONLY response body
            return res.getBody();

        }
        catch(Exception ex)
        {
            AEHC_Logger.logException(ex, 'Apex', 'AEHC_GraphQLCallout', 'Callout', null, 'P1', 'Integration', null, System.Label.AEHC_Environment_Name);
            return null;
        }
    }
        // Encrypt Method
    @AuraEnabled
    public static String encrypt(String plainText) {
		//Secret key (same as DataWeave)
        String secret = System.Label.AEHC_GraphDataEncryptionKey;
        //Base64 encode payload
        Blob payloadBlob = Blob.valueOf(plainText);
        String base64 = EncodingUtil.base64Encode(payloadBlob);
        //Convert base64 STRING → BINARY properly
        Blob message = Blob.valueOf(base64.trim());
        //Convert secret → binary
        Blob key = Blob.valueOf(secret);
        //Generate HMAC SHA256
        Blob mac = Crypto.generateMac('HmacSHA256', message, key);
        //Convert to HEX (VERY IMPORTANT)
        String signedToken = EncodingUtil.convertToHex(mac).toLowerCase();
        // Final token
        return base64 + '.' + signedToken;
    }

@AuraEnabled(cacheable=true)
    public static List<String> getSelectedFields(Id recordId) {
        AEHC_Asset__c rec = [
            SELECT AEHC_GraphQL_Fields__c
            FROM AEHC_Asset__c
            WHERE AEHC_Subscription_Request__c = :recordId AND AEHC_Is_Active__c = true
            ORDER BY createddate DESC
            LIMIT 1
        ];

        if (String.isBlank(rec.AEHC_GraphQL_Fields__c)) {
            return new List<String>();
        }

        return rec.AEHC_GraphQL_Fields__c.split(',');
    }
    
    @AuraEnabled
    public static String createVersionUpdateGraph(String subId, String graphQLFields, String graphSignedToken, String graphFormated) {

        try {
            Integer nextVersion = 1; // ✅ default version

            // ✅ Step 1: Fetch existing active records
            List<AEHC_Asset__c> existingAssets = [
                SELECT Id, AEHC_Is_Active__c, AEHC_Schema_Version__c
                FROM AEHC_Asset__c
                WHERE AEHC_Subscription_Request__c = :subId
                AND AEHC_Is_Active__c = true
                LIMIT 1
            ];
            Subscription__c subrec = [select id, Status__c, AEHC_Schema_Version__c  from Subscription__c where id =:subId LIMIT 1];
            // ✅ Step 2: If active record exists → calculate next version
            if (!existingAssets.isEmpty()) {

                AEHC_Asset__c existing = existingAssets[0];

                if (existing.AEHC_Schema_Version__c != null) {
                    try {
                        nextVersion = Integer.valueOf(existing.AEHC_Schema_Version__c) + 1;
                    } catch (Exception e) {
                        // fallback if invalid value
                        nextVersion = 1;
                    }
                }

                // ✅ Deactivate existing record
                existing.AEHC_Is_Active__c = false;
                update existing;
            }

            // ✅ Step 3: Create new record
            
            Id recordTypeId = Schema.SObjectType.AEHC_Asset__c
                .getRecordTypeInfosByDeveloperName()
                .get(System.Label.AEHC_AEHC_Version_RecType)
                .getRecordTypeId();
            AEHC_Asset__c newAsset = new AEHC_Asset__c();
            newAsset.AEHC_Subscription_Request__c = subId;
            newAsset.AEHC_GraphQL_Fields__c = graphQLFields;
            newAsset.AEHC_Is_Active__c = true;
            newAsset.AEHC_Data_Elements_Required__c = graphFormated;
            newAsset.AEHC_GraphQL_SignedToken__c = graphSignedToken;
            newAsset.AEHC_Is_GraphQL_Request__c = true;
            newAsset.RecordTypeId = recordTypeId;
            newAsset.AEHC_Schema_Version__c = String.valueOf(nextVersion);

            insert newAsset;
            revokePendingApprovals(subId);
            subrec.AEHC_Schema_Version__c = String.valueOf(nextVersion);
            //if(subrec.Status__c != 'Pending Subscriber Business Owner'){
                subrec.Status__c = 'Pending Subscriber Business Owner';
                subrec.AEHC_L1_Approved__c = false;
                subrec.AHEC_L2_Approved__c = false;
            
            subrec.AEHC_Data_Elements_Required__c = graphSignedToken;
            
            update subrec;
            return newAsset.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating asset: ' + e.getMessage());
        }

    }
    
    public static void revokePendingApprovals(Id recordId) {

        // Query pending approval work items
        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id, ProcessInstanceId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :recordId
            AND ProcessInstance.Status = 'Pending'
        ];

        if (workItems.isEmpty()) {
            System.debug('No pending approvals found.');
            return;
        }

        // Prepare recall requests
        List<Approval.ProcessWorkitemRequest> requestList = new List<Approval.ProcessWorkitemRequest>();

        for (ProcessInstanceWorkitem wi : workItems) {
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(wi.Id);
            req.setAction('Removed'); // revoke/recall
            req.setComments('Approval request revoked.');

            requestList.add(req);
        }

        // Process requests
        List<Approval.ProcessResult> results = Approval.process(requestList);

        // Handle results
        for (Approval.ProcessResult res : results) {
            if (res.isSuccess()) {
                System.debug('Approval revoked successfully.');
            } else {
                for (Database.Error err : res.getErrors()) {
                    System.debug('Error: ' + err.getMessage());
                }
            }
        }
    }
}