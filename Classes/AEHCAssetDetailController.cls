/*@Description Controller for aehcAssetDetail lwc to show publication detail and fetch the Field form data lake
 * Author Himanshu Yadav
 * Version 1.0
 */

    public with sharing class AEHCAssetDetailController {
    
    
        //  RESPONSE WRAPPER
        public class AssetResponseWrapper {
            @AuraEnabled public AssetWrapper assets;
            @AuraEnabled public List<String> environments;
        }

    //  ASSET WRAPPER
    public class AssetWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String applicationName;
        @AuraEnabled public String publicationId;
        @AuraEnabled public String schedule;
        @AuraEnabled public String environment;
        @AuraEnabled public String schemaVersion;
        @AuraEnabled public String publicationType;
        @AuraEnabled public String publicationDescription;
        @AuraEnabled public String schemaName;
        @AuraEnabled public String tableName;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String scheduleSummary;
        @AuraEnabled public String cronExpression;
        @AuraEnabled public String ddhJobId;
        @AuraEnabled public String createdDateDisplay;
        @AuraEnabled public Id versionId;
        @auraEnabled public string AEHC_Selected_Fields_JSON;
        @auraEnabled public string status;

    }

    //  MAIN METHOD
        @AuraEnabled
        public static AssetResponseWrapper getAssets(Id assetId, String env) {
        
            if (String.isBlank(env)) {
                env = 'Dev';
            }
        
            AssetResponseWrapper response = new AssetResponseWrapper();
        
            //  STEP 1: Fetch Publication
            AEHC_Asset__c publication = [
                SELECT Id,
                       Name,
                       AEHC_Application__r.Name,
                       AEHC_Application__r.AEHC_Application_Id__c,
                       AEHC_Description__c,
                       AEHC_Publication_Type__c,
                       AEHC_Publication_Id__c,
                       AEHC_Schema_Name__c,
                       AEHC_Table_Name__c,
                       CreatedDate,
                        CreatedBy.Name
                FROM AEHC_Asset__c
                WHERE Id = :assetId
                LIMIT 1
            ];
        
            //  STEP 2: Fetch Schema / Version Records
            List<AEHC_Asset__c> schemaList = [
                       SELECT Id,
                       AEHC_Publication__c,
                       AEHC_Frequency__c,
                       AEHC_Environment__c,
                       AEHC_Schema_Version__c,
                       AEHC_Is_Active__c,
                       AEHC_Schema_Name__c,
                       AEHC_Table_Name__c,
                       AEHC_Schedule_Summary__c,
                       AEHC_CRON_Job_Expression__c,
                        AEHC_IntId__c,Approval_Status__c,AEHC_Selected_Fields_JSON__c
        
                FROM AEHC_Asset__c
                WHERE AEHC_Publication__c = :assetId AND AEHC_Is_Subscription__c = false
                AND (AEHC_Is_Active__c = true or Approval_Status__c in  ('Business Owner Subscriber Review','Business Owner Publication Review',
                                                     'Security Architect Review','DDH Admin Review','Submitted to DDH','Pending') )
        ORDER BY AEHC_Schema_Version__c DESC 
            ];
        
            Set<String> envSet = new Set<String>();
            AEHC_Asset__c selectedSchema = null;
        
            //  STEP 3: Pick correct schema (by env → fallback latest)
            for (AEHC_Asset__c s : schemaList) {
        
                if (s.AEHC_Environment__c != null) {
                    envSet.add(s.AEHC_Environment__c);
                }
        
                //  exact environment match
                if (s.AEHC_Environment__c == env && selectedSchema == null) {
                    selectedSchema = s;
                }
            }
        
            // ✅ fallback if env not found
            if (selectedSchema == null && !schemaList.isEmpty()) {
                selectedSchema = schemaList[0]; // latest version
            }
        
            // ✅ STEP 4: Build response safely
            AssetWrapper wrap = new AssetWrapper();
        
            wrap.id = publication.Id;
            wrap.name = publication.Name;
            wrap.applicationName = publication.AEHC_Application__r?.Name;
            wrap.applicationId = publication.AEHC_Application__r?.AEHC_Application_Id__c;
        
            wrap.publicationId = publication.AEHC_Publication_Id__c;
        
            // ✅ FIX: Description
            wrap.publicationDescription = publication.AEHC_Description__c;
        
            // ✅ Publication Type
            wrap.publicationType = publication.AEHC_Publication_Type__c;
        
            // ✅ SAFE: Schedule (Frequency)
            if (selectedSchema != null && String.isNotBlank(selectedSchema.AEHC_Frequency__c)) {
                wrap.schedule = selectedSchema.AEHC_Frequency__c;
            } else {
                wrap.schedule = 'No Schedule Defined';  // ✅ fallback
            }
        
            // ✅ SAFE: Schema Version
            wrap.schemaVersion = (selectedSchema != null)
                ? (selectedSchema.AEHC_Schema_Version__c +' ( '+selectedSchema.Approval_Status__c+' )')
                : null;
        
            // ✅ SAFE: Environment
            system.debug(env);
            wrap.environment = (selectedSchema != null)
                ? selectedSchema.AEHC_Environment__c
                : env;
            wrap.schemaName =
            publication.AEHC_Schema_Name__c;
        
            wrap.tableName =
                publication.AEHC_Table_Name__c;
            
            wrap.createdByName =
                publication.CreatedBy.Name;
            
            wrap.createdDateDisplay =
                publication.CreatedDate.format(
                    'MM/dd/yyyy hh:mm a'
                );
            
            wrap.scheduleSummary =
                selectedSchema.AEHC_Schedule_Summary__c;
            
            wrap.cronExpression =
                selectedSchema.AEHC_CRON_Job_Expression__c;
            
            wrap.ddhJobId =
                selectedSchema.AEHC_IntId__c;
            wrap.versionId = selectedSchema.id;
            wrap.status = selectedSchema.Approval_Status__c;
            
            wrap.AEHC_Selected_Fields_JSON = selectedSchema.AEHC_Selected_Fields_JSON__c;
            response.assets = wrap;
        
            response.environments = new List<String>(envSet);
            response.environments.sort();
        
            return response;
        }

    /*    
        @AuraEnabled
        public static AEHC_Asset__c getAsset(Id assetId,string env) {
            
            if(env == null)
            {
                env = 'Dev';
            }
            
            return [
                SELECT Id,
                       Name,
                       AEHC_Application__c,
                       AEHC_Application__r.Name,
                       AEHC_Application__r.AEHC_Application_Id__c,
                       AEHC_Publication_Id__c,
                       AEHC_Schedule__c,
                       AEHC_Environment__c,
                       AEHC_Schema_Version__c,
                       AEHC_Publication_Type__c,
                       AEHC_Publication_Description__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication__c = :assetId and AEHC_Environment__c =: env and AEHC_Is_Active__c = true
                LIMIT 1
            ];
        }
    */
    /* ================= FIELD API ================= */
    @AuraEnabled
    public static FieldApiResponse getFieldsFromApi(
        Id assetId,
        String environment, Integer limitSize,
        Integer offsetSize
    ) {
		if(environment == null || environment == '')
        {
            environment = 'dev';
        }
        AEHC_Asset__c asset = [
            SELECT Name,
                   AEHC_Application__r.Name,
           		   AEHC_Schema_Name__c,
            	   AEHC_Table_Name__c
            FROM AEHC_Asset__c
            WHERE Id = :assetId
            LIMIT 1
        ];
        String dataPublicationName =
            environment.toLowerCase() + '.' +
            asset.AEHC_Schema_Name__c + '.' +
             asset.AEHC_Table_Name__c;
        String responseBody;
        Boolean calloutSuccess = false;
		system.debug(dataPublicationName);
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Unity_Catalog_Detail/' + dataPublicationName);
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');			
			req.setHeader('client_id', '{!$Credential.UnityCatalogueAPI.client_id}');
			req.setHeader('client_secret', '{!$Credential.UnityCatalogueAPI.client_secret}');

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                responseBody = res.getBody();
                calloutSuccess = true;
            } else{
                AEHC_Logger.logError(
                    'Invalid response from Unity Catalog API. Status=' + res.getStatusCode(),
                    'Apex',
                    'AEHCAssetDetailController',
                    'getFieldsFromApi',
                    String.valueOf(assetId),
                    'P1',
                    'Callout',
                    null,
                    environment
                );

                throw new AuraHandledException(
                    'Unable to load schema details at this time.'
                );
            }
 
        } catch (Exception ex) {
            //LOG EXCEPTION
            AEHC_Logger.logException(
                ex,
                'Apex',
                'AEHCAssetDetailController',
                'getFieldsFromApi',
                String.valueOf(assetId),
                'P1',
                'Callout',
                null,
                environment
            );

            throw new AuraHandledException(
                'An unexpected error occurred while loading schema details.'
            );
        }

        /*  
        if (!calloutSuccess) {
            responseBody =
            '{ "columns": [' +
            '{"columnName":"etl_publn_id","dataType":"bigint","description":"Publication Identifier","nullable":true},' +
            '{"columnName":"etl_source_sys","dataType":"string","description":"Source system","nullable":true},' +
            '{"columnName":"record_id","dataType":"string","description":"Unique identifier","nullable":false},' +
            '{"columnName":"metric_name","dataType":"string","description":"Metric name","nullable":true},' +
            '{"columnName":"created_date","dataType":"date","description":"Created date","nullable":true}' +
            '] }';
        }
		*/
       RawFieldApiResponse raw =
            (RawFieldApiResponse) JSON.deserialize(
                responseBody,
                RawFieldApiResponse.class
            );

        List<FieldRecord> allRecords = new List<FieldRecord>();
        for (SchemaColumn col : raw.columns) {
            FieldRecord fr = new FieldRecord();
            fr.fieldName   = col.columnName;
            fr.dataType    = col.dataType != null ? col.dataType.toUpperCase() : '';
            fr.description = col.description;
            fr.required    = col.nullable;
            allRecords.add(fr);
        }

        Integer start = offsetSize;
        Integer last   = Math.min(offsetSize + limitSize, allRecords.size());
        List<FieldRecord> paged = new List<FieldRecord>();

        for (Integer i = start; i < last; i++) {
            paged.add(allRecords[i]);
        }

        FieldApiResponse response = new FieldApiResponse();
        response.totalRecords = allRecords.size();
        response.records = paged;
        return response;
    }

    /* ================= CONTACTS ================= */
    @AuraEnabled(cacheable=true)
    public static List<PublicationContactDTO> getPublicationContacts(Id assetId) {
        List<PublicationContactDTO> results = new List<PublicationContactDTO>();
		
        AEHC_Asset__c assetRec = [Select id,AEHC_Application__c from AEHC_Asset__c where id =: assetId];
        
        for (AEHC_AssetMember__c m : [
            SELECT AEHC_Role__c,
                   AEHC_User__r.Name,
                   AEHC_User__r.Email,
                   AEHC_User__r.Contact.Name,
                   AEHC_User__r.Phone,
                   AEHC_User__r.Contact.Email
            FROM AEHC_AssetMember__c
            WHERE AEHC_Asset__c = : assetRec.AEHC_Application__c
              
        ]) {
            PublicationContactDTO dto = new PublicationContactDTO();
            dto.name  = m.AEHC_User__r.Name;
            dto.email = m.AEHC_User__r.Contact.Email;
            dto.phone = m.AEHC_User__r.Phone;
            dto.role  = m.AEHC_Role__c;
            results.add(dto);
        }
        return results;
    }

    
    public class FieldApiResponse {
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public List<FieldRecord> records;
    }

    public class FieldRecord {
        @AuraEnabled public String fieldName;
        @AuraEnabled public String dataType;
        @AuraEnabled public String description;
        @AuraEnabled public String required;
    }

    public class PublicationContactDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String role;
    }

    private class RawFieldApiResponse {
        public List<SchemaColumn> columns;
    }

    private class SchemaColumn {
        public String columnName;
        public String dataType;
        public String description;
        public string nullable;
    }
}