import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createSyncConfiguration from '@salesforce/apex/CleverTapSyncController.createSyncConfiguration';
import getSyncConfigurationById from '@salesforce/apex/CleverTapSyncController.getSyncConfigurationById';
import updateSyncConfiguration from '@salesforce/apex/CleverTapSyncController.updateSyncConfiguration';
import getPicklistValues from '@salesforce/apex/CleverTapSyncController.getPicklistValues';

export default class CtSyncConfig extends NavigationMixin(LightningElement) {
    @api recordId;
    @api mode = 'new';
    @api objectName = 'CleverTap_Mapping__c';
    @api fieldName = 'Data_Type__c';
    
    @track picklistOptions = [];
    @track isLoading = false;
    @track syncData = {
        name: '',
        syncType: '',
        salesforceEntity: '',
        clevertapEntity: '',
        status: 'Active'  // Changed to Active for new configurations
    };

    @track showBasicConfig = true;
    @track showFieldMapping = false;
    @track syncId;

    connectedCallback() {
        console.log('Connected callback executing');
        const urlParams = new URL(window.location.href).searchParams;
        this.mode = urlParams.get('c__mode') || 'new';
        const urlRecordId = urlParams.get('c__recordId');
        
        console.log('Mode:', this.mode);
        console.log('URL Record ID:', urlRecordId);
        
        if (this.mode === 'edit' && urlRecordId) {
            this.recordId = urlRecordId;
            this.syncId = urlRecordId;
            console.log('Loading sync configuration for record:', this.recordId);
            this.loadSyncConfiguration();
        }
    }

    async loadSyncConfiguration() {
        if (!this.recordId) {
            console.log('No record ID available');
            return;
        }
        
        try {
            this.isLoading = true;
            console.log('Loading configuration for recordId:', this.recordId);
            
            const result = await getSyncConfigurationById({ syncId: this.recordId });
            console.log('Raw result from server:', JSON.stringify(result));
            
            if (result) {
                this.syncData = {
                    name: result.name || '',
                    syncType: result.syncType || '',
                    salesforceEntity: result.salesforceEntity || '',
                    clevertapEntity: result.clevertapEntity || '',
                    status: result.status || 'Inactive'
                };
                
                console.log('Updated syncData:', JSON.stringify(this.syncData));
                
                // Force a re-render
                this.template.querySelectorAll('lightning-input, lightning-combobox').forEach(element => {
                    if (element.name && this.syncData[element.name] !== undefined) {
                        setTimeout(() => {
                            element.value = this.syncData[element.name];
                        }, 0);
                    }
                });
                
                this.syncId = this.recordId;
            } else {
                console.warn('No data received from server');
                this.showToast('Warning', 'No data found for this configuration', 'warning');
            }
        } catch (error) {
            console.error('Error in loadSyncConfiguration:', error);
            this.showToast('Error', 'Error loading sync configuration: ' + (error.message || error.body?.message || 'Unknown error'), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get syncTypeOptions() {
        return [
            { label: 'Salesforce to CleverTap', value: 'salesforce_to_clevertap' }
        ];
    }

    get salesforceEntityOptions() {
        return [
            { label: 'Contact', value: 'Contact' },
            { label: 'Lead', value: 'Lead' },
            { label: 'Account', value: 'Account' }
        ];
    }

    get clevertapEntityOptions() {
        return [
            { label: 'Profile', value: 'profile' },
            { label: 'Event', value: 'event' }
        ];
    }

    handleNameChange(event) {
        this.syncData.name = event.target.value;
        console.log('Name changed:', this.syncData.name);
    }

    handleSyncTypeChange(event) {
        this.syncData.syncType = event.target.value;
        console.log('Sync type changed:', this.syncData.syncType);
    }

    handleSalesforceEntityChange(event) {
        this.syncData.salesforceEntity = event.target.value;
        console.log('Salesforce entity changed:', this.syncData.salesforceEntity);
    }

    handleClevertapEntityChange(event) {
        this.syncData.clevertapEntity = event.target.value;
        console.log('CleverTap entity changed:', this.syncData.clevertapEntity);
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'clevertapSyncList'
            }
        });
    }

    async handleNext() {
        if (this.validateForm()) {
            try {
                this.isLoading = true;
                console.log('Processing form submission. Mode:', this.mode);
                
                // Ensure status is set for new configurations
                if (this.mode === 'new') {
                    this.syncData.status = 'Active';
                }
                
                console.log('Sync data to submit:', JSON.stringify(this.syncData));
    
                if (this.mode === 'edit') {
                    console.log('Updating existing configuration:', this.recordId);
                    const updatedConfig = await updateSyncConfiguration({
                        syncId: this.recordId,
                        syncData: JSON.stringify(this.syncData)
                    });
                    this.syncId = this.recordId;
                    this.showToast('Success', 'Sync configuration updated successfully', 'success');
                } else {
                    console.log('Creating new configuration');
                    const result = await createSyncConfiguration({
                        syncData: JSON.stringify(this.syncData)
                    });
                    console.log('Created sync configuration with ID:', result);
                    this.syncId = result;
                    this.recordId = result;
                    this.showToast('Success', 'Sync configuration created successfully', 'success');
                }
                
                await new Promise(resolve => setTimeout(resolve, 100));
                
                console.log('Current syncId before showing field mapping:', this.syncId);
                this.showBasicConfig = false;
                this.showFieldMapping = true;
    
                const fieldMappingComponent = this.template.querySelector('c-ct-field-mapping');
                if (fieldMappingComponent) {
                    console.log('Updating field mapping component with syncId:', this.syncId);
                    fieldMappingComponent.syncId = this.syncId;
                }
            } catch (error) {
                console.error('Error in handleNext:', error);
                const action = this.mode === 'edit' ? 'update' : 'create';
                this.showToast('Error', `Failed to ${action} sync configuration: ${error.message || error.body?.message || 'Unknown error'}`, 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    validateForm() {
        const inputFields = this.template.querySelectorAll('lightning-input,lightning-combobox');
        let isValid = true;

        inputFields.forEach(field => {
            if (!field.checkValidity()) {
                field.reportValidity();
                isValid = false;
            }
        });

        if (isValid) {
            if (!this.syncData.name || !this.syncData.syncType || 
                !this.syncData.salesforceEntity || !this.syncData.clevertapEntity) {
                this.showToast('Error', 'Please fill in all required fields', 'error');
                return false;
            }
        }

        console.log('Form validation result:', isValid);
        return isValid;
    }
    
    handleMappingSave(event) {
        console.log('Mapping save event received:', event);
        this.showToast('Success', 'Field mappings saved successfully', 'success');
        
        // Navigate to sync list with a state param to force refresh
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'clevertapSyncList'
            },
            state: {
                c__refresh: 'true'
            }
        });
    }

    handleBack() {
        // Navigate to sync list with a state param to force refresh
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'clevertapSyncList'
            },
            state: {
                c__refresh: 'true'
            }
        });
    }

    handleCancel() {
        // Use the same navigation method
        this.handleBack();
    }

    showToast(title, message, variant) {
        console.log('Showing toast:', { title, message, variant });
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}