import { LightningElement, api, track } from 'lwc';
import getAssets from '@salesforce/apex/AEHC_EmailController.getAssets';
import getAssociatedUsers from '@salesforce/apex/AEHC_EmailController.getAssociatedUsers';
import sendEmail from '@salesforce/apex/AEHC_EmailController.sendEmail';

import USER_ID from '@salesforce/user/Id';
import IS_GUEST from '@salesforce/user/isGuest';
import { wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
export default class AehcSendEmail extends LightningElement {

    @api orgWideEmailId;

    @track showPopup = false;
    ccEmails = '';

    assetOptions = [];
    filteredAssets = [];
    searchTerm = '';
    selectedAssetId;

    @track users = [];
    selectedContacts = [];
    loggedInUserName = '';

    subject = '';
    body = '';

    formats = ['bold', 'italic', 'underline', 'list', 'link'];

    // ✅ USER VISIBILITY
    get showEmailButton() {
        return USER_ID != null && !IS_GUEST;
    }

    connectedCallback() {
        this.loadAssets();
    }

    @wire(getRecord, {
        recordId: USER_ID,
        fields: [NAME_FIELD]
    })
    wiredUser({ data, error }) {
        if (data) {
            this.loggedInUserName = data.fields.Name.value;
        }
    }
    togglePopup() {
        this.showPopup = !this.showPopup;
    }

    loadAssets() {

        getAssets()
            .then(res => {

                this.assetOptions = (res || []).map(a => ({
                    label: `${a.name} (${a.type})`,
                    value: a.assetId
                }));

                this.filteredAssets = this.assetOptions;
            })
            .catch(error => {

                console.error(error);

                this.assetOptions = [];
                this.filteredAssets = [];
            });
    }


    handleCcChange(event) {
        this.ccEmails = event.target.value;
    }

    handleSearch(e) {

        const value = e.target.value;

        this.searchTerm = value.toLowerCase();

        this.clearSelectedUsers();

        this.filteredAssets = this.searchTerm
            ? this.assetOptions.filter(a =>
                a.label.toLowerCase().includes(this.searchTerm))
            : this.assetOptions;
    }

    handleAssetSelect(e) {
        this.clearSelectedUsers();
        this.selectedAssetId = e.currentTarget.dataset.id;

        const selected = this.assetOptions.find(
            a => a.value === this.selectedAssetId
        );

        this.searchTerm = selected.label;
        this.filteredAssets = [];

        getAssociatedUsers({ assetId: this.selectedAssetId })
            .then(res => {

                this.users = (res || []).map(u => ({
                    ...u,
                    checked: false
                }));

                this.selectedContacts = [];
            })
            .catch(error => {

                console.error(error);

                this.users = [];
                this.selectedContacts = [];

                alert('Unable to load associated users.');
            });
    }

    get showNoResults() {
        return this.searchTerm &&
            this.filteredAssets.length === 0 &&
            !this.selectedAssetId;
    }

    get selectedUserNames() {
        return this.users
            .filter(u => u.checked)
            .map(u => u.name)
            .join(', ');
    }


    handleCheckbox(e) {
        const userId = e.target.dataset.id;
        const checked = e.target.checked;

        let set = new Set(this.selectedContacts);

        this.users = this.users.map(u => {
            if (u.userId === userId) {
                u.checked = checked;
                checked ? set.add(u.contactId) : set.delete(u.contactId);
            }
            return u;
        });

        this.selectedContacts = [...set];
        this.users = [...this.users];
    }

    handleSelectAll(e) {
        const checked = e.target.checked;

        this.users = this.users.map(u => {
            u.checked = checked;
            return u;
        });

        this.selectedContacts = checked
            ? this.users.map(u => u.contactId)
            : [];
        this.users = [...this.users];
    }

    handleSubject(e) {
        this.subject = e.target.value;
    }

    handleBody(e) {
        let value = e.target.value;
        value = value.replace(/text-align:\s*(center|right|justify);?/gi, '');
        this.body = value;
    }

    validateInputs() {

        if (!this.selectedAssetId)
            return alert('Select Application or Publication'), false;

        if (!this.selectedContacts.length) return alert('Select user'), false;
        if (!this.subject) return alert('Enter subject'), false;
        if (!this.body) return alert('Enter body'), false;
        if (this.ccEmails) {

            const invalidEmails = this.ccEmails
                .split(',')
                .map(e => e.trim())
                .filter(
                    e => !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)
                );

            if (invalidEmails.length) {
                alert(
                    'Invalid CC Email(s): ' +
                    invalidEmails.join(', ')
                );
                return false;
            }
        }

        return true;
    }

    handleSend() {
        if (!this.validateInputs()) return;

        let finalBody = `
        <div>
            ${this.body}
        </div>
    `;


        sendEmail({
            contactIds: this.selectedContacts,
            subject: this.subject,
            body: finalBody,
            orgWideEmailId: this.orgWideEmailId,
            ccEmails: this.ccEmails
                ? this.ccEmails
                    .split(',')
                    .map(e => e.trim())
                    .filter(e => e)
                : []
        }).then(() => {
            alert('Email Sent');
            this.resetForm();
            this.showPopup = false;
        })
            .catch(error => {

                console.error(error);

                alert('Unable to send email.');
            });

    }

    resetForm() {
        this.subject = '';
        this.body = '';
        this.ccEmails = '';
        this.searchTerm = '';
        this.selectedAssetId = undefined;
        this.clearSelectedUsers();
    }
    clearSelectedUsers() {

        this.users = [];
        this.selectedContacts = [];
        this.selectedAssetId = null;

        const allUsersCheckbox =
            this.template.querySelector('#allUsers');

        if (allUsersCheckbox) {
            allUsersCheckbox.checked = false;
        }
    }
}