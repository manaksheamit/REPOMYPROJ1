import { LightningElement, api, track } from 'lwc';
import getMembersApex from '@salesforce/apex/AEHC_ManageApplicationUserCtrl.getMembers';
import deleteAssetMemberApex from '@salesforce/apex/AEHC_ManageApplicationUserCtrl.deleteAssetMember';
import searchUsersApex from '@salesforce/apex/AEHC_ManageApplicationUserCtrl.searchUsers';
import upsertAssetMemberApex from '@salesforce/apex/AEHC_ManageApplicationUserCtrl.upsertAssetMember';
// import getAssetMemberRolesApex from '@salesforce/apex/AEHC_ManageApplicationUserCtrl.getAssetMemberRoles';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import USER_ID from '@salesforce/user/Id';

const ROLE_Developer = 'Developer', ROLE_BusinessOwner = 'Business Owner', ROLE_ITOwner = 'IT Owner', ROLE_AssetOwner = 'Asset Owner';
const ALL_ROLES = [
    {
        label: ROLE_Developer,
        value: ROLE_Developer
    },
    {
        label: ROLE_BusinessOwner,
        value: ROLE_BusinessOwner
    },
    {
        label: ROLE_ITOwner,
        value: ROLE_ITOwner
    }
];

export default class AehcManageApplicationUser extends LightningElement {

    @api recordId; // Application Id
    @api appRec = {};

    policies = [
        {
            roleName: ROLE_Developer,
            allowedRoles: [],
            has_EditMember: false,
            has_CreateMember: false,
            has_DeleteMember: false
        },
        {
            roleName: ROLE_ITOwner,
            allowedRoles: ALL_ROLES.filter(role => [ROLE_ITOwner, ROLE_Developer].includes(role.value)),
            has_EditMember: true,
            has_CreateMember: true,
            has_DeleteMember: true
        },
        {
            roleName: ROLE_BusinessOwner,
            allowedRoles: ALL_ROLES,
            has_EditMember: true,
            has_CreateMember: true,
            has_DeleteMember: true
        }
    ]
    currentPolicy = {
        has_EditMember: false,
        has_CreateMember: false,
        has_DeleteMember: false,
        allowedRoles: [],
        allowedRoleNames: [],
    }
    currentUserRole;
    applyPolicy() {

        // find policy
        if ([ROLE_Developer, ROLE_BusinessOwner, ROLE_ITOwner].includes(this.currentUserRole)) {
            this.currentPolicy = this.policies.find(policy => policy.roleName == this.currentUserRole);
            this.currentPolicy.allowedRoleNames = this.currentPolicy.allowedRoles.map(r => r.value);
        }
        // console.log(61, this.currentPolicy)
        // this.currentPolicy = this.policies.find(policy => policy.roleName == ROLE_Developer); // All Access
        // // console.log(64, this.currentPolicy)
        // define List view actions

        // create action
        this.listView.actions = this.currentPolicy.has_CreateMember ? [this.listView.action_Create] : [];

        // row actions
        const listViewColumns = [...this.listView.defaultColumns];

        const getRowActions = (row, doneCallback) => {
            let actions = [];

            if (![this.appRec?.ITOwner?.subField, this.appRec?.BusinessOwner?.subField].includes(row.AEHC_User__r.Email)) {
                // console.log(`getRowActions:Role`, row.AEHC_Role__c);
                if (this.currentPolicy.allowedRoleNames.includes(row.AEHC_Role__c)) {
                    if (this.currentPolicy.has_EditMember) actions.push(this.listView.action_Edit);
                    if (this.currentPolicy.has_DeleteMember) actions.push(this.listView.action_Delete);
                }
            }
            if (row.AEHC_User__c == USER_ID) {
                actions = [];
            }

            // simulate a trip to the server
            // console.log(98, actions);
            if (!actions.length) {
                actions.push({
                    label: 'No Available Actions',
                    name: 'none',
                    disabled: true,
                    iconName: 'utility:info'
                });
            }
            setTimeout(() => {
                doneCallback(actions);
            }, 200);
        }

        if (this.currentPolicy.has_EditMember || this.currentPolicy.has_DeleteMember) {
            listViewColumns.push({
                type: 'action',
                typeAttributes: {
                    rowActions: getRowActions
                }
            });
        }
        this.listView.columns = listViewColumns;

        // allowed roles in detail modal
        this.memberDetail.userRoles = this.currentPolicy.allowedRoles;

    }

