import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSalesforceFields from '@salesforce/apex/CleverTapSyncController.getSalesforceFields';
import saveFieldMappings from '@salesforce/apex/CleverTapSyncController.saveFieldMappings';
import getExistingMappings from '@salesforce/apex/CleverTapSyncController.getExistingMappings';

export default class CtFieldMapping extends NavigationMixin(LightningElement) {
    @api syncId;  // Changed to match the parent component pattern
    @api salesforceEntity;
    @api clevertapEntity;

    @track salesforceFields = [];
    @track mandatoryFieldMapping = { customer_id: '' };
    @track additionalMappings = [];
    @track isLoading = false;

    // Data type options for the dropdown
    dataTypeOptions = [
        { label: 'Text', value: 'Text' },
        { label: 'Number', value: 'Number' },
        { label: 'Date', value: 'Date' },
        { label: 'Boolean', value: 'Boolean' }
    ];

    get showEmptyState() {
        return this.additionalMappings.length === 0;
    }

    connectedCallback() {
        if (this.salesforceEntity) {
            this.loadSalesforceFields();
            this.loadExistingMappings();
        }
    }

    async loadSalesforceFields() {
        try {
            this.isLoading = true;
            const fields = await getSalesforceFields({ objectName: this.salesforceEntity });
            if (fields) {
                this.salesforceFields = fields.map(field => ({
                    label: field.label,
                    value: field.value
                }));
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load Salesforce fields: ' + (error.body?.message || error.message || 'Unknown error'), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadExistingMappings() {
        if (!this.syncId) return;

        try {
            const existingMappings = await getExistingMappings({ syncId: this.syncId });
            if (existingMappings) {
                const mandatoryMapping = existingMappings.find(m => m.Is_Mandatory__c);
                if (mandatoryMapping) {
                    this.mandatoryFieldMapping.customer_id = mandatoryMapping.Salesforce_Field__c;
                }

                this.additionalMappings = existingMappings
                    .filter(m => !m.Is_Mandatory__c)
                    .map(m => ({
                        id: Date.now() + Math.random(),
                        clevertapField: m.CleverTap_Field__c,
                        salesforceField: m.Salesforce_Field__c,
                        dataType: m.Data_Type__c || 'Text'
                    }));
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load existing mappings: ' + (error.body?.message || error.message || 'Unknown error'), 'error');
        }
    }

    handleMandatoryFieldChange(event) {
        this.mandatoryFieldMapping.customer_id = event.detail.value;
    }

    handleClevertapFieldChange(event) {
        const index = parseInt(event.target.dataset.index);
        if (this.additionalMappings[index]) {
            this.additionalMappings[index] = {
                ...this.additionalMappings[index],
                clevertapField: event.target.value
            };
        }
    }

    handleSalesforceFieldChange(event) {
        const index = parseInt(event.target.dataset.index);
        if (this.additionalMappings[index]) {
            this.additionalMappings[index] = {
                ...this.additionalMappings[index],
                salesforceField: event.detail.value
            };
        }
    }

    handleDataTypeChange(event) {
        const index = parseInt(event.target.dataset.index);
        if (this.additionalMappings[index]) {
            this.additionalMappings[index] = {
                ...this.additionalMappings[index],
                dataType: event.detail.value
            };
        }
    }

    handleAddField() {
        this.additionalMappings.push({
            id: Date.now(),
            clevertapField: '',
            salesforceField: '',
            dataType: 'Text'
        });
    }

    handleDeleteMapping(event) {
        const index = parseInt(event.target.dataset.index);
        this.additionalMappings = this.additionalMappings.filter((_, i) => i !== index);
    }

// In ctFieldMapping.js

async handleSave() {
    if (!this.validateMappings()) {
        return;
    }

    try {
        this.isLoading = true;

        const mappingData = {
            syncId: this.syncId,
            mappings: [
                {
                    CleverTap_Field__c: 'customer_id',
                    Salesforce_Field__c: this.mandatoryFieldMapping.customer_id,
                    Data_Type__c: 'Text',
                    Is_Mandatory__c: true
                },
                ...this.additionalMappings
                    .filter(m => m.clevertapField && m.salesforceField)
                    .map(m => ({
                        CleverTap_Field__c: m.clevertapField,
                        Salesforce_Field__c: m.salesforceField,
                        Data_Type__c: m.dataType || 'Text',
                        Is_Mandatory__c: false
                    }))
            ]
        };

        await saveFieldMappings({ 
            mappingData: JSON.stringify(mappingData) 
        });

        this.showToast('Success', 'Field mappings saved successfully', 'success');

        // Navigate to the target page
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'clevertapSyncList'
            },
            state: {
                c__refreshData: 'true',
                c__ts: Date.now() // Add timestamp to force refresh
            }
        });

        // Force full page reload after a short delay
        setTimeout(() => {
            window.location.reload();
        }, 500);

    } catch (error) {
        console.error('Save Error:', error);
        this.showToast('Error', 'Failed to save mappings: ' + (error.body?.message || error.message || 'Unknown error'), 'error');
    } finally {
        this.isLoading = false;
    }
}


handleBack() {
    this[NavigationMixin.Navigate]({
        type: 'standard__navItemPage',
        attributes: {
            apiName: 'clevertapSyncList'
        },
        state: {
            c__refreshData: 'true',
            c__ts: Date.now()
        }
    });
}

handleCancel() {
    this[NavigationMixin.Navigate]({
        type: 'standard__navItemPage',
        attributes: {
            apiName: 'clevertapSyncList'
        },
        state: {
            c__refreshData: 'true',
            c__ts: Date.now()
        }
    });
}

    validateMappings() {
        if (!this.mandatoryFieldMapping.customer_id) {
            this.showToast('Error', 'Please map the mandatory customer_id field', 'error');
            return false;
        }

        const allValid = [...this.template.querySelectorAll('lightning-input,lightning-combobox')]
            .reduce((validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            }, true);

        if (!allValid) {
            return false;
        }

        const clevertapFields = this.additionalMappings
            .filter(m => m.clevertapField)
            .map(m => m.clevertapField.toLowerCase());

        const hasDuplicates = clevertapFields.length !== new Set(clevertapFields).size;
        if (hasDuplicates) {
            this.showToast('Error', 'Duplicate CleverTap field names are not allowed', 'error');
            return false;
        }

        return true;
    }


    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}