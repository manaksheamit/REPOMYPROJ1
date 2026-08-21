trigger AEHC_GroupCreationOnCommunityAsset on ms_aeh__CommunityAsset__c (after insert) {
    if(trigger.isAfter && trigger.isInsert){
        AEHC_GroupCreationCommunityAssetHandler.accountCreation(trigger.new);
    }
}