    // states
    listView = {
        name: 'c-aehc-list-view',
        title: 'Users',
        element: null,
        getElement: function (component) {
            if (!this.element) {
                this.element = component.template.querySelector(this.name);
            }
            return this.element;
        },
        records: [],
        actions: this.currentPolicy.has_CreateMember ? [
            {
                label: 'Add User',
                name: 'row:add',
                icon: 'utility:adduser'
            }
        ] : [],
        defaultColumns: [
            {
                label: 'User', fieldName: 'userName', cellAttributes: {
                    iconName: { fieldName: 'iconName' },
                    class: { fieldName: 'rowClass' }
                }
            },
            { label: 'Role', fieldName: 'AEHC_Role__c' }
        ],
        action_Edit: { label: 'Edit', name: 'row:edit', iconName: 'utility:edit' },
        action_Delete: { label: 'Delete', name: 'row:delete', iconName: 'utility:delete' },
        action_Create: { label: 'Add User', name: 'row:add', iconName: 'utility:adduser' },
        columns: [],
        reset: function (cmp, data) {
            setTimeout(() => {
                const elem = this.getElement(cmp);
                if (elem) elem.reset(data);
            }, 0);
        }
    }

    connectedCallback() {
        this.initialize();
    }

    currentUser;
    isInitialized
    async initialize() {
        // console.log(`initialize`, JSON.stringify(this.appRec))
        // get roles
        // {
        //     const response = await getAssetMemberRolesApex();

        //     if (response.status == 200) {
        //         // this.memberDetail.userRoles = response.data;
        //     }
        // }
        this.isInitialized = true;
    }

    // user Search
    userSearchDetail = {
        name: 'c-aehc-reusable-lookup',
        label: 'User Name or Email',
        objectLabel: 'User',
        required: 'true',
        placeholder: 'Search User',
        iconName: 'utility:user',
        element: null,
        getElement: function (component) {
            return component.template.querySelector(this.name);
        },
        records: []
    }
    async handleUserSearchAction_OnChange(event) {
        const searchTerm = event.detail.value;

        // clear search results
        if (this.searchTimeout) window.clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(async e => {
            this.userSearchDetail.getElement(this).reset({
                records: [],
                isLoading: true
            });
            // console.log(70, searchTerm)
            // make Apex call to search and get user
            const response = await searchUsersApex({
                searchTerm
            });

            // console.log(76, response)
            this.userSearchDetail.getElement(this).reset({
                records: response.status == 200 ? response.data : [],
                isLoading: false
            });

        }, 500);
    }
    handleUserSearchAction_OnSelect(event) {
        const selected = event.detail;

        this.memberDetail.userId = selected.id;
    }
    handleUserSearchAction_OnDeselect(event) {
        this.memberDetail.userId = null;
    }

    // detail
    @track memberDetail = {
        userRoles: [],
        userRole: '',
        userId: null
    }
    handleChange_UserRole(event) {
        this.memberDetail.userRole = event.detail.value;
    }

    async handleClick_Save() {
        const payload = {
            assetId: this.recordId,
            recordId: this.memberDetail.recordId,
            role: this.memberDetail.userRole,
            userId: this.memberDetail.userId
        }

        if (!payload.role || !payload.userId) {
            return;
        }
        this.detailModal.isLoading = true;
        const response = await upsertAssetMemberApex({
            payload: JSON.stringify(payload)
        });

        this.detailModal.isLoading = false;
        // console.log(123, response)

        if (response.status == 200) {
            this.dispatchEvent(new ShowToastEvent({
                message: response.message,
                variant: 'success',
            }));
            this.detailModal.isVisible = false;
            this.getMembers();
        } else if (response.status == 400) {
            this.dispatchEvent(new ShowToastEvent({
                message: response.message,
                variant: 'warning',
            }));
        } else {
            this.dispatchEvent(new ShowToastEvent({
                message: response.message,
                variant: 'error',
            }));
        }

    }

