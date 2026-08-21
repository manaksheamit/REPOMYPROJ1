/**
 * @author Asif Ahmad
 * @date 17Apr2026
 * @description Test Factory, to provide test records with minimum required populated fields
 * @app AEHC
*/
public class AEHC_TestDataFactory {
   
    private static UserRole getUserRole(String roleName) {
        
        List<UserRole> roles = [SELECT Id FROM UserRole WHERE DeveloperName = :roleName];
        
        if(!roles.isEmpty()) return roles[0];
        
        UserRole role = new UserRole(
            Name = roleName,
            DeveloperName = roleName
        );
        insert role;
        return role;
    }
    
    public static User create_ExternalUser(String username) {
        // Get an Experience Cloud profile
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'API Experience Hub Member User'
            LIMIT 1
        ];

        // Create Account & Contact (MANDATORY)
        Account acc = new Account(Name = username);
        insert acc;

        Contact con = new Contact(
            LastName = 'PortalContact',
            AccountId = acc.Id,
            Email = username
        );
        insert con;
        
        User portalUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            UserRole role = getUserRole('AEH_AssetOwner');
            if(UserInfo.getUserRoleId() == null) {
                update new User(
                    Id = UserInfo.getUserId(),
                    UserRoleId = role.Id
                );
            }
            
            // Create External User
            portalUser = new User(
                Username = username,
                Alias = 'puser',
                Email = 'portal@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'PortalUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'Asia/Kolkata',
                ProfileId = portalProfile.Id,
                ContactId = con.Id,
                UserRoleId = null
            );
            
            insert portalUser;
            
        }
        
        return portalUser;
    }
    
    public static void assignPermissionSet(Id userId, List<String> permissionSetNames) {
        
        // Get Permission Set
        List<PermissionSet> psRecs = [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN :permissionSetNames
        ];
        
        List<PermissionSetAssignment> psaRecs = new List<PermissionSetAssignment>();
        for(PermissionSet ps : psRecs) {
            psaRecs.add(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = ps.Id
            ));
        }
        
        // Assign Permission Set
        System.runAs(new User(Id = UserInfo.getUserId())) {
            if(!psaRecs.isEmpty()) insert psaRecs;
        }
    }
    
    public static AEHC_AssetMember__c create_AssetMember(String assetOwnerName, String role, Id userId, Boolean isInsert) {
        AEHC_AssetMember__c member = new AEHC_AssetMember__c(
            AEHC_User__c = userId,
            AEHC_Role__c = role
        );
        if(isInsert) insert member;
        
        return member;
    }
    
    public static Id networkId;
    public static ms_aeh__CommunityAsset__c create_CommunityAsset(String assetType, Boolean isInsert) {
        if(networkId == null) networkId = [SELECT Id FROM Network LIMIT 1].Id;
        
        ms_aeh__CommunityAsset__c asset = new ms_aeh__CommunityAsset__c(
            Name = 'kpmg-nexus-ch-entity-papi' + DateTime.now().getTime(),
            ms_aeh__AssetType__c = assetType,
            ms_aeh__AssetId__c = 'kpmg-nexus-ch-entity-papi',
            ms_aeh__GroupAssetId__c = '9d1390e4-8f9f-406d-a404-a34085c57f2d:kpmg-nexus-ch-entity-papi',
            ms_aeh__GroupId__c = '9d1390e4-8f9f-406d-a404-a34085c57f2',
            ms_aeh__Key__c = '0DB9V000000SivlWAC:9d1390e4-8f9f-406d-a404-a34085c57f2d:kpmg-nexus-ch-entity-papi',
            ms_aeh__NetworkId__c = networkId
        );
        if(isInsert) insert asset;
        
        return asset;
    }

}