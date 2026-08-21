public without sharing class AEHC_RoleBaseBtnVisibility {
    
    	public static final String SECURITY_ARCHITECT = 'Security Architect';
        public static final String ENTERPRISE_ARCHITECT = 'Enterprise Architect';
        public static final String INFORMATION_ARCHITECT = 'Information Architect';
        public static final String DDH_ADMIN = 'DDH Admin';
    	public static final String ADL_REVIEWER = 'ADL Reviewer';
    
    
    @AuraEnabled(cacheable=true)
    public static Boolean ButtonVisibility() {
        Set<string> roleSet = new Set<string>{SECURITY_ARCHITECT,ENTERPRISE_ARCHITECT,INFORMATION_ARCHITECT,DDH_ADMIN,ADL_REVIEWER};
        List<AEHC_AssetMember__c> assetMemberList = [
            SELECT Id
            FROM AEHC_AssetMember__c
            WHERE AEHC_User__c = :UserInfo.getUserId()
            AND AEHC_Role__c IN: roleSet
        ];
    
        return !assetMemberList.isEmpty();
    }
}