public with sharing class Aehcapprovesubs {

    public static Boolean isSubscriber = false;

    public class ResponseWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Object data;

        public ResponseWrapper(Boolean success, String message, Object data) {
            this.success = success;
            this.message = message;
            this.data = data;
        }
    }

    // ✅ Check Approval
    @AuraEnabled(cacheable=true)
    public static ResponseWrapper hasPendingApproval(Id recordId) {

        System.debug('===== START hasPendingApproval =====');
        System.debug('INPUT recordId = ' + recordId);

        if (recordId == null) {
            System.debug('Condition FAILED → recordId is NULL');
            return new ResponseWrapper(false, 'Record Id is NULL', false);
        } else {
            System.debug('Condition PASSED → recordId is valid');
        }

        try {
            Integer countRecords = [
                SELECT COUNT()
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
            ];

            System.debug('Query Result → countRecords = ' + countRecords);

            if (countRecords == 0) {
                System.debug('Condition FAILED → No ProcessInstanceWorkitem found');
                return new ResponseWrapper(false, 'No pending approval found', false);
            } else {
                System.debug('Condition PASSED → Workitems exist');
            }

            String rollVar = getRole(recordId);
            System.debug('Derived role (rollVar) = ' + rollVar);

            String appid = '';

            AEHC_Asset__c assetObj = [
                SELECT Id, AEHC_Application__c, CreatedById
                FROM AEHC_Asset__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            System.debug('Asset Query Result = ' + assetObj);

            if (assetObj == null) {
                System.debug('Condition FAILED → Asset not found');
                return new ResponseWrapper(false, 'Asset not found', false);
            } else {
                System.debug('Condition PASSED → Asset found');
            }

            System.debug('isSubscriber flag = ' + isSubscriber);

            if (isSubscriber) {
                
                System.debug('Branch → Subscriber Flow : '+[ SELECT count() 
                    FROM User 
                    WHERE Id =: assetObj.CreatedById 
                    ]);
				
                User u = [
                    SELECT Id, ContactId, Contact.AEHC_App__c
                    FROM User 
                    WHERE Id =: assetObj.CreatedById
                    LIMIT 1
                ];

                System.debug('User Query Result = ' + u);

                if (u.Contact == null) {
                    System.debug('Condition FAILED → User Contact is NULL');
                    return new ResponseWrapper(false, 'User has no contact', false);
                } else {
                    System.debug('Condition PASSED → User has contact');
                }

                appid = u.Contact.AEHC_App__c;
                System.debug('Derived appId from Contact = ' + appid);

            } else {
                System.debug('Branch → Non-Subscriber Flow');
                appid = assetObj.AEHC_Application__c;
                System.debug('Derived appId from Asset = ' + appid);
            }

            if (String.isBlank(appid)) {
                System.debug('Condition FAILED → appId is blank');
                return new ResponseWrapper(false, 'Application Id is blank', false);
            } else {
                System.debug('Condition PASSED → appId is valid');
            }

            Integer countasmember = [
                SELECT COUNT()
                FROM AEHC_AssetMember__c
                WHERE AEHC_Asset__c = :appid
                AND AEHC_User__c = :UserInfo.getUserId()
                AND AEHC_Role__c = :rollVar
            ];

            System.debug('AssetMember Count = ' + countasmember);
            System.debug('UserId = ' + UserInfo.getUserId());
            System.debug('Role Used = ' + rollVar);

            if (countasmember == 0) {
                System.debug('Condition FAILED → User NOT authorized');
                return new ResponseWrapper(false, 'User not authorized for approval', false);
            } else {
                System.debug('Condition PASSED → User authorized');
            }

            System.debug('FINAL RESULT → Approval AVAILABLE ✅');
            return new ResponseWrapper(true, 'Approval available', true);

        } catch (Exception ex) {
            System.debug('EXCEPTION → ' + ex.getMessage());
            return new ResponseWrapper(false, 'Error: ' + ex.getMessage(), false);
        }
    }

    // ✅ Get Role
    public static String getRole(String recordId) {

        System.debug('===== START getRole =====');
        System.debug('INPUT recordId = ' + recordId);

        if (String.isBlank(recordId)) {
            System.debug('Condition FAILED → recordId is blank');
            return '';
        }

        try {
            ProcessInstanceWorkitem piw = [
                SELECT Id, Actor.Name, OriginalActorId, ProcessInstance.Status
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            System.debug('PIW Result = ' + piw);
            System.debug('Actor Name = ' + piw.Actor.Name);

            String roleVal = '';

            if (piw.Actor.Name == 'DDH Admin') {
                System.debug('Matched Role → DDH Admin');
                roleVal = 'DDH Admin';

            } else if (piw.Actor.Name == 'Publication Business Owner') {
                System.debug('Matched Role → Business Owner (Publication)');
                roleVal = 'Business Owner';

            } else if (piw.Actor.Name == 'Subscriber Business Owner') {
                System.debug('Matched Role → Business Owner (Subscriber)');
                roleVal = 'Business Owner';
                isSubscriber = true;
                System.debug('isSubscriber set to TRUE');

            } else if (piw.Actor.Name == 'Security Architect') {
                System.debug('Matched Role → Security Architect');
                roleVal = 'Security Architect';
            } else {
                System.debug('No matching role found');
            }

            System.debug('FINAL Role Value = ' + roleVal);
            return roleVal;

        } catch (Exception ex) {
            System.debug('EXCEPTION in getRole → ' + ex.getMessage());
            return '';
        }
    }

    // ✅ Approve
    @AuraEnabled
    public static ResponseWrapper approveRecord(Id recordId, String remarks) {

        System.debug('===== START approveRecord =====');
        System.debug('INPUT recordId = ' + recordId);
        System.debug('INPUT remarks = ' + remarks);

        if (recordId == null) {
            System.debug('Condition FAILED → recordId NULL');
            return new ResponseWrapper(false, 'Record Id is required', null);
        }

        if (String.isBlank(remarks)) {
            System.debug('Condition FAILED → remarks blank');
            return new ResponseWrapper(false, 'Remarks are required', null);
        }

        try {
            List<ProcessInstanceWorkitem> items = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                LIMIT 1
            ];

            System.debug('Workitems found = ' + items.size());
            System.debug('Workitems data = ' + items);

            if (items.isEmpty()) {
                System.debug('Condition FAILED → No workitems');
                return new ResponseWrapper(false, 'No pending approval found', null);
            }

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(items[0].Id);
            req.setComments(remarks);
            req.setAction('Approve');

            System.debug('Submitting approval request...');

            Approval.ProcessResult result = Approval.process(req);

            System.debug('Approval Result Object = ' + result);
            System.debug('isSuccess = ' + result.isSuccess());

            if (result.isSuccess()) {
                System.debug('FINAL RESULT → APPROVED ✅');
                return new ResponseWrapper(true, 'Record approved successfully', null);
            } else {
                System.debug('FINAL RESULT → FAILED ❌');
                return new ResponseWrapper(false, 'Approval failed', null);
            }

        } catch (Exception ex) {
            System.debug('EXCEPTION → ' + ex.getMessage());
            return new ResponseWrapper(false, 'Error: ' + ex.getMessage(), null);
        }
    }

    // ✅ Reject
    @AuraEnabled
    public static ResponseWrapper rejectRecord(Id recordId, String remarks) {

        System.debug('===== START rejectRecord =====');
        System.debug('INPUT recordId = ' + recordId);
        System.debug('INPUT remarks = ' + remarks);

        if (recordId == null) {
            System.debug('Condition FAILED → recordId NULL');
            return new ResponseWrapper(false, 'Record Id is required', null);
        }

        if (String.isBlank(remarks)) {
            System.debug('Condition FAILED → remarks blank');
            return new ResponseWrapper(false, 'Remarks are required', null);
        }

        try {
            List<ProcessInstanceWorkitem> items = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                LIMIT 1
            ];

            System.debug('Workitems found = ' + items.size());

            if (items.isEmpty()) {
                System.debug('Condition FAILED → No workitems');
                return new ResponseWrapper(false, 'No pending approval found', null);
            }

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(items[0].Id);
            req.setComments(remarks);
            req.setAction('Reject');

            System.debug('Submitting rejection request...');

            Approval.ProcessResult result = Approval.process(req);

            System.debug('Rejection Result = ' + result);
            System.debug('isSuccess = ' + result.isSuccess());

            if (result.isSuccess()) {
                System.debug('FINAL RESULT → REJECTED ✅');
                return new ResponseWrapper(true, 'Record rejected successfully', null);
            } else {
                System.debug('FINAL RESULT → FAILED ❌');
                return new ResponseWrapper(false, 'Rejection failed', null);
            }

        } catch (Exception ex) {
            System.debug('EXCEPTION → ' + ex.getMessage());
            return new ResponseWrapper(false, 'Error: ' + ex.getMessage(), null);
        }
    }
}