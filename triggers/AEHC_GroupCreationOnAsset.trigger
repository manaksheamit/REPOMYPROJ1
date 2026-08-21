trigger AEHC_GroupCreationOnAsset on AEHC_Asset__c (before insert) {
	if(trigger.isBefore && trigger.isInsert){
        AEHC_GroupCreationOnAssetHandler.accountCreation(trigger.new);
    }
}