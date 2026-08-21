/*@description This class is for SSO JIT Controller.
 * It includes methods for creating and and updating user record and PermissionsetAssignment.
 * It will return the user for SSO Login
 * @author Himanshu
 * @version 1.0
 */
global class AEH_SSOJITHandler implements Auth.SamlJitHandler {
    
    private AEHC_Global_Config__c cnfg ;
    String AEHC_PermissionSetName = '';
        
    public Id getContactId(String email, String lname, String fname) {
    //Check for existing Contact
    List<Contact> existing = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
        system.debug(existing);
    if(!existing.isEmpty()) return existing[0].Id;
    
    // Find or Create the 'Portal' Account
    cnfg = AEHC_Utility.getConfig();
    Id accountId;
    List<Account> portalAccounts = [SELECT Id FROM Account WHERE Name = :cnfg.PORTAL_ACCOUNT_NAME__C LIMIT 1];
     system.debug(portalAccounts);
    if(portalAccounts.isEmpty()) {
        Account newAccount = new Account(
            Name = cnfg.PORTAL_ACCOUNT_NAME__c,
            Description = 'Container for SSO External Identity Users'
        );
        insert newAccount;
        accountId = newAccount.Id;
    } else {
        accountId = portalAccounts[0].Id;
    }

    
    Contact newContact = new Contact(
        FirstName = fname,
        LastName = lname,
        Email = email,
        AccountId = accountId
    );
    insert newContact;
    
    return newContact.Id;
}

    /* 
       CREATE USER METHOD
      */
    global User createUser(
        Id samlSsoProviderId,
        Id communityId,
        Id portalId,
        String federationIdentifier,
        Map<String, String> attributes,
        String assertion
    ) {
        try{
        cnfg = AEHC_Utility.getConfig();
        User u = new User();
        String userFirstName = attributes.get(cnfg.CLAIM_GIVENNAME__C);
        String userEmail = attributes.get(cnfg.CLAIM_EMAIL__c);
        String userLastName = attributes.get(cnfg.CLAIM_SURNAME__c);
        id contactid = getContactId(userEmail,userLastName,userFirstName);
        List<User> existingUsers = new List<User>();
        system.debug(contactid);
        existingUsers = [SELECT Id FROM User  WHERE ContactId = :ContactId  LIMIT 1];
        system.debug(existingUsers);
		if (!existingUsers.isEmpty()) {
   		u.id = existingUsers[0].id;
           
        } 
        else{
		u.Username = federationIdentifier + AEHC_Constant.USERNAME_SUFFIX;
        u.ms_aeh__AnypointUsername__c = u.Username;
        u.ms_aeh__AnypointIdp__c = cnfg.AEHC_Anypoint_IDP_Id__c;
        
        
        u.Email = attributes.get(cnfg.CLAIM_EMAIL__c);
        u.LastName = attributes.get(cnfg.CLAIM_SURNAME__c);
        u.FirstName = attributes.get(cnfg.CLAIM_GIVENNAME__c);
        String alias = (u.FirstName != null) ? u.FirstName.substring(0,1) + u.LastName : u.LastName;
    	u.Alias = alias.length() > 8 ? alias.substring(0, 8) : alias;
       	Profile p = [SELECT Id FROM Profile WHERE Name = :cnfg.PROFILE_EXTERNAL_IDENTITY__C LIMIT 1];
        system.debug(p);
        u.ProfileId = p.Id;
        u.TimeZoneSidKey = AEHC_Constant.DEFAULT_TIMEZONE; 
        u.LocaleSidKey = AEHC_Constant.DEFAULT_LOCALE;
        u.EmailEncodingKey = AEHC_Constant.DEFAULT_ENCODING;
        u.LanguageLocaleKey = AEHC_Constant.DEFAULT_LOCALE;
        u.contactid = ContactId;
        u.IsActive = true;
            
        }
       handleJit(
            true,
            u,
            federationIdentifier,
            attributes
        );
        system.debug(u);
      	 if (!existingUsers.isEmpty()) {
             system.debug('Update');
   			update u;
            return u;
        } 
        system.debug(u);
        insert u;
        assignPermission(
                u.Id,
                AEHC_PermissionSetName
            );
        return u;
        }catch(Exception ex)
        {
            system.debug(ex);
            AEHC_Logger.logException(
                ex,
                'Apex',
                'AEH_SSOJITHandler',
                'Create',
                null,
                'P1',
                'DML',
                null,
                'Dev'
            );
            return null;
        }
    }

    /* 
       UPDATE USER METHOD
       */
    global void updateUser(
        Id userId,
        Id samlSsoProviderId,
        Id communityId,
        Id portalId,
        String federationIdentifier,
        Map<String, String> attributes,
        String assertion
    ) {
        try{
         cnfg = AEHC_Utility.getConfig();
        User u = [
            SELECT Id,
                   ms_aeh__AnypointGroupMappings__c
            FROM User
            WHERE Id = :userId
        ];
		 system.debug('userId : '+userId);
             system.debug('samlSsoProviderId : '+samlSsoProviderId);
             system.debug('communityId : '+communityId);
             system.debug('portalId : '+portalId);
             system.debug('federationIdentifier : '+federationIdentifier);
             system.debug('attributes : '+attributes);
        	system.debug('assertion : '+assertion);
			for(string key : attributes.keyset())
            {
                system.debug(Key + ' : '+attributes.get(key));
            }
        handleJit(false,u,federationIdentifier,attributes);
		
        update u;
        }catch(Exception ex)
        {
              AEHC_Logger.logException(ex,'Apex','AEH_SSOJITHandler','Create',null,'P1','DML',null,'Dev');   
        }
    }

    
    public void handleJit(
        Boolean isCreate,
        User u,
        String federationIdentifier,
        Map<String, String> attributes
    ) {

        cnfg = AEHC_Utility.getConfig();
        if (isCreate) {
            u.FederationIdentifier = federationIdentifier;
        }

       
        String rawGroupId = attributes.get(
            cnfg.CLAIM_GROUPS__c
        );

        if (String.isBlank(rawGroupId)) {
            return; 
        }
        String entraGroupId = rawGroupId.replace('[', '').replace(']', '').replace('"', '').trim();      
        AEHC_SSOConfig__mdt cfg;
        try {
            cfg = [
                SELECT Entra_Group_Id__c,
                       AEHC_anyPointGroupMapping__c,
                       AEHC_PermissionSetName__c,AEHC_User_Persona__c
                FROM AEHC_SSOConfig__mdt
                WHERE Entra_Group_Id__c = :entraGroupId
                LIMIT 1
            ];
        } catch (Exception ex) {
             AEHC_Logger.logException(ex,'Apex','AEH_SSOJITHandler','Create',null,'P1','DML',null,'Dev');   
            return; 
        }

       
        if (cfg != null) {
            
			if(String.isNotBlank(cfg.AEHC_anyPointGroupMapping__c))
            u.ms_aeh__AnypointGroupMappings__c = '["'+cfg.AEHC_anyPointGroupMapping__c+'"]';
            
            u.AEHC_User_Persona__c = cfg.AEHC_User_Persona__c;
        }
		system.debug( u.ms_aeh__AnypointGroupMappings__c);
        
        if (cfg != null &&
            String.isNotBlank(cfg.AEHC_PermissionSetName__c)) {
                if(!isCreate){
            assignPermissionSet(
                u.Id,
                cfg.AEHC_PermissionSetName__c
            );
                }
                else{
                    AEHC_PermissionSetName = cfg.AEHC_PermissionSetName__c;
                   /* assignPermission(u.Id, cfg.AEHC_PermissionSetName__c );*/
                }
        }
    }

   
    public void assignPermissionSet(Id userId, String permSetName) {
        try{
            List<String>  permSetList = permSetName.split(',');
        List<PermissionSetAssignment> permAssExisting = [
            SELECT id,PermissionSet.Name 
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSet.Name in :permSetList
        ];
		
        if (permAssExisting.size() == permSetList.size()) {
            return; 
        }
		Set<string> permNameExisting = new Set<string>();
            for(PermissionSetAssignment permName : permAssExisting )
            {
                permNameExisting.add(permName.PermissionSet.Name );
            }
        List<PermissionSet> ps = [SELECT Id FROM PermissionSet WHERE Name in :permSetList and ( Name NOT IN : permNameExisting )];

            List<PermissionSetAssignment>  permToAssignList = new List<PermissionSetAssignment>();
            for(PermissionSet psvar : ps)
            {
             PermissionSetAssignment permAssignObj =   new PermissionSetAssignment(
            											AssigneeId = userId,
           												PermissionSetId = psvar.Id
       		 											); 
                permToAssignList.add(permAssignObj);
            }
            if(permToAssignList.size() > 0){
        		insert permToAssignList;
            }
    	}catch(Exception ex)
        {
            AEHC_Logger.logException(ex,'Apex','AEH_SSOJITHandler','Create',null,'P1','DML',null,'Dev');            
        }
    }
    
    @future 
    public static void assignPermission(Id userId, String permSetName)
    {
        AEH_SSOJITHandler obj = new AEH_SSOJITHandler();
        obj.cnfg = AEHC_Utility.getConfig();
        obj.assignPermissionSet(
                userId,
                permSetName
            );
    }


}