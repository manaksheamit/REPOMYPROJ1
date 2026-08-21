/**
* @class       AEHC_PublicationController
* @author      Umang Rohitbhai Fofariya
* @created     2026-05-20
* @updated     2026-06-22
* @version     2.0
*
* @description
* AEHC Publication Controller (Experience Cloud + LWC Backend)
* -----------------------------------------------------------
* This Apex controller provides backend services for Data Publication creation,
* validation, version management, and updates in a scalable and enterprise-compliant manner.
*
* This controller follows best practices for:
*  - Transaction safety using Savepoint + Rollback
*  - Centralized exception handling using a single logging method (logException)
*  - Consistent DML handling using Database.insert/update with error validation
*  - Version-controlled data model for Publication and Schema (Dev environment)
*
* ─────────────────────────────────────────────────────────────
* 🔹 CORE FUNCTIONALITIES
* ─────────────────────────────────────────────────────────────
*
* 1) Application Search
*    - getApplications(searchText)
*    - Searches Application (AEHC_Application) records by Name / CI Number
*      and returns additional metadata like Business Owners and Data Classification.
*
* 2) Eligibility Validation
*    - validateEligibility(appId)
*    - Ensures the current user has permission to create/update a publication.
*    - Validates:
*        • Application CMDB status (if applicable)
*        • User role (Developer / Business Owner)
*
* 3) Schema Metadata Retrieval (Unity Catalog Integration)
*    - getTableSchemaForPublicationCreation(applicationName, schemaName, tableName)
*    - Performs HTTP callout via Named Credential to fetch schema/column metadata.
*    - Converts API response into structured DTO (SchemaColumnDTO).
*
* 4) Duplicate Validation Before Preview
*    - validatePublicationBeforePreview(...)
*    - Prevents duplicate:
*        • Publication names within an Application
*        • Schema + Table combinations
*
* 5) Publication Creation (INITIAL VERSION SETUP )
*    - createPublication(requestJson)
*    - Creates:
*        a) Publication record (AEHC_Publication)
*        b) Initial Schema Version (AEHC_Version)
*
*    Versioning behavior:
*        • Publication.AEHC_Latest_Version__c = 1
*        • First schema version = v1
*        • Change type = INITIAL
*        • Establishes base version lineage
*
* 6) Publication Update (Basic Details)
*    - updatePublication(...)
*    - Updates Publication Name and Description only (no version increment).
*
* 7) Advanced Publication Update (VERSION CONTROL )
*    - updatePublicationAdvanced(publicationId, type, payloadJson)
*    - Handles version-based updates with strict control logic:
*
*       BASIC:
*         - Direct update (no version created)
*
*       SCHEDULE CHANGE:
*         - New version created (latest + 1)
*         - New schedule applied
*         - Version marked as inactive (pending)
*         - Change type = "Schedule Change"
*
*       SCHEMA CHANGE:
*         - New version created (latest + 1)
*         - Copies existing schedule
*         - Applies only schema description changes
*         - Version marked as inactive
*         - Change type = "GP Schema Change Request"
*
*       Common behavior:
*         - Uses FOR UPDATE on Publication (prevents concurrency issues)
*         - Tracks Previous Version (lineage)
*         - Updates Publication.AEHC_Latest_Version__c
*         - Returns structured response (success/message)
*
* 8) Active Dev Version Retrieval
*    - getDevActivePublicationData(publicationId)
*    - Fetches Publication metadata along with latest/active Dev version
*      and schedule configuration.
*
* ─────────────────────────────────────────────────────────────
* 🔹 ERROR HANDLING & LOGGING (STANDARDIZED)
* ─────────────────────────────────────────────────────────────
*
*  - Uses Savepoint + Rollback to ensure full transactional integrity.
*  - Uses a SINGLE centralized logging method: logException(...)
*  - All errors (System, DML, Business) are routed through logException
*    for consistency and maintainability.
*  - DML failures are converted to Exception objects before logging.
*  - Context-based logging ensures traceability (userId, method, payload, etc.)
*
* ─────────────────────────────────────────────────────────────
* 🔹 KEY DESIGN PRINCIPLES
* ─────────────────────────────────────────────────────────────
*
*  - Single Source of Truth for versioning → AEHC_Latest_Version__c
*  - Immutable version history (no overwrite, only new versions)
*  - Clear version lineage using Previous Version tracking
*  - Separation of BASIC vs VERSIONED updates
*  - Safe DML operations using Database methods (no partial failures)
*  - Secure field handling using createable checks
*
* ─────────────────────────────────────────────────────────────
* 🔹 DEPENDENCIES
* ─────────────────────────────────────────────────────────────
*
*  - Named Credential: Unity_Catalog_Detail
*  - Custom Logger: AEHC_Logger (logException)
*  - Objects:
*      • AEHC_Asset__c (Application / Publication / Version)
*      • AEHC_AssetMember__c (User roles)
*
* ─────────────────────────────────────────────────────────────
* 🔹 NOTES
* ─────────────────────────────────────────────────────────────
*
*  - RecordTypeIds resolved dynamically using DeveloperName
*  - Environment detection handled via domain parsing
*  - JSON payload-driven design for LWC integration
*  - Designed for extensibility (future: approvals, version diff, rollback)
*
*/
public with sharing class AEHC_PublicationController {
    
    private static final String COMPONENT_TYPE = 'Apex';
    private static final String COMPONENT_NAME = 'AEHC_PublicationController';
    private static final String SEVERITY_P1 = 'P1';
    private static final String SEVERITY_P2 = 'P2';
    private static final String CATEGORY_PUBLICATION = 'Publication';
    private static final String CATEGORY_CALLOUT = 'Callout';
    
    private static final String RECORD_TYPE_APPLICATION = 'AEHC_Application';
    private static final String RECORD_TYPE_PUBLICATION = 'AEHC_Publication';
    private static final String RECORD_TYPE_SCHEMA = 'AEHC_Version';
    
    private static final String NAMED_CREDENTIAL_UNITY_CATALOG = 'callout:Unity_Catalog_Detail/';
    private static final String DEFAULT_SCHEMA_ENVIRONMENT = 'dev';
    
    private static final String FIELD_CI_NUMBER = 'AEHC_CI_Number__c';
    private static final String FIELD_APPLICATION_OWNER = 'AEHC_Application_Owner__c';
    private static final String FIELD_DATA_CLASSIFICATION = 'AEHC_Data_Classification__c';
    private static final String FIELD_CMDB_STATUS = 'AEHC_CMDB_Validation_Status__c';
    private static final String FIELD_CMDB_BOOLEAN = 'AEHC_CMDB_Validated__c';

    public class PublicationEditResponse {

    @AuraEnabled public String publicationId;

    @AuraEnabled public String applicationId;
    @AuraEnabled public String applicationName;
    @AuraEnabled public String applicationOwner;
    @AuraEnabled public String dataClassification;

    @AuraEnabled public String publicationName;
    @AuraEnabled public String description;
    @AuraEnabled public String publicationType;

    @AuraEnabled public String schemaName;
    @AuraEnabled public String tableName;

    @AuraEnabled public String selectedFieldsJson;

    @AuraEnabled public ScheduleWrapper schedule;
}
    
    private static final Set<String> ELIGIBLE_ROLES = new Set<String>{
        'Developer',
            'Business Owner'
            };
                
                public class SchemaColumnDTO {
                    @AuraEnabled public String id;
                    @AuraEnabled public String name;
                    @AuraEnabled public String dataType;
                    @AuraEnabled public String description;
                    @AuraEnabled public Boolean nullable;
                    @AuraEnabled public Boolean required;
                    @AuraEnabled public String piiLevel;
                    @AuraEnabled public String cciLevel;
                    @AuraEnabled public Integer order;
                }
    
    
    public class ApplicationSearchDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String ciNumber;
        
        @AuraEnabled public List<String> ownerNames;
        @AuraEnabled public String ownerNamesJoined;
        
        @AuraEnabled public String dataClassification;
    }   
    
    public class PublicationDataResponse {
        @AuraEnabled public Id publicationId;
        @AuraEnabled public String publicationName;
        @AuraEnabled public String description;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String applicationName;
        @AuraEnabled public ScheduleWrapper schedule;
    }
    
    public class ScheduleWrapper {
        @AuraEnabled public String schedulerMode;
        @AuraEnabled public String frequency;
        @AuraEnabled public String scheduleTime;
        @AuraEnabled public String weeks;
        @AuraEnabled public String weekdays;
        @AuraEnabled public String monthlyDay;
        @AuraEnabled public String cronExpression;
        @AuraEnabled public String scheduleSummary;
    }
    
    @AuraEnabled
    public static List<ApplicationSearchDTO> getApplications(String searchText) {
        if (String.isBlank(searchText)) {
            return new List<ApplicationSearchDTO>();
        }
        
        Id applicationRtId = getRecordTypeIdByDeveloperName(
            AEHC_Asset__c.SObjectType,
            RECORD_TYPE_APPLICATION
        );
        
        String searchPattern = '%' + searchText.trim() + '%';
        
        Map<String, Schema.SObjectField> fieldMap =
            AEHC_Asset__c.SObjectType.getDescribe().fields.getMap();
        
        Boolean hasCi = fieldMap.containsKey(FIELD_CI_NUMBER);
        Boolean hasClass = fieldMap.containsKey(FIELD_DATA_CLASSIFICATION);
        
        List<String> selectFields = new List<String>{ 'Id', 'Name' };
            if (hasCi) selectFields.add(FIELD_CI_NUMBER);
        if (hasClass) selectFields.add(FIELD_DATA_CLASSIFICATION);
        
        String soql =
            'SELECT ' + String.join(selectFields, ',') +
            ' FROM AEHC_Asset__c' +
            ' WHERE RecordTypeId = :applicationRtId';
        
        if (hasCi) {
            soql += ' AND (Name LIKE :searchPattern OR ' + FIELD_CI_NUMBER + ' LIKE :searchPattern)';
        } else {
            soql += ' AND Name LIKE :searchPattern';
        }
        
        soql += ' ORDER BY Name LIMIT 20';
        
        List<AEHC_Asset__c> apps = Database.query(soql);
        
        Set<Id> appIds = new Set<Id>();
        for (AEHC_Asset__c a : apps) appIds.add(a.Id);
        
        // Map appId -> list of owner names
        Map<Id, List<String>> ownerMap = new Map<Id, List<String>>();
        
        if (!appIds.isEmpty()) {
            for (AEHC_AssetMember__c m : [
                SELECT AEHC_Asset__c, AEHC_User__r.Name
                FROM AEHC_AssetMember__c
                WHERE AEHC_Asset__c IN :appIds
                AND AEHC_Role__c = 'Business Owner'
                ORDER BY AEHC_User__r.Name
            ]) {
                if (!ownerMap.containsKey(m.AEHC_Asset__c)) {
                    ownerMap.put(m.AEHC_Asset__c, new List<String>());
                }
                ownerMap.get(m.AEHC_Asset__c).add(m.AEHC_User__r.Name);
            }
        }
        
        List<ApplicationSearchDTO> outList = new List<ApplicationSearchDTO>();
        
        for (AEHC_Asset__c a : apps) {
            ApplicationSearchDTO dto = new ApplicationSearchDTO();
            dto.id = a.Id;
            dto.name = a.Name;
            
            if (hasCi) dto.ciNumber = (String)a.get(FIELD_CI_NUMBER);
            if (hasClass) dto.dataClassification = (String)a.get(FIELD_DATA_CLASSIFICATION);
            
            List<String> owners = ownerMap.get(a.Id);
            dto.ownerNames = owners == null ? new List<String>() : owners;
            dto.ownerNamesJoined = (dto.ownerNames.isEmpty())
                ? ''
                : String.join(dto.ownerNames, '; ');
            
            outList.add(dto);
        }
        
        return outList;
    }
    
    @AuraEnabled
    public static void updatePublication( Id publicationId,String newName, String newDescription) {
        Savepoint sp = Database.setSavepoint();        
        String orgEnv = getCurrentEnvironment();
        
        Map<String, Object> context = new Map<String, Object>{'method' => 'updatePublication', 'publicationId' => publicationId,'userId' => UserInfo.getUserId() };
                    
        try {
            //  Validation
            if (publicationId == null) {
                throw new AuraHandledException('Publication Id is required');
            }
            
            if (String.isBlank(newName)) {
                throw new AuraHandledException('Publication Name cannot be empty');
            }
            
            if (String.isBlank(newDescription)) {
                throw new AuraHandledException('Publication Description cannot be empty');
            }
            
            //  Fetch record
            AEHC_Asset__c pub = [SELECT Id, Name, AEHC_Description__c FROM AEHC_Asset__c WHERE Id = :publicationId LIMIT 1 ];
                     
            pub.Name = newName;
            pub.AEHC_Description__c = newDescription;                        
            Database.SaveResult nameUpdateResult = Database.update(pub, false);
            
            if (!nameUpdateResult.isSuccess()) {
                System.debug('Publication Update failed');
                Database.rollback(sp);                
                logSaveErrors(nameUpdateResult, 'updatePublication', publicationId, context);                
                throw new AuraHandledException('Failed to update Publication : ' + getFirstDmlError(nameUpdateResult));
            }
                        
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);            
            logException( ahe,'updatePublication_AuraHandled',publicationId,context );
            throw ahe;
            
        } catch (Exception ex) {
            Database.rollback(sp);            
            logException(ex,'updatePublication',publicationId,context);            
            throw new AuraHandledException('Unable to update Publication. Please try again later.' );
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> validateEligibility(Id appId) {
        Map<String, Object> response = new Map<String, Object>();
        
        if (appId == null) {
            response.put('isEligible', false);
            response.put('message', 'Application is required.');
            return response;
        }
        
        try {
            if (!isApplicationCmdbValidated(appId)) {
                response.put('isEligible', false);
                response.put('message', 'This Application is not validated against ServiceNow CMDB. Publication creation is not allowed.');
                return response;
            }
            
            List<AEHC_AssetMember__c> members = [SELECT Id,AEHC_Role__c FROM AEHC_AssetMember__c WHERE AEHC_Asset__c = :appId AND AEHC_User__c = :UserInfo.getUserId()];
            
            if (members.isEmpty()) {
                response.put('isEligible', false);
                response.put('message', 'Your current role does not allow Publication creation for this Application');
                return response;
            }
            
            Set<String> userRoles = new Set<String>();
            
            for (AEHC_AssetMember__c member : members) {
                if (String.isNotBlank(member.AEHC_Role__c)) {
                    userRoles.add(member.AEHC_Role__c);
                }
            }
            Boolean hasEligibleRole = false;
            String matchedRole;
            
            for (String role : userRoles) {
                if (ELIGIBLE_ROLES.contains(role)) {
                    hasEligibleRole = true;
                    matchedRole = role;
                    break;
                }
            }
            
            if (!hasEligibleRole) {
                response.put('isEligible', false);
                response.put('message', 'Your current role does not allow Publication creation. Please contact the Application Owner.');
                return response;
            }
            
            response.put('isEligible', true);
            response.put('message', '');
            response.put('role', matchedRole);
            
            return response;
            
        } catch (Exception ex) {
            logException(ex, 'validateEligibility', appId, null);
            throw new AuraHandledException('Unable to validate publication eligibility.');
        }
    }
    
    @AuraEnabled
    public static List<SchemaColumnDTO> getTableSchemaForPublicationCreation(
        String applicationName,
        String schemaName,
        String tableName
    ) {
        if (String.isBlank(schemaName)) {
            throw new AuraHandledException('Schema Name is required.');
        }
        
        if (String.isBlank(tableName)) {
            throw new AuraHandledException('Table Name is required.');
        }
        
        Map<String, Object> context = new Map<String, Object>{
            'method' => 'getTableSchemaForPublicationCreation',
                'userId' => UserInfo.getUserId(),
                'applicationName' => applicationName,
                'schemaName' => schemaName,
                'tableName' => tableName
                };
                    
                    String orgEnv = getCurrentEnvironment();
        
        try {
            String dataPublicationName =
                DEFAULT_SCHEMA_ENVIRONMENT + '.' +
                schemaName.trim() + '.' +
                tableName.trim();
            
            context.put('dataPublicationName', dataPublicationName);
            
            String endpoint = NAMED_CREDENTIAL_UNITY_CATALOG + dataPublicationName;
            context.put('endpoint', endpoint);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            //req.setHeader('client_id', '{!$Credential.UnityCatalogueAPI.client_id}');
            //req.setHeader('client_secret', '{!$Credential.UnityCatalogueAPI.client_secret}');
            
            HttpResponse response = new Http().send(req);
            
            context.put('statusCode', response.getStatusCode());
            context.put('status', response.getStatus());
            
            if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
                AEHC_Logger.logError(
                    'Invalid response from Unity Catalog API. Status=' + response.getStatusCode(),
                    COMPONENT_TYPE,
                    COMPONENT_NAME,
                    'getTableSchemaForPublicationCreation',
                    null,
                    SEVERITY_P2,
                    CATEGORY_CALLOUT,
                    context,
                    orgEnv
                );
                
                throw new AuraHandledException('Unable to load schema fields at this time.');
            }
            
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            
            if (!payload.containsKey('columns') || payload.get('columns') == null) {
                throw new AuraHandledException('Schema response is invalid.');
            }
            
            List<Object> columns = (List<Object>) payload.get('columns');
            List<SchemaColumnDTO> result = new List<SchemaColumnDTO>();
            
            for (Object item : columns) {
                Map<String, Object> columnMap = (Map<String, Object>) item;
                
                SchemaColumnDTO dto = new SchemaColumnDTO();
                dto.id = String.valueOf(columnMap.get('columnName'));
                dto.name = String.valueOf(columnMap.get('columnName'));
                dto.dataType = columnMap.get('dataType') == null ? null : String.valueOf(columnMap.get('dataType'));
                dto.description = columnMap.get('description') == null ? '' : String.valueOf(columnMap.get('description'));
                dto.nullable = parseBooleanFlexible(columnMap.get('nullable'));
                dto.required = dto.nullable == null ? false : !dto.nullable;
                dto.piiLevel = columnMap.get('pii') == null ? '' : String.valueOf(columnMap.get('pii'));
                dto.cciLevel = columnMap.get('cci') == null ? '' : String.valueOf(columnMap.get('cci'));
                dto.order = parseIntegerSafe(columnMap.get('position'));

                result.add(dto);
            }
            
            return result;
            
        } catch (AuraHandledException ahe) {
            throw ahe;
            
        } catch (Exception ex) {
            logException(ex, 'getTableSchemaForPublicationCreation', null, context);
            throw new AuraHandledException('Unable to load schema fields.');
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> validatePublicationBeforePreview(
        Id applicationId,
        String publicationName,
        String schemaName,
        String tableName
    ) {
        Map<String, Object> response = new Map<String, Object>{
            'isValid' => true,
                'message' => ''
                };
                    
                    if (applicationId == null) {
                        response.put('isValid', false);
                        response.put('message', 'Application is required.');
                        return response;
                    }
        
        if (String.isBlank(publicationName)) {
            response.put('isValid', false);
            response.put('message', 'Publication Name is required.');
            return response;
        }
        
        if (String.isBlank(schemaName) || String.isBlank(tableName)) {
            response.put('isValid', false);
            response.put('message', 'Schema and Table are required.');
            return response;
        }
        
        Id publicationRtId = getRecordTypeIdByDeveloperName(
            AEHC_Asset__c.SObjectType,
            RECORD_TYPE_PUBLICATION
        );
        
        List<AEHC_Asset__c> duplicatePublication = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :publicationRtId
            AND AEHC_Application__c = :applicationId
            AND Name = :publicationName
            LIMIT 1
        ];
        //Umang - Need to Fix
        if (!duplicatePublication.isEmpty()) {
            response.put('isValid', false);
            response.put('message', 'Publication Name already exists for this Application.');
            return response;
        }
        
        Id schemaRtId = getRecordTypeIdByDeveloperName(
            AEHC_Asset__c.SObjectType,
            RECORD_TYPE_SCHEMA
        );
        
        /*List<AEHC_Asset__c> duplicateSchema = [
            SELECT Id
            FROM AEHC_Asset__c
            WHERE RecordTypeId = :schemaRtId
            AND AEHC_Application__c = :applicationId
            AND AEHC_Schema_Name__c = :schemaName
            AND AEHC_Table_Name__c = :tableName
            LIMIT 1
        ];
        
        if (!duplicateSchema.isEmpty()) {
            response.put('isValid', false);
            response.put('message', 'A Publication already exists for the selected Schema and Table.');
            return response;
        }*/
        
        return response;
    }
    
    private static String generateNextPublicationId() {
        Integer maxNumber = 0;
        
        List<AEHC_Asset__c> recentRecords = [
            SELECT AEHC_Publication_Id__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication_Id__c != null
            ORDER BY AEHC_Publication_Id__c DESC
            LIMIT 20
        ];
        
        for (AEHC_Asset__c rec : recentRecords) {
            String val = rec.AEHC_Publication_Id__c;
            
            if (String.isBlank(val)) continue;
            
            if (val.startsWith('PUB_') && val.contains('_')) {
                try {
                    Integer num = Integer.valueOf(val.split('_')[1]);
                    if (num > maxNumber) {
                        maxNumber = num;
                    }
                } catch (Exception e) {
                    // ignore bad data
                }
            }
        }
        
        Integer next = maxNumber + 1;
        return 'PUB_' + String.valueOf(next).leftPad(4, '0');
    }
    
    
    
    @AuraEnabled
    public static Map<String, Object> createPublication(String requestJson) {
         System.debug('Amit requestJson'+requestJson);        
        if (String.isBlank(requestJson)) {
            throw new AuraHandledException('Request payload cannot be empty.');
        }
        
        Savepoint sp = Database.setSavepoint();
        
        String orgEnv = getCurrentEnvironment();
        
        Map<String, Object> context = new Map<String, Object>{'method' => 'createPublication', 'userId' => UserInfo.getUserId(), 'orgEnv' => orgEnv};
            try {
                // ✅ Parse request
                Map<String, Object> request =
                    (Map<String, Object>) JSON.deserializeUntyped(requestJson);
                
                Map<String, Object> application =
                    (Map<String, Object>) request.get('application');
                
                Map<String, Object> metadata =
                    (Map<String, Object>) request.get('metadata');
                
                Map<String, Object> schemaData =
                    (Map<String, Object>) request.get('schema');
                
                Map<String, Object> schedule =
                    (Map<String, Object>) request.get('schedule');
                
                List<Object> selectedFieldsJson = (List<Object>) request.get('selectedFieldsJson');
                
                // ✅ Validate request
                validateCreateRequest(application, metadata, schemaData, schedule);
                
                Id applicationId = (Id) String.valueOf(application.get('id'));
                String publicationName = String.valueOf(metadata.get('name'));
                String publicationDescription = String.valueOf(metadata.get('description'));
                String publicationSchemaName = String.valueOf(schemaData.get('schema'));
                String publicationTableName = String.valueOf(schemaData.get('table'));
                String publicationType = String.valueOf(metadata.get('publicationType'));
                
                // ✅ Eligibility check
                Map<String, Object> eligibility = validateEligibility(applicationId);
                
                if (eligibility.get('isEligible') != true) {
                    throw new AuraHandledException(String.valueOf(eligibility.get('message')));
                }
                
                // ✅ Duplicate validation
                Map<String, Object> previewValidation = validatePublicationBeforePreview(
                    applicationId,
                    publicationName,
                    String.valueOf(schemaData.get('schema')),
                    String.valueOf(schemaData.get('table'))
                );
                
                /*if (previewValidation.get('isValid') != true) {
throw new AuraHandledException(String.valueOf(previewValidation.get('message')));
}*/
                
                /**
* ✅ STEP 1: Create Publication (Asset - Publication RT)
*/
                AEHC_Asset__c publication = new AEHC_Asset__c();
                
                publication.RecordTypeId = getRecordTypeIdByDeveloperName(
                    AEHC_Asset__c.SObjectType,
                    RECORD_TYPE_PUBLICATION
                );
                
                publication.Name = publicationName;
                
                String nextPubId = generateNextPublicationId();
                String pubid = nextPubId;
                putIfCreateable(publication, 'AEHC_Publication_Id__c', pubid);
                putIfCreateable(publication, 'AEHC_Publication_IdNew__c', pubid);                
                putIfCreateable(publication, 'AEHC_Application__c', applicationId);
                putIfCreateable(publication, 'AEHC_Description__c', publicationDescription);
                putIfCreateable(publication, 'AEHC_Schema_Name__c', publicationSchemaName);
                putIfCreateable(publication, 'AEHC_Table_Name__c', publicationTableName);
                putIfCreateable(publication, 'AEHC_Publication_Type__c', publicationType);
                putIfCreateable(publication, 'AEHC_Latest_Version__c', 1);
                
                Database.SaveResult publicationResult = Database.insert(publication, false);
                
                if (!publicationResult.isSuccess()) {
                    Database.rollback(sp);
                    logSaveErrors(publicationResult, 'insertPublication', null, context);
                    
                    throw new AuraHandledException(
                        'Publication insert failed: ' + getFirstDmlError(publicationResult)
                    );
                }
                
                Id publicationRecordId = publicationResult.getId();
                
                /**
* STEP 2: Create Schema Asset (Asset - Schema RT)
*/
                AEHC_Asset__c appRec = [SELECT Name FROM AEHC_Asset__c WHERE Id = :applicationId LIMIT 1];
                String appName = appRec.Name;
                String baseName = appName + '_' + publicationName + '_DEV_V1';
                AEHC_Asset__c schemaAsset = new AEHC_Asset__c();
                
                schemaAsset.RecordTypeId = getRecordTypeIdByDeveloperName(
                    AEHC_Asset__c.SObjectType,
                    RECORD_TYPE_SCHEMA
                );
                
                String schemaName = String.valueOf(schemaData.get('schema'));
                String tableName  = String.valueOf(schemaData.get('table'));
                
                schemaAsset.Name = AEHC_PublicationSubRequestController.buildVersionName(
                    appName,
                    publicationName,
                    'DEV',
                    '1'
                );
                
                putIfCreateable(schemaAsset, 'AEHC_Publication__c', publicationRecordId);
                putIfCreateable(schemaAsset, 'AEHC_Publication_Id__c', pubid);
                putIfCreateable(schemaAsset, 'AEHC_Publication_IdNew__c', pubid);
                putIfCreateable(schemaAsset, 'AEHC_Application__c', applicationId);
                putIfCreateable(schemaAsset, 'AEHC_Environment__c', 'Dev');
                putIfCreateable(schemaAsset, 'AEHC_Schema_Name__c', publicationSchemaName);
                putIfCreateable(schemaAsset, 'AEHC_Table_Name__c', publicationTableName);
                putIfCreateable(schemaAsset, 'AEHC_Schema_Version__c', '1');
                putIfCreateable(schemaAsset, 'Approval_Status__c', 'Business Owner Publication Review');
                
                // ✅ Safe JSON handling
                putIfCreateable(schemaAsset, 'AEHC_Selected_Fields_JSON__c', selectedFieldsJson != null ? JSON.serialize(selectedFieldsJson) : '[]');
                
                // ✅ Apply schedule
                applySchedule(schemaAsset, schedule);
                
                Database.SaveResult schemaResult = Database.insert(schemaAsset, false);
                
                if (!schemaResult.isSuccess()) {
                    Database.rollback(sp);
                    logSaveErrors(schemaResult, 'insertSchemaAsset', publicationRecordId, context);
                    
                    throw new AuraHandledException(
                        'Schema insert failed: ' + getFirstDmlError(schemaResult)
                    );
                }
                
                /**
* ✅ SUCCESS RESPONSE
*/
                return new Map<String, Object>{
                    'success' => true,
                        'publicationRecordId' => publicationRecordId,
                        'publicationId' => pubid,
                        'publicationName' => publicationName
                        };
                            
                            } catch (AuraHandledException ahe) {
                                Database.rollback(sp);
                                logException(ahe, 'createPublication_AuraHandled', null, context);
                                throw ahe;
                                
                            } catch (Exception ex) {
                                Database.rollback(sp);
                                logException(ex, 'createPublication', null, context);
                                
                                throw new AuraHandledException(
                                    'Unable to create publication. Please try again later.'
                                );
                            }
    }
    
    private static void validateCreateRequest(
        Map<String, Object> application,
        Map<String, Object> metadata,
        Map<String, Object> schemaData,
        Map<String, Object> schedule
    ) {
        if (application == null || String.isBlank(String.valueOf(application.get('id')))) {
            throw new AuraHandledException('Application is required.');
        }
        
        if (metadata == null || String.isBlank(String.valueOf(metadata.get('name')))) {
            throw new AuraHandledException('Publication Name is required.');
        }
        
        if (metadata == null || String.isBlank(String.valueOf(metadata.get('description')))) {
            throw new AuraHandledException('Publication Description is required.');
        }
        
        if (schemaData == null || String.isBlank(String.valueOf(schemaData.get('schema')))) {
            throw new AuraHandledException('Schema is required.');
        }
        
        if (schemaData == null || String.isBlank(String.valueOf(schemaData.get('table')))) {
            throw new AuraHandledException('Table is required.');
        }
        
        if (schemaData.get('fields') == null) {
            throw new AuraHandledException('Field metadata is required.');
        }
        
        if (schedule == null || String.isBlank(String.valueOf(schedule.get('frequency')))) {
            throw new AuraHandledException('Schedule is required.');
        }
    }
    
    private static Boolean isApplicationCmdbValidated(Id appId) {
        Map<String, Schema.SObjectField> fieldMap =
            AEHC_Asset__c.SObjectType.getDescribe().fields.getMap();
        
        Boolean hasBooleanCmdbField = fieldMap.containsKey(FIELD_CMDB_BOOLEAN);
        Boolean hasStatusCmdbField = fieldMap.containsKey(FIELD_CMDB_STATUS);
        
        if (!hasBooleanCmdbField && !hasStatusCmdbField) {
            return true;
        }
        
        String soql = 'SELECT Id';
        
        if (hasBooleanCmdbField) {
            soql += ', ' + FIELD_CMDB_BOOLEAN;
        }
        
        if (hasStatusCmdbField) {
            soql += ', ' + FIELD_CMDB_STATUS;
        }
        
        soql += ' FROM AEHC_Asset__c WHERE Id = :appId LIMIT 1';
        
        AEHC_Asset__c app = Database.query(soql);
        
        if (hasBooleanCmdbField) {
            Object boolValue = app.get(FIELD_CMDB_BOOLEAN);
            
            if (boolValue != null && Boolean.valueOf(String.valueOf(boolValue)) == true) {
                return true;
            }
        }
        
        if (hasStatusCmdbField) {
            Object statusValue = app.get(FIELD_CMDB_STATUS);
            
            if (statusValue != null && String.valueOf(statusValue).equalsIgnoreCase('Validated')) {
                return true;
            }
        }
        
        return false;
    }
    
    private static void applySchedule(AEHC_Asset__c schemaAsset, Map<String, Object> schedule) {
        if (schedule == null) {
            return;
        }
        
        putIfCreateable(schemaAsset, 'AEHC_VSchedule__c', schedule.get('schedulerMode'));
        putIfCreateable(schemaAsset, 'AEHC_Frequency__c', schedule.get('frequency'));
        putIfCreateable(schemaAsset, 'AEHC_Schedule_Summary__c', schedule.get('scheduleSummary'));
        putIfCreateable(schemaAsset, 'AEHC_CRON_Job_Expression__c', schedule.get('cronExpression'));
        
        String frequency = String.valueOf(schedule.get('frequency'));
        
        if (
            frequency == 'Daily' ||
            frequency == 'Weekly' ||
            frequency == 'Multi-Weekly' ||
            frequency == 'Monthly' ||
            frequency == 'Annual'
        ) {
            putIfCreateable(
                schemaAsset,
                'AEHC_Time__c',
                convertStringToTime(String.valueOf(schedule.get('scheduleTime')))
            );
        }
        
        if (frequency == 'Weekly') {
            List<Object> weekdays = (List<Object>) schedule.get('weekdays');
            
            if (weekdays != null && !weekdays.isEmpty()) {
                putIfCreateable(schemaAsset, 'AEHC_Weekdays__c', joinObjectList(weekdays));
            }
        }
        
        if (frequency == 'Multi-Weekly') {
            List<Object> weeks = (List<Object>) schedule.get('multiWeekWeeks');
            List<Object> days = (List<Object>) schedule.get('multiWeekDays');
            
            if (weeks != null && !weeks.isEmpty()) {
                putIfCreateable(schemaAsset, 'AEHC_Weeks__c', joinObjectList(weeks));
            }
            
            if (days != null && !days.isEmpty()) {
                putIfCreateable(schemaAsset, 'AEHC_Weekdays__c', joinObjectList(days));
            }
        }
        
        if (frequency == 'Monthly') {
            putIfCreateable(schemaAsset, 'AEHC_Day_of_Month__c', schedule.get('monthlyDay'));
        }
        
        if (frequency == 'Annual') {
            putIfCreateable(schemaAsset, 'AEHC_Annual_Month__c', schedule.get('annualMonth'));
            putIfCreateable(schemaAsset, 'AEHC_Annual_Day__c', schedule.get('annualDay'));
            putIfCreateable(schemaAsset, 'AEHC_Annual_Date__c', schedule.get('annualDate'));
        }
    }
    
    private static String joinObjectList(List<Object> values) {
        List<String> output = new List<String>();
        
        for (Object value : values) {
            output.add(String.valueOf(value));
        }
        
        return String.join(output, ';');
    }
    
    private static Time convertStringToTime(String inputTime) {
        if (String.isBlank(inputTime) || inputTime == 'null') {
            return null;
        }
        
        try {
            String cleanTime = inputTime.split('\\.')[0];
            List<String> parts = cleanTime.split(':');
            
            Integer hour = Integer.valueOf(parts[0]);
            Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
            Integer second = parts.size() > 2 ? Integer.valueOf(parts[2]) : 0;
            
            return Time.newInstance(hour, minute, second, 0);
            
        } catch (Exception ex) {
            return null;
        }
    }
    
    private static Id getRecordTypeIdByDeveloperName(
        Schema.SObjectType sObjectType,
        String developerName
    ) {
        Schema.RecordTypeInfo rtInfo =
            sObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(developerName);
        
        if (rtInfo == null) {
            throw new AuraHandledException('Required record type is missing: ' + developerName);
        }
        
        return rtInfo.getRecordTypeId();
    }
    
    private static void putIfCreateable(SObject record, String fieldApiName, Object value) {
        Schema.SObjectField fieldToken =
            record.getSObjectType()
            .getDescribe()
            .fields
            .getMap()
            .get(fieldApiName);
        
        if (fieldToken != null && fieldToken.getDescribe().isCreateable()) {
            record.put(fieldApiName, value);
        }
    }
    
    private static String getFirstDmlError(Database.SaveResult result) {
        if (result != null && result.getErrors() != null && !result.getErrors().isEmpty()) {
            return result.getErrors()[0].getMessage();
        }
        
        return 'Unable to save record.';
    }
    
    private static String getCurrentEnvironment() {
        String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();
        
        if (domain.contains('sandbox') || domain.contains('--') || domain.contains('cs')) {
            if (domain.contains('dev') || domain.contains('--dev')) {
                return 'Dev';
            }
            
            if (domain.contains('qa') || domain.contains('--qa')) {
                return 'QA';
            }
            
            if (domain.contains('uat') || domain.contains('--uat')) {
                return 'UAT';
            }
            
            return 'Sandbox';
        }
        
        return 'Prod';
    }
    
    private static void logException(
        Exception ex,
        String operation,
        Id relatedRecordId,
        Map<String, Object> context
    ) {
        try {
            AEHC_Logger.logException(ex,COMPONENT_TYPE,COMPONENT_NAME,operation,relatedRecordId == null ? null : String.valueOf(relatedRecordId),SEVERITY_P1,CATEGORY_PUBLICATION,context,getCurrentEnvironment());
        } catch (Exception loggingException) {
            System.debug(LoggingLevel.ERROR, 'Logging failed: ' + loggingException.getMessage());
        }
    }
    
    private static void logSaveErrors(
        Database.SaveResult result,
        String operation,
        Id relatedRecordId,
        Map<String, Object> context
    ) {
        try {
            if (result == null || result.getErrors() == null) {
                return;
            }
            
            for (Database.Error err : result.getErrors()) {
                Map<String, Object> logContext = context == null
                    ? new Map<String, Object>()
                    : new Map<String, Object>(context);
                
                logContext.put('operation', operation);
                logContext.put('statusCode', String.valueOf(err.getStatusCode()));
                logContext.put('fields', err.getFields());
                
                AEHC_Logger.logError(err.getMessage(),COMPONENT_TYPE,COMPONENT_NAME,operation,relatedRecordId == null ? null : String.valueOf(relatedRecordId),SEVERITY_P2,'DML',logContext,getCurrentEnvironment());
            }
        } catch (Exception loggingException) {
            System.debug(LoggingLevel.ERROR, 'Failed to log save errors: ' + loggingException.getMessage());
        }
    }
    private static Boolean parseBooleanFlexible(Object raw) {
        if (raw == null) return null;
        
        if (raw instanceof Boolean) {
            return (Boolean) raw;
        }
        
        String v = String.valueOf(raw).trim().toLowerCase();
        
        // true variants
        if (v == 'true' || v == 'yes' || v == 'y' || v == '1') return true;
        
        // false variants
        if (v == 'false' || v == 'no' || v == 'n' || v == '0') return false;
        
        // fallback: treat unknown as null (safer than defaulting to false)
        return null;
    }
    
    private static Integer parseIntegerSafe(Object raw) {
        if (raw == null) return null;
        
        String s = String.valueOf(raw).trim();
        if (String.isBlank(s) || s.equalsIgnoreCase('null')) return null;
        
        try {
            return Integer.valueOf(s);
        } catch (Exception e) {
            return null;
        }
    }
    @AuraEnabled
    public static PublicationDataResponse getDevActivePublicationData(Id publicationId) {
        
        if (publicationId == null) {
            throw new AuraHandledException('Publication Id required');
        }
        
        List<AEHC_Asset__c> versions = [
            SELECT
            AEHC_Publication__r.AEHC_Application__c,
            AEHC_Publication__r.AEHC_Application__r.Name,
            AEHC_Publication__r.AEHC_Application__r.AEHC_Application_Id__c,
            AEHC_Publication__c,
            AEHC_Publication__r.Name,
            AEHC_Publication__r.AEHC_Description__c,
            AEHC_VSchedule__c,
            AEHC_Frequency__c,
            AEHC_Time__c,
            AEHC_Weekdays__c,
            AEHC_Day_of_Month__c,
            AEHC_CRON_Job_Expression__c,
            AEHC_Schedule_Summary__c,
            AEHC_Schema_Version__c,
            AEHC_Is_Active__c
            FROM AEHC_Asset__c
            WHERE AEHC_Publication__c = :publicationId
            AND AEHC_Environment__c = 'Dev'
            ORDER BY AEHC_Is_Active__c DESC,
            AEHC_Schema_Version__c DESC
            LIMIT 1
        ];
        
        AEHC_Asset__c version =
            versions.isEmpty() ? null : versions[0];
        
        if (version == null) {
            return null;
        }
        
        PublicationDataResponse response =
            new PublicationDataResponse();
        
        response.publicationId =
            String.valueOf(version.AEHC_Publication__c);
        
        response.publicationName =
            version.AEHC_Publication__r.Name;
        
        response.description =
            version.AEHC_Publication__r.AEHC_Description__c;
        
        response.applicationId =
            version.AEHC_Publication__r.AEHC_Application__r
            .AEHC_Application_Id__c;
        
        response.applicationName =
            version.AEHC_Publication__r.AEHC_Application__r
            .Name;
        
        ScheduleWrapper schedule =
            new ScheduleWrapper();
        
        schedule.schedulerMode =
            version.AEHC_VSchedule__c;
        
        schedule.frequency =
            version.AEHC_Frequency__c;
        
        schedule.scheduleTime =
            version.AEHC_Time__c != null
            ? formatTime(version.AEHC_Time__c)
            : null;
        
        schedule.weekdays =
            version.AEHC_Weekdays__c;
        
        schedule.monthlyDay =
            version.AEHC_Day_of_Month__c != null
            ? String.valueOf(version.AEHC_Day_of_Month__c)
            : null;
        
        schedule.cronExpression =
            version.AEHC_CRON_Job_Expression__c;
        
        schedule.scheduleSummary =
            version.AEHC_Schedule_Summary__c;
        
        response.schedule = schedule;
        
        return response;
    }
   
    @AuraEnabled
    public static Map<String, Object> editPublication(Id publicationId, String payloadJson) {
        Savepoint sp = Database.setSavepoint();
        Map<String, Object> response = new Map<String, Object>();

        try {
            if (publicationId == null) {
                throw new AuraHandledException('Publication Id required');
            }

            if (String.isBlank(payloadJson)) {
                throw new AuraHandledException('Payload is required');
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            System.debug('PAYLOAD'+payload);
            Map<String, Object> metadata = (Map<String, Object>) payload.get('metadata');
            Map<String, Object> schemaData = (Map<String, Object>) payload.get('schema');
            Map<String, Object> schedule = (Map<String, Object>) payload.get('schedule');
            Object selectedFieldsJson = payload.get('selectedFieldsJson');

            AEHC_Asset__c pub = [
                SELECT Id, Name, AEHC_Description__c, AEHC_Latest_Version__c
                FROM AEHC_Asset__c
                WHERE Id = :publicationId
                LIMIT 1
                FOR UPDATE
            ];

            AEHC_Asset__c existing = [
                SELECT Id,
                    AEHC_Application__c,
                    AEHC_Selected_Fields_JSON__c,
                    AEHC_Publication_Id__c,
                    AEHC_Publication_IdNew__c,
                    AEHC_Publication__r.AEHC_Application__r.Name,
                    AEHC_Publication__r.Name,
                    AEHC_Publication__r.AEHC_Schema_Name__c,
                    AEHC_Publication__r.AEHC_Table_Name__c,
                    AEHC_Schema_Name__c,
                    AEHC_Table_Name__c,
                    AEHC_Schema_Version__c,
                    AEHC_Is_Active__c,
                    AEHC_VSchedule__c,
                    AEHC_Frequency__c,
                    AEHC_Time__c,
                    AEHC_Weekdays__c,
                    AEHC_Weeks__c,
                    AEHC_Day_of_Month__c,
                    AEHC_CRON_Job_Expression__c,
                    AEHC_Schedule_Summary__c,
                    AEHC_Selected_Fields__c,
                    AEHC_ADL_Review_Required__c,
                    AEHC_Is_Fields_Change__c,
                    AEHC_Field_Change_Type__c,
                    AEHC_IntId__c
                FROM AEHC_Asset__c
                WHERE AEHC_Publication__c = :publicationId
                    AND AEHC_Environment__c = 'Dev'
                    AND AEHC_Is_Active__c = true
                    AND AEHC_Is_Subscription__c = false
                ORDER BY AEHC_Schema_Version__c DESC
                LIMIT 1
            ];

            String newName = metadata != null ? String.valueOf(metadata.get('name')) : null;
            System.debug('Amit Newname'+newName);
            String newDescription = metadata != null ? String.valueOf(metadata.get('description')) : null;
            String updatedName = !String.isBlank(newName) ? newName : pub.Name;
            String updatedDescription = !String.isBlank(newDescription) ? newDescription : pub.AEHC_Description__c;

            Boolean basicChanged = false;
            if (metadata != null) {
                basicChanged =
                    (!String.isBlank(newName) && newName != pub.Name) ||
                    (!String.isBlank(newDescription) && newDescription != pub.AEHC_Description__c);
            }

            Boolean schemaChanged = isSchemaUpdateRequired(schemaData, existing, selectedFieldsJson);
            Boolean scheduleChanged = isScheduleUpdateRequired(schedule, existing);
            System.debug('schemaChanged'+schemaChanged);
            System.debug('scheduleChanged'+scheduleChanged);
            System.debug('basicChanged'+basicChanged);

            if (!basicChanged && !schemaChanged && !scheduleChanged) {
                response.put('success', true);
                response.put('message', 'No changes detected.');
                response.put('publicationName',updatedName);
                response.put('publicationRecordId',publicationId);
                return response;
            }

            if (basicChanged && !schemaChanged && !scheduleChanged) {
                updatePublication(publicationId, updatedName, updatedDescription);
                response.put('success', true);
                response.put('message', 'Publication details updated successfully.');
                response.put('publicationName',updatedName);
                response.put('publicationRecordId',publicationId);
                return response;
            }

            Integer latestVersion = pub.AEHC_Latest_Version__c == null ? 0 : Integer.valueOf(pub.AEHC_Latest_Version__c);
            Integer nextVersion = latestVersion + 1;

            AEHC_Asset__c newVersion = new AEHC_Asset__c();
            newVersion.RecordTypeId = getRecordTypeIdByDeveloperName(AEHC_Asset__c.SObjectType, 'AEHC_Version');
            newVersion.Name = AEHC_PublicationSubRequestController.buildVersionName(existing.AEHC_Publication__r.AEHC_Application__r.Name,
                                                                                    existing.AEHC_Publication__r.Name,'DEV',String.valueOf(nextVersion));
            newVersion.AEHC_Publication__c = publicationId;
            newVersion.AEHC_Publication_Id__c = existing.AEHC_Publication_Id__c;
            newVersion.AEHC_Environment__c = 'Dev';
            newVersion.AEHC_Schema_Name__c = schemaChanged ? String.valueOf(schemaData.get('schema'))
                                                : (String.isBlank(existing.AEHC_Schema_Name__c) 
                                                ? existing.AEHC_Publication__r.AEHC_Schema_Name__c
                                                : existing.AEHC_Schema_Name__c);
            newVersion.AEHC_Table_Name__c = schemaChanged ? String.valueOf(schemaData.get('table'))
                : (String.isBlank(existing.AEHC_Table_Name__c)
                    ? existing.AEHC_Publication__r.AEHC_Table_Name__c
                    : existing.AEHC_Table_Name__c);
            newVersion.AEHC_Schema_Version__c = String.valueOf(nextVersion);
            newVersion.AEHC_Previous_Version__c = existing.Id;
            newVersion.AEHC_Is_Active__c = false;
            newVersion.AEHC_Selected_Fields_JSON__c = schemaChanged
                ? JSON.serialize(toObjectList(selectedFieldsJson))
                : existing.AEHC_Selected_Fields_JSON__c;            
            newVersion.Approval_Status__c = 'Business Owner Publication Review';
            newVersion.AEHC_IntId__c = existing.AEHC_IntId__c;
            newVersion.AEHC_Selected_Fields__c = existing.AEHC_Selected_Fields__c;
            newVersion.AEHC_Application__c = existing.AEHC_Application__c;
            //newVersion.AEHC_ADL_Review_Required__c = schemaChanged ? true: existing.AEHC_ADL_Review_Required__c;
            newVersion.AEHC_Is_Fields_Change__c = schemaChanged ? true: false;
            newVersion.AEHC_Field_Change_Type__c  = schemaChanged && scheduleChanged ? 'Field Schema Change;Schedule Change': schemaChanged ? 'Field Schema Change' : scheduleChanged ? 'Schedule Change':'';  

            if (scheduleChanged) {
                newVersion.AEHC_VSchedule__c = null;
                newVersion.AEHC_Frequency__c = null;
                newVersion.AEHC_Time__c = null;
                newVersion.AEHC_Weekdays__c = null;
                newVersion.AEHC_Weeks__c = null;
                newVersion.AEHC_Day_of_Month__c = null;
                newVersion.AEHC_CRON_Job_Expression__c = null;
                newVersion.AEHC_Schedule_Summary__c = null;
                applySchedule(newVersion, schedule);
            } else {
                newVersion.AEHC_VSchedule__c = existing.AEHC_VSchedule__c;
                newVersion.AEHC_Frequency__c = existing.AEHC_Frequency__c;
                newVersion.AEHC_Time__c = existing.AEHC_Time__c;
                newVersion.AEHC_Weekdays__c = existing.AEHC_Weekdays__c;
                newVersion.AEHC_Weeks__c = existing.AEHC_Weeks__c;
                newVersion.AEHC_Day_of_Month__c = existing.AEHC_Day_of_Month__c;
                newVersion.AEHC_CRON_Job_Expression__c = existing.AEHC_CRON_Job_Expression__c;
                newVersion.AEHC_Schedule_Summary__c = existing.AEHC_Schedule_Summary__c;
            }

            Database.SaveResult insertResult = Database.insert(newVersion, false);
            if (!insertResult.isSuccess()) {
                Database.rollback(sp);
                throw new AuraHandledException('Failed to create new version');
            }

            AEHC_Asset__c publicationUpdate = new AEHC_Asset__c(Id = publicationId);
            if (basicChanged) {
                publicationUpdate.Name = updatedName;
                publicationUpdate.AEHC_Description__c = updatedDescription;
            }
            if (schemaChanged) {
                publicationUpdate.AEHC_Schema_Name__c = String.valueOf(schemaData.get('schema'));
                publicationUpdate.AEHC_Table_Name__c = String.valueOf(schemaData.get('table'));
                
            }
            publicationUpdate.AEHC_Latest_Version__c = nextVersion;

            Database.SaveResult pubUpdate = Database.update(publicationUpdate, false);
            if (!pubUpdate.isSuccess()) {
                Database.rollback(sp);
                throw new AuraHandledException('Failed to update publication version');
            }

            response.put('success', true);
            response.put('message', (basicChanged && !schemaChanged && !scheduleChanged)
                ? 'Publication updated successfully.' 
                :(basicChanged && (schemaChanged || scheduleChanged))? 'Publication updated and new version created successfully.':(!basicChanged && (schemaChanged || scheduleChanged))?'New publication version created successfully.':'');
            response.put('publicationName',pub.name);
            response.put('publicationRecordId',publicationId);
            return response;

        } catch (Exception ex) {
            Database.rollback(sp);
            return new Map<String, Object>{
                'success' => false,
                'message' => ex.getMessage()
            };
        }
    }

    private static Boolean isSchemaUpdateRequired(  Map<String, Object> schemaData, AEHC_Asset__c existing,Object selectedFieldsJson) {
        
        System.debug('schemaData'+schemaData);
        System.debug('existing'+existing);
        System.debug('existing'+existing.AEHC_Schema_Name__c);
        System.debug('existing'+existing.AEHC_Table_Name__c);
        System.debug('existingAEHC_Selected_Fields_JSON__c'+existing.AEHC_Selected_Fields_JSON__c);
        System.debug('selectedFieldsJson'+selectedFieldsJson);
        if (schemaData == null) {
            return false;
        }

        if (!String.isBlank(String.valueOf(schemaData.get('schema'))) &&
            String.valueOf(schemaData.get('schema')) != existing.AEHC_Schema_Name__c) {
            return true;
        }

        if (!String.isBlank(String.valueOf(schemaData.get('table'))) &&
            String.valueOf(schemaData.get('table')) != existing.AEHC_Table_Name__c) {
            return true;
        }

        if (!areSelectedFieldsEqual(selectedFieldsJson, existing.AEHC_Selected_Fields_JSON__c)) {
            return true;
        }

        return false;
    }

    private static Boolean isScheduleUpdateRequired(Map<String, Object> schedule,AEHC_Asset__c existing) {
        if (schedule == null) {
            return false;
        }

        String requestedSchedulerMode = normalizeScheduleValue(schedule.get('schedulerMode'));
        String requestedFrequency = normalizeScheduleValue(schedule.get('frequency'));
        String requestedCron = normalizeScheduleValue(schedule.get('cronExpression'));
        String requestedSummary = normalizeScheduleValue(schedule.get('scheduleSummary'));
        String requestedTime = normalizeScheduleValue(schedule.get('scheduleTime'));
        String requestedMonthlyDay = normalizeScheduleValue(schedule.get('monthlyDay'));

        String existingSchedulerMode = normalizeScheduleValue(existing.AEHC_VSchedule__c);
        String existingFrequency = normalizeScheduleValue(existing.AEHC_Frequency__c);
        String existingCron = normalizeScheduleValue(existing.AEHC_CRON_Job_Expression__c);
        String existingSummary = normalizeScheduleValue(existing.AEHC_Schedule_Summary__c);
        String existingMonthlyDay = normalizeScheduleValue(existing.AEHC_Day_of_Month__c);
        String existingTime = existing.AEHC_Time__c != null ? formatTime(existing.AEHC_Time__c) : '';

        if (requestedSchedulerMode != existingSchedulerMode) {
            return true;
        }

        if (requestedFrequency != existingFrequency) {
            return true;
        }

        if (requestedCron != existingCron) {
            return true;
        }

        if (requestedSummary != existingSummary) {
            return true;
        }

        if (!String.isBlank(requestedTime) && requestedTime.split('\\.')[0] != existingTime) {
            return true;
        }

        if (!stringListsEqual((List<Object>) schedule.get('weekdays'), existing.AEHC_Weekdays__c)) {
            return true;
        }

        if (!stringListsEqual((List<Object>) schedule.get('multiWeekWeeks'), existing.AEHC_Weeks__c)) {
            return true;
        }

        if (requestedMonthlyDay != existingMonthlyDay) {
            return true;
        }

        return false;
    }

    private static Boolean areSelectedFieldsEqual(Object payloadSelectedFieldsJson, String existingJson) {
        List<Object> payloadList = toObjectList(payloadSelectedFieldsJson);
        List<Object> existingList = String.isBlank(existingJson)
            ? new List<Object>()
            : (List<Object>) JSON.deserializeUntyped(existingJson);

        if (payloadList == null && existingList == null) {
            return true;
        }

        if (payloadList == null || existingList == null) {
            return false;
        }

        if (payloadList.size() != existingList.size()) {
            return false;
        }

        Set<String> payloadSignatures = new Set<String>();
        for (Object item : payloadList) {
            if (item instanceof Map<String, Object>) {
                payloadSignatures.add(buildMapSignature((Map<String, Object>) item));
            }
        }

        for (Object item : existingList) {
            if (!(item instanceof Map<String, Object>)) {
                return false;
            }
            if (!payloadSignatures.contains(buildMapSignature((Map<String, Object>) item))) {
                return false;
            }
        }

        return true;
    }

    private static List<Object> toObjectList(Object raw) {
        if (raw == null) {
            return new List<Object>();
        }

        if (raw instanceof List<Object>) {
            return (List<Object>) raw;
        }

        if (raw instanceof String) {
            try {
                return (List<Object>) JSON.deserializeUntyped((String) raw);
            } catch (Exception ex) {
                return new List<Object>();
            }
        }

        return new List<Object>();
    }

    private static String buildMapSignature(Map<String, Object> signatureMap) {
        // List<String> keys = new List<String>(signatureMap.keySet());
        // keys.sort();

        // List<String> parts = new List<String>();
        // for (String key : keys) {
        //     parts.add(key + ':' + String.valueOf(signatureMap.get(key)));
        // }

        // return String.join(parts, '|');
        

        List<String> parts = new List<String>();

        parts.add(String.valueOf(signatureMap.get('fieldName')));
        //parts.add(String.valueOf(signatureMap.get('dataType')));
        //parts.add(String.valueOf(signatureMap.get('description')));
        parts.add(String.valueOf(signatureMap.get('piiLevel')));
       // parts.add(String.valueOf(signatureMap.get('cciLevel')));
        parts.add(String.valueOf(signatureMap.get('required')));
        parts.add(String.valueOf(signatureMap.get('labelName')));

        return String.join(parts, '|');

    }

    private static String normalizeScheduleValue(Object value) {
        if (value == null) {
            return '';
        }

        String text = String.valueOf(value).trim();
        if (text.equalsIgnoreCase('null')) {
            return '';
        }

        return text;
    }

    private static Boolean stringListsEqual(List<Object> incomingList, String existingValue) {
        String incoming = joinObjectList(incomingList == null ? new List<Object>() : incomingList);
        String existing = String.isBlank(existingValue) ? '' : existingValue;
        return incoming == existing;
    }
    
    @AuraEnabled(cacheable=true)
    public static Integer getDescriptionMaxLimit(){
        return AEHC_Constant.DESCRIPTION_LIMIT;
    }
    private static String formatTime(Time t) {
        if (t == null) return null;
        
        Integer hour = t.hour();
        Integer minute = t.minute();
        
        String hh = hour < 10 ? '0' + hour : String.valueOf(hour);
        String mm = minute < 10 ? '0' + minute : String.valueOf(minute);
        
        return hh + ':' + mm;
    }
    @AuraEnabled(cacheable=true)
    public static PublicationEditResponse getPublicationForEdit(Id publicationId) {
        Map<String, Object> context = new Map<String, Object>{'method' => 'getPublicationForEdit', 'publicationId' => publicationId, 'userId' => UserInfo.getUserId()};
        try{

    

        if (publicationId == null) {
            throw new AuraHandledException('Publication Id required');
        }

        List<AEHC_Asset__c> versions = [SELECT AEHC_Publication__c, AEHC_Publication__r.Name, AEHC_Publication__r.AEHC_Description__c,
        AEHC_Publication__r.AEHC_Publication_Type__c, AEHC_Publication__r.AEHC_Schema_Name__c, AEHC_Publication__r.AEHC_Table_Name__c,
        AEHC_Publication__r.AEHC_Application__c, AEHC_Publication__r.AEHC_Application__r.Name, AEHC_Publication__r.AEHC_Application__r.AEHC_Application_Id__c, 
        AEHC_Publication__r.AEHC_Application__r.AEHC_Data_Classification__c, AEHC_Selected_Fields_JSON__c, AEHC_VSchedule__c, AEHC_Frequency__c, AEHC_Time__c,
        AEHC_Weekdays__c, AEHC_Weeks__c, AEHC_CRON_Job_Expression__c, AEHC_Schedule_Summary__c, AEHC_Day_of_Month__c
        FROM AEHC_Asset__c
        WHERE AEHC_Publication__c = :publicationId
        AND AEHC_Environment__c = 'Dev'
        AND AEHC_Is_Active__c= true
        ORDER BY            
            AEHC_Schema_Version__c DESC
        LIMIT 1
        ];

        if (versions.isEmpty()) {
            throw new AuraHandledException('No active Dev version found.');
        }
        AEHC_Asset__c version = versions[0];

    PublicationEditResponse response = new PublicationEditResponse();

    /** Application*/
    response.applicationId = String.valueOf(version.AEHC_Publication__r.AEHC_Application__c);
    response.applicationName = version.AEHC_Publication__r.AEHC_Application__r.Name;
    response.dataClassification = version.AEHC_Publication__r.AEHC_Application__r.AEHC_Data_Classification__c;

    /** Business Owners*/
    List<String> owners =new List<String>();
    for (AEHC_AssetMember__c member : [SELECT AEHC_User__r.Name FROM AEHC_AssetMember__c WHERE AEHC_Asset__c = :version.AEHC_Publication__r.AEHC_Application__c AND AEHC_Role__c = 'Business Owner' ORDER BY AEHC_User__r.Name]) {
        owners.add(member.AEHC_User__r.Name);
    }
    response.applicationOwner = owners.isEmpty() ? '' : String.join(owners, '; ');

    /** Publication*/
    response.publicationId = String.valueOf(version.AEHC_Publication__c);
    response.publicationName = version.AEHC_Publication__r.Name;
    response.description = version.AEHC_Publication__r.AEHC_Description__c;
    response.publicationType = version.AEHC_Publication__r.AEHC_Publication_Type__c;

    /** Schema*/
    response.schemaName = version.AEHC_Publication__r.AEHC_Schema_Name__c;
    response.tableName = version.AEHC_Publication__r.AEHC_Table_Name__c;

    /** Selected Fields*/
    response.selectedFieldsJson = String.isBlank(version.AEHC_Selected_Fields_JSON__c) ? '[]' : version.AEHC_Selected_Fields_JSON__c;

    /** Schedule*/
    ScheduleWrapper schedule = new ScheduleWrapper();
    schedule.schedulerMode = version.AEHC_VSchedule__c;
    schedule.frequency = version.AEHC_Frequency__c;
    schedule.scheduleTime = version.AEHC_Time__c != null ? formatTime(version.AEHC_Time__c) : null;
    schedule.weekdays = version.AEHC_Weekdays__c;
    schedule.monthlyDay = version.AEHC_Day_of_Month__c != null ? String.valueOf(version.AEHC_Day_of_Month__c) : null;
    schedule.weeks = version.AEHC_Weeks__c != null ?version.AEHC_Weeks__c:null;
    schedule.cronExpression = version.AEHC_CRON_Job_Expression__c;
    schedule.scheduleSummary = version.AEHC_Schedule_Summary__c;
    response.schedule = schedule;

    return response;
        }catch(Exception ex){
            logException(ex, 'getPublicationForEdit', publicationId, context);
            throw new AuraHandledException( 'Unable to load Publication details.');
        }
}
    
}