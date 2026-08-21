trigger AEHC_AssetMemberACRTrigger on AEHC_AssetMember__c (before insert) {
    if(trigger.isBefore && trigger.isInsert){
        AEHC_AssetMemberACRTriggerHandler.assetMember(trigger.new);
    }

}