    errorCallback(error, stack) {
        this.error = error;

        // console.log(`errorCallback`, this.error)
    }

    async getMembers() {
        try {


            this.listView.reset(this, {
                isLoading: true
            });
            const response = await getMembersApex({
                applicationId: this.recordId
            });

            // console.log(42, response);
            if (response.status == 200) {
                this.listView.records = response.data.map(row => {
                    const rec = {
                        ...row,
                        userName: row.AEHC_User__r?.Name
                    }

                    if (row.AEHC_User__c == USER_ID) {
                        rec.userName = row.AEHC_User__r?.Name + ' (You)';
                        rec.iconName = 'utility:user';
                        rec.rowClass = 'slds-text-title_bold';
                    }

                    return rec;
                });
                // console.log(267, USER_ID)
                // find current User
                const currentUserMembership = this.listView.records.find(rec => rec.AEHC_User__c == USER_ID);
                if (currentUserMembership) {
                    this.currentUserRole = currentUserMembership.AEHC_Role__c;
                }
            } else {
                this.listView.records = [];
            }
            this.applyPolicy();

            this.isInitialized = true;

            // data in List View
            this.listView.reset(this, {
                columns: this.listView.columns,
                actions: this.listView.actions,
                records: this.listView.records,
                isLoading: false
            });
        } catch (err) {
            // console.log(297, err);
        }
    }

    // handlers
    handleListViewAction(event) {
        try {
            const eventDetail = event.detail;
            const actionName = eventDetail.name;
            if (!actionName) return;

            // console.log(98, actionName);
            if (actionName == 'row:add') {

                this.detailModal.title = 'New Member';

                this.memberDetail.recordId = null;
                this.memberDetail.userRole = null;
                this.memberDetail.userId = null;
                this.memberDetail.user = null;

                this.detailModal.isVisible = true;
            } else {
                const actionDetail = event.detail.detail;
                // console.log(103, actionDetail)
                if (actionName == 'row:edit') {

                    this.detailModal.title = 'Modify Member';
                    this.memberDetail.recordId = actionDetail.Id;
                    this.memberDetail.userRole = actionDetail.AEHC_Role__c;
                    this.memberDetail.userId = actionDetail.AEHC_User__c;
                    this.memberDetail.user = {
                        id: actionDetail.AEHC_User__r.Id,
                        mainField: actionDetail.AEHC_User__r.Name,
                        subField: actionDetail.AEHC_User__r.Email
                    }

                    this.detailModal.isVisible = true;
                } else if (actionName == 'row:delete') {
                    this.confirmModal.userName = actionDetail.userName;
                    this.confirmModal.userRole = actionDetail.AEHC_Role__c;
                    this.confirmModal.recordId = actionDetail.Id;
                    this.confirmModal.isVisible = true;
                }
            }
        } catch (err) {
            // console.log(`handleListViewAction:err`, err);
        }
    }

    // detail modal
    @track detailModal = {
        isVisible: false,
        title: ''
    }

    // confirm modal
    @track confirmModal = {
        isVisible: false,
        title: 'Revoke Membership'
    }

    async handleClick_RemoveMember(event) {
        const dataset = event.currentTarget.dataset;
        if (!dataset) return;

        this.confirmModal.isLoading = true;
        const response = await deleteAssetMemberApex({
            recordId: dataset.recordId
        });
        this.confirmModal.isLoading = false;

        // console.log(`handleClick_RemoveMember`, response)
        if (response.status == 200) {
            this.dispatchEvent(new ShowToastEvent({
                message: response.message,
                variant: 'success',
            }));
            this.confirmModal.isVisible = false;
            this.getMembers();
        } else if (response.status == 400) {
            this.dispatchEvent(new ShowToastEvent({
                message: response.message,
                variant: 'warning',
            }));
        } else {
            this.dispatchEvent(new ShowToastEvent({
                message: response.message,
                variant: 'error',
            }));
        }
    }

    handleClose_Modal(event) {
        const dataset = event.currentTarget.dataset;
        if (!dataset) return;

        this[dataset.modal].isVisible = false;
    }

}