import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getSubscriptionDetailPageData from '@salesforce/apex/AEHC_SubscriptionDetailPageController.getSubscriptionDetailPageData';
import getSubscriptionVersionDetails from '@salesforce/apex/AEHC_SubscriptionDetailPageController.getSubscriptionVersionDetails';
import getVersionId from '@salesforce/apex/AEHC_VersionHistoryController.getVersionId';

export default class AehcSubscriptionDetailPage extends NavigationMixin(LightningElement) {

    @track subscriptionId;
    @track showPage = false;
    @track subscriptionName;
    @track applicationName;
    @track publicationId;
    @track publicationName;
    @track purposeOfUse;
    @track subscriberId;
    @track isEditableUser = false;
    @track environments = [];
    @track environmentMap = {};

    @track selectedEnvironment;
    @track versionOptions = [];
    @track selectedVersion;

    @track versionData;
    @track isLoading = false;

    @track currentUserId;
    @track subscriptionOwnerId;

    @track showEditWizard = false;
    @track editContext = {};

    @wire(CurrentPageReference)
    getPageRef(pageRef) {

        if (pageRef?.state) {

            this.subscriptionId = pageRef.state.subscriptionId;

            this.selectedEnvironment = pageRef.state.env || null;
            this.selectedVersion = pageRef.state.ver || null;

            this.loadPageData();
        }
    }

    async loadPageData() {

        try {

            const data = await getSubscriptionDetailPageData({
                subscriptionId: this.subscriptionId
            });

            this.showPage = true;

            this.subscriptionName = data.subscriptionName;
            this.applicationName = data.applicationName;
            this.publicationName = data.publicationName;
            this.publicationRecordId = data.publicationRecordId;
            this.purposeOfUse = data.purposeOfUse;
            this.subscriberId = data.subscriberId;
            this.isEditableUser = data.isEditableUser;
            this.currentUserId = data.currentUserId;
            this.subscriptionOwnerId = data.subscriptionOwnerId;

            this.environments = data.environments;
            this.environmentMap = data.environmentMap;


            if (!this.selectedEnvironment) {
                this.selectedEnvironment = this.environments[0];
            }


            this.updateVersions();
            await this.fetchVersionDetails();

        } catch (error) {
            console.error('Error loading page', error);
            this.showPage = false;
        }
    }

    updateUrlParams() {

    const params = [];

    params.push(`subscriptionId=${encodeURIComponent(this.subscriptionId)}`);

    if (this.selectedEnvironment) {
        params.push(`env=${encodeURIComponent(this.selectedEnvironment)}`);
    }

    if (this.selectedVersion !== null && this.selectedVersion !== undefined) {
        params.push(`ver=${encodeURIComponent(this.selectedVersion)}`);
    }

    this[NavigationMixin.Navigate](
        {
            type: 'standard__webPage',
            attributes: {
                url: `${window.location.pathname}?${params.join('&')}`
            }
        },
        true
    );
}


   updateVersions() {

    const versions = this.environmentMap[this.selectedEnvironment] || [];

    this.versionOptions = versions.map(v => {

        let displayStatus;
        let isEditable = false;
        let actionType = null;

        const isOwnerOrBO = this.isEditableUser;

        /*
        ✅ FINAL RULE IMPLEMENTATION
        */

        // ✅ ACTIVE + ACTIVE
        if (v.approvalStatus === 'Active' && v.isActive === true) {
            displayStatus = 'Active';
            isEditable = isOwnerOrBO;
            actionType = 'CREATE_NEW_VERSION';
        }

        // ✅ ACTIVE BUT NOT ACTIVE → DEPRECATED
        else if (v.approvalStatus === 'Active' && v.isActive === false) {
            displayStatus = 'Deprecated';
            isEditable = false;
            actionType = null;
        }

        // ✅ REJECTED → EDIT SAME VERSION
        else if (v.approvalStatus === 'Rejected') {
            displayStatus = 'Rejected';
            isEditable = isOwnerOrBO;
            actionType = 'UPDATE';
        }

        // ✅ ALL OTHER STATUSES (Approved, Pending, etc.)
        else {
            displayStatus = v.approvalStatus || 'Draft';
            isEditable = false;
            actionType = null;
        }

        return {
            label: `${v.versionNumber} (${displayStatus})`,
            value: String(v.versionNumber),
            isEditable,
            actionType // ✅ useful later in wizard
        };
    });

    /*
    ✅ PRESERVE SELECTED VERSION
    */
    const exists = this.versionOptions.some(
    v => String(v.value) === String(this.selectedVersion)
);

   
if (!exists) {
    const active = this.versionOptions.find(v => v.label.includes('(Active)'));

    this.selectedVersion = active
        ? active.value
        : this.versionOptions[0]?.value;
}
}

    handleEnvChange(event) {

        this.selectedEnvironment = event.detail.value;

        /*
        ✅ Reset version on env change
        */
        this.selectedVersion = null;

        this.updateVersions();
        

        if (this.selectedEnvironment && this.selectedVersion) {
            this.updateUrlParams();   // ✅ ADD
            this.fetchVersionDetails();
        }
    }

    get disableEdit() {

        const selected = this.versionOptions.find(
            v => v.value === this.selectedVersion
        );

        return !(selected && selected.isEditable);
    }

    handleVersionChange(event) {

        this.selectedVersion = String(event.detail.value);
      
        this.updateUrlParams();   // ✅ ADD

        if (this.selectedEnvironment && this.selectedVersion) {
            this.fetchVersionDetails();
        }
    }

    async fetchVersionDetails() {

        if (!this.selectedEnvironment || !this.selectedVersion) {
            return;
        }

        this.isLoading = true;

        try {

            const data = await getSubscriptionVersionDetails({
                subscriptionId: this.subscriptionId,
                environment: this.selectedEnvironment,
                versionNumber: this.selectedVersion
            });

            this.versionData = data;

        } catch (error) {
            console.error('Error fetching version', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleEditClick() {
        const selected = this.versionOptions.find(
            v => v.value === this.selectedVersion
        );

        this.editContext = {
            subscriptionId: this.subscriptionId,
            environment: this.selectedEnvironment,
            version: this.selectedVersion,
            isDraft: this.versionData?.approvalStatus === 'Rejected'
        };

        this.showEditWizard = true;
    }

    handleCloseWizard() {
        this.showEditWizard = false;

        // ✅ bring back overview
        this.showPage = true;

        // ✅ OPTIONAL: refresh data
        this.loadPageData();
    }


    handleApprovalHistory() {
        this.fetchVersionId();
    }

    closeChangeHistoryModal() {
        this.isChangeHistory = false;
    }

    getversionId;
    isChangeHistory = false;
    isJobRunHistory = false;
    isVersionHistory = false;

    async fetchVersionId() {

        this.isLoading = true;

        try {

            const data = await getVersionId({
                subId: this.subscriptionId,
                env: this.selectedEnvironment,
                version: this.selectedVersion
            });

            this.getversionId = data;
            this.isChangeHistory = true;
        } catch (error) {
            console.error('Error fetching version', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleJobHistory(event) {
        this.isJobRunHistory = true;
    }


    handleVersionHistory(event) {
        this.isVersionHistory = true;
    }


    closeJobHistoryModal() {
        this.isJobRunHistory = false;
    }

    closeVersionHistoryModal() {
        this.isVersionHistory = false;
    }
}